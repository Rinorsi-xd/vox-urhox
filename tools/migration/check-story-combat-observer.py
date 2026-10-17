"""Small functional check for the opt-in story observer; no engine or timing."""
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

lua = LuaRuntime(unpack_returned_tuples=True)
for key, path in {
    'MATH_SOURCE': 'scripts/core/Math3.lua',
    'WEAPON_SOURCE': 'scripts/combat/WeaponSystem.lua',
    'MISSION_SOURCE': 'scripts/story/Mission.lua',
    'OBSERVER_SOURCE': 'tools/migration/story-combat-observer.lua',
    'ROUTE_SOURCE': 'tools/migration/story-route-observer.lua',
}.items():
    lua.globals()[key] = (ROOT / path).read_text(encoding='utf-8-sig')
checks = lua.execute(r'''
local math3=assert(load(MATH_SOURCE))()
local modules={['core.Math3']=math3,['combat.WeaponDefs']={ENERGY={}},Config={CELL=.5},
    ['drive.RotorMotion']={Weapons=function()end},['combat.DriverActions']={Apply=function()end}}
require=function(id)return modules[id] or {} end
local Weapons=assert(load(WEAPON_SOURCE))()
local Mission=assert(load(MISSION_SOURCE))()
assert(load(OBSERVER_SOURCE))();assert(load(ROUTE_SOURCE))()
local identity={x=0,y=0,z=0,w=1}
local player={name='player',team='blue',alive=true,bodyHp=800,bodyHpMax=1000,struct=50,structMax=250,hitAt=0,pos={0,0,0}}
local enemy={name='target',team='red',alive=true,bodyHp=700,bodyHpMax=1000,struct=100,structMax=250,hitAt=0,pos={0,0,30},hull={}}
local body={translation=function()return {x=0,y=0,z=0}end,rotation=function()return identity end}
player.vehicle={body=body};enemy.vehicle={body={}}
local weapons={};for i=1,5 do weapons[i]={id=i,type='laser',muzzle={0,1,2},dir={0,0,1},yaw=0,pitch=0,err=0,
    limited=false,cool=.1,shotAt=3,stats={range=100,aimTol=.03}} end
local system=setmetatable({groups={{kind='laser',weapons=weapons}},current=1,energy=90,offline=false},Weapons)
local mission={player=player};local casts=0;local selectedHit
local session={story=mission,weapons=system,aimPoint={0,1,30},aimRef=enemy,firing=true,
    world={time=4,units={player,enemy},CastRay=function(_,origin,dir,reach,excluded)
        casts=casts+1;assert(excluded==body and reach==100);assert(origin[3]==2 and dir[3]==1)
        return selectedHit
    end}}
local function data()return {story={id='s3'},aimTargets={{name='target',team='red',pos={0,0,30},parts=91}}}end
local n=0
for _,kind in ipairs({'car','wall','none'})do
    selectedHit=kind~='none' and {dist=kind=='car' and 28 or 5,point={0,1,kind=='car' and 30 or 7},normal={0,0,-1},
        owner={type=kind,ref=kind=='car' and enemy or nil,partId=kind=='car' and 13 or nil},collider=17} or nil
    local before=casts;local projected=G0_StoryRouteState(data(),session);local out=projected.storyCombat
    assert(casts-before==4 and out.rays==4 and #out.muzzles==4 and out.totalWeapons==5)
    assert(out.units[1].bodyHp==700 and out.units[1].struct==100 and out.units[1].parts==91)
    assert(projected.aimTargets[1].unitId==out.units[1].id and out.aimUnitId==out.units[1].id)
    local hit=out.muzzles[1].hit
    if kind=='none' then assert(hit==false)else assert(hit.ownerType==kind and hit.collider==17)
        assert((kind=='car' and hit.unitId==out.units[1].id and hit.partId==13)or(kind=='wall' and hit.unitId==nil))end
    assert(out.muzzles[1].aligned and out.muzzles[1].query=='instantaneous-center-shot-ray-no-spread')
    assert(player.bodyHp==800 and enemy.bodyHp==700 and enemy.struct==100 and system.energy==90 and weapons[1].cool==.1)
    out.units[1].pos[1]=99;assert(enemy.pos[1]==0,'snapshot must not alias live position')
    n=n+1
end
local oldId=G0_StoryRouteState(data(),session).storyCombat.units[1].id
enemy.vehicle={body={}};assert(G0_StoryRouteState(data(),session).storyCombat.units[1].id==oldId,'rebuild identity')
weapons[1].stats.homing=true;weapons[2].stats.drill=true
assert(G0_StoryRouteState(data(),session).storyCombat.rays==2,'special paths must not claim straight-shot LOS');n=n+2
local function targetCase(target,alive,truck)
    local seen
    player.alive=alive
    local unit={alive=true,Flush=function()end,Position=function()return {0,0,30}end,RegenerateStructure=function()end,
        weapons={Step=function()end,fx={}},vehicle={rotors={},StepRotors=function()end,Step=function()end,
        body={translation=function()return {x=0,y=0,z=30}end,linvel=function()return {x=0,y=0,z=0}end,rotation=function()return identity end}}}
    local m=setmetatable({player=player,convoy=truck and {},truckTarget={name='truck'},world={time=0},Doomed=function()end,
        entries={{unit=unit,target=target,env={},driver={Step=function(_,dt,victim)seen=victim;return {},{0,0,0},false,{} end}}},
        session={effects={Consume=function()end},weaponAudio={Consume=function()end}}},Mission)
    m:BeforeStep(1/60,{}, {0,0,0})
    if alive or target=='truck' then assert(seen==(target=='truck' and truck and m.truckTarget or player))
    else assert(seen==nil) end
end
targetCase(nil,true,false);targetCase('truck',true,true);targetCase('truck',true,false);targetCase('player',false,false);n=n+4
return n
''')

