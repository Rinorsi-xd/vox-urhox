"""Opt-in AfterStep scopes; offline real Lua call graph, no engine run."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

snapshot = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / '.tmp/outgame-cached-1792171171463'
node = r"""
const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const p=JSON.parse(fs.readFileSync(path.join(process.argv[1],'identity.json')));
const b=require('./tools/migration/build-drive-sections-probe.cjs'),s=require('./tools/migration/trial-section-bindings.cjs');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const base=b.buildDriveSectionsProbe(p),trial=b.buildDriveSectionsProbe(p,{trialSections:true});
// Frozen before adding this opt-in mode; default 57 and 102 output must not drift.
assert.equal(sha(base),'c110268747ca5441358e1bba8e8d2a2886742ad7ca4d7a7b8821ac3b5d03e100');
assert.equal(sha(trial),'8fa0cb41bffd8cc8eccc2da3c93ae43f11d064e95daca65766e351bde1104d4d');
assert.equal(s.expectedBindings,102);assert.equal(s.afterStep.expectedBindings,108);
assert.throws(()=>b.buildDriveSectionsProbe(p,{afterStep:true}),/extend explicit trial/);
const runner=require('./tools/migration/check-performance-uninstrumented-web.cjs');
const identity={driveSectionsProfile:true,trialSectionsProfile:true,afterStepProfile:true};
runner.verifyProfileIdentity(identity,true,false,true,false,true);
assert.throws(()=>runner.verifyProfileIdentity(identity,true,false,true),/matching runner/);
assert.throws(()=>runner.verifyProfileIdentity({afterStepProfile:true},false,false,false,false,true),/extend trial/);
assert.throws(()=>runner.verifyProfileIdentity(identity,true,true,true,false,true),/separate runs/);
const state={trialSectionsProfile:true,bindings:108,expectedBindings:108,profile:s.afterStep.profile,instanceLabels:s.instanceLabels};
runner.verifyDriveBindings(state,true,true);
assert.throws(()=>runner.verifyDriveBindings({...state,bindings:102},true,true),/binding count/);
assert.throws(()=>runner.verifyDriveBindings(state,true),/binding count/);
const suffix=b.buildDriveSectionsProbe(p,{trialSections:true,afterStep:true});
const sources={};for(const name of ['combat.BattleController','combat.BattleObjectives','render.ObjectiveView','combat.ConquestRules','audio.BattleFlow']){
 const relative=name.replaceAll('.','/')+'.lua';sources[name]=fs.readFileSync(path.join(p.source_directory,'scripts',relative),'utf8');
}
for(const [name,keys]of s.afterStep.methods.slice(s.methods.length))for(const key of keys)
 assert.match(sources[name],new RegExp('function\\s+\\w+[.:]'+key+'\\s*\\('),'Actual source export '+name+'.'+key);
console.log(JSON.stringify({suffix,sources,profile:s.afterStep.profile,sourceModules:s.afterStep.sourceModules.length,defaultHashes:{base:sha(base),trial:sha(trial)}}));
"""
payload = json.loads(subprocess.check_output(['node', '-e', node, str(snapshot)], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('assert(load(...))', payload['suffix'])
lua.execute(r"""
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local actualRequire=require
QA_MODULES={}
require=function(name)
 if name=='core.Math3' then return actualRequire(name) end
 if not QA_MODULES[name] then QA_MODULES[name]=setmetatable({},{__index=function(t,key)
  local f=function(...)return ... end;rawset(t,key,f);return f
 end}) end
 return QA_MODULES[name]
