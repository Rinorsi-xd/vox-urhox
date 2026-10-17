"""Offline Lua 5.4 state-machine/restore controls; never launches UrhoX/GPU."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ProbeSource = (ROOT / 'tools/migration/qa-auto-gc-aba.lua').read_text(encoding='utf-8')
result = lua.execute(r'''
local factory=assert(load(ProbeSource))()
local checks=0
local cases={}
local function Check(value,label)
    assert(value,label);checks=checks+1
end
local function Fixture(options)
    local c={time=0,frame=0,kb=1024,running=true,mode='generational',calls={},signature='eight-unchanged',gate=false}
    local function GC(op)
        c.calls[#c.calls+1]=op or 'collect'
        if op=='count' then return c.kb elseif op=='isrunning' then return c.running end
        if op=='incremental' or op=='generational' then local old=c.mode;c.mode=op;return old end
        if op=='stop' then c.running=false elseif op=='restart' then c.running=true end
        if c.throw and c.throw==op then error('controlled GC exception') end
        return 77
    end
    c.original=GC;c.global=GC
    local env={gc=GC,clock=function()return c.time end,frame=function()return c.frame end,
        getGlobal=function()return c.global end,setGlobal=function(v)c.global=v end,
        gate=function()if c.gateThrow then error('controlled gate exception')end;return c.gate,c.signature end}
    c.probe=factory.New(env,options)
    function c:Tick(ms)
        self.frame=self.frame+1;self.probe:Safe('BeginFrame');self.time=self.time+(ms or 100);self.probe:Safe('EndFrame')
    end
    function c:Until(phase)
        for _=1,150 do if self.probe.phase==phase then return end;self:Tick() end
        error('phase not reached: '..phase..' actual '..self.probe.phase)
    end
    function c:Restored(label)
        Check(not self.probe.active and self.probe.restored,label..' acknowledged')
        Check(self.running and self.mode=='generational',label..' original collector restored')
        Check(self.global==self.original,label..' original global restored')
    end
    return c
end
do
    local c=Fixture();Check(#c.calls==0,'factory has no collector side effects')
    c:Tick();Check(#c.calls==0 and c.probe.phase=='off','dormant frame hooks do not touch GC')
    Check(c.probe:Arm(),'explicit arm');c:Until('B')
    Check(not c.running and c.mode=='generational','B only disables automatic GC, preserves mode')
    c:Until('done');c:Restored('normal completion')
    Check(c.probe.framesB==12,'B wall boundary at 1200ms')
    Check(#c.probe.explicitCalls==0,'own diagnostic GC commands excluded from contamination list')
    Check(c.probe:Arm()==false,'single-use probe cannot rearm')
    cases[#cases+1]='normal/default/single-use'
end
for _,reason in ipairs({'menu','loading','lost focus','retirement pending','not eight vehicles'}) do
    local c=Fixture();c.gate=reason
    Check(c.probe:Arm()==false,'initial gate rejected '..reason)
    Check(#c.calls==0 and c.global==c.original,'initial gate preserves collector '..reason)
    c.gate=false;c.probe:Arm();c:Until('B');c.gate=reason;c:Tick();c:Restored('runtime gate '..reason)
    cases[#cases+1]=reason
end
for _,which in ipairs({'growth','absolute','roster-change','dead','unexpected-stop','exception','missing-begin','deadline'}) do
    local c=Fixture();c.probe:Arm();c:Until('B')
    if which=='growth' then c.kb=c.kb+16385
    elseif which=='absolute' then c.kb=131073
    elseif which=='roster-change' then c.signature='part removed'
    elseif which=='dead' then c.gate='vehicle died'
    elseif which=='unexpected-stop' then c.running=true
    elseif which=='exception' then c.gateThrow=true
    elseif which=='missing-begin' then c.probe:Safe('EndFrame')
    elseif which=='deadline' then c:Tick(1501) end
    if which~='missing-begin' and which~='deadline' then c:Tick() end
    Check(c.probe.phase=='invalid','invalid on '..which);c:Restored(which)
    cases[#cases+1]=which
end
for _,op in ipairs({'step','collect','stop','restart','incremental','generational','nil-default'}) do
    local c=Fixture();c.probe:Arm();c:Until('B')
    if op=='nil-default' then c.global() else c.global(op) end
    Check(c.probe.phase=='invalid' and #c.probe.explicitCalls==1,'explicit operation invalidates '..op)
    c:Restored('explicit '..op);cases[#cases+1]='explicit '..op
end
do
    local c=Fixture();c.running=false
    Check(c.probe:Arm()==false and not c.running,'initial stopped collector is never restarted')
    c=Fixture();c.probe:Arm();c:Until('B');c.throw='step'
    Check(not pcall(c.global,'step'),'explicit collector exception forwarded');c:Restored('explicit throw')
    c=Fixture();c.probe:Arm();c:Until('B');local owner=function()end;c.global=owner;c:Tick()
    Check(c.probe.restored and c.running and c.global==owner,'later global owner preserved while original collector restored')
    c=Fixture({bFrames=3,bMs=999999});c.probe:Arm();c:Until('recovery')
    Check(c.probe.framesB==3,'independent B frame cap');c.probe:Abort('cancel');c:Restored('cancel')
    c=Fixture();c.probe:Arm();c:Until('B');c.probe:Abort('Runtime Stop');c:Restored('Stop')
    cases[#cases+1]='refusal/exception/ownership/framecap/cancel/Stop'
end
-- Execute the actual Lua 5.4 collector as well as the deterministic negative controls.
do
    local previous=collectgarbage('generational');collectgarbage('restart')
    local clock,frame=0,0;local original=collectgarbage;local global=original
    local p=factory.New({gc=original,clock=function()return clock end,frame=function()return frame end,
        getGlobal=function()return global end,setGlobal=function(v)global=v end,gate=function()return nil,'eight' end})
    Check(p:Arm(),'real Lua54 arm')
    for _=1,120 do
        frame=frame+1;p:Safe('BeginFrame');clock=clock+100;p:Safe('EndFrame')
        if p.phase=='B' then Check(not original('isrunning'),'real Lua54 B stopped') end
        if p.phase=='done' then break end
    end
    Check(p.phase=='done' and p.restored and original('isrunning') and global==original,'real Lua54 completion/restoration')
    Check(original('generational')=='generational','real Lua54 original mode restored')
    original(previous)
    cases[#cases+1]='actual Lua54 collector'
end
return {checks=checks,cases=cases}
''')

checks = result['checks']
cases = [result['cases'][i] for i in range(1, len(result['cases']) + 1)]
suffix = subprocess.check_output(
    ['node', '-e', "process.stdout.write(require('./tools/migration/run-auto-gc-aba.cjs').suffix())"],
    cwd=ROOT, encoding='utf-8')
empty_game_observer_kib = None
allocation_suffix = subprocess.check_output(
    ['node', '-e', "process.stdout.write(require('./tools/migration/run-auto-gc-aba.cjs').suffix({allocation:true}))"],
    cwd=ROOT, encoding='utf-8')
scenarios = ['complete', 'Stop', 'Update-error', 'PostUpdate-error', 'presented-error', 'cancel']
for scenario, with_allocation in [(s, a) for a in [False, True] for s in scenarios]:
    control = LuaRuntime(unpack_returned_tuples=True)
    control.execute(r'''
local now,frame=0,0
Time={GetSystemTime=function()return now end};GetTime=function()return {frameNumber=frame}end
KEY_F10=10;KEY_F11=11;KEY_W=87;MOUSEB_LEFT=1
local keys={};input={focus=true,minimized=false,GetKeyPress=function(_,k)return keys[k]end,
    GetKeyDown=function()return true end,GetMouseButtonDown=function()return true end}
local entries,units={},{}
for i=1,8 do
 local u={alive=true,vehicle={body=true},bp={Size=function()return 12 end}}
 entries[i]={unit=u};units[i]=u
end
VOX_HANGAR={app={loadingFlow={active=false},trial={pointer={captured=true},controls={held={fire=true}},
    battle={entries=entries,rules={state='live',round=1}},world={units=units},hud={Update=function()end}}}}
local modules={}
require=function(id)
 if id=='core.CollectionCycle' then return {State=function()return {}end} end
 if id=='render.RenderTargetLifetime' then return {PendingCount=function()return 0 end} end
 if not modules[id] then modules[id]=setmetatable({},{__index=function(t,k)local f=function()end;rawset(t,k,f);return f end})end
 return modules[id]
end
cjson={encode=function(value)lastReport=value;return 'test-report'end};print=function()end
updateThrow=false;postThrow=false;presentedThrow=false;stops=0
function HandleUpdate()if updateThrow then error('controlled update error')end;now=now+100 end
function HandlePostUpdate()if postThrow then error('controlled post error')end end
function HandleFramePresented()if presentedThrow then error('controlled presented error')end end
function Stop()stops=stops+1 end
originalCollector=collectgarbage
function TestFrame(key)
 keys={[key or 0]=true};frame=frame+1;HandleUpdate();HandlePostUpdate();HandleFramePresented()
end
''')
    control.execute(allocation_suffix if with_allocation else suffix)
    assert control.eval("VOX_QA_AUTO_GC_ABA.phase=='off' and collectgarbage==originalCollector")
    control.execute("TestFrame(KEY_F10);for i=1,50 do if VOX_QA_AUTO_GC_ABA.phase=='B' then break end;TestFrame()end")
    assert control.eval("VOX_QA_AUTO_GC_ABA.phase=='B' and not originalCollector('isrunning')")
    if scenario == 'complete':
        control.execute("calibrationStart=originalCollector('count');for i=1,10 do TestFrame()end;calibrationKiB=originalCollector('count')-calibrationStart")
        if not with_allocation:
            empty_game_observer_kib = control.globals().calibrationKiB
        control.execute("for i=1,100 do TestFrame();if VOX_QA_AUTO_GC_ABA.phase=='done' then break end end")
        assert control.eval("VOX_QA_AUTO_GC_ABA.phase=='done'")
    elif scenario == 'Stop':
        control.execute('Stop()')
        assert control.eval('stops==1')
    elif scenario == 'cancel':
        control.execute('TestFrame(KEY_F11)')
    else:
        control.execute({'Update-error': 'updateThrow', 'PostUpdate-error': 'postThrow', 'presented-error': 'presentedThrow'}[scenario] + '=true')
        assert not control.eval('pcall(TestFrame)')[0]
    assert control.eval("VOX_QA_AUTO_GC_ABA.restored and originalCollector('isrunning') and collectgarbage==originalCollector")
    if with_allocation:
        assert control.eval('lastReport.allocation.bindingCount==33 and not lastReport.allocation.invalid')
    checks += 4
    cases.append('actual suffix ' + ('allocation ' if with_allocation else '') + scenario)
subprocess.run(['node', 'tools/migration/run-auto-gc-aba.cjs', '--self-test'], cwd=ROOT, check=True)
print(json.dumps({'result': 'PASS', 'checks': checks, 'cases': cases,
                  'new_suffix_empty_game_10_frame_allocation_kib': empty_game_observer_kib,
                  'calibration_boundary': 'Actual new Lua suffix with mocked eight-vehicle gate and empty Update/Presented only; excludes engine bindings, existing pipeline, UI, QA dumps and production simulation. Not subtracted from real measurements.',
                  'boundary': 'Offline Lua54/Lupa and exact QA integration controls only. No engine, real battle, GPU, performance gain or Snapdragon845 evidence.'}, ensure_ascii=False))
