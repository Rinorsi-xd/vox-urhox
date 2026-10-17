"""Actual monitor/bindings with synthetic shared classes; no engine/FPS claim."""
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

ORIGINAL = (ROOT / 'scripts/diagnostics/PerformanceBindings.lua').read_text('utf8')
MONITOR = (ROOT / 'scripts/diagnostics/PerformanceMonitor.lua').read_text('utf8')
NEEDLE = "local function Bind(monitor,object,prefix)\n    if type(object)~='table' then return end\n"
REPLACEMENT = """local attachEpoch=0
local attached=setmetatable({},{__mode='k'})
local function Bind(monitor,object,prefix)
    if type(object)~='table' then return end
    local prefixes=attached[object]
    if not prefixes then prefixes={};attached[object]=prefixes end
    if prefixes[prefix]==attachEpoch then return end
    prefixes[prefix]=attachEpoch
"""
assert ORIGINAL.count(NEEDLE) == 1
CANDIDATE = ORIGINAL.replace(NEEDLE, REPLACEMENT)
GUARD = "    if not monitor or monitor.enabled==false or not app then return end\n"
assert CANDIDATE.count(GUARD) == 1
CANDIDATE = CANDIDATE.replace(GUARD, GUARD + '    attachEpoch=attachEpoch+1\n')

SETUP = r'''
local modules,classes={},{}
local function noop(self,a,b) return nil,a,b,nil end
local function methods(names)
 local m={}
 for name in names:gmatch('%S+') do m[name]=noop end
 return m
end
local specs={
 {'scene.Hangar','Bind init Update UpdateGrid BuildReflection ResizeReflection'},
 {'scene.HangarAtmosphere','Update'}, {'scene.HangarPanels','init Update Render'},
 {'ui.GarageHud','Create Update'}, {'ui.BayPreviews','Update'},
 {'render.ReflectionFilter','Init Queue'},
 {'render.VehicleView','New init Rebuild UpdateIdle UpdateWeaponEffects SyncBlueprint AddPart RemovePart'},
 {'render.WeaponEffects','New Update Batch'},
 {'drive.ContactControl','Step'}, {'drive.ChassisStability','Step'},
 {'drive.HoverControl','Step Motion'}, {'drive.ThrusterControl','Step'},
 {'drive.WingControl','Step'}, {'drive.LegGait','Step'}, {'render.WeaponView','Update'},
 {'core.CollectionCycle','Step Collect Restore EnterIncremental Advance'},
 {'render.RenderTargetLifetime','Update Flush Retire'},
}
for _,s in ipairs(specs) do modules[s[1]]=methods(s[2]) end
local function object(kind,names)
 if not classes[kind] then classes[kind]=methods(names);classes[kind].__index=classes[kind] end
 return setmetatable({},classes[kind])
end
local function vehicle(legs)
 local v=object('vehicle','Step StepRotors ApplyRotors PostStep SyncDrillPose')
 v.suspension=object('suspension','Sample Apply')
 v.legHitboxes=object('legHitboxes','Update')
 if legs then v.legControl=object('legs','Step') end
 return v
end
local function view()
 return setmetatable({view=setmetatable({}, {__index=modules['render.VehicleView']})},
 {__index=classes.playerView})
end
classes.playerView=methods('Update SavePose')
require=function(name) assert(modules[name],name);return modules[name] end
local binding=assert(load(BINDINGS_SOURCE))()
local tick=0
local monitor=Monitor.New{clock=function()return tick end,noFile=true,sink=function()end}
local app=object('app','Update PostUpdate Install HomeView GroundDisplay AdvanceOpeningRetirements ReleaseSettledAssets')
local trial=object('trial','Update Tick PostUpdate ConsumeWorldEvents Aim');app.trial=trial
trial.world=object('world','Step Explode Hit')
trial.world.space=object('physics','Step')
trial.world.debris=object('debris','Advance CapturePoses')
trial.world.units={}
trial.combat=object('combat','Update BeforeStep AfterStep SyncPlayer Events')
trial.combat.entries={}
trial.combatView=object('combatView','Consume SavePose Update');trial.combatView.units={}
for i=1,8 do
 local unit=object('unit','Step Flush Build RegenerateStructure RestoreMissing Destroy Die Explode')
 unit.vehicle=vehicle(i==4 or i==8);unit.weapons=object('weapons','Step')
 unit.weapons.drill=object('drill','Step')
 trial.world.units[i]=unit
 if i>1 then trial.combat.entries[#trial.combat.entries+1]={driver=object('ai','Step')} end
 trial.combatView.units[unit]=view()
end
trial.vehicle=trial.world.units[1].vehicle;trial.view=view()
trial.hud=methods('Update');trial.hud.overlay=object('hudOverlay','Update Consume')
trial.effects=object('effects','Consume Update')
trial.effects.chips=object('chips','Update Break');trial.effects.missiles=object('missiles','Update')
for field,spec in pairs({environment={'environment','Update'},chase={'camera','Pose'},
 aimLines={'aimLines','Update'},boundary={'boundary','Update'},weaponAudio={'weaponAudio','Update Consume'},
 drivingAudio={'drivingAudio','Update Observe'},feedbackAudio={'feedbackAudio','Update Consume'},
 collisionAudio={'collisionAudio','BeforeStep AfterStep'}}) do trial[field]=object(spec[1],spec[2]) end
local function state()
 local wrapped={}
 for object,entries in pairs(monitor.restores) do
  for _,entry in ipairs(entries) do wrapped[#wrapped+1]=entry.key end
 end
 table.sort(wrapped);return table.concat(wrapped,','),#wrapped
end
local function invoke()
 monitor:BeginFrame(.016)
 for _,unit in ipairs(trial.world.units) do
  local a,b,c,d=unit:Step('payload',false);assert(a==nil and b=='payload' and c==false and d==nil)
  unit.vehicle:Step();unit.vehicle.suspension:Sample()
 end
 monitor:EndFrame{trialId='fixture',stepsTotal=1}
end
return {binding=binding,monitor=monitor,app=app,trial=trial,classes=classes,modules=modules,
 attach=function()binding.Attach(monitor,app)end,state=state,invoke=invoke}
'''


