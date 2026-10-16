-- Actual Tick / CombatView / DriveView / Vehicle methods with strict native doubles.
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(v,s)assert(v,s);checks=checks+1 end
local function noop()end
local function Noop()return setmetatable({},{__index=function()return noop end})end
local vec={x=0,y=0,z=0,Lerp=function(self)return self end,Slerp=function(self)return self end}
Vector3=setmetatable({ZERO=vec,UP=vec},{__call=function()return vec end})
function Quaternion()return vec end
local modules={'controls.ChaseCamera','controls.ChaseState','controls.DriveInput','ui.DriveHud','render.CombatEffects',
 'urhox-libs/UI','ui.DialogHost','render.TargetFeedback','drive.VehicleSetup','drive.RaySuspension','drive.ContactControl',
 'drive.ChassisStability','drive.HoverControl','drive.ThrusterControl','drive.LegControl','drive.LegHitboxes','drive.RotorMotion',
 'core.Rotations','drive.VehicleSpec','render.ActuatorView','render.LegView','render.EquipmentEffects','core.Math3'}
for _,name in ipairs(modules)do package.loaded[name]={}end
package.loaded['controls.DriveAim']={AutoFire=function()return false end}
package.loaded['render.NodeVisibility']={Set=function(root,on)root.enabled=on end}
package.loaded['core.Coord']={Vec=function()return vec end}
package.loaded.Config={CELL=.5}
package.loaded['render.WeaponView']={Update=noop}
package.loaded['render.PartRig']={SetWheel=noop}
local flashEvents=0
package.loaded['render.PartHitFlash']={New=function()return {Consume=function(self,world)flashEvents=flashEvents+#world.viewEvents end,Update=noop,Dispose=noop}end}
local function Visual()
 local v={root={position=vec,rotation=vec,SetScale=noop},visuals={},joined={Update=noop}}
 function v:AddPart(p)self.visuals[p.id]={part=p}end
 function v:RemovePart(id)self.visuals[id]=nil end
 function v:Dispose()self.disposed=true end
 v.UpdateIdle=noop;v.UpdateWeaponEffects=noop
 return v
end
package.loaded['render.VehicleView']={New=Visual}
local Vehicle=require 'drive.Vehicle'
local Drive=require 'render.DriveView'
local Combat=require 'render.CombatView'
local Trial=TrialSource and assert(load(TrialSource,'@manifest-e266:app/TrialSession.lua'))() or require 'app.TrialSession'
local function Native()
 return setmetatable({native={},node={Dispose=noop},space={Unregister=noop},wheels={{rest=1,sag0=0,drop=0,spinSign=1}},
 suspension={states={{grounded=true,length=1,steer=0,spin=0}}}},Vehicle)
end
local function DriveFixture(vehicle)
 local d=setmetatable({vehicle=vehicle,view=Visual(),previous={p=vec,q=vec},current={p=vec,q=vec},
 rotors={Update=noop},wheels={{i=1,vis={},up={}}},tracks={},wings={},actuators={Update=noop},legs={Update=noop},
 mechs={Update=noop},equipment={Update=noop,Dispose=noop},time=0},Drive)
 d.SavePose=noop
 function d:Bind(bp,nextVehicle)self.vehicle=nextVehicle;self.bound=true end
 return d
end
local function Fixture()
 local player={alive=true,externalView=true,weapons={projectiles={},drill={Latched=function()return false end,ControlsBody=function()return false end}},vehicle={body={center=function()return vec end},speed=0},bp={}}
 local vehicle=Native();local enemy={alive=true,weapons={projectiles={},drill={Latched=function()return false end}},bp={parts={}},vehicle=vehicle}
 local world={time=0,viewEvents={},debris={events={}},fx={},units={player,enemy},metrics={Timing=noop},targets={}}
 function world:Step(dt)self.time=self.time+dt end
 local combatView=Combat.New({});local drive=DriveFixture(vehicle);combatView.units[enemy]=drive
 local s=setmetatable({world=world,combat={player=player,voice={},entries={},BeforeStep=noop,AfterStep=noop},
 pointer={captured=false},weaponAudio=Noop(),drivingAudio=Noop(),feedbackAudio=Noop(),collisionAudio=Noop(),
 restoreFlash=Noop(),camera={GetNode=function()return vec end},view={view=Visual(),Update=noop,SavePose=noop},
 weapons={drill={Latched=function()return false end,ControlsBody=function()return false end}},
 effects=Noop(),accumulator=0,fixedSteps=0,droppedTime=0,fxContext={},safeReset=Noop()},Trial)
 local syncs,consumed=0,0
 s.combat.session=s;s.combat.world=world
 function s.combat:SyncPlayer()syncs=syncs+1;require('combat.PlayerViewSync').Update(self) end
 s.Aim=function()return {}end
 s.combatView=combatView
 s.vehicle=player.vehicle;s.weapons=player.weapons
 function s.view.view:Rebuild()self.rebuilt=true end
 function s.view:Bind(bp,vehicle)assert(vehicle and not vehicle.disposed,'player never binds disposed vehicle');self.bound=vehicle end
 s.feedbackAudio.Consume=function()consumed=consumed+1 end
 return s,enemy,drive,vehicle,function()return syncs,consumed end
end
local function Run(s,dt)
 s:Tick(dt,{throttle=0,steer=0})
end
local s,enemy,drive,old,stats=Fixture()
old:Dispose();enemy.alive=false;enemy.vehicle=nil;s.world.viewEvents={{type='unitKilled',unit=enemy}}
local ok,err=pcall(Run,s,.001)
local first={pass=ok,error=not ok and tostring(err)or nil}
if not Trial.ConsumeWorldEvents then
 Check(not ok and tostring(err):find('suspension',1,true),'old actual zero-step frame dereferences disposed suspension')
 return {pass=false,checks=checks,reproducedBeforeFix=first}
end
Check(ok,'zero-step kill frame synchronizes before DriveView render: '..tostring(err))
Check(drive.disposed and s.combatView.units[enemy]==nil,'dead DriveView retired')
Check(s.fixedSteps==0 and #s.world.viewEvents==0,'zero-step consumes lifecycle without simulating')
local sync,consume=stats();Check(sync==1 and consume==1,'owner synchronization and feedback exactly once')
for _,kind in ipairs({'unitRemoved','unitKilled'})do
 local t,u,d,v=Fixture();v:Dispose();u.vehicle=nil;u.alive=false;t.world.viewEvents={{type=kind,unit=u}}
 Run(t,.001);Check(d.disposed and not t.combatView.units[u],kind..' external event retires old view')
end
local t,u,d,v=Fixture();v:Dispose();u.vehicle=Native();t.world.viewEvents={{type='unitRebuilt',unit=u}}
Run(t,.001)
Check(d.bound and d.vehicle==u.vehicle and not d.vehicle.disposed,'zero-step surviving rebuild binds actual replacement before WheelPose')
Check(t.fixedSteps==0,'rebuild does not advance physics')
local pending,pu,pd,pv=Fixture();local player=pending.combat.player
player.vehicle={body={center=function()return vec end},speed=0}
pending.world.viewEvents={{type='unitRebuilt',unit=player}}
Run(pending,.001)
Check(#pending.world.viewEvents==0 and pending.view.bound==player.vehicle and pending.view.view.rebuilt,'actual PlayerViewSync binds final living replacement')
local dead,deadEnemy,deadDrive,deadNative,deadStats=Fixture()
dead.combat.player.alive=false;dead.world.viewEvents={{type='unitKilled',unit=dead.combat.player}}
Run(dead,.001);local ds,dc=deadStats()
Check(ds==1 and dc==1 and #dead.world.viewEvents==0 and dead.view.bound==nil and dead.view.view.root.enabled==false,'actual PlayerViewSync hides dead player without Bind')
local multi,mu,md,mv,mstats=Fixture()
local flashBefore=flashEvents
Run(multi,.05);local ms,mc=mstats()
Check(multi.fixedSteps==3,'three actual fixed steps preserved')
Check(ms==3 and mc==3,'fixed step feedback consumes once per step, no empty tail duplication')
Check(flashEvents==flashBefore,'empty fixed-step batches do not invent hit events')
local twice,tu,td,tv,tstats=Fixture();twice.world.viewEvents={{type='unitDamaged',unit=tu}}
flashBefore=flashEvents;Run(twice,2/60);local ts,tc=tstats()
Check(twice.fixedSteps==2 and tc==2 and flashEvents-flashBefore==1,'two steps consume pending hit exactly once, no tail replay')
local paused,uu,dd,vv,pstats=Fixture()
paused.pointer.captured=false;vv:Dispose();uu.alive=false;uu.vehicle=nil;paused.world.viewEvents={{type='unitKilled',unit=uu}}
Run(paused,.001)
Check(dd.disposed and paused.fixedSteps==0,'pointer-unlocked neutral Tick keeps lifecycle synchronized')
local debris,du,ddrive,dvehicle,dstats=Fixture()
debris.world.debris.events={{type='spawn',piece={parts={{id=17,_cells={{0,0,0}}}},previous={p={0,0,0},q={w=1,x=0,y=0,z=0}},current={p={0,0,0},q={w=1,x=0,y=0,z=0}},age=0}}}
Run(debris,.001)
Check(#debris.world.debris.events==0 and next(debris.combatView.pieces)~=nil,'zero-step detached piece events consumed')
local idle,iu,id,iv,istats=Fixture();Run(idle,.001);local is,ic=istats()
Check(is==0 and ic==0,'idle zero-step frame does not replay or allocate consumption')
local effect,eu,ed,ev,estats=Fixture();effect.world.fx={{type='impact'}};local effectsConsumed=0
effect.effects.Consume=function(self,list)effectsConsumed=effectsConsumed+#list end
Run(effect,.001)
Check(#effect.world.fx==0 and effectsConsumed==1,'fx-only zero-step frame consumed once')
for _,kind in ipairs({'endless-editing','endless-over','battle-over','story-finished','salvage-finished'})do
 local early,uu,dd,vv,earlyStats=Fixture()
 local renderCalls=0;early.combatView.Update=function()renderCalls=renderCalls+1 end
 if kind=='endless-editing' then early.endless={run={state='editing'}}
 elseif kind=='endless-over' then early.endless={run={state='over'}}
 elseif kind=='battle-over' then early.battle={rules={state='over'}}
 elseif kind=='story-finished' then early.story={};early.combat.rules={finished=true}
 else early.salvage={begun=true,rules={},audio={SetActive=noop}};early.combat.rules={finished=true}end
 early.world.viewEvents={{type='unitKilled',unit=uu}}
 Run(early,.001);local es,ec=earlyStats()
 Check(renderCalls==0 and ec==0 and es==0 and #early.world.viewEvents==1,'early-return preserves pending lifecycle without rendering: '..kind)
end
return {pass=true,checks=checks,reproducedBeforeFix=first,boundary='Actual Tick, PlayerViewSync.Update, CombatView, DriveView.Update and Vehicle.Dispose/WheelPose with strict native/vector/audio/geometry adapters; no guard on disposed suspension. External kill/remove/rebuild/player/debris/fx, zero/two/three steps, feedback exactly once, pointer-unlocked neutral path and editing/over/story-finished/salvage-finished early-return. No GPU, natural firing or device performance acceptance.'}
