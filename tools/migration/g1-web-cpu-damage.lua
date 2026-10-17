-- CPU portion of check-damage-native-timing.lua; uses its real production
-- CarUnit/TrackWorld/Debris path, with no CombatView or effects substitution.
local localSections={Begin=function()end,Finish=function()end}
_G.G1_WEB_CPU_LOCAL_SECTIONS=localSections
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Unit=require 'combat.CarUnit'
local TrackWorld=require 'drive.TrackWorld'
local Space=require 'physics.Space'
local Debris=require 'combat.Debris'
local Metrics=require 'drive.TrialMetrics'
local M={}
function M.LocalProfile(clock,enabled)
 local names={'TurretRange.For.Signatures','TurretRange.For.Invalidations','TurretRange.Prepare','TurretRange.Evaluate','TurretRange.SameContext',
  'MergeBoxes.Index','MergeBoxes.Sort','MergeBoxes.Sweep'}
 if not enabled then return {Reset=function()end,Snapshot=function()return false end,Restore=function()end}end
 local rows,byName,stack={},{},{}
 for _,name in ipairs(names)do local row={name=name,calls=0,ms=0,selfMs=0};rows[#rows+1]=row;byName[name]=row end
 local oldBegin,oldFinish=localSections.Begin,localSections.Finish
 localSections.Begin=function(name)
  local frame={row=assert(byName[name],'Unknown local profile scope'),children=0,at=clock()};stack[#stack+1]=frame;return frame
 end
 localSections.Finish=function(frame)
  assert(stack[#stack]==frame,'Local profile stack imbalance');stack[#stack]=nil
  local elapsed=(clock()-frame.at)&0xffffffff;local row=frame.row
  row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-frame.children
  if #stack>0 then stack[#stack].children=stack[#stack].children+elapsed end
 end
 return {
  Reset=function()assert(#stack==0);for _,row in ipairs(rows)do row.calls=0;row.ms=0;row.selfMs=0 end end,
  Snapshot=function()assert(#stack==0);local out={};for i,row in ipairs(rows)do out[i]={name=row.name,calls=row.calls,ms=row.ms,selfMs=row.selfMs}end;return out end,
  Restore=function()assert(#stack==0);localSections.Begin=oldBegin;localSections.Finish=oldFinish end,
 }
end
local function Ranges(unit)
 local out={}
 for _,weapon in ipairs(unit.spec and unit.spec.weapons or {})do out[#out+1]={partId=weapon.partId,range=weapon.range or false}end
 return out
end
function M.Profile(clock,enabled)
 if not enabled then return {Reset=function()end,Snapshot=function()return false end,Restore=function()end}end
 local Spec=require 'drive.VehicleSpec'
 local Vehicle=require 'drive.Vehicle'
 local Weapons=require 'combat.WeaponSystem'
 local Body=require 'physics.Body'
 local rows,stack,restores={},{},{}
 local function Wrap(object,key,name)
  local original=assert(object[key],'Actual exported profile entry '..name)
  local row={name=name,calls=0,ms=0,selfMs=0};rows[#rows+1]=row
  object[key]=function(...)
   local frame={children=0};stack[#stack+1]=frame;local at=clock();local result=table.pack(original(...))
   local elapsed=(clock()-at)&0xffffffff;stack[#stack]=nil
   row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-frame.children
   if #stack>0 then stack[#stack].children=stack[#stack].children+elapsed end
   return table.unpack(result,1,result.n)
  end
  restores[#restores+1]=function()object[key]=original end
 end
 for _,entry in ipairs({{BP,'Graph','Blueprint.Graph'},{BP,'Connectivity','Blueprint.Connectivity'},
  {Spec,'Build','VehicleSpec.Build'},{Spec,'BuildParts','VehicleSpec.BuildParts'},{Spec,'MergeBoxes','VehicleSpec.MergeBoxes'},
  {Spec,'Debris','VehicleSpec.Debris'},{Unit,'DisposeVehicle','CarUnit.DisposeVehicle'},{Unit,'Build','CarUnit.Build'},
  {Unit,'Budget','CarUnit.Budget'},{Unit,'LostCombatAbility','CarUnit.LostCombatAbility'},
  {Vehicle,'New','Vehicle.New'},{Vehicle,'init','Vehicle.init'},{Vehicle,'Dispose','Vehicle.Dispose'},
  {Weapons,'New','WeaponSystem.New'},{Weapons,'init','WeaponSystem.init'},{Weapons,'Refit','WeaponSystem.Refit'},
  {Debris,'Spawn','Debris.Spawn'},{Space,'Register','Space.Register'},{Space,'Unregister','Space.Unregister'},
  {Body,'Wrap','Body.Wrap'},{TrackWorld,'NewVehicle','TrackWorld.NewVehicle'},
  {require 'construction.Rotors','Spec','Rotors.Spec'},{require 'construction.TurretRange','For','TurretRange.For'}})do Wrap(table.unpack(entry))end
 return {
  Reset=function()assert(#stack==0,'Cannot reset an active damage profile');for _,row in ipairs(rows)do row.calls=0;row.ms=0;row.selfMs=0 end end,
  Snapshot=function()assert(#stack==0,'Damage profile scopes must close');local out={};for i,row in ipairs(rows)do out[i]={name=row.name,calls=row.calls,ms=row.ms,selfMs=row.selfMs}end;return out end,
  Restore=function()assert(#stack==0,'Damage profile scopes must close');for _,restore in ipairs(restores)do restore()end end,
 }
end
function M.Run(config,Hash,clock)
 math.randomseed(config.seed)
 local digest=Hash();local fixtures={};local progressSequence=0
 local cases={{name='raceCar',combat=false},{name='raceCar',combat=true},{name='megaMech',combat=false},{name='megaMech',combat=true},{name='bridge-detach',combat=false}}
 for _,case in ipairs(cases)do
  local name,combat=case.name,case.combat
  coroutine.yield()
  local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
  local world=setmetatable({scene=scene,space=space,time=0,viewEvents={},fx={},units={},stats={shots=0,hits=0,damage=0,kills=0},
   metrics=Metrics.New({}),debris=Debris.New(space)},TrackWorld)
  local bp=name=='bridge-detach'and BP.New():Load(assert(G1_WEB_CPU_BRIDGE_SOURCE))or Prefab.Create(BP.New(),name)
  if name=='bridge-detach'then for _,part in ipairs(bp:List())do part.g=1 end end
  local source=bp:ToTable()
  local profiler=M.Profile(clock,config.mode=='profile')
  local locals=M.LocalProfile(clock,config.mode=='profile')
  profiler.Reset();locals.Reset()
  local at=clock();local unit=Unit.New(world,source,{name=name,spawn={pos={0,30,0},yaw=.3},
   combat=combat,autoRespawn=false,externalControl=true});local buildMs=(clock()-at)&0xffffffff
  local initialBuildScopes=profiler.Snapshot()
  local initialBuildLocalScopes=locals.Snapshot()
  local initialRanges=Hash();initialRanges.add(Ranges(unit))
  world.units={unit};assert(unit.alive and unit.vehicle,'Authored damage fixture must spawn')
  unit.vehicle.body.setLinvel({x=2,y=1,z=3});unit.vehicle.body.setAngvel({x=.1,y=.2,z=.05})
  local fixture={name=name,combat=combat,sourceParts=bp:Size(),initialBuildMs=buildMs,initialBuildScopes=initialBuildScopes,initialBuildLocalScopes=initialBuildLocalScopes,initialRangesDigest=initialRanges.get(),stages={}};fixtures[#fixtures+1]=fixture
  local function Damage(id,kind)
   coroutine.yield();world.time=world.time+.25;world.debris:Advance(world.time)
   assert(unit.alive and unit.bp.parts[id],'Living authored target required')
   local before=unit.bp:Size();local budgetBefore=unit:Budget();profiler.Reset();locals.Reset()
   local started=clock();local amount=unit:Damage(id,1e9,{0,30,0});local damageMs=(clock()-started)&0xffffffff
   local damageScopes=profiler.Snapshot();local damageLocalScopes=locals.Snapshot();profiler.Reset();locals.Reset()
   started=clock();unit:Flush();local flushMs=(clock()-started)&0xffffffff
   local flushScopes=profiler.Snapshot()
   local flushLocalScopes=locals.Snapshot()
   local weaponRanges=Ranges(unit);local rangeDigest=Hash();rangeDigest.add(weaponRanges)
   local stage={kind=kind,target=id,amount=amount,partsBefore=before,partsAfter=unit.bp:Size(),alive=unit.alive,
    budgetBefore=budgetBefore,budgetAfter=unit:Budget(),damageMs=damageMs,flushMs=flushMs,debrisPieces=#world.debris.pieces,
    damageScopes=damageScopes,flushScopes=flushScopes,damageLocalScopes=damageLocalScopes,flushLocalScopes=flushLocalScopes,rangeDigest=rangeDigest.get()}
   fixture.stages[#fixture.stages+1]=stage
   progressSequence=progressSequence+1
   local progress=cjson.encode({name=name,combat=combat,stage=stage});local count=math.ceil(#progress/3500)
   for index=1,count do print('G1_WEB_CPU_DAMAGE_STAGE '..cjson.encode({sequence=progressSequence,index=index,count=count,data=progress:sub((index-1)*3500+1,index*3500)}))end
   local events={};for _,event in ipairs(world.viewEvents)do events[#events+1]={type=event.type,id=event.id,reason=event.reason,amount=event.amount}end
   local debris={};for _,piece in ipairs(world.debris.pieces)do debris[#debris+1]={id=piece.id,parts=piece.parts,mass=piece.mass,current=piece.current}end
   local state={kind=kind,target=id,amount=amount,partsBefore=before,partsAfter=unit.bp:Size(),alive=unit.alive,
    blueprint=unit.bp:ToTable(),hp=unit.hp,shields=unit.shields,stats=world.stats,events=events,fx=world.fx,debris=debris,
    vehicle=unit.vehicle and unit.vehicle:GetState()or false,weaponRanges=weaponRanges}
   digest.add(state)
   stage.stateDigest=digest.get()
   assert(amount>0,'Actual damage must be applied')
   world.viewEvents={};world.fx={};world.debris.events={}
  end
  if name=='bridge-detach'then
   Damage(3,'bridge disconnect')
   assert(unit.bp:Size()==2 and #world.debris.pieces==1,'Bridge must detach its disconnected group')
   assert(#world.debris.pieces[1].parts==4,'Detached bridge group must contain four parts')
   assert(unit:Budget()>=unit.budget0*Unit.WRECK_RATIO and unit.alive,'Current bridge remainder stays above the production wreck threshold')
  elseif not combat then for index=1,3 do
   local parts=unit.bp:List();local id=nil ---@type number?
   for i=#parts,1,-1 do if parts[i].type~='core'then id=parts[i].id;break end end
   assert(id,'Non-core part required');Damage(id,'part '..index);if not unit.alive then break end
  end end
  if unit.alive then Damage(assert(unit.bp:CoreParts()[1]).id,combat and 'combat hull kill'or'core kill')end
  assert(not unit.alive,'Final core damage must kill authored unit')
  coroutine.yield();local started=clock();world.debris:Advance(world.time+Debris.LIFE+.01);fixture.expiryMs=(clock()-started)&0xffffffff
  assert(#world.debris.pieces==0,'Actual debris must expire')
  unit:Dispose();world.debris:Clear();assert(next(space.bodies)==nil,'Actual body registrations must release');profiler.Restore();locals.Restore()
  space:Dispose();scene:Dispose()
 end
 local tail={};for i=1,32 do tail[i]=math.random()end
 return {fixtures=fixtures,stateDigest=digest.get(),randomTail=tail,
  boundary='Real CarUnit.Damage and Flush including connectivity, VehicleSpec rebuild, native compound creation/disposal and real Debris. Timers split direct Damage/Flush and initialBuild/expiry. Timing mode installs no wrappers; profile mode adds 23 actual exported method scopes with inclusive/self/calls and observation overhead, split for Damage and Flush, so parents overlap children and are not summed. No CombatView, UI, sound or FX geometry update. Events retained in digest then drained outside timers. Four authored raceCar/megaMech noncombat/combat cases and the verified single-bridge detachment case followed by separate core kill; no performance threshold or FPS claim.'}
end
return M
