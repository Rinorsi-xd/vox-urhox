"""Execute the generated six-child Vehicle QA offline; no Runtime or hardware."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

node = r"""
const fs=require('fs'),assert=require('assert/strict'),build=require('./tools/migration/build-frame-pipeline-probe.cjs');
const prepared=JSON.parse(fs.readFileSync('.tmp/outgame-cached-1792187441376/identity.json'));
const flags=['--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline','--profile-presentation-pipeline','--profile-before-step-pipeline','--profile-vehicle-pipeline'];
build.validateFramePipelineOptions(flags);
for(const removed of flags.slice(0,-1))assert.throws(()=>build.validateFramePipelineOptions(flags.filter(f=>f!==removed)));
for(const extra of ['--cdp','--allocation-owners','--auto-gc-aba','--qa-aim-engine','--profile-trial-sections'])assert.throws(()=>build.validateFramePipelineOptions([...flags,extra]));
for(const name of build.vehicleModules){const bad=structuredClone(prepared);bad.identity.scripts[name]='bad';assert.throws(()=>build.buildFramePipelineProbe(bad,{fixedSteps:true,presentation:true,beforeStep:true,vehicle:true}));}
assert.throws(()=>build.buildFramePipelineProbe(prepared,{fixedSteps:true,presentation:true,vehicle:true}));
console.log(JSON.stringify({suffix:build.buildFramePipelineProbe(prepared,{fixedSteps:true,presentation:true,beforeStep:true,vehicle:true}),prepared}));
"""
built = json.loads(subprocess.check_output(['node', '-e', node], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r"""
tick=0;frameId=1;steps=2
Time={GetSystemTime=function()return tick end};function GetTime()return {frameNumber=frameId}end
function Advance(n)tick=tick+n end
Suspension={Sample=function()Advance(2)end,Apply=function()Advance(3)end}
Legs={Step=function()Advance(4);if FAIL_LEG then error('leg expected failure')end end}
Hover={Step=function()Advance(5)end}
Contact={Step=function()Advance(6);Hover.Step()end}
LegHitboxes={Update=function()Advance(7)end}
Vehicle={Step=function(index)
 Advance(1);Suspension.Sample();Contact.Step();Hover.Step()
 if index~=8 then Legs.Step()end
 LegHitboxes.Update();Suspension.Apply();return 7,nil,false
end}
Driver={Step=function()Advance(2)end};Weapons={Step=function()Advance(3)end}
Unit={Flush=function()Advance(1)end,RegenerateStructure=function()Advance(1)end}
Battle={Pick=function()Advance(1)end,AfterStep=function()Advance(1)end}
Battle.BeforeStep=function()
 Advance(2)
 for i=1,8 do
  Unit.RegenerateStructure();if i>1 then Battle.Pick();Driver.Step()end
  Unit.Flush();local a,b,c=Vehicle.Step(i);assert(a==7 and b==nil and c==false);Weapons.Step()
 end
end
World={Step=function()Advance(3)end}
CombatView={Update=function()Advance(3)end};Effects={Update=function()Advance(2)end};Hud={Update=function()Advance(4)end}
Trial={Tick=function(self)Advance(2);for i=1,steps do Battle.BeforeStep();World.Step();Battle.AfterStep()end;CombatView.Update();Effects.Update();self.hud.Update()end}
Trial.Update=function(self)Advance(1);self:Tick()end
App={Update=function(self)Advance(1);if self.trial then self.trial:Update()end end}
session=setmetatable({hud=Hud},{__index=Trial});app=setmetatable({trial=session},{__index=App})
UI={Update=function()Advance(1)end,Layout=function()end,UpdateInspector=function()end,Render=function()Advance(1)end}
function HandleUpdate()app:Update()end;function HandlePostUpdate()Advance(1)end;function HandleFramePresented()end
require=function(name)
 local modules={['urhox-libs/UI']=UI,['combat.BattleController']=Battle,['drive.TrackWorld']=World,
 ['app.HangarApp']=App,['app.TrialSession']=Trial,['render.CombatView']=CombatView,['render.CombatEffects']=Effects,
 ['drive.Vehicle']=Vehicle,['combat.EnemyDriver']=Driver,['combat.WeaponSystem']=Weapons,['combat.CarUnit']=Unit,
 ['drive.RaySuspension']=Suspension,['drive.LegControl']=Legs,['drive.HoverControl']=Hover,
 ['drive.ContactControl']=Contact,['drive.LegHitboxes']=LegHitboxes}
 return assert(modules[name],name)
