"""Execute frozen H5 and real Lua story/CarUnit regeneration without hardware."""
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
const fs=require('fs'),crypto=require('crypto'),vm=require('vm');
const b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const hashes={},c=vm.createContext({THREE:{Vector3:class{}},KINDS:{},PARTS:{boost:{wtier:3}},applyRotorWeapons(){}});
function load(p,expression){const raw=fs.readFileSync(b.snapshot+'/'+p),h=crypto.createHash('sha256').update(raw).digest('hex');
 if(h!==b.files[p].sha256)throw Error('Frozen source drift: '+p);hashes[p]=h;
 return vm.runInContext('(()=>{'+raw.toString().replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nreturn '+expression+';})()',c);}
Object.assign(c,load('shared/combat/tuning.js','{HULL,STRUCT,FOV}'));
Object.assign(c,load('shared/drive/combatSpeed.js','{combatSpeed,combatTopSpeed}'));
const Unit=load('shared/combat/carUnit.js','CarUnit'),Mission=load('three/src/battle/storyMission.js','StoryMission');
const inputs=[];
for(const actor of ['player','enemy','parked-enemy'])for(const variant of ['moving','stationary','recent-hit','full','capped','boosted','dead','threshold','breathing'])
 inputs.push({actor,variant,speed:variant==='stationary'?0:variant==='threshold'?12:20,
  hitAt:variant==='recent-hit'?1.5:0,struct:variant==='full'?100:variant==='capped'?99.99:30,
  alive:variant!=='dead',dt:.1,time:variant==='breathing'?6:2,thrusters:variant==='boosted'});
const cases=inputs.map(input=>{
 const events=[],u=Object.create(Unit.prototype);
 Object.defineProperty(u,'pos',{value:[1,2,3]});Object.defineProperty(u,'health',{value:.8});
 Object.assign(u,{alive:input.alive,struct:input.struct,structMax:100,hitAt:input.hitAt,env:{time:input.time},
  heal(){events.push('heal');this.struct=100},
  externalControl:true,flush(){},vehicle:{spec:{motion:{topSpeed:20,thrusterSpeed:0},thrusters:input.thrusters?[{type:'boost'}]:[]},
  thrusterOutputs:new Map(input.thrusters?[['boost',1]]:[]),rotors:[],body:{linvel:()=>({x:input.speed,y:0,z:0}),translation:()=>({x:1,y:2,z:3}),rotation:()=>({})},
  step(){events.push('motion')},stepRotors(){events.push('rotors')}},
  weapons:{drill:{controlsBody:false},step(){events.push('fire')},fx:[]}});
 u._regenStructure=function(dt){events.push('regen');return Unit.prototype._regenStructure.call(this,dt)};
 if(input.actor==='player'){const m=Object.create(Mission.prototype);m.level={steps:[]};m.enemies=new Map();m.drive={player:u,sim:{time:input.time,fx:[]}};
  m.beforeStep(input.dt);u.step(input.dt,{throttle:1},{aim:[1,2,3]});u.fire(input.dt,{firing:false,aim:[1,2,3]},{});}
 else {const m=Object.create(Mission.prototype);m.level={steps:[]};m.drive={player:{alive:input.actor!=='parked-enemy',pos:[0,0,0]},sim:{time:0,fx:[]}};
  m._doomed=()=>false;m.enemies=new Map([[u,{target:'player',driver:{step:()=>({command:{throttle:1},aim:[1,2,3],trigger:false})}}]]);
  m.beforeStep(input.dt);}
 return {input,struct:u.struct,healCalls:events.filter(e=>e==='heal').length,regenCalls:events.filter(e=>e==='regen').length,fireCalls:events.filter(e=>e==='fire').length,
  order:events,regenAfterMotion:!events.includes('regen')||events.indexOf('regen')>events.indexOf('motion'),
  regenBeforeFire:!events.includes('fire')||events.indexOf('regen')<events.indexOf('fire')};
});
console.log(JSON.stringify({baseline:{branch:b.branch,commit:b.commit},hashes,structure:c.STRUCT,cases}));
'''
reference = json.loads(subprocess.check_output(['node', '-e', SOURCE], encoding='utf-8'))
structure = json.loads((ROOT / 'assets/Combat/Arena.json').read_text(encoding='utf-8-sig'))['structure']
assert all(structure[key] == value for key, value in reference['structure'].items() if key != 'enabled')
production = ROOT / 'scripts/story/Mission.lua'
unit_code = (ROOT / 'scripts/combat/CarUnit.lua').read_text(encoding='utf-8-sig')


def execute(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MissionCode = code
    lua.globals().UnitCode = unit_code
    lua.globals().Structure = lua.table_from(structure)
    run = lua.execute(r'''
