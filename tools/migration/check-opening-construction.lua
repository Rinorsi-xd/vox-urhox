-- Actual OpeningHost.Prepare / TrialSession constructors, engine boundaries stubbed.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks={};local trace={};local units={};local views={};local worlds={};local failAt=nil
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Noop() end
local function Record(name) trace[#trace+1]=name;if failAt==name then error('injected '..name) end end
local function Module(name,value) package.loaded[name]=value end
local function Owned(name)
 return {name=name,Dispose=function(self)if not self.disposed then self.disposed=true;Record('dispose:'..name)end end}
end
local function Node(name)
 local n=Owned(name);n.enabled=true;n.SetEnabledRecursive=function(self,v)self.enabled=v end;return n
end
local scene={CreateChild=function(_,name)return Node(name)end}
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
input={};MM_ABSOLUTE='absolute'
local BP={};BP.__index=BP
function BP.New()return setmetatable({name='test'},BP)end
function BP:Load(source)self.source=source;self.name=source.name or 'test';return self end
function BP:ToTable()return self.source or {name=self.name}end
function BP:List()return {{id=1}}end
function BP:Size()return 1 end
Module('construction.Blueprint',BP)
Module('core.Coord',{Vec=Vector3})
Module('Config',{CELL=.5})
Module('urhox-libs/UI',{})
Module('ui.DialogHost',{Dispose=Noop})
Module('controls.TouchPreferences',{Get=Noop})
Module('controls.TouchMode',{Enabled=function()return false end})
Module('controls.DriveInput',{New=function()return {Clear=Noop}end})
Module('controls.DrivePointer',{New=function()return {Release=Noop}end})
Module('controls.ChaseState',{New=function()return {}end})
Module('controls.SpeedFov',{New=function()return {}end})
Module('controls.CameraFeedback',{New=function()return {Queue=Noop}end})
Module('controls.SafeReset',{New=function()return Owned('reset')end})
Module('controls.ChaseCamera',{Create=function()
 Record('camera');local node=Node('camera');return {GetNode=function()return node end,GetCamera=function()return {}end}
end})
Module('ui.DriveHud',{})
Module('render.WeaponView',{})
Module('render.MatchMapShot',{New=function()return Owned('minimap')end})
Module('render.TargetFeedback',{New=function()Record('target-feedback');return Owned('target-feedback')end})
Module('render.CombatEffects',{New=function()Record('effects');return Owned('effects')end})
Module('render.RestoreFlash',{New=function()Record('restore-flash');return Owned('restore-flash')end})
Module('render.AimLines',{New=function()Record('aim-lines');return Owned('aim-lines')end})
Module('render.DrillSpeed',{New=function()Record('drill-speed');return Owned('drill-speed')end})
Module('render.BoundaryFx',{ForWorld=function()return {}end,New=function()Record('boundary');return Owned('boundary')end})
Module('audio.SoundPreparation',{Prepare=function(progress)Record('sounds');progress(1,'sounds')end})
for _,name in ipairs({'WeaponAudio','DrivingAudio','CombatFeedbackAudio','CollisionAudio'})do
 Module('audio.'..name,{New=function()Record(name);return Owned(name)end})
end
local function World()
 local w=Owned('world');w.scene=scene;w.units={};w.viewEvents={};w.targets={};w.layout={teleports={{yaw=0}}}
 w.GroundAt=function()return 0 end;w.SetUnits=function()Record('set-units')end
 local dispose=w.Dispose;function w:Dispose()if not self.disposed then for _,u in ipairs(self.units)do u:Dispose()end;dispose(self)end end
 worlds[#worlds+1]=w;return w
end
Module('fixture.World',{New=function()return World()end})
Module('fixture.Assets',{Release=Noop})
Module('fixture.Environment',{New=function()Record('environment');return Owned('environment')end})
Module('drive.CraterWorld',{New=function()return World()end})
Module('drive.CraterPhysics',{Build=function(_,progress)Record('physics');progress(1,'physics')end})
Module('drive.VehicleSpec',{Build=function()return {ok=true,weapons={{}},wings={},wheels={{}},legs={},hovers={}}end})
Module('construction.Prefab',{BuildRaceCar=function()error('unexpected fallback')end})
Module('combat.CarUnit',{New=function(w,source,options,progress,retain)
 Record('unit');local u=Owned('unit');u.alive=true;u.bp=BP.New():Load(source);u.spawnAt=options.spawn;u.team=options.team
 u.externalView=options.externalView;u.externalControl=options.externalControl
 u.vehicle=Owned('vehicle');u.vehicle.native={enabled=true};u.vehicle.Place=Noop;u.weapons={drill={Cancel=Noop}}
 local dispose=u.Dispose;function u:Dispose()if not self.disposed then self.vehicle:Dispose();dispose(self)end end
 if retain then retain(u)end
 units[#units+1]=u;w.viewEvents[#w.viewEvents+1]={type='unitSpawn',unit=u}
 if progress then progress(1)end;return u
end})
Module('combat.EnemyDriver',{New=function()return {}end})
local function MakeCombat(session,bp,field)
 Record(field);local u=require('combat.CarUnit').New(session.world,bp:ToTable(),{spawn={yaw=0},externalView=true})
 session.world.units[#session.world.units+1]=u
 local c=Owned(field);c.player=u;c.entries={{unit=u}};c.rules={};c.objectives={Update=Noop};c.sounds={Play=Noop}
 session[field]=c;session.combat=c;return c
end
Module('app.PracticeSession',{New=function(s,bp)s.world:SetUnits(bp,true);return MakeCombat(s,bp,'practice')end})
for _,cfg in ipairs({{'app.EndlessSession','endless'},{'salvage.Run','salvage'},{'story.Mission','story'},{'combat.BattleController','battle'}})do
 Module(cfg[1],{New=function(s,bp)return MakeCombat(s,bp,cfg[2])end})
end
Module('render.DriveView',{New=function(_,bp,vehicle,progress,retain)
 Record('drive-view');local v=Owned('drive-view');v.bp=bp;v.vehicle=vehicle;v.view={root=Node('view-root'),SetVisible=Noop,UpdateIdle=Noop,UpdateWeaponEffects=Noop}
 v.equipment={root=Node('equipment')};v.ResetPose=Noop;v.Update=Noop
 if retain then retain(v)end;views[#views+1]=v
 if progress then progress(1)end;Record('drive-view-ready');return v
end})
Module('render.CombatView',{New=function()
 Record('combat-view');local v=Owned('combat-view');v.units={}
 function v:Consume(w,progress)
  Record('consume-views');for _,u in ipairs(w.units)do if not u.externalView then
   self.units[u]=require('render.DriveView').New(scene,u.bp,u.vehicle,progress,function(view)self.units[u]=view end)
  end end;w.viewEvents={}
 end
 local dispose=v.Dispose;function v:Dispose()if not self.disposed then for _,view in pairs(self.units)do view:Dispose()end;dispose(self)end end
 return v
end})
local Session=require('app.TrialSession')
-- Camera math/rendering are covered separately; keep constructor and disposal real.
Session.ResetCamera=function()Record('reset-camera')end
Session.PostUpdate=function()Record('post-update')end
local app={graphicsSettings={RetainPost=function()Record('retain-post')end}}
local map={id='crater',scene='Scenes/Crater.xml',world='fixture.World',assets='fixture.Assets',environment='fixture.Environment'}
Module('app.DriveMaps',{crater=map})
local function Reset()trace={};units={};views={};worlds={};failAt=nil end
local function Count(name)local n=0;for _,entry in ipairs(trace)do if entry==name then n=n+1 end end;return n end
local function Shared(s,label)
 for _,key in ipairs({'controls','pointer','world','environment','effects','cameraFeedback','weaponAudio','drivingAudio','feedbackAudio','collisionAudio','combatView','view','target','restoreFlash','chase','speedFov','camera','boundary','aimLines','fxContext','drillSpeed','safeReset'})do
  Check(s[key]~=nil,label..' keeps '..key)
 end
 Check(s.vehicle==s.combat.player.vehicle and s.weapons==s.combat.player.weapons,label..' uses final player body/weapons')
 Check(s.world.feedbackPlayer==s.combat.player,label..' final player owns damage attribution')
end
for _,mode in ipairs({'practice','endless','salvage','story','battle'})do
 Reset();local m={};for k,v in pairs(map)do m[k]=v end
 if mode=='story'then m.storyLevel=1 elseif mode=='battle'then m.battleMode='ffa' elseif mode~='practice'then m[mode]=true end
 local retained=nil;local s=Session.New(scene,BP.New(),app,m,nil,nil,function(value)retained=value end)
 Check(s==retained,mode..' retains shared session before construction');Check(Count(mode)==1,mode..' default controller once')
 Check(#units==1 and #views==1 and views[1].vehicle==s.vehicle,mode..' creates one final body/view');Shared(s,mode)
 local w=s.world;s:Dispose();s:Dispose();Check(w.disposed and units[1].disposed and views[1].disposed,mode..' disposal owns final objects')
 Check(Count('dispose:world')==1 and Count('dispose:drive-view')==1,mode..' disposal is idempotent')
end
Module('intro.IntroShots',{Cast=function(data)
 local cast={};for i=1,7 do cast[i]={source=data.actors.invaders[i].blueprint,name='enemy'..i,spawn={pos={i,0,i},yaw=0}}end;return cast
end})
Module('render.VehicleView',{New=function()return {root=Node('hero'),AddPart=Noop,joined={Update=Noop},Dispose=Noop}end})
Module('intro.IntroAssembly',{New=function()return Owned('assembly')end})
Module('intro.IntroGarage',{New=function()return Owned('garage')end})
Module('ui.IntroSortieUi',{New=function()Record('sortie-ui');return Owned('sortie-ui')end})
Module('app.SceneLoader',{New=function()return {Load=function(self,_,done,fail,options)self.options=options;self.done=done end}end})
local Host=require('app.OpeningHost');Host.Dependencies=function()return {'opening-dependency'}end
local data={actors={hero={name='hero'},cart={name='cart'},invaders={}}}
for i=1,7 do data.actors.invaders[i]={blueprint={name='enemy'..i},role='attacker'}end
local function Prepare(yielding)
 local a={};for k,v in pairs(app)do a[k]=v end;a.scene=scene;a.blueprint=BP.New()
 local host=Host.New(a);host.Prepare({data=data},Noop,Noop)
 local progress={};local work=coroutine.create(function()
  host.state.loader.options.prepare(scene,function(p,stage)progress[#progress+1]={p=p,stage=stage};if yielding then coroutine.yield()end end)
 end)
 return host,work,progress
end
for _,yielding in ipairs({false,true})do
 Reset();local host,work,progress=Prepare(yielding);local frames=0
 repeat local ok,err=coroutine.resume(work);assert(ok,err);frames=frames+1 until coroutine.status(work)=='dead'
 local s=host.state.session;Shared(s,'opening');Check(s.practice==nil,'opening never creates temporary practice controller')
 CONSTRUCTION_METRICS={bodies=#units,views=#views,practice=Count('practice'),discardedBodies=Count('dispose:vehicle'),discardedViews=Count('dispose:drive-view')}
 Check(Count('practice')==0 and Count('set-units')==0,'opening never suppresses or invokes default SetUnits')
 Check(#s.combat.entries==9 and #s.world.units==9,'opening preserves final 9 active actors')
 Check(#units==10 and #views==10,'opening creates exactly 9 actor bodies/views plus original pooled montage body/view')
 Check(s.combat.montage and not s.combat.montage.activated,'opening retains original prebuilt montage')
 Check(s.view.vehicle==s.vehicle and s.view.bp==s.combat.player.bp,'opening final view belongs to final player')
 Check(Count('dispose:vehicle')==0 and Count('dispose:drive-view')==0,'opening has no discarded temporary body or view')
 Check(Count('sounds')==1 and Count('consume-views')==1 and Count('retain-post')==1,'opening creates sound/views/post chain once')
 Check(progress[1].p>=0 and progress[#progress].p==1,'opening progress spans actual preparation to completion')
 for i=2,#progress do Check(progress[i].p>=progress[i-1].p,'opening progress monotonic '..i)end
 Check(yielding==false and frames==1 or yielding==true and frames>1,'opening keeps cooperative checkpoints')
 local world=s.world;local montage=s.combat.montage;s:Dispose();s:Dispose()
 Check(world.disposed and montage.disposed,'opening world and montage disposed with shared session')
 for i,u in ipairs(units)do Check(u.disposed,'opening releases actor body '..i)end
 for i,v in ipairs(views)do Check(v.disposed,'opening releases actor view '..i)end
end
for _,stage in ipairs({'unit','environment','drive-view-ready','camera'})do
 Reset();failAt=stage;local retained=nil
 local ok,err=pcall(Session.New,scene,BP.New(),app,map,nil,nil,function(s)retained=s end,function(s)
  local c=MakeCombat(s,BP.New(),'cinematic');return c
 end)
 Check(not ok and tostring(err):find('injected '..stage,1,true)~=nil,'constructor propagates '..stage..' failure')
 Check(retained and retained.disposed and retained.world==nil,'partial '..stage..' constructor disposes retained session')
 Check(worlds[1].disposed,'partial '..stage..' constructor disposes world')
 for i,u in ipairs(units)do Check(u.disposed,'partial '..stage..' releases body '..i)end
 for i,v in ipairs(views)do Check(v.disposed,'partial '..stage..' releases view '..i)end
end
return {checks=checks,count=#checks}
