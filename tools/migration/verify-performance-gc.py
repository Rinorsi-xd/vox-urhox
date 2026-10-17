"""Measure real collector/retirement bindings with deterministic service costs."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FIXTURE = r'''
local clock,checks,mode=0,0,'generational'
local complete=false
local function check(ok,label)assert(ok,label);checks=checks+1 end
local calls={}
collectgarbage=function(action,size)
 calls[#calls+1]={action,size}
 if action=='count' then return 123 end
 if action=='incremental' then local previous=mode;mode=action;clock=clock+7;return previous end
 if action=='generational' then local previous=mode;mode=action;clock=clock+3;return previous end
 if action=='step' then clock=clock+11;return complete end
 if action=='collect' then clock=clock+13;return 0 end
 error('Unexpected collector action '..action)
end
local C=assert(load(CYCLE_SOURCE,'@core/CollectionCycle.lua'))()
local modules={['core.CollectionCycle']=C}
require=function(name)modules[name]=modules[name]or{};return modules[name]end
local RT=assert(load(RETIRE_SOURCE,'@render/RenderTargetLifetime.lua'))()
modules['render.RenderTargetLifetime']=RT
local Bindings=assert(load(BINDINGS_SOURCE,'@diagnostics/PerformanceBindings.lua'))()
local Monitor=assert(load(MONITOR_SOURCE,'@diagnostics/PerformanceMonitor.lua'))()
Time={GetSystemTime=function()return clock end}
renderer={GetNumBatches=function()return 0 end,GetNumPrimitives=function()return 0 end}
cache={GetTotalMemoryUse=function()return 0 end,GetNumBackgroundLoadResources=function()return 0 end}
local app={mode='hangar'}
local monitor=Monitor.New{clock=function()return clock end,noFile=true,sink=function()end}
Bindings.Attach(monitor,app)
local before=RT.Update
Bindings.Attach(monitor,app)
check(before==RT.Update,'retirement wrappers idempotent')
local surface={SetNumViewports=function(_,n)check(n==0,'retire detaches views')end}
local texture={GetRenderSurface=function()return surface end,
 Dispose=function()error('live borrower must not be disposed')end}
monitor:BeginFrame(.016)
RT.Retire(texture)
check(Bindings.Context(app).retiredTargets==1,'pending target count reaches real frame context')
RT.Update();RT.Update();RT.Update()
local function ms(name,value)
 local s=monitor.stages[name];check(s and s.ms==value,name..' inclusive time '..value)
 return s
end
ms('gc.EnterIncremental',7);ms('gc.Advance',11)
local step=ms('gc.Step',18)
check(step.selfMs==0,'GC parent excludes separately measured collector children')
ms('retirement.Update',18)
check(#calls>=2 and calls[1][1]=='count','context still performs original memory observation')
local commands={}
for _,call in ipairs(calls)do if call[1]~='count'then commands[#commands+1]=call end end
check(#commands==2 and commands[1][1]=='incremental' and commands[2][1]=='step'
 and commands[2][2]==128,'same collector mode/step order and budget')
check(C.State().active and C.Epoch()==0 and mode=='incremental','incomplete cycle state retained')
complete=true
RT.Update();RT.Update();RT.Update()
ms('gc.EnterIncremental',7);ms('gc.Advance',22);ms('gc.Restore',3)
ms('gc.Step',32)
check(C.Epoch()==1 and not C.State().active and mode=='generational','completed cycle restores prior mode')
RT.Flush()
ms('retirement.Flush',13);ms('gc.Collect',13)
check(C.Epoch()==2 and RT.PendingCount()==1,'flush retains live external borrower')
monitor:EndFrame(Bindings.Context(app))
monitor:Dispose()
check(RT.Update~=before,'diagnostic dispose removes retirement wrapper')
return checks
'''


def run(cycle):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().CYCLE_SOURCE = cycle
    for key, relative in {
        'RETIRE_SOURCE': 'render/RenderTargetLifetime.lua',
        'BINDINGS_SOURCE': 'diagnostics/PerformanceBindings.lua',
        'MONITOR_SOURCE': 'diagnostics/PerformanceMonitor.lua',
    }.items():
        lua.globals()[key] = (ROOT / 'scripts' / relative).read_text('utf8')
    return lua.execute(FIXTURE)


cycle_path = ROOT / 'scripts/core/CollectionCycle.lua'
checks = run(cycle_path.read_text('utf8'))
before = subprocess.check_output([
    'git', 'show', 'f94827b26fc12b707e6d6904d093e16358caaf41:scripts/core/CollectionCycle.lua'
], cwd=ROOT, text=True)
try:
    run(before)
except Exception as error:
    assert 'gc.EnterIncremental inclusive time' in str(error), str(error)
    negative = str(error).splitlines()[0]
else:
    raise AssertionError('Old undivided collector unexpectedly supplies subphase timing')
print(json.dumps({
    'result': 'PASS', 'checks': checks, 'negativeControl': negative,
    'collectionSha256': hashlib.sha256(cycle_path.read_bytes()).hexdigest(),
    'boundary': 'Actual monitor, bindings, collection and retirement modules; deterministic collector service costs. No runtime speed or native finalizer claim.'
}, indent=2))