end
QA_MODULES['core.ResourceData']={Read=function()return {cues={}}end}
local ticks=0
Time={GetSystemTime=function()ticks=ticks+1;return ticks end}
QA_EMITTED={};cjson={encode=function(value)QA_EMITTED[#QA_EMITTED+1]=value;return '{}'end}
print=function()end
""")
# Actual production functions with controlled world/render/audio dependencies.
for name in ['combat.ConquestRules', 'render.ObjectiveView', 'combat.BattleObjectives', 'audio.BattleFlow', 'combat.BattleController']:
    lua.globals().QA_MODULES[name] = lua.execute(payload['sources'][name])
lua.execute(payload['suffix'])
result = lua.execute(r"""
local function Noop()end
local hud={Update=Noop,readouts={Tick=Noop,Refresh=Noop},match={Update=Noop},sniper={Update=Noop}}
local app={trial={hud=hud,battle={}},loadingFlow={active=false}}
local BC=QA_MODULES['combat.BattleController'];local O=QA_MODULES['combat.BattleObjectives']
local Rules=QA_MODULES['combat.ConquestRules'];local View=QA_MODULES['render.ObjectiveView']
local Flow=QA_MODULES['audio.BattleFlow']
local rule=Rules.New({prep=10},{});rule.events={}
local b=setmetatable({clock=0,rules=rule,entries={},events={},sounds=setmetatable({ready=false},{__index=Flow})},{__index=BC})
local objectives=setmetatable({id='conquest',battle=b,points={},bases={blue={aim={0,0,0}},red={aim={0,0,0}}}},{__index=O})
b.objectives=objectives;b.session={};objectives.view=setmetatable({age=0,nextUpdate=0,mode=objectives,Refresh=function()return false end},{__index=View})
for i,id in ipairs({'A','B','C'})do objectives.points[i]={id=id,pos={i*10,0,0},radius=22}end
for i=1,8 do
 local unit={alive=true,team=i<=4 and 'blue' or 'red',spec={bounds={radius=2}},Health=function()return 1 end,Position=function()return {0,0,0}end}
 b.entries[i]={unit=unit}
end
local M=VOX_QA_DRIVE_SECTIONS;M.Toggle()
assert(M.Snapshot().bindings==103)
M.BeginFrame(app);assert(M.Snapshot().bindings==108)
b:AfterStep(1/60)
M.EndFrame();assert(#VOX_DRIVE_SCOPE.stack==0)
local rows=VOX_DRIVE_SCOPE.rows
for _,name in ipairs({'combat.AfterStep','combat.WorldState','objectives.WorldState','objectives.Update','objectiveView.Update','conquestRules.Step','battleFlow.Countdown'})do
 assert(rows[name] and rows[name].calls==1,'Actual nested scope '..name)
end
local sum=0;for _,r in pairs(rows)do sum=sum+r.selfMs end
assert(sum==rows['update.production'].ms,'Real nested call tree self conservation')
assert(rows['combat.WorldState'].ms>=rows['objectives.WorldState'].ms)
assert(rows['objectives.Update'].ms>=rows['objectiveView.Update'].ms)
assert(math.abs(b.clock-1/60)<1e-12 and math.abs(rule.t-1/60)<1e-12)
local snapshot=M.Snapshot();assert(snapshot.profile=='trial-after-step-v1' and snapshot.expectedBindings==108)
assert(snapshot.sourceIdentity['render.ObjectiveView'] and snapshot.sourceIdentity['audio.BattleFlow'])
M.Emit();assert(#QA_EMITTED==1 and #QA_EMITTED[1].frames==1)
M.Toggle();assert(not M.Snapshot().enabled)
return {bindings=snapshot.bindings,profile=snapshot.profile,scopeCount=7,selfConserved=true}
""")
report = {'result': 'PASS', 'profile': result['profile'], 'bindings': result['bindings'],
          'actualProductionNestedScopes': result['scopeCount'], 'selfConserved': result['selfConserved'],
          'defaultSuffixHashesUnchanged': payload['defaultHashes'], 'sourceModules': payload['sourceModules'] + 2,
          'negativeControls': 6,
          'toolSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'boundary': 'Offline real AfterStep/WorldState/BattleObjectives/ConquestRules/ObjectiveView/BattleFlow methods with synthetic clock and controlled dependencies. No engine objects, browser, device FPS or optimization gain.'}
(ROOT / 'docs/migration/evidence/after-step-sections-offline.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
