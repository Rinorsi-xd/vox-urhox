"""Execute the QA suffix in Lua 5.4. This is not a runtime performance test."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

node = r"""
const fs=require('fs'),crypto=require('crypto');
const main=fs.readFileSync('scripts/main.lua'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const prepared={source_directory:process.cwd(),identity:{scripts:{'main.lua':sha(main)}}};
for(const name of ['combat/BattleController.lua','drive/TrackWorld.lua'])prepared.identity.scripts[name]=sha(fs.readFileSync('scripts/'+name));
const build=require('./tools/migration/build-frame-pipeline-probe.cjs').buildFramePipelineProbe;
const suffix=build(prepared),fixedSuffix=build(prepared,{fixedSteps:true});let rejected=false;prepared.identity.scripts['main.lua']='wrong';
try{build(prepared)}catch{rejected=true}
const validate=require('./tools/migration/build-frame-pipeline-probe.cjs').validateFramePipelineOptions;
validate(['--qa','--monitor-disabled','--profile-frame-pipeline']);
validate(['--qa','--monitor-disabled','--profile-frame-pipeline','--profile-fixed-step-pipeline']);
let fixedDenied=false;try{validate(['--qa','--monitor-disabled','--profile-fixed-step-pipeline'])}catch{fixedDenied=true}if(!fixedDenied)throw Error('Standalone fixed-step profile accepted');
prepared.identity.scripts['main.lua']=sha(main);prepared.identity.scripts['drive/TrackWorld.lua']='wrong';
let fixedDrift=false;try{build(prepared,{fixedSteps:true})}catch{fixedDrift=true}if(!fixedDrift)throw Error('Changed frozen fixed module accepted');
for(const bad of [['--qa'],['--monitor-disabled'],['--qa','--monitor-disabled','--profile-drive-sections'],['--qa','--monitor-disabled','--story-route'],['--qa','--monitor-disabled','--loading-failure-test'],['--qa','--monitor-disabled','--cdp']]){
 let denied=false;try{validate([...bad,'--profile-frame-pipeline'])}catch{denied=true}if(!denied)throw Error('Mixed/missing profile flags accepted');
}
console.log(JSON.stringify({suffix,fixedSuffix,rejected}));
"""
built = json.loads(subprocess.check_output(['node', '-e', node], cwd=ROOT, text=True, encoding='utf-8'))
assert built['rejected'], 'A changed frozen main must reject the build'
reference = (ROOT / 'urhox-libs/UI/Core/UI.lua').read_text(encoding='utf-8')
update_body = re.search(r'SubscribeToEvent\("Update", function\(self, eventType, eventData\)(.*?)\n    end\)', reference, re.S).group(1)
render_body = re.search(r'SubscribeToEvent\(nvg_, "NanoVGRender", function\(self, eventType, eventData\)(.*?)\n    end\)', reference, re.S).group(1)
assert 'UI.Update(dt)' in update_body and 'UI.Render()' in render_body

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('assert(load(...))', (ROOT / 'scripts/main.lua').read_text(encoding='utf-8') + '\n' + built['suffix'])
full_suffix = '\n'.join([
    (ROOT / 'scripts/main.lua').read_text(encoding='utf-8'),
    (HERE / 'qa-frame-wall-observer.lua').read_text(encoding='utf-8'),
    (HERE / 'probe-outgame-web.lua').read_text(encoding='utf-8'),
    (HERE / 'monitor-disabled-observer.lua').read_text(encoding='utf-8'),
    built['suffix'],
    (HERE / 'qa-frame-pipeline-control.lua').read_text(encoding='utf-8'),
])
lua.execute('assert(load(...))', full_suffix)
lua.execute("""
tick=0;frameId=1
Time={GetSystemTime=function()return tick end}
function GetTime()return {frameNumber=frameId}end
function Advance(n)tick=(tick+n)&0xffffffff end
UI={}
function UI.Layout()Advance(2)end
function UI.Update()if QA_FAIL then Advance(7);error('expected pipeline failure')end;Advance(3)end
function UI.UpdateInspector()Advance(1)end
function UI.Render()Advance(1);UI.Layout();Advance(1)end
function HandleUpdate(a,b,c,d)Advance(5);return a,b,c,d end
function HandlePostUpdate()Advance(2)end
function HandleFramePresented()QA_IN_PRESENTED=true;QA_PHASE='EndFrame';QA_F9=false;Advance(1);QA_IN_PRESENTED=false end
originalUpdate=HandleUpdate;originalPost=HandlePostUpdate;originalRender=UI.Render
require=function(name)assert(name=='urhox-libs/UI');return UI end
KEY_F9=999;QA_F9=false;QA_PHASE='Update';input={GetKeyPress=function(self,key)assert(key==KEY_F9);if QA_PHASE~='Update' then return false end;local pressed=QA_F9;QA_F9=false;return pressed end}
EMITTED={};cjson={encode=function(value)assert(not QA_IN_PRESENTED);EMITTED[#EMITTED+1]=value;return '{}'end}
print=function()end
""")
# Use the reference library's actual auto-event callback bodies, already created
# before opt-in. This verifies lookup through the UI table after wrapping.
lua.execute('function AutoUpdate(self,eventType,eventData)' + update_body + '\nend\n'
            'function AutoRender(self,eventType,eventData)' + render_body + '\nend')
lua.execute(built['suffix'])
lua.execute((HERE / 'qa-frame-pipeline-control.lua').read_text(encoding='utf-8'))
result = lua.execute("""
local M=VOX_QA_FRAME_PIPELINE
assert(not M.enabled and M.prepared and HandleUpdate~=originalUpdate and UI.Render~=originalRender)
-- Model a registry that caches function references at Start/SubscribeToEvent.
local cachedUpdate,cachedPost,cachedPresented=HandleUpdate,HandlePostUpdate,HandleFramePresented
local dormantRender=UI.Render
local ed={TimeStep={GetFloat=function()return 1/60 end}}
M.Enable();assert(M.Snapshot().bindings==7)
local function RunFrame(uiFirst)
 QA_PHASE='Update'
 if uiFirst then AutoUpdate(nil,'Update',ed)end
 local a,b,c,d=cachedUpdate(7,nil,false,4);assert(a==7 and b==nil and c==false and d==4)
 if not uiFirst then AutoUpdate(nil,'Update',ed)end
 UI.UpdateInspector();cachedPost();AutoRender();cachedPresented();Advance(2)
end
RunFrame(true);frameId=2;RunFrame(false);frameId=3;RunFrame(true)
assert(#EMITTED==0,'Capture must not serialize or print')
M.Enable(false)
assert(HandleUpdate==cachedUpdate and HandlePostUpdate==cachedPost and UI.Render==dormantRender)
local report=M.Take();assert(#report.frames==3 and report.dropped==0)
QA_REPORT=report
for i,f in ipairs(report.frames)do
 assert(f.frame==i and f.scopes['ui.Update'].calls==1 and f.scopes['main.Update'].calls==1)
 assert(f.scopes['ui.Render'].inclusiveMs==4 and f.scopes['ui.Render'].selfMs==2)
 assert(f.scopes['ui.Layout'].inclusiveMs==2 and f.scopes['ui.Layout'].selfMs==2)
 assert(f.measuredWallMs==16 and f.wallMs==18 and f.unscopedWallMs==2)
 assert(f.framePresentedCalls==1 and f.callsAfterFramePresented==0)
 assert(f.partialStart==(i==1) and f.partialEnd==(i==3))
 local first=f.events[1][1]
 assert(first==(i==2 and 'main.Update' or 'ui.Update'))
end
assert(M.Snapshot().pending==0)
-- Dormant callbacks remain cached but perform no extra timing calls.
local before=tick;HandleUpdate();assert(tick-before==5 and M.Snapshot().currentFrame==nil)
-- An exception is rethrown, the stack closes, and the caller can stop capture.
QA_FAIL=true
frameId=5;M.Enable();local ok,err=pcall(UI.Update)
assert(not ok and tostring(err):find('expected pipeline failure',1,true))
M.Enable(false);local errorReport=M.Take()
assert(errorReport.frames[1].scopes['ui.Update'].errors==1)
-- Integer timer wrap preserves measured durations.
QA_FAIL=false
tick=4294967294;frameId=9;M.Enable();UI.Update();M.Enable(false)
assert(M.Take().frames[1].scopes['ui.Update'].inclusiveMs==3)
-- The bounded buffer reports dropped frames rather than growing indefinitely.
M.capacity=1;frameId=10;M.Enable();HandleUpdate();frameId=11;HandleUpdate();M.Enable(false)
local bounded=M.Take();assert(#bounded.frames==1 and bounded.dropped==1)
-- Stop before emission; no serialization occurs in measured scopes.
M.capacity=4096;frameId=20;M.Enable();HandleUpdate();M.Enable(false)
assert(M.Emit()==1 and #EMITTED==1)
-- F9 is processed only after the measured EndFrame handler and cached wrapper
-- return. It starts/stops capture without changing any subscribed reference.
frameId=30;QA_PHASE='Update';QA_F9=true;cachedUpdate();cachedPresented();assert(M.enabled and HandleUpdate==cachedUpdate)
frameId=31;RunFrame(true);frameId=32;QA_F9=true;RunFrame(false)
assert(not M.enabled and M.Snapshot().bindings==7 and M.Snapshot().pending==0)
assert(HandleFramePresented==cachedPresented and HandlePostUpdate==cachedPost)
assert(M.control.detected==2 and M.control.changes==2)
return {frames=#report.frames,orders=2,bindings=7,nestedRenderMs=4,nestedLayoutMs=2,selfTotalMs=16,
 errorPreserved=true,nilReturnsPreserved=true,clockWrap=true,boundedBuffer=true,noCapturePrinting=true,
 cachedCallbacks=true,preStartDormantWrappers=true,f9OutsideMeasuredCallback=true}
""")
values = dict(result.items())
module_lua = LuaRuntime(unpack_returned_tuples=True)
module_lua.globals().PIPELINE_SUFFIX = built['suffix']
module_lua.globals().CONTROL_SUFFIX = (HERE / 'qa-frame-pipeline-control.lua').read_text(encoding='utf-8')
module_lua.execute("""
local ticks=0
SYSTEM={phase='Update',key=false,frame=1,wrongCalls=0}
Time={GetSystemTime=function()return ticks end}
function GetTime()return {frameNumber=SYSTEM.frame}end
function Advance(n)ticks=ticks+n end
KEY_F9=999
input={GetKeyPress=function(self,key)assert(key==KEY_F9);if SYSTEM.phase~='Update' then return false end;local pressed=SYSTEM.key;SYSTEM.key=false;return pressed end}
UI={Update=function()Advance(1)end,Layout=function()Advance(1)end,UpdateInspector=function()end}
UI.Render=function()UI.Layout();Advance(1)end
require=function(name)assert(name=='urhox-libs/UI');return UI end
function HandleUpdate()SYSTEM.wrongCalls=SYSTEM.wrongCalls+1 end
HandlePostUpdate=HandleUpdate;HandleFramePresented=HandleUpdate
local sharedUpdate=HandleUpdate
cjson={encode=function()assert(SYSTEM.phase=='EndFrame');return '{}'end};print=function()end
local moduleEnv=setmetatable({},{__index=_G})
local base=[[
moduleCalls={update=0,post=0,presented=0}
function HandleUpdate()moduleCalls.update=moduleCalls.update+1;Advance(2)end
function HandlePostUpdate()moduleCalls.post=moduleCalls.post+1;Advance(1)end
function HandleFramePresented()moduleCalls.presented=moduleCalls.presented+1;SYSTEM.phase='EndFrame';SYSTEM.key=false;Advance(1)end
]]
assert(load(base..'\\n'..PIPELINE_SUFFIX..'\\n'..CONTROL_SUFFIX,'module-env-fixture','t',moduleEnv))()
-- Same-named callbacks in _G deliberately differ from actual module callbacks.
assert(HandleUpdate==sharedUpdate and moduleEnv.HandleUpdate~=HandleUpdate)
local cached={update=moduleEnv.HandleUpdate,post=moduleEnv.HandlePostUpdate,presented=moduleEnv.HandleFramePresented}
local M=VOX_QA_FRAME_PIPELINE
SYSTEM.key=true;cached.update();cached.presented();assert(M.enabled)
SYSTEM.frame=2;SYSTEM.phase='Update';UI.Update();cached.update();cached.post();UI.Render();cached.presented()
SYSTEM.frame=3;SYSTEM.phase='Update';SYSTEM.key=true;cached.update();cached.post();cached.presented()
assert(not M.enabled and M.control.detected==2 and M.control.changes==2)
assert(SYSTEM.wrongCalls==0 and moduleEnv.moduleCalls.update==3 and moduleEnv.moduleCalls.post==2)
assert(M.observed['main.Update'].calls==3 and M.observed['main.FramePresented'].calls==3)
assert(M.Snapshot().bindings==7 and M.Snapshot().identity.callbackOwner=='lexical-entry')
""")
values['moduleEnvDifferentFromGlobal'] = True
values['updateLatchSurvivesEndFrameKeyClear'] = True
def native(value):
    if hasattr(value, 'items'):
        items = dict(value.items())
        if items and set(items) == set(range(1, len(items) + 1)):
            return [native(items[i]) for i in range(1, len(items) + 1)]
        return {key: native(item) for key, item in items.items()}
    return value

captured = native(lua.globals().QA_REPORT)
records = [{'frame': frame, 'dropped': captured['dropped'], 'identity': captured['identity']}
           for frame in captured['frames']]
analyzed = json.loads(subprocess.check_output([
    'node', '-e', "const fs=require('fs');console.log(JSON.stringify(require('./tools/migration/analyze-frame-pipeline.cjs').analyze(JSON.parse(fs.readFileSync(0,'utf8')))))"
], input=json.dumps(records), cwd=ROOT, text=True, encoding='utf-8'))
assert analyzed['completeFrames'] == 1 and not analyzed['issues']
assert analyzed['meanWallMs'] == 18 and analyzed['meanMeasuredWallMs'] == 16 and analyzed['meanUnscopedWallMs'] == 2
assert next(row for row in analyzed['rows'] if row['name'] == 'ui.Render')['selfMsPerFrame'] == 2
values['analyzerEndToEnd'] = True
fixed_lua = LuaRuntime(unpack_returned_tuples=True)
fixed_lua.execute("""
tick=0;frameId=1;steps=2;Time={GetSystemTime=function()return tick end}
function GetTime()return {frameNumber=frameId}end
function Advance(n)tick=tick+n end
UI={Update=function()Advance(3)end,Layout=function()Advance(2)end,UpdateInspector=function()end}
UI.Render=function()Advance(1);UI.Layout();Advance(1)end
Battle={BeforeStep=function(a,b,c)Advance(2);if FAIL_FIXED then error('fixed failure')end;return a,b,c end,
 AfterStep=function()Advance(1)end}
World={Step=function()Advance(3)end}
local originals={Battle.BeforeStep,World.Step,Battle.AfterStep}
require=function(name)
 if name=='urhox-libs/UI'then return UI end
 if name=='combat.BattleController'then return Battle end
 assert(name=='drive.TrackWorld');return World
end
function HandleUpdate()
 Advance(4)
 for i=1,steps do
  local a,b,c=Battle.BeforeStep(7,nil,false);assert(a==7 and b==nil and c==false)
  World.Step();Battle.AfterStep()
 end
end
function HandlePostUpdate()Advance(2)end
function HandleFramePresented()Advance(1)end
cjson={encode=function()error('No serialization while capturing')end};print=function()end
""")
fixed_lua.execute(built['fixedSuffix'])
fixed_report = fixed_lua.execute("""
local M=VOX_QA_FRAME_PIPELINE;assert(M.Snapshot().bindings==10)
assert(M.Snapshot().identity.fixedSteps and M.Snapshot().identity.fixedStepSources['combat/BattleController.lua'])
M.Enable()
for i=1,3 do
 frameId=i;UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();Advance(2)
end
M.Enable(false);local report=M.Take()
for _,frame in ipairs(report.frames)do
 assert(frame.scopes['fixed.BeforeStep'].calls==2 and frame.scopes['fixed.WorldStep'].calls==2 and frame.scopes['fixed.AfterStep'].calls==2)
 assert(frame.scopes['main.Update'].inclusiveMs==16 and frame.scopes['main.Update'].selfMs==4)
 assert(frame.measuredWallMs==26 and frame.wallMs==28 and frame.unscopedWallMs==2)
 assert(frame.scopes['fixed.WorldStep'].selfMs==6)
end
steps=6;frameId=9;M.Enable();UI.Update();HandleUpdate();HandlePostUpdate();UI.Render();HandleFramePresented();M.Enable(false)
assert(M.Take().frames[1].droppedEvents==0,'Maximum six fixed steps fit the event buffer')
FAIL_FIXED=true;frameId=10;M.Enable();local ok,err=pcall(HandleUpdate)
assert(not ok and tostring(err):find('fixed failure',1,true));M.Enable(false)
local failed=M.Take().frames[1];assert(failed.scopes['fixed.BeforeStep'].errors==1 and failed.scopes['main.Update'].errors==1)
return report
""")
fixed_capture = native(fixed_report)
fixed_records = [{'frame': frame, 'dropped': fixed_capture['dropped'], 'identity': fixed_capture['identity']}
                 for frame in fixed_capture['frames']]
fixed_analysis = json.loads(subprocess.check_output([
    'node', '-e', "const fs=require('fs'),assert=require('assert/strict'),a=require('./tools/migration/analyze-frame-pipeline.cjs').analyze;const records=JSON.parse(fs.readFileSync(0,'utf8')),good=a(records);const bad=structuredClone(records);bad[1].frame.scopes['fixed.AfterStep'].calls++;assert.ok(a(bad).issues.some(s=>s.includes('Fixed-step call count mismatch')));const outside=structuredClone(records);outside[1].frame.events.unshift(['fixed.BeforeStep','enter',0],['fixed.BeforeStep','leave',0]);assert.ok(a(outside).issues.some(s=>s.includes('outside direct main.Update')));console.log(JSON.stringify(good));"
], input=json.dumps(fixed_records), cwd=ROOT, text=True, encoding='utf-8'))
assert fixed_analysis['issues'] == [] and fixed_analysis['completeFrames'] == 1
assert fixed_analysis['fixedSteps']['total'] == 2
assert fixed_analysis['fixedSteps']['mainFixedMsPerStep'] == 6
assert fixed_analysis['fixedSteps']['mainFixedMsPerFrame'] == 12
assert fixed_analysis['fixedSteps']['meanOtherUpdateMs'] == 4
assert fixed_analysis['fixedSteps']['meanOutsideUpdateMs'] == 12
values['optionalFixedStepBindings'] = 10
values['fixedStepModules'] = 2
values['fixedStepCallsAndParentConserved'] = True
values['fixedStepResidualsAndNegativeControls'] = True
values['fixedStepErrorAndNilReturnsPreserved'] = True
values['sixStepEventBuffer'] = True
values['probeSha256'] = hashlib.sha256((HERE / 'qa-frame-pipeline.lua').read_bytes()).hexdigest()
print(json.dumps({'result': 'PASS', 'checks': values, 'boundary': 'Offline Lua behavior only; no frame rate or engine attribution claim'}, ensure_ascii=False, indent=2))
