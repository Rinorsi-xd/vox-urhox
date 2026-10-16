"""Frozen 10/15 update/objective versus actual salvage rules and result consumer."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = r'''
const fs=require('node:fs'),crypto=require('node:crypto'),vm=require('node:vm');
const baseline=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const name='three/src/salvage/salvageRun.js',raw=fs.readFileSync(require('node:path').join(baseline.snapshot,name));
const hash=crypto.createHash('sha256').update(raw).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen source drift');
const context=vm.createContext({URLSearchParams,location:{search:''},performance:{now:()=>0},CARGO_SLOTS:20,THREE:{Vector3:class{}}});
vm.runInContext(raw.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Run=SalvageRun;',context);
const objectives=[];
for(const time of [0,600,600.01,899.99])for(const count of [0,15,20])for(const opened of [false,true]){
 const run=Object.create(context.Run.prototype);
 Object.assign(run,{time,cargo:new Map(),opened:new Set(opened?['core']:[]),_used:()=>count,
 drive:{player:{pos:[0,0,0]},camera:{getWorldDirection(){return {x:0,z:1};}}},
 wrecks:[{id:'core',kind:'wreck',model:'core',name:'core',g:[10,0,0]}],extracts:[{id:'A',name:'exit',g:[5,0,0],openAt:600}]});
 objectives.push({time,count,opened,target:run._objective()});
}
const deadlines=[];
for(const initial of [899.98,899.99,900,901]){
 const trace=[],run=Object.create(context.Run.prototype);
 Object.assign(run,{begun:true,landed:true,finished:false,time:initial,deadAt:null,extracts:[],cargo:new Map(),
 drive:{player:{pos:[0,0,0]},input:{}},fx:{update(){},target(){}},cine:{update(){}},hud:{search(){}},
 _fail(reason){trace.push(reason);this.finished=true;},_hud(){},_weigh(){},_airdrop(){},_encounters(){},_director(){},_target(){return null;}});
 run.update(.01);deadlines.push({initial,dt:.01,time:run.time,finished:run.finished,reasons:trace});
}
console.log(JSON.stringify({commit:baseline.commit,sourceHashes:{[name]:hash},objectives,deadlines}));
'''
golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
paths = ['scripts/salvage/RunRules.lua', 'scripts/salvage/Run.lua', 'scripts/salvage/Director.lua', 'scripts/salvage/Loot.lua']
before = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
resources = {p: json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8')) for p in ['UI/Outgame.json', 'Salvage/RunData.json']}
fixture = r'''
package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
package.loaded['core.ResourceData']={Read=function(path) return resources[path] end}
package.loaded['combat.CarUnit']={};package.loaded['combat.EnemyDriver']={};package.loaded['salvage.Drops']={}
package.loaded['ui.SalvageLootMotion']={Event=function() end}
local Rules=require 'salvage.RunRules'
local Run=require 'salvage.Run'
if not onlyDeadline then for i,case in ipairs(golden.objectives) do
 local r=Rules.New({loot={},wrecks={},extracts={}},{vaults=0})
 r.time=case.time;r.cargo={scrap=case.count*require('salvage.Loot').Stack('scrap')};r.opened.core=case.opened
 r.objects={{id='core',kind='wreck',model='core',name='core',g={10,0,0}}}
 r.extracts={{id='A',name='exit',g={5,0,0},openAt=600}}
 local target=r:Objective({0,0,0})
 Check(not target and not case.target or target and case.target and target.text==case.target.text and target.dist==case.target.dist,'frozen source objective retained '..i)
end end
for i,case in ipairs(golden.deadlines) do
 local r=Rules.New({loot={},wrecks={},extracts={}},{vaults=0})
 r.time=case.initial;r.airdrops={};r.cargo={scrap=3}
 r:Step(case.dt,{alive=true,pos={0,0,0},speed=0,width=2})
 Check(math.abs(r.time-case.time)<1e-8 and r.finished==case.finished,'source exact deadline eligibility '..i)
 local observed
 local run=setmetatable({rules=r,player={alive=true},original={parts={}},runId='deadline',cine={playing=false},
 audio={Event=function() end},session={Pause=function() end,app={salvageLobby={
 Owned=function() return 0 end,CommitRun=function(_,id,result) observed=result;return true end}}}},Run)
 run:Events()
 if case.finished then
  Check(run.result and run.result.title==case.reasons[1] and run.committed,'actual failed event reaches exact original result title '..i)
  Check(observed==run.result and not observed.ok and next(observed.cargo)==nil,'actual result consumer retains failure loss contract '..i)
 else Check(not run.result and observed==nil,'no result before source deadline '..i) end
end
return checks
'''


def execute(old=None, only_deadline=False):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().resources = table(resources)
    lua.globals().golden = table(golden)
    lua.globals().onlyDeadline = only_deadline
    if old:
        lua.globals().oldSource = old
        lua.execute("package.preload['salvage.RunRules']=assert(load(oldSource,'@48ef-pre-fix'))")
    return list(lua.execute(fixture).values())


checks = execute()
old_commit = '48ef15f2c9c95c400f91ee6e34309399d02b3733'
old_path = 'scripts/salvage/RunRules.lua'
old_bytes = subprocess.check_output(['git', 'show', old_commit + ':' + old_path])
old_hash = hashlib.sha256(old_bytes).hexdigest()
assert old_hash == '31f704dcb780fc343f84c96ee6b2e8545a5f15cd566a7db5aeb330d0030e1a00'
negative = []
for mode in [True]:
    try:
        execute(old_bytes.decode('utf-8'), mode)
    except Exception as error:
        negative.append({'scope': 'deadline', 'rejected': True, 'reason': str(error).splitlines()[0]})
    else:
        raise AssertionError('Real old main must reject source contract')
assert before == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}, 'Production drift'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'],
          'sourceCases': len(golden['objectives']) + len(golden['deadlines']), 'productionHashes': before,
          'resources': {'assets/' + p: hashlib.sha256((ROOT / 'assets' / p).read_bytes()).hexdigest() for p in resources},
          'testInputs': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in ['tools/migration/check-salvage-exit-contract.py']},
          'negativeControl': {'commit': old_commit, 'path': old_path, 'sha256': old_hash, 'cases': negative},
          'boundary': 'Frozen actual SalvageRun._objective/update versus real Lua RunRules.Objective/Step and Run.Events/Finish. Resource data real; engine/UI/audio/storage consumers adapted. Source cargo slot usage supplied explicitly; actual Lua Loot.Used consumes real stack sizes. No natural extraction, browser/GPU, real account, visual or performance acceptance.'}
output = ROOT / 'docs/migration/evidence/salvage-exit-contract-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases'], 'negativeControls': len(negative)}))
