"""Exercise real monitor/bindings; deterministic clocks verify attribution, not speed."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE_COMMIT = 'f94827b26fc12b707e6d6904d093e16358caaf41'
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

BINDINGS = ROOT / 'scripts/diagnostics/PerformanceBindings.lua'
MONITOR = ROOT / 'scripts/diagnostics/PerformanceMonitor.lua'

FIXTURE = r'''
local checks,clock,loads=0,0,{}
local function check(v,message)assert(v,message);checks=checks+1 end
local modules={}
local specs={
 {'scene.Hangar','hangar','Bind init Update UpdateGrid BuildReflection ResizeReflection'},
 {'scene.HangarAtmosphere','hangarAtmosphere','Update'},
 {'scene.HangarPanels','hangarPanels','init Update Render'},
 {'ui.GarageHud','hangarHud','Create Update'},
 {'ui.BayPreviews','bayPreviews','Update'},
 {'render.ReflectionFilter','reflection','Init Queue'},
 {'render.VehicleView','vehicleView','New init Rebuild UpdateIdle UpdateWeaponEffects SyncBlueprint AddPart RemovePart'},
 {'render.WeaponEffects','weaponIdleFx','New Update Batch'},
}
for _,spec in ipairs(specs)do
 local m={};modules[spec[1]]=m
 for method in spec[3]:gmatch('%S+')do
  m[method]=function(a,b,c)clock=clock+2;return nil,a,b,c end
 end
end
modules['core.CollectionCycle']={}
modules['render.RenderTargetLifetime']={}
require=function(name)
 check(modules[name]~=nil,'only existing app dependencies are resolved: '..name)
 loads[name]=(loads[name]or 0)+1
 return modules[name]
end
local Bindings=assert(load(BINDINGS_SOURCE))()
local monitor=Monitor.New{clock=function()return clock end,noFile=true,sink=function()end}
local app={}
local originalApp={}
for _,name in ipairs({'Update','Install','HomeView','GroundDisplay'})do
 app[name]=function(self,a,b)clock=clock+3;return nil,self,a,b end
 originalApp[name]=app[name]
end
Bindings.Attach(monitor,app)
local firstUpdate=modules['scene.Hangar'].Update
for i=1,4 do Bindings.Attach(monitor,app)end
check(firstUpdate==modules['scene.Hangar'].Update,'repeated Attach never stacks wrappers')
for _,spec in ipairs(specs)do check(loads[spec[1]]==1,'module reference cached once '..spec[1])end
monitor:BeginFrame(.016)
for _,spec in ipairs(specs)do
 for method in spec[3]:gmatch('%S+')do
  local a,b,c,d=modules[spec[1]][method]('self',37,false)
  check(a==nil and b=='self'and c==37 and d==false,'nil/multiple return and arguments '..spec[2]..'.'..method)
  local stage=monitor.stages[spec[2]..'.'..method]
  check(stage and stage.ms==2 and stage.selfMs==2 and stage.calls==1,'first scene work attributed '..spec[2]..'.'..method)
 end
end
for _,name in ipairs({'Update','Install','HomeView','GroundDisplay'})do
 local a,b,c,d=app[name](app,'value',false)
 check(a==nil and b==app and c=='value'and d==false,'app arguments retained '..name)
 check(monitor.stages['app.'..name].ms==3,'app boundary '..name)
end
monitor:EndFrame{}
monitor:Dispose()
for name,original in pairs(originalApp)do check(app[name]==original,'app original restored '..name)end
local disabled=Monitor.New{enabled=false,clock=function()return clock end,noFile=true,sink=function()error('disabled output')end}
local before=modules['scene.Hangar'].Update
Bindings.Attach(disabled,app)
check(before==modules['scene.Hangar'].Update,'disabled monitor leaves original module method unchanged')
return checks
'''


def run(bindings):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Monitor = lua.execute(MONITOR.read_text('utf8'))
    lua.globals().BINDINGS_SOURCE = bindings
    return lua.execute(FIXTURE)


current = BINDINGS.read_text('utf8')
checks = run(current)
baseline = subprocess.check_output(
    ['git', 'show', f'{BASELINE_COMMIT}:scripts/diagnostics/PerformanceBindings.lua'], cwd=ROOT, text=True,
)
try:
    run(baseline)
except Exception as error:
    assert 'module reference cached once' in str(error) or 'first scene work attributed' in str(error), str(error)
    negative = str(error).split('\n')[0]
else:
    raise AssertionError('Fixed baseline unexpectedly supplied missing first-scene sections')
print(json.dumps({
    'result': 'PASS', 'checks': checks, 'baselineCommit': BASELINE_COMMIT,
    'baselineNegativeControl': negative,
    'bindingsSha256': hashlib.sha256(BINDINGS.read_bytes()).hexdigest(),
    'boundary': 'Real monitor and binding modules, stubbed app dependencies and deterministic wall clock. '
                'Validates first-scene boundaries, single module resolution, idempotent wrapping, '
                'method arguments, nil/multiple returns and restoration. No runtime speed claim.',
}))
