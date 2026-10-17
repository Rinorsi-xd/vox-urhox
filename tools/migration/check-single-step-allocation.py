"""Offline Lua54 observer/lifecycle verification; does not launch game hardware."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().FactorySource = (ROOT / 'tools/migration/qa-single-step-allocation.lua').read_text(encoding='utf8')
probe = (ROOT / 'tools/migration/vehicle-allocation-probe.lua').read_text(encoding='utf8')
lua.eval('function(s) assert(load(s)) end')(probe)
bindings = re.findall(r"\{'([\w.]+)','(\w+)'\}", probe)
for module, method in bindings:
    source = (ROOT / 'scripts' / (module.replace('.', '/') + '.lua')).read_text(encoding='utf8')
    assert re.search(r'function\s+\w+[.:]' + re.escape(method) + r'\s*\(', source), (module, method)

result = lua.execute(r'''
local Factory=assert(load(FactorySource))()
local checks=0
local function Check(v,label) assert(v,label);checks=checks+1 end
local function Fixture(options)
    local c={kb=1000,running=true,time=0,ops={}}
    function c.gc(op)
        c.ops[#c.ops+1]=op
        if op=='count' then return c.kb elseif op=='isrunning' then return c.running
        elseif op=='stop' then c.running=false elseif op=='restart' then c.running=true
        else error('Unexpected collector mode mutation: '..tostring(op))end
    end
    c.p=Factory.New{gc=c.gc,clock=function()return c.time end,capacity=options and options.capacity or 8,
        limitKiB=options and options.limitKiB or 16384,deadlineMs=250}
    return c
end
do
    local c=Fixture();local api={}
    api.Child=function(a,b,d)c.kb=c.kb+3;return a,b,d end
    api.Parent=function(a,b,d)c.kb=c.kb+2;local x,y,z=api.Child(a,b,d);c.kb=c.kb+5;return x,y,z end
    local parent,child=api.Parent,api.Child
    c.p:Wrap(api,'Parent','parent');c.p:Wrap(api,'Child','child')
    local calls=0
    c.p:Capture(1,function()calls=calls+1;local a,b,d=api.Parent(4,nil,false);Check(a==4 and b==nil and d==false,'nil/false contract')end)
    local r=c.p:Report()
    Check(calls==1,'one Capture calls fixed-step exactly once')
    Check(r.frames[1].complete and r.frames[1].restored and c.running,'successful step restores collector')
    Check(r.totals[1].inclusiveKiB==10 and r.totals[1].selfKiB==7,'parent inclusive and exclusive allocation')
    Check(r.totals[2].inclusiveKiB==3 and r.totals[2].maxKiB==3,'child allocation and max')
    Check(r.frames[1].netKiB==10 and r.frames[1].unscopedKiB==0,'complete-step conservation')
    Check(r.allocationValidity=='COMPLETE_SAMPLES_ONLY' and r.timingValidity=='INVALID_FOR_PERFORMANCE','allocation only validity')
    for _,op in ipairs(c.ops)do Check(op=='count' or op=='isrunning' or op=='stop' or op=='restart','never changes collector mode')end
    c.p:Restore();Check(api.Parent==parent and api.Child==child,'all original methods restored')
end
do
    local c=Fixture();local one={Read=function()c.kb=c.kb+2 end};local two={Read=function()c.kb=c.kb+4 end}
    c.p:Wrap(one,'Read','body.read');c.p:Wrap(two,'Read','body.read')
    c.p:Capture(1,function()one.Read();two.Read()end)
    local r=c.p:Report();Check(#r.names==1 and r.totals[1].calls==2 and r.totals[1].inclusiveKiB==6,'aggregate body methods share owner row')
    c.p:Restore()
end
do
    local c=Fixture();local sentinel={};local api={Fail=function()c.kb=c.kb+3;error(sentinel)end}
    c.p:Wrap(api,'Fail','fail');local ok,err=pcall(c.p.Capture,c.p,1,api.Fail)
    Check(not ok and err==sentinel,'original error identity preserved')
    local r=c.p:Report();Check(c.running and r.restored and c.p.depth==0,'exception collector and stack restored')
    Check(not r.frames[1].complete and r.totals[1].errors==1 and r.allocationValidity=='INVALID_ABORTED_CAPTURE','partial allocation cannot rank')
    c.p:Restore()
end
do
    local c=Fixture({limitKiB=16});local api={Inner=function()c.kb=c.kb+17 end}
    api.Outer=function()api.Inner()end
    c.p:Wrap(api,'Outer','outer');c.p:Wrap(api,'Inner','inner')
    local ok=pcall(c.p.Capture,c.p,1,api.Outer);local r=c.p:Report()
    Check(not ok and c.running and r.restored and r.aborted,'growth limit restores before abort')
    Check(c.p.depth==0 and not r.frames[1].complete and r.allocationValidity=='INVALID_ABORTED_CAPTURE','outer unwinding is explicitly invalid')
    Check(not pcall(c.p.Capture,c.p,2,api.Outer),'cannot keep sampling after abort')
    c.p:Restore()
end
do
    local c=Fixture();local api={Run=function()c.time=251 end};c.p:Wrap(api,'Run','run')
    Check(not pcall(c.p.Capture,c.p,1,api.Run) and c.running,'deadline restores collector')
    Check(c.p:Report().aborted and c.p.depth==0,'deadline marks allocation invalid')
    c.p:Restore()
end
do
    local c=Fixture();c.running=false
    Check(not pcall(c.p.Capture,c.p,1,function()end),'initial stopped collector refused')
    Check(not c.running and c.p.count==0,'refusal preserves original stopped state')
end
do
    local c=Fixture({capacity=1});c.p:Capture(1,function()end)
    Check(not pcall(c.p.Capture,c.p,2,function()end) and c.running,'capacity guard preserves running collector')
end
do
    local c=Fixture();local api={Run=function()end};c.p:Wrap(api,'Run','run')
    Check(not pcall(c.p.Wrap,c.p,api,'Run','duplicate'),'duplicate object/key rejected')
    local external=function()return 7 end;api.Run=external;c.p:Restore()
    Check(api.Run==external,'wrapper restore does not overwrite external replacement')
end
-- Real Lua allocator verifies the observer does not allocate per wrapped no-op.
do
    local p=Factory.New{gc=collectgarbage,clock=function()return 0 end,capacity=1}
    local api={Read=function(a,b,d)return a,b,d end};p:Wrap(api,'Read','noop')
    p:Capture(1,function()for _=1,10000 do local a,b,d=api.Read(1,nil,false);assert(a==1 and b==nil and d==false)end end)
    local r=p:Report();Check(r.totals[1].calls==10000,'real Lua noop coverage')
    Check(r.frames[1].netKiB<4 and r.frames[1].netKiB>=0,'no per-call token/result table allocations')
    Check(collectgarbage('isrunning'),'real collector restored');p:Restore()
end
return {status='PASS',checks=checks,boundary='Offline factory behavior and actual Lua54 allocator no-op checks only. No Native/Web/hardware or game performance run.'}
''')
out = dict(result)
out['validatedExistingModuleBoundaries'] = len(bindings)
print(json.dumps(out, ensure_ascii=False))
