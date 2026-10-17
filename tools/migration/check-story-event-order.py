"""Compare actual frozen story methods and production event dispatch, without GPU."""
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source_script = r'''
const fs=require('fs'),crypto=require('crypto'),vm=require('vm');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
let log=[];
const c=vm.createContext({THREE:{Vector3:class{}},KINDS:{},performance:{now:()=>0},
 radio:name=>log.push('radio:'+name),recordClear:()=>({newBest:true,best:{}}),
 document:{pointerLockElement:null},localStorage:{getItem:()=>null},setTimeout(){},clearTimeout(){}});
const hashes={};
for(const [path,name] of [['three/src/battle/storyMission.js','StoryMission'],
 ['shared/story/level2.js','LEVEL2'],['shared/story/level3.js','LEVEL3'],['shared/story/level4.js','LEVEL4']]){
 const bytes=fs.readFileSync(baseline.snapshot+'/'+path),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[path].sha256)throw Error('Frozen source changed: '+path);hashes[path]=hash;
 vm.runInContext('(()=>{'+bytes.toString().replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.'+name+'='+name+';})()',c);
}
const cases=[];
for(const level of [c.LEVEL2,c.LEVEL3,c.LEVEL4])for(const step of level.steps)
 for(const [index,beat] of (step.beats||[]).entries())if(beat.spawn){
  log=[];const m=Object.create(c.StoryMission.prototype);
  Object.assign(m,{stepT:beat.t||0,progress:beat.p||0,beatsFired:new Set(),
   hud:{talking:false,say:()=>log.push('say'),banner:()=>log.push('banner')},
   spawn:()=>log.push('spawn'),alive:()=>0,hold:{energy:.5}});
  m._beats({beats:[beat]},.01);
  cases.push({level:level.id,step:step.id,beat:index+1,events:log});
 }
log=[];const m=Object.create(c.StoryMission.prototype),noop=()=>{};
Object.assign(m,{time:120,stats:{deaths:0,fails:0},level:{id:'s2',name:'物资车',no:'02'},
 view:{hideBeacon:noop},clearEnemies:noop,hud:{marker:noop,pips:noop,clock:noop,objectiveDone:noop,banner:noop,result:noop}});
m._complete();m._result();const completion=[...log];
const seedCases=[];let seeds=[];
Object.assign(c,{enemyPrefab:()=>({source:{}}),centeredSpawn:(_spec,at)=>at,
 EnemyDriver:class{constructor(opts){seeds.push(opts.seed)}},
 CarUnit:class{constructor(){this.alive=true;this.spec={};this.vehicle={place(){}}}savePose(){}}});
for(const test of [{name:'default'},{name:'explicit',tag:'reinforcements'},{name:'clear-fight',fight:true}]){
 seeds=[];const beat={t:1,spawn:[{at:[1,2,3]},{at:[4,5,6]}]};if(test.tag!==undefined)beat.tag=test.tag;
 const m=Object.create(c.StoryMission.prototype);
 Object.assign(m,{time:73.9,level:{id:'s3'},stepT:1,progress:0,beatsFired:new Set(),enemies:new Map(),
  drive:{player:{bp:{stats:()=>({fitTier:{id:2}})},pos:[0,0,0]},sim:{units:[]},layout:{nav:{}}},
  hud:{talking:false},view:{},_env:()=>({})});
 if(test.fight){
  const step={id:'scouts',kind:'clear',pos:[0,0,0],trigger:10,enemies:beat.spawn,timeout:360,fightTitle:'scouts'};
  m.level.steps=[step];Object.assign(m,{begun:true,deadAt:null,phase:'go',i:0,fx:{update:noop},_target:()=>step.pos,_marker:noop,
   hud:{talking:false,update:noop,say:noop,banner:noop,retitle:noop},view:{update:noop,hideBeacon:noop}});
  m.drive.player.alive=true;m.update(0);
 }else m._beats({beats:[beat]},.01);
 const tags=[...m.enemies.values()].map(e=>e.tag),captured=[...seeds],remaining=[];
 m.clearEnemies('unrelated');remaining.push(m.enemies.size);
 m.clearEnemies(tags[0]);remaining.push(m.enemies.size);
 seedCases.push({...test,seeds:captured,tags,remaining});
}
console.log(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,cases,completion,seedCases}));
'''
reference = json.loads(subprocess.check_output(['node', '-e', source_script], encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().MissionDependencies=lua.table_from(re.findall(r'require\s*\(?\s*[\'"]([^\'"]+)',(root/'scripts/story/Mission.lua').read_text(encoding='utf-8-sig')))


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


levels = {f's{i}': json.loads((root / f'assets/Story/Mission/Level{i}.json').read_text(
    encoding='utf-8-sig'))['level'] for i in [2, 3, 4]}
lua.globals().Levels = convert(levels)
runner = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,id in ipairs(MissionDependencies)do
 if id~='story.MissionRules' then package.preload[id]=function()return {}end end
end
package.preload['render.StoryStomp']=function()return {Emit=function()end}end
local Mission=require 'story.Mission';local Rules=require 'story.MissionRules'
package.loaded['combat.ArenaData'].prefabs={['red:1:assault:0']={}}
local seeds={}
package.loaded['combat.EnemyDriver'].New=function(_,_,_,_,opts)seeds[#seeds+1]=opts.seed;return {}end
package.loaded['combat.CarUnit'].New=function()
 return {spec={bounds={min={0,0,0},max={1,1,1}}},vehicle={Place=function()end},SavePose=function()end,Dispose=function()end}
end
return {
 seed=function(test)
  seeds={};local beat={t=1,tag=test.tag,spawn={{at={1,2,3}},{at={4,5,6}}}}
  local step=test.fight and {id='scouts',kind='clear',pos={0,0,0},trigger=10,enemies=beat.spawn,timeout=360,fightTitle='scouts'} or {beats={beat}}
  local r=Rules.New({id='s3',steps={step}});r.index=1;r.stepT=1;r.time=73.9
  if test.fight then r.begun=true;r.phase='go';r:Step(0,{alive=true,pos={0,0,0},enemies=2})
  else r:Beats(.01,{enemies=0,talking=false})end
  local m=setmetatable({rules=r,level=r.level,tier=1,world={layout={nav={nodes={}}},units={}},
   player={pos={0,0,0}},entries={{unit={}}},session={},radio={Play=function()end},voice={Say=function()end},
   view={HideBeacon=function()end},Banner=function()end,Environment=function()return {}end},Mission)
  m:Events();local tags={};for i=2,#m.entries do tags[#tags+1]=m.entries[i].tag or '<nil>'end
  local remaining={};m:ClearEnemies('unrelated');remaining[1]=#m.entries-1
  m:ClearEnemies(tags[1]);remaining[2]=#m.entries-1
  return {seeds=seeds,tags=tags,remaining=remaining}
 end,
 beat=function(test)
  local level=Levels[test.level];local step
  for _,s in ipairs(level.steps)do if s.id==test.step then step=s end end
  local beat=assert(step.beats[test.beat]);local r=Rules.New({spawn={},steps={{beats={beat}}}})
  r.index=1;r.stepT=beat.t or 0;r.progress=beat.p or 0;r.hold={energy=.5}
  r:Beats(.01,{enemies=0,talking=false});local out={}
  for _,e in ipairs(r:Drain())do
   out[#out+1]=e.type=='radio' and 'radio:'..e.cue or e.type
  end
  return out
 end,
 completion=function()
  local out={};local events={{type='complete'},{type='result',grade='S',time=120}}
  local noop=function()end
  local m=setmetatable({level={id='s2',no='02',name='物资车'},rules={time=120,Drain=function()return events end},
   radio={Play=function(_,name)out[#out+1]='radio:'..name end},voice={PrepareResultQuote=noop},
   player={alive=true},ClearEnemies=noop,Banner=noop,Quote=function()return ''end,view={Objective=noop,HideBeacon=noop},
   session={Pause=noop,app={store={Read=function()return {}end,Write=function()return true end}}}},Mission)
  m:Events();return out
 end}
''')
failures = []
checks = 0
for case in reference['cases']:
    actual = list(runner.beat(convert(case)).values())
    if actual != case['events']:
        failures.append({'case': f"{case['level']}/{case['step']}/{case['beat']}",
                         'expected': case['events'], 'actual': actual})
    checks += 1
actual = list(runner.completion().values())
if actual != reference['completion']:
    failures.append({'case': 'complete-then-result', 'expected': reference['completion'], 'actual': actual})
checks += 1
for case in reference['seedCases']:
    actual = runner.seed(convert(case))
    for key in ['seeds', 'tags', 'remaining']:
        values = list(actual[key].values())
        if values != case[key]:
            failures.append({'case': f"spawn-{case['name']}-{key}", 'expected': case[key], 'actual': values})
        checks += 1
paths = ['scripts/story/Mission.lua', 'scripts/story/MissionRules.lua']
report = {'result': 'FAIL' if failures else 'PASS', 'checks': checks, 'failures': failures,
          'reference': reference, 'productionHashes': {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths},
          'boundary': 'Actual frozen StoryMission._beats/spawn/_complete/_result and authored s2/s3/s4 spawn beats; actual Lua MissionRules.Beats, Mission.Events and Mission.Spawn. Native car/driver constructors are adapters capturing default and explicit tags/seeds. Event order, cue count and seed strings only; no rendered, audible, natural campaign or performance acceptance.'}
suffix = '-before' if failures else ''
out = root / f'docs/migration/evidence/story-event-order-offline{suffix}.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': checks, 'failures': failures, 'evidence': str(out)}, ensure_ascii=False))
if failures:
    sys.exit(1)