SOURCE = r'''
const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};function read(p){const raw=fs.readFileSync(b.snapshot+'/'+p),h=crypto.createHash('sha256').update(raw).digest('hex');if(h!==b.files[p].sha256)throw Error('Source drift '+p);hashes[p]=h;return raw.toString();}
const ctx=vm.createContext({}),tuning=read('shared/combat/tuning.js');vm.runInContext(tuning.replace(/^export /gm,'')+';globalThis.tuning={HULL,STRUCT}',ctx);
const raw=read('three/src/battle/storyMission.js'),a=raw.indexOf('\t_targetOf( e ) {'),z=raw.indexOf('\n\tbeforeStep(',a);
if(a<0||z<a)throw Error('Missing actual source target method');vm.runInContext('globalThis.M=class{'+raw.slice(a,z)+'}',ctx);
const m=new ctx.M();m.drive={player:{pos:[1,2,3]}};m.truck={pos:[4,5,6]};
if(m._targetOf({}).unit!==m.drive.player||m._targetOf({target:'truck'}).pos!==m.truck.pos)throw Error('Target mismatch');
console.log(JSON.stringify({commit:b.commit,hashes,tuning:ctx.tuning,defaultTarget:'player',truckTarget:'truck when present'}));
'''
source = json.loads(subprocess.check_output(['node', '-e', SOURCE], encoding='utf-8'))
arena = json.loads((ROOT / 'assets/Combat/Arena.json').read_text(encoding='utf-8-sig'))
for source_name, target_name in [('HULL', 'hull'), ('STRUCT', 'structure')]:
    assert all(arena[target_name][key] == value for key, value in source['tuning'][source_name].items() if key != 'enabled')
failure = ROOT / 'docs/migration/evidence/story-natural-s3-manifest-b2b281a1-2026-10-16T20-34-33-394Z/result.json'
historical = json.loads(failure.read_text(encoding='utf-8'))
hold = [s for s in historical['samples'] if s['story']['step'] == 'hold' and not s['story']['failing']]
files = ['tools/migration/story-combat-observer.lua', 'tools/migration/story-route-observer.lua',
         'tools/migration/serve-outgame.cjs', 'tools/migration/probe-outgame-web.lua',
         'tools/migration/check-story-natural-web.cjs', 'tools/migration/story-hold-defense-input.cjs']
report = {'result': 'PASS', 'controlledCases': checks, 'source': source,
          'historicalFailure': {'path': str(failure.relative_to(ROOT)), 'sha256': hashlib.sha256(failure.read_bytes()).hexdigest(),
                                'result': historical['result'], 'holdSamples': len(hold),
                                'heldFireSamples': sum(s['firing'] for s in hold),
                                'selectedTargetSamples': sum(bool(s.get('navigation', {}).get('hold', {}).get('target')) for s in hold),
                                'missingTargetIdentityHullStructureAndMuzzleLos': all('storyCombat' not in s for s in hold)},
          'hashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files},
          'boundary': 'Real complete Lua WeaponSystem.Muzzle/Aligned, Mission.BeforeStep and opt-in observer with read-only body/ray adapters. Frozen H5 target method/tuning. No actual engine LOS, shot result, natural victory, difficulty change, CPU timing or performance claim.'}
out = ROOT / 'docs/migration/evidence/story-combat-observer-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
