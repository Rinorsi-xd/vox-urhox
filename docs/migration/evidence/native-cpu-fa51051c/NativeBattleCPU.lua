local output;local mode='fine';local coverage=false
for _,arg in ipairs(GetArguments())do output=arg:match('^%-cpu%-output=(.+)$') or output;mode=arg:match('^%-cpu%-mode=(.+)$') or mode;coverage=coverage or arg=='-cpu-coverage=true' end
assert(output,'-cpu-output required')
local report={result='RUNNING',frames={},stages={},skipped={},events={},instrumentation=mode~='none',mode=mode,
 boundary='Native graphicsheadless actual CraterWorld/Bullet, BattleController, AI, WeaponSystem, damage/repair/respawn, CombatView and CombatEffects CPU calls. Fixed 60 Hz simulation driven synchronously, no viewport/GPU, HUD, input loop or audio mixing. No whole-game FPS or phone claim. Inclusive nested durations must not be summed. Exclusive only subtracts wrapped descendants. os.clock is not verified thread CPU; Time is millisecond wall time. Lua KB changes are net, not allocator traffic, and include instrumentation.'}
local scene,world,session,battle,frame
local stack={}
local function Write()local f=assert(io.open(output,'wb'));f:write(cjson.encode(report));f:close()end
local function Wall()return Time:GetSystemTime()end
local function Span(now,then_)return (now-then_)&0xffffffff end
local coarse={
 ['combat.BattleController.BeforeStep']=true,['combat.BattleController.AfterStep']=true,
 ['combat.BattleController.SyncPlayer']=true,['combat.EnemyDriver.Step']=true,
 ['combat.CarUnit.Flush']=true,['combat.CarUnit.Spawn']=true,
 ['drive.Vehicle.Step']=true,['drive.VehicleSpec.Build']=true,
 ['physics.Space.Step']=true,['combat.WeaponSystem.Step']=true,
 ['render.CombatView.Consume']=true,['render.CombatView.Update']=true,
 ['render.DriveView.New']=true,['render.DriveView.Update']=true,
 ['render.VehicleView.Rebuild']=true,['render.VehicleView.SyncBlueprint']=true,
 ['render.CombatEffects.Consume']=true,['render.CombatEffects.Update']=true,
 ['render.ObjectiveView.Update']=true,
}
local function Wrap(module,key,label)
 if mode=='none'then return end
 if mode=='coarse'and not coarse[label]then return end
 local original=module[key]
 if type(original)~='function'then report.skipped[#report.skipped+1]=label;return end
 module[key]=function(...)
  if not frame then return original(...)end
  local row=frame.methods[label]
  if not row then row={calls=0,wallMs=0,clockMs=0,selfWallMs=0,selfClockMs=0};frame.methods[label]=row end
  local parent=stack[#stack];local state={wall=Wall(),clock=os.clock(),childWall=0,childClock=0,childAlloc=0,
   alloc=frame.phase=='allocation-no-gc'and collectgarbage('count')or nil}
  stack[#stack+1]=state
  local values=table.pack(pcall(original,...))
  local wallMs,clockMs=Span(Wall(),state.wall),(os.clock()-state.clock)*1000
  stack[#stack]=nil
  row.calls=row.calls+1;row.wallMs=row.wallMs+wallMs;row.clockMs=row.clockMs+clockMs
  row.selfWallMs=row.selfWallMs+wallMs-state.childWall;row.selfClockMs=row.selfClockMs+clockMs-state.childClock
  if state.alloc then
   local allocation=collectgarbage('count')-state.alloc
   row.allocationKiB=(row.allocationKiB or 0)+allocation
   row.selfAllocationKiB=(row.selfAllocationKiB or 0)+allocation-state.childAlloc
   if parent then parent.childAlloc=parent.childAlloc+allocation end
  end
  if parent then parent.childWall=parent.childWall+wallMs;parent.childClock=parent.childClock+clockMs end
  if not values[1]then error(values[2],0)end
  return table.unpack(values,2,values.n)
 end
end
local targets={
 {'combat.BattleController',{'BeforeStep','AfterStep','Pick','WorldState','SyncPlayer'}},
 {'combat.BattleObjectives',{'Update','UnitTick','Goal','Cast','Explode','Hit'}},
 {'combat.EnemyDriver',{'Step','Path'}},
 {'combat.MatchTarget',{'Pick'}},
 {'combat.CarUnit',{'Flush','Step','Damage','Destroy','Build','Spawn','RegenerateStructure','SavePose','Health','Integrity'}},
 {'construction.Blueprint',{'Graph','Connectivity','List','Stats'}},
 {'construction.Rotors',{'Spec'}},
 {'construction.TurretRange',{'For'}},
 {'drive.VehicleSpec',{'Build','BuildParts','MergeBoxes'}},
 {'drive.Vehicle',{'New','init','Dispose','Step','StepRotors','PostStep'}},
 {'drive.TrackWorld',{'Step','CastRay','NewVehicle','Hit','Explode','Lockables'}},
 {'physics.Space',{'Step','Raycast'}},
 {'combat.VehicleRay',{'Cast'}},
 {'drive.RaySuspension',{'Sample','Apply'}},
 {'drive.ContactControl',{'Step'}},
 {'drive.ChassisStability',{'Step'}},
 {'drive.HoverControl',{'Step','Motion'}},
 {'drive.LegControl',{'Step','Cast'}},
 {'drive.LegGait',{'Step','Foothold'}},
 {'drive.MechControl',{'Step','Cast'}},
 {'drive.ThrusterControl',{'Step'}},
 {'drive.WingControl',{'Step'}},
 {'drive.LegHitboxes',{'Update'}},
 {'drive.MechHitboxes',{'Update'}},
 {'combat.WeaponSystem',{'Step','Aim','Integrate','Fire'}},
 {'combat.Debris',{'Advance','CapturePoses','Spawn'}},
 {'render.ObjectiveView',{'Update','Refresh'}},
 {'render.CombatView',{'Consume','Update','SavePose'}},
 {'render.DriveView',{'New','Bind','Update','SavePose'}},
 {'render.VehicleView',{'Rebuild','SyncBlueprint','AddPart','RemovePart','UpdateIdle','UpdateWeaponEffects'}},
 {'render.WeaponView',{'Update'}},
 {'render.PartRig',{'SetWheel','SetTrack','SetWeapon','SetLegTarget','SetMechPose'}},
 {'render.CombatEffects',{'Consume','Update','Helix'}},
 {'render.EffectBatch',{'Begin','Quad','Finish','Segment','Disc'}},
}
local function Metadata()
 local units={};local alive,parts,projectiles,shots,damage,kills=0,0,0,0,0,0
 for _,e in ipairs(battle.entries)do local u=e.unit
  if u.alive then alive=alive+1 end;local n=u.bp:Size();parts=parts+n
  projectiles=projectiles+#u.weapons.projectiles;shots=shots+(e.env.stats.shots or 0)
  local stats=battle.stats[u];damage=damage+stats.damage;kills=kills+stats.kills
  units[#units+1]={name=u.name,team=u.team,role=e.member.role,alive=u.alive,parts=n,
   wheels=u.vehicle and #u.vehicle.wheels or 0,legs=u.spec and #(u.spec.legs or {})or 0}
 end
 return {alive=alive,parts=parts,projectiles=projectiles,shots=shots,damage=damage,kills=kills,units=units,
  particles=#session.effects.particles,smoke=#session.effects.smoke,debris=#world.debris.pieces}
end
local function Run()
 math.randomseed(20261016)
 if not rawget(_G,'_tr')then require('urhox-libs/Engine/i18n')end
 local BP=require 'construction.Blueprint'
 local bp=require('construction.Prefab').Create(BP.New(),'raceCar')
 local seedStore={Read=function()return nil end,Write=function()return true end}
 local tier=(bp:Stats().fitTier or {id=5}).id
 local roster=require('combat.Matchmaker').Find(seedStore,4,tier,nil,20261016)
 scene=Scene();scene:CreateComponent('Octree')
 local cameraNode=scene:CreateChild('CPUDiagnosticCamera');cameraNode.position=Vector3(0,25,-175)
 local camera=cameraNode:CreateComponent('Camera')
 local started=Wall();world=require('drive.CraterWorld').New(scene)
 report.stages.worldBuildMs=Span(Wall(),started)
 local effects=require('render.CombatEffects').New(scene,function(x,z)return world:GroundAt(x,z)end)
 session={scene=scene,world=world,map={battleMode='conquest',battleRoster=roster},app={store=seedStore},
  camera={GetNode=function()return cameraNode end,GetCamera=function()return camera end},effects=effects,
  weaponAudio={Consume=function()end,SetActive=function()end},Pause=function()end}
 started=Wall();battle=require('combat.BattleController').New(session,bp)
 report.stages.battleBuildMs=Span(Wall(),started)
 assert(#battle.entries==8,'Expected actual 4v4')
 session.vehicle=battle.player.vehicle;session.weapons=battle.player.weapons
 session.view=require('render.DriveView').New(scene,battle.player.bp,session.vehicle)
 session.combatView=require('render.CombatView').New(scene);session.combatView:Consume(world)
 report.initial=Metadata();report.tier=tier;report.seed=20261016
 for i,e in ipairs(battle.entries)do
  local blue=e.unit.team=='blue';local x=((i%4)-1.5)*18;local z=-140+(blue and -20 or 20)
  e.unit.vehicle:Place({x,world:GroundAt(x,z)+2,z},blue and 0 or math.pi)
  e.unit:SavePose();e.unit.previous=e.unit.current
 end
 session.view:ResetPose()
 for _,target in ipairs(targets)do local module=require(target[1]);for _,key in ipairs(target[2])do Wrap(module,key,target[1]..'.'..key)end end
 local WeaponView=require 'render.WeaponView'
 local dt=1/60
 local context={camera=cameraNode,time=0,fov=60}
 local function Step(index,allocation)
  local target=battle.player:Position()
  for _,e in ipairs(battle.entries)do if e.unit.alive and e.unit.team~=battle.player.team then
   target=e.unit:Position();target[2]=target[2]+.6;break end end
  local command={throttle=.3,steer=math.sin(index/120)*.15,firing=true,aim=target}
  if index>300 then frame={step=index-300,phase=allocation and 'allocation-no-gc'or 'combat',methods={},luaBeforeKiB=collectgarbage('count')}end
  local started,clock=Wall(),os.clock()
  battle:BeforeStep(dt,command,target);world:Step(dt);battle:AfterStep(dt);battle:SyncPlayer()
  session.combatView:Consume(world);session.combatView:SavePose()
  effects:Consume(world.fx);world.fx={};context.time=world.time
  if battle.player.alive then
   session.view:SavePose();session.view:Update(0,dt,context)
   WeaponView.Update(session.view.view,session.weapons,0,dt,world.time,effects)
   session.view.view:UpdateWeaponEffects(dt,context,effects)
  end
  session.combatView:Update(0,dt,context)
  local shots={}
  for _,entry in ipairs(battle.entries)do if entry.unit.alive then
   for _,shot in ipairs(entry.unit.weapons.projectiles)do shots[#shots+1]=shot end
  end end
  effects:Update(dt,shots,cameraNode)
  if frame then
   assert(#stack==0,'Unbalanced timing stack')
   frame.totalWallMs=Span(Wall(),started);frame.totalClockMs=(os.clock()-clock)*1000
   frame.luaAfterKiB=collectgarbage('count');frame.luaNetKiB=frame.luaAfterKiB-frame.luaBeforeKiB
   frame.state=Metadata();report.frames[#report.frames+1]=frame;frame=nil
  end
 end
 if coverage then
  for i=1,300 do Step(i,false)end
  local units={battle.player,battle.entries[5].unit};local old={};local died={}
  for i,u in ipairs(units)do
   old[i]=u.vehicle;local core=assert(u.bp:CoreParts()[1])
   for n=1,3 do if u.alive and not u.kill then u:Damage(core.id,1e9,u:Position())end end
   u:Flush();assert(not u.alive,'Real damage did not kill coverage unit');died[i]=u.deadAt
  end
  local returned={};local spawnCalls=0;local postSpawnSteps=0
  local coverageEnd=300+math.ceil((battle.rules.cfg.respawn+3)*60)
  for i=301,coverageEnd do
   Step(i,false)
   local row=report.frames[#report.frames].methods['combat.CarUnit.Spawn'];spawnCalls=spawnCalls+(row and row.calls or 0)
   for j,u in ipairs(units)do if u.alive and u.vehicle~=old[j]and not returned[j]then returned[j]=world.time end end
   if returned[1]and returned[2]then
    assert(session.vehicle==battle.player.vehicle and session.view.vehicle==battle.player.vehicle,'Player view not rebound')
    local enemyView=assert(session.combatView.units[units[2]],'Enemy view missing after respawn')
    assert(enemyView.vehicle==units[2].vehicle,'Enemy view not rebound');postSpawnSteps=postSpawnSteps+1
   end
  end
  report.coverage={forcedRealCoreDamage=true,deadAt=died,respawnAt=returned,spawnCalls=spawnCalls,postSpawnSteps=postSpawnSteps,
   playerAndEnemyNewVehicle=true,playerAndEnemyViewRebound=true,ruleRespawnSeconds=battle.rules.cfg.respawn}
  assert(returned[1]and returned[2]and spawnCalls>=2 and postSpawnSteps>60,'Respawn coverage incomplete')
  report.final=Metadata();report.result='PASS';report.simulationSeconds=coverageEnd/60;report.measuredSteps=coverageEnd-300;report.warmupSteps=300;Write()
  session.combatView:Dispose();session.view:Dispose();effects:Dispose();battle:Dispose();world:Dispose();scene:Dispose();scene=nil;return
 end
 for i=1,2100 do Step(i,false);if i%300==0 then print('[NativeBattleCPU] step='..i..' alive='..Metadata().alive);Write()end end
 collectgarbage('collect');collectgarbage('stop')
 for i=2101,2160 do Step(i,true)end
 collectgarbage('restart')
 report.final=Metadata();report.simulationSeconds=2160/60;report.measuredSteps=1860;report.warmupSteps=300
 report.result='PASS';Write()
 session.combatView:Dispose();session.view:Dispose();effects:Dispose();battle:Dispose();world:Dispose();scene:Dispose();scene=nil
end
function Start()
 local ok,err=xpcall(Run,debug.traceback)
 if not ok then report.result='FAIL';report.error=err;print(err);Write()end
 engine:Exit()
end