local modules={}
require=function(id) return modules[id] or {} end
modules['parts.Defs']={PARTS={boost={wtier=3}}};modules.Config={CELL=.5}
modules['drive.RotorMotion']={Weapons=function()end}
modules['combat.DriverActions']={Apply=function()end}
local Unit=assert(load(UnitCode))()
local Mission=assert(load(MissionCode))()
return function(input)
 local order={};local function event(name)order[#order+1]=name end
 local u=setmetatable({alive=input.alive,struct=input.struct,structMax=100,hitAt=input.hitAt,env={time=input.time},
  structure=Structure,
  externalControl=true,Flush=function()end,Position=function()return {1,2,3}end,
  Heal=function(self)event('heal');self.struct=100 end},Unit)
 u.RegenerateStructure=function(self,dt)event('regen');return Unit.RegenerateStructure(self,dt)end
 u.vehicle={spec={bounds={min={0,0,0}},motion={topSpeed=20,thrusterSpeed=0},thrusters=input.thrusters and {{type='boost'}} or {}},
  thrusterOutputs=input.thrusters and {boost=1} or {},rotors={},
  Step=function()event('motion')end,StepRotors=function()event('rotors')end,
  body={linvel=function()return {x=input.speed,y=0,z=0}end,translation=function()return {x=1,y=2,z=3}end,rotation=function()return {}end}}
 u.weapons={fx={},Step=function()event('fire')end}
 local player=input.actor=='player' and u or {alive=input.actor~='parked-enemy'}
 local m=setmetatable({entries={{unit=u,target=input.actor~='player' and 'player' or nil,env={},
  driver={Step=function()return {throttle=1},{1,2,3},false,{}end}}},player=player,
  world={time=input.time},regen=0,Doomed=function()end,session={camera={GetNode=function()return {worldPosition={x=0,y=0,z=0}}end},
  effects={Consume=function()end},weaponAudio={Consume=function()end}}},Mission)
 m:BeforeStep(input.dt,{throttle=1},{1,2,3})
 -- TrackWorld also steps external units; this must not double their recovery.
 u:Step(input.dt)
 local calls,fire,heal,regenAt,motionAt,fireAt=0,0,0,0,0,0
 for i,name in ipairs(order)do
  if name=='regen' then calls=calls+1;regenAt=i elseif name=='motion' then motionAt=i elseif name=='fire' then fire=fire+1;fireAt=i elseif name=='heal' then heal=heal+1 end
 end
 return {struct=u.struct,healCalls=heal,regenCalls=calls,fireCalls=fire,regenAfterMotion=calls==0 or regenAt>motionAt,
  regenBeforeFire=fire==0 or regenAt<fireAt}
end
''')
    checks = 0
    failures = []
    for row in reference['cases']:
        actual = run(lua.table_from(row['input']))
        for key in ['struct', 'healCalls', 'regenCalls', 'fireCalls', 'regenAfterMotion', 'regenBeforeFire']:
            expected = row[key]
            valid = abs(actual[key] - expected) < 1e-9 if key == 'struct' else actual[key] == expected
            checks += 1
            if not valid:
                failures.append({'input': row['input'], 'key': key, 'expected': expected, 'actual': actual[key]})
    return checks, failures


code = production.read_text(encoding='utf-8-sig')
checks, failures = execute(code)
negative = []
if not failures:
    for name, mutated in [
        ('missing recovery', code.replace('u:RegenerateStructure(dt)', '')),
        ('double recovery', code.replace('u:RegenerateStructure(dt)', 'u:RegenerateStructure(dt);u:RegenerateStructure(dt)')),
        ('recovery before vehicle motion', code.replace('v:Step(cmd,dt);u:RegenerateStructure(dt)', 'u:RegenerateStructure(dt);v:Step(cmd,dt)')),
    ]:
        assert mutated != code, name
        assert execute(mutated)[1], 'Undetected negative control: ' + name
        negative.append(name)
report = {'result': 'FAIL' if failures else 'PASS', 'checks': checks, 'cases': len(reference['cases']),
          'failures': failures, 'negativeControls': negative, 'source': reference,
          'productionHashes': {'scripts/story/Mission.lua': hashlib.sha256(production.read_bytes()).hexdigest(),
                               'scripts/combat/CarUnit.lua': hashlib.sha256((ROOT / 'scripts/combat/CarUnit.lua').read_bytes()).hexdigest()},
          'boundary': 'Actual frozen H5 CarUnit.step/_regenStructure and StoryMission.beforeStep versus real Lua Mission.BeforeStep and CarUnit.RegenerateStructure/Step. Controlled standard chassis, clock and native adapters. No natural S3 victory, rendered parity, hardware or performance claim.'}
out = ROOT / ('docs/migration/evidence/story-structure-regen-offline-before.json' if failures else 'docs/migration/evidence/story-structure-regen-offline.json')
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': checks, 'failures': failures[:4], 'negativeControls': negative, 'evidence': str(out)}, ensure_ascii=False))
sys.exit(bool(failures))
