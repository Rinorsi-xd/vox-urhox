"""Actual frozen H5 unit/session steps versus Lua G5 entry points, without hardware."""
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
const b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8')),hashes={};
const c=vm.createContext({THREE:{Vector3:class{}},PARTS:{boost:{wtier:3}},CARGO_SLOTS:20,
 URLSearchParams,location:{search:''},performance:{now:()=>0},stepRaiderExplosion:()=>false,
 shieldContains:()=>false,stepAirdropLanding:(u)=>u.events.push('airdrop')});
function load(p,expression){const raw=fs.readFileSync(b.snapshot+'/'+p),h=crypto.createHash('sha256').update(raw).digest('hex');
 if(h!==b.files[p].sha256)throw Error('Frozen source drift: '+p);hashes[p]=h;
 return vm.runInContext('(()=>{'+raw.toString().replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nreturn '+expression+';})()',c);}
Object.assign(c,load('shared/combat/tuning.js','{HULL,STRUCT,FOV}'));
Object.assign(c,load('shared/drive/combatSpeed.js','{combatSpeed,combatTopSpeed}'));
Object.assign(c,load('shared/battle/endlessConfig.js','{ENDLESS}'));
const Unit=load('shared/combat/carUnit.js','CarUnit');
const Salvage=load('three/src/salvage/salvageRun.js','SalvageRun');
const Endless=load('three/src/battle/endlessSession.js','EndlessSession');
const cases=[];
for(const mode of ['salvage','endless'])for(const actor of ['player','enemy','parked-enemy'])
 for(const variant of ['moving','stationary','recent-hit','full','capped','boosted','dead','threshold','killed']){
  const input={mode,actor,variant,speed:variant==='stationary'?0:variant==='threshold'?12:20,
   hitAt:variant==='recent-hit'?1.5:0,struct:variant==='full'?100:variant==='capped'?99.99:30,
   alive:variant!=='dead',kill:variant==='killed',dt:.1,time:2,thrusters:variant==='boosted'};
  const events=[],u=Object.create(Unit.prototype);
  Object.defineProperty(u,'pos',{value:[1,2,3]});
  Object.assign(u,{events,alive:input.alive,kill:input.kill,struct:input.struct,structMax:100,hitAt:input.hitAt,env:{time:input.time},
   autoRespawn:false,flush(){},fire(){events.push('fire');return []},
   vehicle:{spec:{motion:{topSpeed:20,thrusterSpeed:0,load:1},weapons:[1],thrusters:input.thrusters?[{type:'boost'}]:[]},
    thrusterOutputs:new Map(input.thrusters?[['boost',1]]:[]),
    body:{linvel:()=>({x:input.speed,y:0,z:0})},step(){events.push('motion')},stepRotors(){events.push('rotors')}},
   weapons:{drill:{controlsBody:false}}});u.spec=u.vehicle.spec;
  u._regenStructure=function(dt){events.push('regen');return Unit.prototype._regenStructure.call(this,dt)};
  const p=actor==='player'?u:{alive:actor!=='parked-enemy',pos:[0,0,0],hitAt:0,heal(){throw Error('Unexpected generic heal')}};
  const driver={step:()=>({command:{throttle:1},aim:[1,2,3],trigger:false})};
  const m=Object.create(mode==='salvage'?Salvage.prototype:Endless.prototype);
  m.drive={player:p,sim:{time:input.time,fx:[]}};
  if(mode==='salvage'){m.landed=true;m.units=actor==='player'?new Map():new Map([[u,{driver}]]);m.beforeStep(input.dt)}
  else {m.audioReview=true;m.run={step(){},shield:{hp:0},time:2};m.events=()=>{};m.spawn=()=>{};m.pending=[];
   m.enemies=actor==='player'?new Map():new Map([[u,driver]]);m.debug={flags:{freeze:false}};m.shieldTarget={};m.beforeStep(input.dt)}
  if(actor==='player')u.step(input.dt,{throttle:1},{});
  cases.push({input,struct:u.struct,regenCalls:events.filter(e=>e==='regen').length,
   regenAfterMotion:!events.includes('regen')||events.indexOf('regen')>events.indexOf('motion'),
   regenBeforeFire:!events.includes('regen')||!events.includes('fire')||events.indexOf('regen')<events.indexOf('fire')});
 }
console.log(JSON.stringify({baseline:{branch:b.branch,commit:b.commit},hashes,structure:c.STRUCT,config:c.ENDLESS,cases}));
'''
reference = json.loads(subprocess.check_output(['node', '-e', SOURCE], encoding='utf-8'))
structure = json.loads((ROOT / 'assets/Combat/Arena.json').read_text(encoding='utf-8-sig'))['structure']
assert all(structure[key] == value for key, value in reference['structure'].items() if key != 'enabled')
paths = {'salvage': 'scripts/salvage/Run.lua', 'endless': 'scripts/app/EndlessSession.lua'}
codes = {mode: (ROOT / name).read_text(encoding='utf-8-sig') for mode, name in paths.items()}
unit_code = (ROOT / 'scripts/combat/CarUnit.lua').read_text(encoding='utf-8-sig')


def execute(code_by_mode):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value
    lua.globals().Codes = table(code_by_mode)
    lua.globals().UnitCode = unit_code
    lua.globals().Structure = table(structure)
    lua.globals().EndlessConfig = table(reference['config'])
    run = lua.execute(r'''
