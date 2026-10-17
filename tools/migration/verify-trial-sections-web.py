"""Small offline QA observer contract checks. Does not start a game or measure performance."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

snapshot = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / '.tmp/outgame-cached-1792166173967'
node = r"""
const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const prepared=JSON.parse(fs.readFileSync(path.join(process.argv[1],'identity.json'))),tool=require('./tools/migration/build-drive-sections-probe.cjs');
const spec=require('./tools/migration/trial-section-bindings.cjs');
for(const [name,keys] of spec.methods){
 const source=fs.readFileSync(path.join(prepared.source_directory,'scripts',name.replaceAll('.','/')+'.lua'),'utf8');
 for(const key of keys)assert.match(source,new RegExp('function\\s+\\w+[.:]'+key+'\\s*\\('),'Actual exported method '+name+'.'+key);
}
const old=JSON.parse(fs.readFileSync('docs/migration/evidence/performance-drive-sections-match-1792166475802/result.json'));
const base=tool.buildDriveSectionsProbe(prepared),detail=tool.buildDriveSectionsProbe(prepared,{trialSections:true});
const suffix=fs.readFileSync('tools/migration/qa-frame-wall-observer.lua','utf8')+'\n'+base+'\n'+
fs.readFileSync('tools/migration/probe-outgame-web.lua','utf8')+'\n'+fs.readFileSync('tools/migration/monitor-disabled-observer.lua','utf8');
assert.equal(crypto.createHash('sha256').update(suffix).digest('hex'),old.identity.probeSha256,'Original 57 wrapper suffix stays byte-identical');
console.log(JSON.stringify({base,detail,spec,defaultSuffixUnchanged:true}));
"""
payload = json.loads(subprocess.check_output(['node', '-e', node, str(snapshot)], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('assert(load(...))', payload['detail'])
lua.execute('assert(load(...))', (ROOT / 'scripts/main.lua').read_text(encoding='utf-8') + '\n' + payload['detail'])
setup = r"""
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
local ticks=0
Time={GetSystemTime=function()ticks=ticks+1;return ticks end}
QA_EMITTED={}
cjson={encode=function(value) QA_EMITTED[#QA_EMITTED+1]=value;return '{}' end}
print=function()end
local function Identity(...)return ... end
QA_HUD={Update=Identity,readouts={Tick=Identity,Refresh=Identity},match={Update=Identity},sniper={Update=Identity}}
QA_APP={trial={hud=QA_HUD,battle={}},loadingFlow={active=false}}
"""
lua.execute(setup)
lua.execute(payload['detail'])
result = lua.execute(r"""
local M=VOX_QA_DRIVE_SECTIONS
assert(M.Snapshot().trialSectionsProfile and not M.Snapshot().installed)
M.Toggle();assert(M.Snapshot().bindings==97)
for i=1,5 do
 M.BeginFrame(QA_APP)
 local a,b,c,d=QA_MODULES['render.DriveView'].Update(7,nil,false,4)
 assert(a==7 and b==nil and c==false and d==4)
 QA_HUD.Update(QA_APP.trial,1/60)
 QA_HUD.readouts:Tick(1/60,false);QA_HUD.readouts:Refresh()
 QA_HUD.match.Update(1/60);QA_HUD.sniper.Update({}, {})
 M.EndFrame()
end
local snapshot=M.Snapshot();assert(snapshot.bindings==102 and snapshot.expectedBindings==102)
assert(#snapshot.instanceLabels==5 and snapshot.frames==5)
M.Emit();assert(#QA_EMITTED==3 and #QA_EMITTED[3].frames==1)
local newHud={};for key,value in pairs(QA_HUD)do newHud[key]=value end
QA_APP.trial.hud=newHud
local ok,err=pcall(M.BeginFrame,QA_APP);assert(not ok and tostring(err):find('session/HUD changed',1,true))
QA_APP.trial.hud=QA_HUD
-- Each rejected BeginFrame is fatal in a real run; reset only this fixture.
M.inFrame=false
QA_HUD.readouts.Tick=function()end
ok,err=pcall(M.BeginFrame,QA_APP);assert(not ok and tostring(err):find('HUD method changed',1,true))
return {bindings=snapshot.bindings,frames=snapshot.frames,batches=#QA_EMITTED}
""")
negative = LuaRuntime(unpack_returned_tuples=True)
negative.execute(setup)
duplicate = payload['detail'].replace('local TRIAL_METHODS={', 'local TRIAL_METHODS={{"drive.Vehicle",{"Step"},"vehicle"},', 1)
assert duplicate != payload['detail']
negative.execute(duplicate)
try:
    negative.execute('VOX_QA_DRIVE_SECTIONS.Toggle()')
except Exception as error:
    assert 'Duplicate drive scope binding: vehicle.Step' in str(error), str(error)
else:
    raise AssertionError('Duplicate base/extension binding survived')
print(json.dumps({'result': 'PASS', 'syntax': 2, 'default57SuffixByteIdentical': payload['defaultSuffixUnchanged'],
                  'exportedModuleMethods': payload['spec']['moduleBindings'], 'bindings': result['bindings'],
                  'frames': result['frames'], 'batches': result['batches'],
                  'negativeControls': ['duplicate base/extension binding', 'HUD instance replaced', 'HUD method replaced'],
                  'boundary': 'Offline fake clock and module fixtures only; no Web, Native or device performance result.'}))
