"""Offline Lua 5.4 accounting and lifecycle checks; no engine/GPU timing."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ProbeSource = (ROOT / 'tools/migration/qa-allocation-owners.lua').read_text(encoding='utf-8')
result = lua.execute(r'''
local Factory=assert(load(ProbeSource))()
local checks=0
local noOpNetKiB=false
local function Check(v,label) assert(v,label);checks=checks+1 end
local function Fixture(real)
    local c={kb=1000,running=true,phase='A1',frame=1,gcCalls={}}
    c.gc=function(op)
        c.gcCalls[#c.gcCalls+1]=op
        if op=='count' then return c.kb end
        if op=='isrunning' then return c.running end
        error('Observer must never mutate collector state: '..tostring(op))
    end
    c.probe=Factory.New{gc=real and collectgarbage or c.gc,phase=function()return c.phase end,frame=function()return c.frame end}
    c.probe.prepared=true;c.probe.trialPrepared=true
    function c:Start() self.phase='B';self.running=false;Check(self.probe:BeginFrame(),'B frame starts') end
    function c:Finish() Check(self.probe:EndFrame(),'B frame ends');self.phase='recovery';self.running=true end
    return c
end
do
    local c=Fixture();Check(#c.gcCalls==0,'factory does not query or mutate collector')
    local api={Child=function(a,b,d)c.kb=c.kb+3;return a,b,d end}
    api.Parent=function()c.kb=c.kb+2;local a,b,d=api.Child(4,nil,false);Check(a==4 and b==nil and d==false,'nil/false return contract');c.kb=c.kb+5 end
    c.probe:Wrap(api,'Parent','parent');c.probe:Wrap(api,'Child','child')
    Check(not c.probe:BeginFrame() and #c.gcCalls==0,'A1 dormant hooks do not query heap')
    api.Parent();Check(c.probe.count==0,'A1 calls are not measured')
    c:Start();c.kb=c.kb+7;api.Parent();c.kb=c.kb+11;c:Finish()
    local r=c.probe:Report();local p,ch=r.totals[1],r.totals[2]
    Check(p.calls==1 and p.inclusiveKiB==10 and p.selfKiB==7,'parent includes child and self excludes child')
    Check(ch.calls==1 and ch.inclusiveKiB==3 and ch.selfKiB==3,'child exact allocation')
    Check(r.frames[1].netKiB==28 and r.frames[1].measuredKiB==10 and r.frames[1].unscopedKiB==18,'frame conservation and explicit unscoped allocation')
    Check(p.selfKiB+ch.selfKiB==r.frames[1].measuredKiB,'nested self allocation conservation')
    Check(not r.invalid,'valid nested frame')
    c.probe:RestoreWrappers();Check(api.Child(1,nil,false)==1,'original callable restored')
    for _,op in ipairs(c.gcCalls)do Check(op=='count' or op=='isrunning','heap observer read-only collector')end
end
do
    local c=Fixture();local sentinel={};local original=function()c.kb=c.kb+6;error(sentinel)end
    local api={Fail=original};c.probe:Wrap(api,'Fail','fail');c:Start()
    local ok,err=pcall(api.Fail);Check(not ok and err==sentinel,'error identity preserved')
    Check(c.probe.depth==0,'to-close guard unwinds errors');c:Finish()
    local r=c.probe:Report();Check(r.totals[1].errors==1 and r.totals[1].inclusiveKiB==6,'error allocation recorded')
    c.probe:RestoreWrappers();Check(api.Fail==original,'error wrapper restored')
end
do
    local c=Fixture();local api={Run=function()c.frame=c.frame+1 end};c.probe:Wrap(api,'Run','run');c:Start();api.Run();c:Finish()
    Check(c.probe:Report().invalid,'cross-frame scope cannot masquerade as valid accounting')
end
do
    local c=Fixture();c.phase='B';Check(not c.probe:BeginFrame(),'running collector cannot start sample')
    Check(c.probe.invalid and c.probe.count==0,'running collector sample rejected')
end
do
    local c=Fixture();local api={Run=function()end};c.probe:Wrap(api,'Run','run')
    for i=1,64 do c.frame=i;c:Start();api.Run();c:Finish() end
    c.phase='B';c.running=false;Check(not c.probe:BeginFrame() and c.probe.invalid,'bounded frame capacity refuses overflow')
    Check(#c.probe:Report().frames==64,'frame capacity is retained exactly')
end
do
    local c=Fixture();local api={Run=function()end};c.probe:Wrap(api,'Run','run')
    local ok=pcall(c.probe.Wrap,c.probe,api,'Run','again');Check(not ok,'duplicate method wrapper rejected')
    c:Start();api.Run();c:Finish()
    ok=pcall(c.probe.Wrap,c.probe,{Run=function()end},'Run','late');Check(not ok,'late binding after B rejected')
end
do
    local c=Fixture();c.probe.prepared=false;c.probe.trialPrepared=false
    local noop=function()end
    local callbacks={HandleUpdate=noop,HandlePostUpdate=noop,HandleFramePresented=noop}
    local ui={Update=noop,Layout=noop,Render=noop,UpdateInspector=noop}
    local absent={Update=noop,Layout=noop,Render=noop}
    Check(not pcall(c.probe.PrepareCallbacks,c.probe,callbacks,absent),'missing UI boundary rejected')
    Check(#c.probe.bindings==0 and callbacks.HandleUpdate==noop,'callback preparation validates atomically')
    c.probe:PrepareCallbacks(callbacks,ui);Check(#c.probe.bindings==7,'all existing seven frame callbacks prepared')
    local modules={}
    local function Load(name)
        if not modules[name] then modules[name]=setmetatable({},{__index=function(t,k)rawset(t,k,noop);return noop end})end
        return modules[name]
    end
    local app={trial={world={units={1,2,3,4,5,6,7,8}},battle={},hud={Update=noop}}}
    c.probe:PrepareTrial(app,Load)
    Check(#c.probe.bindings==33 and c.probe.trialPrepared,'all thirty-three owner boundaries prepared')
    c:Start();callbacks.HandleUpdate();modules['combat.BattleController'].BeforeStep();app.trial.hud.Update();c:Finish()
    local r=c.probe:Report();Check(r.totals[1].calls==1 and r.totals[8].calls==1 and r.totals[33].calls==1,'actual bound methods route to expected owner ids')
    local external=function()return 'external'end;ui.Update=external
    c.probe:RestoreWrappers();Check(ui.Update==external and callbacks.HandleUpdate==noop,'restore respects externally changed function ownership')
end
-- Actual Lua allocator exercise. No timing or engine allocation attribution.
do
    local c=Fixture(true);local api={Run=function()return 1,nil,false end}
    c.probe:Wrap(api,'Run','no-op');collectgarbage('collect');collectgarbage('stop')
    local ok,err=pcall(function()
        c:Start()
        for _=1,10000 do local a,b,d=api.Run();assert(a==1 and b==nil and d==false)end
        c:Finish()
    end)
    collectgarbage('restart');assert(ok,err)
    local r=c.probe:Report()
    noOpNetKiB=r.frames[1].netKiB
    Check(r.totals[1].calls==10000,'actual Lua allocator call coverage')
    Check(math.abs(r.frames[1].netKiB)<4,'reused observer does not allocate per no-op call')
    Check(not r.invalid,'actual stopped Lua allocator frame valid')
end
return {checks=checks,noOpCalls=10000,noOpNetKiB=noOpNetKiB,boundary='Offline actual factory in Lua 5.4; mocked exact owner accounting plus real Lua allocator no-op exercise. No engine/GPU/gameplay/FPS or device evidence.'}
''')
print(json.dumps(dict(result), ensure_ascii=False))
