"""Execute current production methods in Lua 5.4 with boundary stubs; no engine."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().BATTLE_SOURCE = (ROOT / 'scripts/combat/BattleController.lua').read_text(encoding='utf-8-sig')
lua.globals().UNIT_SOURCE = (ROOT / 'scripts/combat/CarUnit.lua').read_text(encoding='utf-8-sig')
result = lua.execute(r'''
local noop=function()end
local session=false;local prepares,spawns,checkpointValues={}, {}, {}
local cacheCount=0
local Cache={New=function()
 cacheCount=cacheCount+1
 local c={disposed=false}
 function c:Prepare(source,checkpoint)
  assert(session.battle and session.combat==session.battle and session.battle.spawnSpecCache==self,'Retain cache before yielding')
  prepares[#prepares+1]={source=source,cache=self}
  if checkpoint then checkpoint();checkpoint() end
  return true
 end
 function c:Dispose()self.disposed=true end
 return c
end}
local sourceA={id='player'};local sourceB={id='enemy'}
local rules={state='live',cfg={respawn=5,prep=1}}
local objectives={Rules=function()return rules end,Spawn=function()return {pos={0,0,0},yaw=0}end,
 PlaceCart=noop,Dispose=noop}
local sounds={Prepare=function(_,_,checkpoint)if checkpoint then checkpoint()end end,Dispose=noop}
local unitStub={New=function(env,source,config,checkpoint,retain)
 assert(config.spawnSpecCache==session.battle.spawnSpecCache,'Pass scene cache to Unit.New')
 assert(prepares[#prepares].source==source,'Prepare before Unit.New')
 local u={alive=true,team=config.team,name=config.name,spawnAt=config.spawn,spawnSpecCache=config.spawnSpecCache,source=source}
 function u:Spawn()
  assert(self.spawnSpecCache==session.battle.spawnSpecCache,'Respawn retains same scene cache')
  spawns[#spawns+1]=self.source;self.alive=false
 end
 function u:Dispose()self.disposed=true end
 if retain then retain(u)end
 if checkpoint then assert(env.units[#env.units]==u,'Retain candidate before yield');checkpoint(.8);checkpoint(.85);checkpoint(.9)end
 return u
end}
local mods={
 ['drive.SpawnSpecCache']=Cache,['combat.CarUnit']=unitStub,
 ['audio.BattleFlow']={New=function()return sounds end},
 ['combat.BattleObjectives']={New=function()return objectives end},
 ['audio.MatchVoice']={New=function()return {Dispose=noop,Say=noop}end},
 ['combat.ArenaData']={prefabs={['red:3:heavy:0']=sourceB},modes={conquest={size=4}}},
 ['combat.EnemyDriver']={New=function()return {}end},
}
require=function(name)return mods[name] or {}end
local Battle=assert(load(BATTLE_SOURCE,'BattleController'))()
local bp={Stats=function()return {fitTier={id=3}}end,ToTable=function()return sourceA end}
local function Session()
 return {world={units={},time=10,RecordDamage=noop,RecordKill=noop},app={store={}},
  map={battleMode='conquest',battleRoster={blue={{player=true,name='P'}},red={{role='heavy',name='E'}}}}}
end
local yields=0
session=Session()
local co=coroutine.create(function()
 return Battle.New(session,bp,function(p)
  assert(type(p)=='number' and p>=0 and p<=1,'Finite normalized progress')
  assert(#checkpointValues==0 or p>=checkpointValues[#checkpointValues],'Monotone original progress')
  checkpointValues[#checkpointValues+1]=p;yields=yields+1;coroutine.yield()
 end)
end)
local battle
while coroutine.status(co)~='dead' do local ok,value=coroutine.resume(co);assert(ok,value);battle=value or battle end
assert(battle==session.battle and #battle.entries==2 and #prepares==2)
assert(#session.world.units==2 and checkpointValues[#checkpointValues]==1)
for _,entry in ipairs(battle.entries)do entry.unit.alive=false;entry.unit.deadAt=0 end
battle:BeforeStep(1/60,{},nil);assert(#spawns==2,'Real BeforeStep calls original Spawn')
local cache=battle.spawnSpecCache;battle:Dispose();assert(cache.disposed and battle.spawnSpecCache==nil)
-- Abandon a loading coroutine at its first yield, as scene cancellation does.
session=Session();local partial=coroutine.create(function()return Battle.New(session,bp,function()coroutine.yield()end)end)
local ok,why=coroutine.resume(partial);assert(ok,why)
local loadingCache=session.battle.spawnSpecCache;session.battle:Dispose();assert(loadingCache.disposed)
assert(coroutine.status(partial)=='suspended');coroutine.close(partial)
-- Cancel inside cache Prepare as well as before the audio loading checkpoint.
session=Session();local partialCache=coroutine.create(function()return Battle.New(session,bp,function()coroutine.yield()end)end)
for i=1,2 do local resumed,reason=coroutine.resume(partialCache);assert(resumed,reason)end
local preparedCache=session.battle.spawnSpecCache;session.battle:Dispose();assert(preparedCache.disposed)
assert(coroutine.status(partialCache)=='suspended');coroutine.close(partialCache)
-- A caller without scheduling callbacks must also use the cache normally.
session=Session();local sync=Battle.New(session,bp);assert(#sync.entries==2);sync:Dispose()

-- Execute actual CarUnit.Flush with data boundaries stubbed. Damaged-blueprint
-- rebuilding must call fresh Spec.Build(bp,nil,connected), never source cache.
local freshSpec={ok=true};local specCalls=0;local cacheGets=0;local graphCalls=0
local specModule={Build=function(bp,checkpoint,connected)
 specCalls=specCalls+1;assert(checkpoint==nil and connected and connected.adj and connected.conn)
 return freshSpec
end}
mods['construction.Blueprint']={};mods['parts.Defs']={PARTS={}};mods['Config']={CELL=.5}
mods['drive.VehicleSpec']=specModule
local CarUnit=assert(load(UNIT_SOURCE,'CarUnit'))()
local stubBp={Graph=function()graphCalls=graphCalls+1;return {}end,
 Connectivity=function()return {floating={},reached={},coreId=1}end,parts={}}
local vehicle={body={translation=function()return {x=0,y=0,z=0}end,rotation=function()return {x=0,y=0,z=0,w=1}end},
 GetState=function()return {p={x=0,y=0,z=0},q={x=0,y=0,z=0,w=1}}end,SetState=noop}
local u=setmetatable({dirty=true,alive=true,bp=stubBp,vehicle=vehicle,lastDir={0,0,0},budget0=100,
 spawnSpecCache={Get=function()cacheGets=cacheGets+1;error('Damage must not use pristine source cache')end},
 env={debris={Spawn=noop},viewEvents={}},weapons={drill={Cancel=noop}}},CarUnit)
u.Budget=function()return 100 end;u.LostCombatAbility=function()return false end
u.DisposeVehicle=noop;u.Build=function(self,spec)assert(spec==freshSpec);self.vehicle=vehicle end
u:Flush();assert(specCalls==1 and graphCalls==1 and cacheGets==0 and not u.dirty)
return {status='PASS',checkpoints=yields,cacheScenes=cacheCount,respawns=#spawns,
 monotoneProgress=true,retainedBeforeYield=true,disposeDuringLoad=true,noCheckpoint=true,
 damageRebuildUsesFreshSpec=true,boundary='Current production Lua methods with dependency stubs; routing/lifecycle/progress only, no physics or FPS evidence.'}
''')
report = {key: value for key, value in result.items()}
report['battleSha256'] = hashlib.sha256((ROOT / 'scripts/combat/BattleController.lua').read_bytes()).hexdigest()
report['carUnitSha256'] = hashlib.sha256((ROOT / 'scripts/combat/CarUnit.lua').read_bytes()).hexdigest()
print(json.dumps(report, ensure_ascii=False))