def setup(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Monitor = lua.execute(MONITOR)
    lua.globals().BINDINGS_SOURCE = source
    return lua, lua.execute(SETUP)


def verify(source):
    lua, fixture = setup(source)
    lua.globals().F = fixture
    return lua.execute(r'''
local checks,calls=0,0
local function check(v,m)assert(v,m);checks=checks+1 end
local original=F.monitor.Wrap
F.monitor.Wrap=function(self,...)calls=calls+1;return original(self,...)end
F.attach();local initial=calls;local signature,count=F.state()
calls=0;F.attach();local steady=calls
local secondSignature,secondCount=F.state()
check(signature==secondSignature and count==secondCount,'stable wrapper set')
F.invoke()
check(F.monitor.stages['vehicle.Step'].calls==8,'all vehicle Step boundaries retained')
check(F.monitor.stages['unit.Step'].calls==8,'all unit Step boundaries retained')
local before=F.classes.vehicle.Step
F.classes.vehicle.Step=function(self,a,b)return nil,a,b,77 end
F.attach()
check(F.classes.vehicle.Step~=before,'hot replaced shared method rebound next frame')
F.monitor:BeginFrame(.016)
local a,b,c,d=F.trial.vehicle:Step('new',false)
check(a==nil and b=='new' and c==false and d==77,'hot replacement returns preserved')
check(F.monitor.stages['vehicle.Step'].calls==1,'replacement receives existing stage')
F.monitor:EndFrame{trialId='fixture',stepsTotal=2}
F.trial.hud={Update=function(self,a)return a,42 end};F.attach()
F.monitor:BeginFrame(.016)
local a,b=F.trial.hud:Update('hud')
check(a=='hud' and b==42 and F.monitor.stages['hud.Update'].calls==1,'new HUD bound')
F.monitor:EndFrame{trialId='fixture',stepsTotal=3}
local newVehicle=setmetatable({}, {__index={Step=function()return 53 end}})
F.trial.world.units[9]={vehicle=newVehicle}
F.attach();F.monitor:BeginFrame(.016)
check(newVehicle:Step()==53 and F.monitor.stages['vehicle.Step'].calls==1,'new vehicle class bound')
F.monitor:EndFrame{trialId='fixture',stepsTotal=4}
F.monitor.enabled=false;local stopped=calls;F.attach()
check(calls==stopped,'disabled remains disabled')
F.monitor.enabled=true;F.monitor:Dispose()
check(newVehicle:Step()==53,'restore new vehicle original')
return {checks=checks,initialWrapAttempts=initial,steadyWrapAttempts=steady,
 distinctWrappedMethods=count,signature=signature}
''')


def mapping(table):
    return dict(table.items())


def timed(source, count=20000):
    lua, fixture = setup(source)
    fixture['attach']()
    lua.globals().F = fixture
    run = lua.eval('function(n)for i=1,n do F.attach()end end')
    run(500)
    start = time.perf_counter()
    run(count)
    seconds = time.perf_counter() - start
    return {'iterations': count, 'seconds': seconds, 'microsecondsPerAttach': seconds / count * 1e6}


baseline, candidate = mapping(verify(ORIGINAL)), mapping(verify(CANDIDATE))
assert baseline['signature'] == candidate['signature']
assert baseline['distinctWrappedMethods'] == candidate['distinctWrappedMethods']
timings = []
for variant in ['A', 'B', 'B', 'A', 'A', 'B', 'B', 'A']:
    timings.append({'variant': variant, **timed(ORIGINAL if variant == 'A' else CANDIDATE)})
means = {v: sum(t['microsecondsPerAttach'] for t in timings if t['variant'] == v) / 4 for v in ['A', 'B']}
out = ROOT / 'docs/migration/evidence/monitor-attach-dedup-offline-1017'
out.mkdir(parents=True, exist_ok=True)
(out / 'PerformanceBindings-candidate.lua').write_text(CANDIDATE, encoding='utf8', newline='\n')
report = {'result': 'PASS', 'baselineSha256': hashlib.sha256(ORIGINAL.encode()).hexdigest(),
          'candidateSha256': hashlib.sha256(CANDIDATE.encode()).hexdigest(),
          'monitorSha256': hashlib.sha256(MONITOR.encode()).hexdigest(),
          'baseline': baseline, 'candidate': candidate, 'timings': timings,
          'meanMicrosecondsPerAttach': means, 'candidateChangePct': (means['B'] / means['A'] - 1) * 100,
          'boundary': 'Actual production monitor/bindings, synthetic eight-car shared-class graph. '
                      'Automatic GC enabled. CPU time here is Python host elapsed for repeated Lua Attach only, '
                      'not Native/Web gameplay or FPS. No production changes or hardware test.'}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps(report, indent=2))