local modules={}
require=function(id)return modules[id] or {} end
modules['parts.Defs']={PARTS={boost={wtier=3}}};modules.Config={CELL=.5}
modules['core.ResourceData']={Read=function()return {}end}
modules['endless.Data']={config=EndlessConfig}
modules['drive.RotorMotion']={Weapons=function()end}
modules['combat.DriverActions']={Apply=function()end}
modules['combat.DrillRaiderDriver']={StepExplosion=function()return false end,ArmExplosion=function()end}
modules['combat.ShieldQuery']={Contains=function()return false end}
local Unit=assert(load(UnitCode))();modules['combat.CarUnit']=Unit
local Run={salvage=assert(load(Codes.salvage))(),endless=assert(load(Codes.endless))()}
return function(input)
 local order={};local function event(name)order[#order+1]=name end
 local u=setmetatable({alive=input.alive,kill=input.kill,struct=input.struct,structMax=100,hitAt=input.hitAt,
  env={time=input.time},structure=Structure,externalControl=true,autoRespawn=false,
  Flush=function()end,Position=function()return {1,2,3}end},Unit)
 u.RegenerateStructure=function(self,dt)event('regen');return Unit.RegenerateStructure(self,dt)end
 u.spec={bounds={min={0,0,0}},motion={topSpeed=20,thrusterSpeed=0,load=1},weapons={1},thrusters=input.thrusters and {{type='boost'}} or {}}
 u.vehicle={spec=u.spec,thrusterOutputs=input.thrusters and {boost=1} or {},rotors={},
  Step=function()event('motion')end,StepRotors=function()event('rotors')end,
  body={linvel=function()return {x=input.speed,y=0,z=0}end,translation=function()return {x=1,y=2,z=3}end,rotation=function()return {}end}}
 u.weapons={fx={},drill={ControlsBody=function()return false end},Step=function()event('fire')end}
 local player=input.actor=='player' and u or {alive=input.actor~='parked-enemy',hitAt=0,Position=function()return {0,0,0}end}
 local m=setmetatable({entries={{unit=u,env={},driver={Step=function()return {throttle=1},{1,2,3},false,{}end}}},player=player,
  begun=true,landed=true,rules={finished=false},cine={Command=function(_,command)return command end},
  run={state='combat',time=2,shield={hp=0},Step=function()end},shieldTarget={},repairClock=0,pending={},
  world={time=input.time},Events=function()end,Spawn=function()end,Airdrop=function()event('airdrop')end,
  director={Target=function()return {1,2,3}end},session={effects={Consume=function()end},weaponAudio={Consume=function()end}}},Run[input.mode])
 m:BeforeStep(input.dt,{throttle=1},{1,2,3});u:Step(input.dt)
 local calls,regenAt,motionAt,fireAt=0,0,0,0
 for i,name in ipairs(order)do if name=='regen' then calls=calls+1;regenAt=i elseif name=='motion' then motionAt=i elseif name=='fire' then fireAt=i end end
 return {struct=u.struct,regenCalls=calls,regenAfterMotion=calls==0 or regenAt>motionAt,regenBeforeFire=calls==0 or fireAt==0 or regenAt<fireAt}
end
''')
    failures = []
    count = 0
    for case in reference['cases']:
        actual = run(table(case['input']))
        for key in ['struct', 'regenCalls', 'regenAfterMotion', 'regenBeforeFire']:
            valid = abs(actual[key] - case[key]) < 1e-9 if key == 'struct' else actual[key] == case[key]
            count += 1
            if not valid:
                failures.append({'input': case['input'], 'key': key, 'expected': case[key], 'actual': actual[key]})
    return count, failures


checks, failures = execute(codes)
negatives = []
if not failures:
    for mode in paths:
        for label, mutate in [
            ('missing recovery', lambda text: text.replace('u:RegenerateStructure(dt)', '')),
            ('double recovery', lambda text: text.replace('u:RegenerateStructure(dt)', 'u:RegenerateStructure(dt);u:RegenerateStructure(dt)')),
            ('recovery before movement', lambda text: text.replace('v:Step(cmd,dt);u:RegenerateStructure(dt)', 'u:RegenerateStructure(dt);v:Step(cmd,dt)')),
        ]:
            changed = mutate(codes[mode])
            assert changed != codes[mode], (mode, label)
            assert execute({**codes, mode: changed})[1], (mode, label)
            negatives.append(mode + ': ' + label)
report = {'result': 'FAIL' if failures else 'PASS', 'cases': len(reference['cases']), 'checks': checks,
          'failures': failures, 'negativeControls': negatives, 'source': reference,
          'productionHashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                               for name in [*paths.values(), 'scripts/combat/CarUnit.lua']},
          'boundary': 'Actual frozen H5 SalvageRun/EndlessSession.beforeStep and CarUnit.step/_regenStructure against actual Lua G5 BeforeStep and CarUnit.RegenerateStructure/Step. Player uses actual source unit.step, corresponding to testDrive fixed loop. Native vehicle, clocks, AI, audio and rendering are adapters; no natural recovery visuals or performance claim.'}
destination = ROOT / ('docs/migration/evidence/g5-structure-regen-offline-before.json' if failures else 'docs/migration/evidence/g5-structure-regen-offline.json')
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'cases': len(reference['cases']), 'checks': checks,
                  'failures': failures[:3], 'negativeControls': negatives, 'evidence': str(destination)}, ensure_ascii=False))
sys.exit(bool(failures))
