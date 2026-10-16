"""Execute frozen JS result frames against actual Lua cinematic/result timing."""
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
const fs=require('node:fs'),crypto=require('node:crypto'),vm=require('node:vm'),path=require('node:path');
const base=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const ctx=vm.createContext({URLSearchParams,location:{search:''},performance:{now:()=>0},THREE:{Vector3:class{}},
 setTimeout(){},showSalvageResult(){},CARGO_SLOTS:20});
const hashes={};
for(const [name,expose] of [['three/src/salvage/salvageRun.js','Run=SalvageRun'],['three/src/salvage/salvageCine.js','Cine=SalvageCine']]){
 const raw=fs.readFileSync(path.join(base.snapshot,name)),hash=crypto.createHash('sha256').update(raw).digest('hex');
 if(hash!==base.files[name].sha256)throw Error('Frozen source drift: '+name);hashes[name]=hash;
 vm.runInContext(raw.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.'+expose+';',ctx);
}
const cases=[];
for(const name of ['extract','death'])for(const cadence of ['regular','small','mixed'])for(const controlling of [false,true]){
 const run=Object.create(ctx.Run.prototype),cine=Object.create(ctx.Cine.prototype),trace=[];
 Object.assign(run,{begun:true,landed:true,finished:false,time:100,kills:2,openedCount:4,cargo:new Map([['scrap',3]]),
  extracts:[],extracting:name==='extract',deadAt:name==='death'?100:null,
  drive:{player:{pos:[0,0,0]},input:{controlling},camera:{},renderer:{},ui:{}},
  hud:{el:{hidden:false},bars(){},caption(){},skip(){}},fx:{shake:0,update(){},target(){}},_hud(){},_value(){return 3;}});
 Object.assign(cine,{run,drive:run.drive,cur:{name,t:0,len:name==='extract'?6.2:2.8,onDone:()=>run._extracted({name:'exit'})},
  _approachStep(){},_extractStep(){return null;},_deathStep(){return null;}});run.cine=cine;
 for(let i=0;i<160;i++){
  const dt=cadence==='regular'?.1:cadence==='small'?.05:[.07,0,.1,.03][i%4];
  run.update(dt);trace.push({dt,time:run.time,resultTime:run.result?.time??null,finished:run.finished,paused:run.paused,shot:!!cine.cur});
  if(run.finished){run.update(.1);trace.push({dt:.1,time:run.time,resultTime:run.result.time,finished:true,paused:run.paused,shot:!!cine.cur});break;}
 }
 if(!run.result)throw Error('Source result missing');cases.push({name,cadence,controlling,trace});
}
console.log(JSON.stringify({commit:base.commit,sourceHashes:hashes,cases}));
'''

golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
paths = ['scripts/salvage/Run.lua', 'scripts/salvage/Cinematics.lua', 'scripts/salvage/RunRules.lua',
         'scripts/salvage/Loot.lua', 'scripts/app/TrialSession.lua']
before = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
resources = {p: json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8')) for p in ['UI/Outgame.json', 'Salvage/RunData.json']}

FIXTURE = r'''
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(path) return resources[path] end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
package.loaded['render.SalvageCinematics']={};package.loaded['salvage.CineMotion']={}
package.loaded['ui.SourceButtonMotion']={Step=function() end}
local Run=require 'salvage.Run';local Cine=require 'salvage.Cinematics'
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Near(a,b) return a~=nil and b~=nil and math.abs(a-b)<1e-8 end
local function New(name)
 local run=setmetatable({begun=true,landed=true,rules={finished=true,time=100,cargo={scrap=3},kills=2,openedCount=4},
  original={parts={}},player={alive=name~='death'},runId='time',
  session={Pause=function() end,app={salvageLobby={Owned=function() return 0 end,CommitRun=function() return true end}}}},Run)
 local cine=setmetatable({run=run,session=run.session,time=0,shake=0,flashTime=0,playing=true,blocking=true,
  current={name=name,t=0,len=name=='extract' and 6.2 or 2.8,exit={name='exit'}},view={HideShip=function() end},
  bars={},hud={},namecard={},caption={},skip={},StepShot=function() end,HoldCar=function() end},Cine)
 run.cine=cine;return run,cine
end
for ci,case in ipairs(golden.cases) do
 local run,cine=New(case.name)
 Check(run:Return()==false and not run.result,'cinematic denies early return '..ci)
 for fi,frame in ipairs(case.trace) do
  cine:Update(frame.dt)
  local label=ci..':'..fi
  Check(Near(run.rules.time,frame.time),'source elapsed time '..label)
  Check((run.result~=nil)==frame.finished,'source result boundary '..label)
  Check((cine.current~=nil)==frame.shot,'source shot completion '..label)
  if frame.resultTime then Check(Near(run.result.time,frame.resultTime),'source final frame snapshots before dt '..label) end
 end
 Check(run.committed and run:Return(),'finished result can return '..ci)
end
for _,name in ipairs({'drop','elite','none'}) do
 local run,cine=New(name);cine.current=name~='none' and {name=name,t=0,len=100} or nil
 cine:Update(.1);Check(run.rules.time==100,'unrelated presentation has no second gameplay clock '..name)
end
for _,guard in ipairs({'notBegun','notLanded','disposedRun','disposedCine','alreadyResult','liveRules'}) do
 local run,cine=New('extract')
 if guard=='notBegun' then run.begun=false elseif guard=='notLanded' then run.landed=false
 elseif guard=='disposedRun' then run.disposed=true elseif guard=='disposedCine' then cine.disposed=true
 elseif guard=='alreadyResult' then run.result={} else run.rules.finished=false end
 cine:Update(.1);Check(run.rules.time==100,'elapsed guard '..guard)
end
local run,cine=New('extract');cine:Update(.5)
Check(Near(run.rules.time,100.5) and Near(cine.current.t,.1),'original elapsed dt retained independently of existing visual clamp')
local run,cine=New('death');cine.current.t=2.75;cine:Update(.1)
Check(run.result.time==100 and Near(run.rules.time,100.1),'final frame adds only after actual Finish/Commit snapshot')
local run,cine=New('extract');cine:Update(-1)
Check(run.rules.time==100,'negative input does not reverse elapsed time')
return checks
'''


def execute(old=None, mutation=None):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().golden = table(golden)
    lua.globals().resources = table(resources)
    sources = dict(old or {})
    if mutation:
        sources['salvage.Cinematics'] = mutation
    for module, source in sources.items():
        lua.globals().moduleSource = source
        lua.globals().moduleName = module
        lua.execute('package.preload[moduleName]=assert(load(moduleSource,moduleName))')
    return list(lua.execute(FIXTURE).values())


checks = execute()
commit = '48ef15f2c9c95c400f91ee6e34309399d02b3733'
old = {}; old_hashes = {}
for module in ['salvage.Run', 'salvage.Cinematics']:
    path = 'scripts/' + module.replace('.', '/') + '.lua'
    data = subprocess.check_output(['git', 'show', commit + ':' + path])
    old[module] = data.decode('utf-8');old_hashes[path] = hashlib.sha256(data).hexdigest()
negative = []
candidate = (ROOT / 'scripts/salvage/Cinematics.lua').read_text(encoding='utf-8')
after = '    if advanceTime then self.run:AdvancePresentationTime(presentationDt) end'
assert candidate.count(after) == 1
before_finish = candidate.replace(after, '').replace('    if c then\n', after + '\n    if c then\n', 1)
for label, modules, mutation in [('actual old main', old, None), ('incorrect final frame ordering', None, before_finish)]:
    try:
        execute(modules, mutation)
    except Exception as error:
        negative.append({'name': label, 'rejected': True, 'reason': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control accepted: ' + label)
assert before == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}, 'Production drift'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'],
          'sourceCases': len(golden['cases']), 'sourceFrames': sum(len(c['trace']) for c in golden['cases']),
          'productionHashes': before, 'resources': {'assets/' + p: hashlib.sha256((ROOT / 'assets' / p).read_bytes()).hexdigest() for p in resources},
          'testInputs': {'tools/migration/check-salvage-presentation-time.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
          'negativeControl': {'commit': commit, 'hashes': old_hashes, 'cases': negative},
          'boundary': 'Actual frozen JS Run.update/Cine.update/_end/Run._finish and actual Lua Cine.Update/Finish/Run.Finish/Commit. UI/graphics/vector motion/audio/SDK are edge adapters. Real .05/.1/mixed dt, pointer-controlling true/false, and zero dt; no wall clock. Existing Lua visual dt clamp >.1 is not changed and long-stall cinematic duration equality is not claimed. Return denial and unrelated/finished/disposed guards executed. TrialSession integration read only. No browser/GPU, natural extraction/death, real account, audible or performance acceptance.'}
output = ROOT / 'docs/migration/evidence/salvage-presentation-time-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases'], 'sourceFrames': report['sourceFrames'], 'negativeControls': len(negative)}))
