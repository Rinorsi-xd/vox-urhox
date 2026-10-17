"""Execute the opt-in six-boundary extension offline. Never starts hardware."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

node = r"""
const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const build=require('./tools/migration/build-frame-pipeline-probe.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const prepared=JSON.parse(fs.readFileSync('.tmp/outgame-cached-1792183721377/identity.json'));
for(const [fixedSteps,expected]of [[false,'9c46befdd584217165061a0eff518c65f8a881f97ccd0b3ab62d78bdb54ab1f3'],[true,'b149f12b6e8822182ab078f8faf5a8f4566a35af713e0d4895b42c958c51ac8c']])assert.equal(sha(build.buildFramePipelineProbe(prepared,{fixedSteps})),expected,'Unchanged ordinary/fixed generated suffix bytes');
const flags=['--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline','--profile-presentation-pipeline'];
build.validateFramePipelineOptions(flags);
for(const removed of ['--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline'])assert.throws(()=>build.validateFramePipelineOptions(flags.filter(v=>v!==removed)));
for(const extra of ['--cdp','--allocation-owners','--auto-gc-aba','--qa-aim-engine','--qa-salvage-stock','--profile-trial-sections'])assert.throws(()=>build.validateFramePipelineOptions([...flags,extra]));
assert.throws(()=>build.buildFramePipelineProbe(prepared,{presentation:true}));
const suffix=build.buildFramePipelineProbe(prepared,{fixedSteps:true,presentation:true});
const drift=structuredClone(prepared);drift.identity.scripts['render/CombatView.lua']='wrong';assert.throws(()=>build.buildFramePipelineProbe(drift,{fixedSteps:true,presentation:true}));
console.log(JSON.stringify({suffix,identity:prepared,sourceSha256:sha(build.pipelineSource(true)),defaultByteIdentity:true,flagAndDriftNegatives:12}));
"""
built = json.loads(subprocess.check_output(['node', '-e', node], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r"""
tick=0;frameId=1;steps=2;Time={GetSystemTime=function()return tick end}
function GetTime()return {frameNumber=frameId}end
function Advance(n)tick=tick+n end
UI={Update=function()Advance(3)end,Layout=function()Advance(2)end,UpdateInspector=function()end}
UI.Render=function()Advance(1);UI.Layout();Advance(1)end
Battle={BeforeStep=function()Advance(2)end,AfterStep=function()Advance(1)end}
World={Step=function()Advance(3)end}
CombatView={Update=function()Advance(3);return 7,nil,false end}
Effects={Update=function()Advance(2)end}
Hud={Update=function()Advance(4);if FAIL_HUD then error('expected hud failure')end end}
Trial={}
function Trial:Tick()
 Advance(2)
 for i=1,steps do Battle.BeforeStep();World.Step();Battle.AfterStep()end
 local a,b,c=CombatView.Update();assert(a==7 and b==nil and c==false)
 Effects.Update();self.hud.Update()
end
function Trial:Update()Advance(1);self:Tick()end
session=setmetatable({hud=Hud},{__index=Trial})
App={Update=function(self)Advance(1);if self.trial then self.trial:Update()end end}
appInstance=setmetatable({trial=session},{__index=App})
function HandleUpdate()Advance(1);appInstance:Update()end
function HandlePostUpdate()Advance(2)end
function HandleFramePresented()Advance(1)end
require=function(name)
 local modules={['urhox-libs/UI']=UI,['combat.BattleController']=Battle,['drive.TrackWorld']=World,
 ['app.HangarApp']=App,['app.TrialSession']=Trial,['render.CombatView']=CombatView,['render.CombatEffects']=Effects}
 return assert(modules[name],name)
end
cjson={encode=function()error('No serialization while measuring')end};print=function()end
originalHud=Hud.Update
""")
lua.execute(built['suffix'])
report = lua.execute(r"""
local M=VOX_QA_FRAME_PIPELINE
assert(M.Snapshot().bindings==15 and not M.enabled)
HandleUpdate();assert(M.Snapshot().bindings==16 and Hud.Update~=originalHud)
M.Enable()
for i=1,3 do
 frameId=i;UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();Advance(2)
end
M.Enable(false);local report=M.Take()
for _,f in ipairs(report.frames)do
 assert(f.scopes['main.Update'].inclusiveMs==26 and f.scopes['main.Update'].selfMs==1)
 assert(f.scopes['envelope.AppUpdate'].inclusiveMs==25 and f.scopes['envelope.AppUpdate'].selfMs==1)
 assert(f.scopes['envelope.TrialUpdate'].inclusiveMs==24 and f.scopes['envelope.TrialUpdate'].selfMs==1)
 assert(f.scopes['envelope.TrialTick'].inclusiveMs==23 and f.scopes['envelope.TrialTick'].selfMs==2)
 assert(f.scopes['presentation.CombatView'].inclusiveMs==3 and f.scopes['presentation.HudUpdate'].inclusiveMs==4)
 assert(f.measuredWallMs==36 and f.wallMs==38 and f.unscopedWallMs==2)
end
local old=Hud.Update
Hud2={Update=function()Advance(4)end};session.hud=Hud2
frameId=4;HandleUpdate();assert(Hud.Update==originalHud and Hud2.Update~=originalHud and M.Snapshot().bindings==16)
session.hud=Hud;frameId=5;HandleUpdate();assert(M.Snapshot().bindings==16)
steps=6;frameId=6;M.Enable();UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();M.Enable(false)
assert(M.Take().frames[1].droppedEvents==0,'Six steps and six added scopes remain below 64 events')
FAIL_HUD=true;frameId=7;M.Enable();local ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('expected hud failure',1,true));M.Enable(false)
local failed=M.Take().frames[1]
assert(failed.scopes['presentation.HudUpdate'].errors==1 and failed.scopes['main.Update'].errors==1)
FAIL_HUD=false;appInstance.trial=nil;HandleUpdate()
assert(Hud.Update==originalHud and M.Snapshot().bindings==15,'Retired HUD reference released')
return report
""")


def native(value):
    if hasattr(value, 'items'):
        entries = dict(value.items())
        if entries and set(entries) == set(range(1, len(entries) + 1)):
            return [native(entries[i]) for i in range(1, len(entries) + 1)]
        return {key: native(item) for key, item in entries.items()}
    return value


captured = native(report)
records = [{'frame': frame, 'dropped': captured['dropped'], 'identity': captured['identity']}
           for frame in captured['frames']]
node_verify = r"""
const fs=require('fs'),assert=require('assert/strict');
const {records,identity}=JSON.parse(fs.readFileSync(0,'utf8'));
const analyze=require('./tools/migration/analyze-frame-pipeline.cjs').analyze;
const runner=require('./tools/migration/check-performance-uninstrumented-web.cjs');
const result=analyze(records);assert.deepEqual(result.issues,[]);assert.equal(result.completeFrames,1);
assert.equal(result.presentation.means.updateRemainderMs,14);assert.equal(result.presentation.means.appServicesMs,1);
assert.equal(result.presentation.means.tickSideMs,2);assert.equal(result.presentation.means.hudMs,4);
const service={...identity,framePipelineProfile:true,fixedStepPipelineProfile:true,presentationPipelineProfile:true};
runner.verifyProfileIdentity(service,false,false,false,true,false,true,false,true);
assert.throws(()=>runner.verifyProfileIdentity(service,false,true,false,true,false,true,true,true));
assert.throws(()=>runner.verifyProfileIdentity(service,false,false,false,true,false,true));
const snap={available:true,bindings:16,identity:records[0].identity,dropped:0};runner.verifyFramePipeline(snap,service);
for(const change of [v=>v.bindings--,v=>v.identity.presentationSources['ui/DriveHud.lua']='wrong',v=>v.identity.probeSha256='wrong']){
 const bad=structuredClone(snap);change(bad);assert.throws(()=>runner.verifyFramePipeline(bad,service));
}
const mutations=[
 r=>delete r[1].frame.scopes['presentation.HudUpdate'],
 r=>r[1].frame.scopes['envelope.TrialTick'].selfMs++,
 r=>r[1].frame.events.find(e=>e[0]==='presentation.CombatView'&&e[1]==='enter')[0]='outside',
 r=>delete r[1].identity.presentationSources,
 r=>r[1].frame.scopes['envelope.AppUpdate'].calls++,
 r=>r[1].frame.droppedEvents++,
];
for(const change of mutations){const bad=structuredClone(records);change(bad);assert.ok(analyze(bad).issues.length,'Corrupted presentation evidence must fail');}
console.log(JSON.stringify({result:'PASS',analysis:result,negativeControls:11}));
"""
analysis = json.loads(subprocess.check_output(['node', '-e', node_verify], cwd=ROOT,
                       input=json.dumps({'records': records, 'identity': built['identity']}),
                       text=True, encoding='utf-8'))
print(json.dumps({'result': 'PASS', 'defaultByteIdentity': built['defaultByteIdentity'],
                 'flagAndDriftNegatives': built['flagAndDriftNegatives'], 'evidenceNegatives': analysis['negativeControls'],
                 'bindings': 16, 'hudReplacementRestoresOldOwner': True, 'sixStepsNoTruncation': True,
                 'nilReturnsAndErrorsPreserved': True, 'noCaptureSerialization': True,
                 'frameConservation': analysis['analysis']['presentation']['means'],
                 'sourceSha256': built['sourceSha256'],
                 'boundary': 'Offline Lua execution of generated actual suffix and JS runner/analyzer gates. No engine, browser, performance gain or device acceptance.'}, indent=2))