end
cjson={encode=function()error('No measurement serialization')end};print=function()end
""")
lua.execute(built['suffix'])
report = lua.execute(r"""
local M=VOX_QA_FRAME_PIPELINE
assert(M.Snapshot().bindings==27 and not M.enabled)
HandleUpdate();assert(M.Snapshot().bindings==28)
M.Enable();for i=1,3 do frameId=i;UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();Advance(2)end
M.Enable(false);local report=M.Take();local f=report.frames[2]
assert(f.scopes['before.Vehicle'].inclusiveMs==520 and f.scopes['before.Vehicle'].selfMs==16)
assert(f.scopes['vehicle.Sample'].inclusiveMs==32 and f.scopes['vehicle.Apply'].inclusiveMs==48)
assert(f.scopes['vehicle.Legs'].inclusiveMs==56 and f.scopes['vehicle.Legs'].calls==14)
assert(f.scopes['vehicle.Hover'].inclusiveMs==80 and f.scopes['vehicle.Hover'].calls==16)
assert(f.scopes['vehicle.Contact'].inclusiveMs==176 and f.scopes['vehicle.LegHitboxes'].inclusiveMs==112)
-- Nested Hover inside Contact and calls outside Vehicle retain their original path.
frameId=4;M.Enable();Vehicle.Step(1);Suspension.Sample();Legs.Step();M.Enable(false);assert(#M.Take().frames==0)
steps=6;frameId=5;M.Enable();UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();M.Enable(false)
local six=M.Take().frames[1];assert(six.droppedEvents==0 and #six.events>1024 and #six.events<2048)
FAIL_LEG=true;frameId=6;M.Enable();local ok,err=pcall(HandleUpdate);assert(not ok and tostring(err):find('leg expected failure',1,true));M.Enable(false)
local failed=M.Take().frames[1];assert(failed.scopes['vehicle.Legs'].errors==1 and failed.scopes['before.Vehicle'].errors==1 and failed.scopes['fixed.BeforeStep'].errors==1)
return report
""")


def native(value):
    if hasattr(value, 'items'):
        values = dict(value.items())
        if values and set(values) == set(range(1, len(values) + 1)):
            return [native(values[i]) for i in range(1, len(values) + 1)]
        return {key: native(item) for key, item in values.items()}
    return value


captured = native(report)
records = [{'frame': f, 'identity': captured['identity'], 'dropped': captured['dropped']} for f in captured['frames']]
verify = r"""
const fs=require('fs'),path=require('path'),child=require('child_process'),assert=require('assert/strict'),{records,prepared}=JSON.parse(fs.readFileSync(0));
const analyze=require('./tools/migration/analyze-frame-pipeline.cjs').analyze,runner=require('./tools/migration/check-performance-uninstrumented-web.cjs');
const service={...prepared,framePipelineProfile:true,fixedStepPipelineProfile:true,presentationPipelineProfile:true,beforeStepPipelineProfile:true,vehiclePipelineProfile:true};
runner.verifyProfileIdentity(service,false,false,false,true,false,true,false,true,true,true);
assert.throws(()=>runner.verifyProfileIdentity(service,false,false,false,true,false,true,false,true,true));
runner.verifyFramePipeline({available:true,bindings:28,identity:records[0].identity,dropped:0},service);
const result=analyze(records);assert.deepEqual(result.issues,[]);assert.equal(result.completeFrames,1);
assert.equal(result.vehicle.meanVehicleMs,520);assert.equal(result.vehicle.meanSelfMs,16);
assert.deepEqual(result.vehicle.means,{'vehicle.Sample':32,'vehicle.Apply':48,'vehicle.Legs':56,'vehicle.Hover':80,'vehicle.Contact':176,'vehicle.LegHitboxes':112});
const complete=records.filter(r=>!r.frame.partialStart&&!r.frame.partialEnd);
const replayDir=fs.mkdtempSync(path.resolve('.tmp/vehicle-independent-recheck-'));
fs.writeFileSync(path.join(replayDir,'frame-pipeline.jsonl'),complete.map(r=>JSON.stringify(r)).join('\n'));
fs.writeFileSync(path.join(replayDir,'frame-pipeline-summary.json'),JSON.stringify({...result,afterFrame:complete[0].frame.frame-1,throughFrame:complete.at(-1).frame.frame}));
fs.writeFileSync(path.join(replayDir,'result.json'),JSON.stringify({identity:{monitorDisabled:true}}));
child.execFileSync(process.execPath,['tools/migration/recheck-presentation-capture.cjs',replayDir]);
const replay=JSON.parse(fs.readFileSync(path.join(replayDir,'independent-recheck.json')));
assert.equal(replay.result,'PASS');assert.deepEqual(replay.vehicle,{meanVehicleMs:520,meanSelfMs:16,means:result.vehicle.means});
for(const mutate of [r=>delete r[1].identity.vehicleSources,r=>r[1].frame.scopes['before.Vehicle'].selfMs++,r=>r[1].frame.events.find(e=>e[0]==='vehicle.Sample'&&e[1]==='enter')[0]='outside',r=>r[1].frame.scopes['vehicle.Legs'].calls++,r=>r[1].identity.vehiclePipeline=false]){
 const bad=structuredClone(records);mutate(bad);assert.ok(analyze(bad).issues.length);
}
console.log(JSON.stringify({result:'PASS',bindings:28,completeFrames:result.completeFrames,vehicleMs:520,vehicleSelfMs:16,means:result.vehicle.means,negativeControls:23,sixStepsNoTruncation:true,nestedAndOutsideCallsUnmeasured:true,nilAndErrorPreserved:true,independentReplay:true}));
"""
print(subprocess.check_output(['node', '-e', verify], cwd=ROOT, input=json.dumps({'records': records, 'prepared': built['prepared']}), text=True, encoding='utf-8'))
