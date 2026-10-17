"""Execute generated six-child BeforeStep QA offline; no engine or hardware."""
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
const flags=['--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline','--profile-presentation-pipeline','--profile-before-step-pipeline'];
build.validateFramePipelineOptions(flags);
for(const removed of flags.slice(0,-1))assert.throws(()=>build.validateFramePipelineOptions(flags.filter(f=>f!==removed)));
for(const extra of ['--cdp','--allocation-owners','--auto-gc-aba','--qa-aim-engine','--profile-trial-sections'])assert.throws(()=>build.validateFramePipelineOptions([...flags,extra]));
for(const name of build.beforeStepModules){const bad=structuredClone(prepared);bad.identity.scripts[name]='bad';assert.throws(()=>build.buildFramePipelineProbe(bad,{fixedSteps:true,presentation:true,beforeStep:true}));}
console.log(JSON.stringify({suffix:build.buildFramePipelineProbe(prepared,{fixedSteps:true,presentation:true,beforeStep:true}),prepared}));
"""
built = json.loads(subprocess.check_output(['node', '-e', node], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r"""
tick=0;frameId=1;steps=2
Time={GetSystemTime=function()return tick end};function GetTime()return {frameNumber=frameId}end
function Advance(n)tick=tick+n end
Vehicle={Step=function()Advance(4);return 7,nil,false end}
Driver={Step=function()Advance(2)end};Weapons={Step=function()Advance(3);if FAIL_WEAPON then error('weapon expected failure')end end}
Unit={Flush=function()Advance(1)end,RegenerateStructure=function()Advance(1)end}
Battle={Pick=function()Advance(1)end,AfterStep=function()Advance(1)end}
Battle.BeforeStep=function()
 Advance(2)
 for i=1,8 do
  Unit.RegenerateStructure();if i>1 then Battle.Pick();Driver.Step()end
  Unit.Flush();local a,b,c=Vehicle.Step();assert(a==7 and b==nil and c==false);Weapons.Step()
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
 ['drive.Vehicle']=Vehicle,['combat.EnemyDriver']=Driver,['combat.WeaponSystem']=Weapons,['combat.CarUnit']=Unit}
 return assert(modules[name],name)
end
cjson={encode=function()error('No measurement serialization')end};print=function()end
""")
lua.execute(built['suffix'])
report = lua.execute(r"""
local M=VOX_QA_FRAME_PIPELINE
assert(M.Snapshot().bindings==21 and not M.enabled)
HandleUpdate();assert(M.Snapshot().bindings==22)
M.Enable();for i=1,3 do frameId=i;UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();Advance(2)end
M.Enable(false);local report=M.Take()
local f=report.frames[2]
assert(f.scopes['fixed.BeforeStep'].inclusiveMs==190 and f.scopes['fixed.BeforeStep'].selfMs==4)
assert(f.scopes['before.Vehicle'].calls==16 and f.scopes['before.Vehicle'].inclusiveMs==64)
assert(f.scopes['before.Driver'].calls==14 and f.scopes['before.Driver'].inclusiveMs==28)
assert(f.scopes['before.Pick'].calls==14 and f.scopes['before.Pick'].inclusiveMs==14)
assert(f.scopes['before.Weapons'].calls==16 and f.scopes['before.Weapons'].inclusiveMs==48)
-- Outside BeforeStep, calls must retain original semantics without child records.
frameId=4;M.Enable();Vehicle.Step();M.Enable(false);assert(#M.Take().frames==0)
steps=6;frameId=5;M.Enable();UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();M.Enable(false)
local six=M.Take().frames[1];assert(six.droppedEvents==0 and #six.events>64 and #six.events<1024)
FAIL_WEAPON=true;frameId=6;M.Enable();local ok,err=pcall(HandleUpdate);assert(not ok and tostring(err):find('weapon expected failure',1,true));M.Enable(false)
local failed=M.Take().frames[1];assert(failed.scopes['before.Weapons'].errors==1 and failed.scopes['fixed.BeforeStep'].errors==1 and failed.scopes['main.Update'].errors==1)
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
const fs=require('fs'),assert=require('assert/strict'),{records,prepared}=JSON.parse(fs.readFileSync(0));
const analyze=require('./tools/migration/analyze-frame-pipeline.cjs').analyze,runner=require('./tools/migration/check-performance-uninstrumented-web.cjs');
const service={...prepared,framePipelineProfile:true,fixedStepPipelineProfile:true,presentationPipelineProfile:true,beforeStepPipelineProfile:true};
runner.verifyProfileIdentity(service,false,false,false,true,false,true,false,true,true);
assert.throws(()=>runner.verifyProfileIdentity(service,false,false,false,true,false,true,false,true));
runner.verifyFramePipeline({available:true,bindings:22,identity:records[0].identity,dropped:0},service);
const result=analyze(records);assert.deepEqual(result.issues,[]);assert.equal(result.completeFrames,1);
assert.equal(result.beforeStep.meanBeforeMs,190);assert.equal(result.beforeStep.meanSelfMs,4);
assert.equal(result.beforeStep.means['before.Vehicle'],64);
const path=require('path'),child=require('child_process');
const complete=records.filter(r=>!r.frame.partialStart&&!r.frame.partialEnd);
const replayDir=fs.mkdtempSync(path.resolve('.tmp/before-independent-recheck-'));
fs.writeFileSync(path.join(replayDir,'frame-pipeline.jsonl'),complete.map(r=>JSON.stringify(r)).join('\n'));
fs.writeFileSync(path.join(replayDir,'frame-pipeline-summary.json'),JSON.stringify({...result,afterFrame:complete[0].frame.frame-1,throughFrame:complete.at(-1).frame.frame}));
fs.writeFileSync(path.join(replayDir,'result.json'),JSON.stringify({identity:{monitorDisabled:true}}));
child.execFileSync(process.execPath,['tools/migration/recheck-presentation-capture.cjs',replayDir]);
const replay=JSON.parse(fs.readFileSync(path.join(replayDir,'independent-recheck.json')));
assert.equal(replay.result,'PASS');assert.deepEqual(replay.beforeStep,{meanBeforeMs:190,meanSelfMs:4,means:result.beforeStep.means});
for(const mutate of [r=>delete r[1].identity.beforeStepSources,r=>r[1].frame.scopes['fixed.BeforeStep'].selfMs++,r=>r[1].frame.events.find(e=>e[0]==='before.Vehicle'&&e[1]==='enter')[0]='outside',r=>r[1].frame.scopes['before.Driver'].calls++]){
 const bad=structuredClone(records);mutate(bad);assert.ok(analyze(bad).issues.length);
}
console.log(JSON.stringify({result:'PASS',bindings:22,completeFrames:result.completeFrames,beforeMs:result.beforeStep.meanBeforeMs,beforeSelfMs:result.beforeStep.meanSelfMs,means:result.beforeStep.means,negativeControls:20,sixStepsNoTruncation:true,outsideCallsUnmeasured:true,nilAndErrorPreserved:true,independentReplay:true}));
"""
print(subprocess.check_output(['node', '-e', verify], cwd=ROOT, input=json.dumps({'records': records, 'prepared': built['prepared']}), text=True, encoding='utf-8'))
