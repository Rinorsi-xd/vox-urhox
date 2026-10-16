package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks={};local ai={};local cleanup={};local selected={};local noop=function()end
local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local function module(name,value)package.loaded[name]=value end
module('core.Coord',{})
local BP={New=function()return {Load=function(self,s)self.source=s;return self end,ToTable=function(self)return self.source end}end}
module('construction.Blueprint',BP)
module('drive.VehicleSpec',{Build=function(bp)return bp.source.spec end})
local fallback={fallback=true}
module('construction.Prefab',{BuildRaceCar=function(bp)bp.source=fallback;return bp end})
local Select=require('intro.IntroSortieCar').Select
for _,case in ipairs(REFERENCE.selection)do
 local spec={ok=case.ok}
 for bit,key in ipairs({'weapons','wings','wheels','legs','hovers','mechLegs'})do spec[key]=(case.flags&(1<<(bit-1)))~=0 and {{}}or {}end
 local source={spec=spec};local actual=Select(source)
 check((actual==source)==case.original,'source sortie eligibility '..tostring(case.ok)..'/'..case.flags)
 check(actual==source or actual==fallback,'fallback is the actual race-car builder result')
 selected[#selected+1]={ok=case.ok,flags=case.flags,original=actual==source}
end
local function ground(_,x,z)return x*.01-z*.02 end
local function unit(world,source,opt,checkpoint,retain)
 local u={alive=true,source=source,team=opt.team,spawnAt=opt.spawn,externalControl=opt.externalControl,places={},spawns=0,bp={}}
 function u:Position()return self.pos end
 function u:Flush()end
 local function build()
  u.pos={table.unpack(opt.spawn.pos)}
  local body={translation=function()return{x=u.pos[1],y=u.pos[2],z=u.pos[3]}end,linvel=function()return{x=0,y=0,z=0}end,rotation=function()return{}end}
  u.vehicle={body=body,native={enabled=true},spec={wings={}},rotors={},com={0,0,0},StepRotors=noop,Step=noop,
   Place=function(_,p,yaw)u.pos={table.unpack(p)};u.places[#u.places+1]={pos=p,yaw=yaw}end}
  u.weapons={fx={},projectiles={},drill={Cancel=noop},Step=noop}
 end
 function u:Spawn()self.alive=true;self.spawns=self.spawns+1;build()end
 function u:Dispose()self.alive=false;self.disposes=(self.disposes or 0)+1 end
 if retain then retain(u)end
 build();world.viewEvents[#world.viewEvents+1]={type='unitSpawn',unit=u}
 if checkpoint then checkpoint(1)end;return u
end
module('combat.CarUnit',{New=unit})
module('combat.EnemyDriver',{New=function(_,u)return {Step=function(_,_,victim)u.lastVictim=victim;u.driverCalls=(u.driverCalls or 0)+1;return{throttle=1},victim:Position(),false end}end})
module('combat.DriverActions',{Apply=noop});module('drive.RotorMotion',{Weapons=noop})
module('combat.PlayerViewSync',{Update=noop})
module('render.DriveView',{New=function()return{view={SetVisible=noop,UpdateIdle=noop,UpdateWeaponEffects=noop},equipment={},ResetPose=noop,Update=noop,Dispose=noop}end})
module('app.SceneLoader',{New=function()return {Update=noop,Cancel=noop}end})
module('ui.CommsCard',{})
module('scene.Crater',{Release=noop})
local Battle=require 'intro.IntroBattle'
local Pool=require 'intro.IntroMontagePool'
local Host=require 'app.OpeningHost'
local function create()
 local world={units={},viewEvents={},GroundAt=ground}
 local s={world=world,scene={Dispose=noop},fxContext={},effects={Consume=noop},weaponAudio={Consume=noop},camera={GetNode=function()return{worldPosition={x=0,y=0,z=0}}end,GetCamera=function()return{node={position={x=-98,y=13,z=-212}}}end},
  view={Dispose=noop},Pause=function(self)self.pauses=(self.pauses or 0)+1 end,ResetCamera=noop,ReleaseAssets=noop}
 local battle=Battle.New(s,INTRO_DATA,{id='teaching'});s.vehicle=battle.player.vehicle;s.weapons=battle.player.weapons
 local pool=Pool.New(s,battle,INTRO_DATA.actors.hero)
 local app={car={SetVisible=noop},graphicsSettings={SetSceneVisible=noop,ReleasePost=noop,Show=noop},DeferAssetRelease=function(_,fn)fn()end}
 local host=Host.New(app);host.state.session=s;host.state.world=world;host.state.scene=s.scene
 host.state.hallActor={root={enabled=true},SetVisible=function(self,visible)self.root.enabled=visible end,UpdateIdle=noop,Dispose=noop}
 function s:Dispose()
  if self.disposed then return end;self.disposed=true;self.disposes=(self.disposes or 0)+1
  self.combat:Dispose();for _,u in ipairs(self.world.units)do u:Dispose()end
 end
 return host,s,battle,pool
end
for _,case in ipairs(REFERENCE.ai)do
 local host,s,b=create();b.stage=case.stage;b.cart.alive=case.targetAlive;b.player.alive=case.targetAlive
 local actor=case.easy and b.easy or b.entries[2].unit
 local calls=actor.driverCalls or 0;b:BeforeStep(1/60,{throttle=0},nil)
 local label=actor.lastVictim==b.player and 'player'or actor.lastVictim==b.cart and 'cart'or nil
 check((actor.driverCalls or 0)-calls==#case.calls,'source cinematic AI presence '..case.stage..'/'..tostring(case.targetAlive))
 if #case.calls>0 then check(label==case.calls[1],'source cinematic AI target '..case.stage)end
 ai[#ai+1]={stage=case.stage,targetAlive=case.targetAlive,target=label}
 host.Dispose();host.Dispose();check(s.disposes==1,'cancel and repeated disposal release session once')
end
if not HISTORICAL then
 local Retirement=require('app.OpeningRetirement')
 local clock=0;Time={GetSystemTime=function()clock=clock+1;return clock end}
 local host,s=create();local state=host.state;local app=state.app
 local jobs={};local releases=0
 local borrowed=0;local hidden=0
 state.hallActor={SetVisible=function(_,visible)check(not visible,'old hall actor hides before handoff');hidden=hidden+1 end,Dispose=function()borrowed=borrowed+1 end}
 state.garage={root={SetEnabledRecursive=function(_,visible)check(not visible,'old hall props hide before handoff');hidden=hidden+1 end},Dispose=function()borrowed=borrowed+1 end}
 app.RetireOpening=function(_,work,done)jobs[#jobs+1]=Retirement.New(work,done)end
 app.DeferAssetRelease=function(_,fn,incremental)check(incremental,'opening release uses incremental collection');releases=releases+1;fn()end
 local disposedScene=0;s.scene.GetChildren=function()return{}end;s.scene.Dispose=function()disposedScene=disposedScene+1 end
 host.Dispose({completed=true});host.Dispose({completed=true})
 check(#jobs==1 and not s.disposed and s.pauses==1,'normal completion parks one owned retirement and pauses input immediately')
 check(borrowed==2 and hidden==2 and not state.hallActor and not state.garage,'borrowed hall objects end before replacement may dispose their parent')
 check(s.scene.updateEnabled==false,'retiring independent scene stops native update immediately')
 -- A later opening or match can replace app ownership before the old job ends.
 local newScene={};app.scene=newScene;app.mode='trial';app.openingRestoreOwner={}
 while not Retirement.Step(jobs[1],false)do end
 check(s.disposes==1 and disposedScene==1 and releases==1,'retirement releases captured old session and scene exactly once')
 check(app.scene==newScene and app.mode=='trial','old retirement cannot clear a replacement match scene')
 check(Retirement.Step(jobs[1],true) and releases==1,'completed retirement is idempotent under Stop drain')
 local steps=0;local done=0
 local job=Retirement.New(function(checkpoint)for _=1,100 do steps=steps+1;checkpoint()end end,function()done=done+1 end)
 check(not Retirement.Step(job,false) and steps<100 and done==0,'retirement yields across real time budget before all work completes')
 Retirement.Step(job,true);check(steps==100 and done==1,'Stop drains suspended work synchronously and completes once')
 local order={};local function node(name,children)
  return {GetChildren=function(_,recursive)check(recursive==false,'tree retirement requests direct children');return children or{}end,
   Dispose=function()order[#order+1]=name end}
 end
 Retirement.Nodes(node('root',{node('parent',{node('leaf')})}),noop)
 check(table.concat(order,',')=='leaf,parent','native nodes retire children before their parent')
 local untouched=0;Retirement.Nodes({GetChildren=function()untouched=untouched+1 end},nil)
 check(untouched==0,'synchronous cancellation leaves native ownership to existing Dispose')
 for _,cancelEarly in ipairs({false,true}) do
  local h,trial=create();local st=h.state;local owner=st.app;local queued={};local releasesEarly=0;local garageFrames=0
  local scene=trial.scene;scene.GetChildren=function()return{}end
  local destroyed=0;scene.Dispose=function()destroyed=destroyed+1 end
  owner.RetireOpening=function(_,work,done)queued[#queued+1]=Retirement.New(work,done)end
  owner.DeferAssetRelease=function(_,release)releasesEarly=releasesEarly+1;release()end
  st.activeScene='garage';st.hall={};st.hallCamera={}
  st.garage={root={SetEnabledRecursive=noop},Shot=noop,Update=function()garageFrames=garageFrames+1 end,Dispose=noop}
  st.hallActor.UpdateIdle=function()garageFrames=garageFrames+1 end
  st.sortieUi={Dispose=function(self)self.disposed=true end}
  local intro={ready=true,time=20,shot='comms',age=0}
  h.Shot('comms',intro)
  check(#queued==1 and not trial.disposed and trial.pauses==1,'comms schedules paused world retirement once')
  check(not st.session and not st.world and not st.scene and not st.sortieUi,'comms detaches every battle entry before asynchronous disposal')
  h.Update(1/60,intro)
  check(garageFrames==1 and not st.hallActor.root.enabled,'garage continues while hidden hall actor stays idle during battle retirement')
  h.Shot('comms',intro)
  check(#queued==1,'repeated comms cannot enqueue duplicate destruction')
  if cancelEarly then h.Dispose() end
  while not Retirement.Step(queued[1],false)do end
  check(trial.disposes==1 and destroyed==1 and releasesEarly==1,'early retirement disposes captured battle once, cancel='..tostring(cancelEarly))
  check(not st.assetReleasePending,'early retirement clears asset gate after release')
  h.Dispose();h.Dispose()
  check(releasesEarly==1 and #queued==1,'final page disposal never repeats completed world release')
 end
end
for _,mode in ipairs({'normal','skip-brief','skip-countdown','skip-playing','cancel-brief','cancel-playing','before-brief'})do
 local host,s,b,pool=create();local old=b.player;local held=pool.unit
 check(#b.easy.places==0 and b.easy.damageMultiplier==nil,'easy retains authored initial placement before '..mode)
 if mode~='before-brief'then host.Shot('sortie-brief',{time=0});check(b.stage==0 and b.easy.damageMultiplier==2 and b.damageScale==.12,'brief establishes teaching multipliers')end
 if mode=='normal'then
  s.Tick=function(_,dt,command)b:BeforeStep(dt,command,nil)end;host.state.activeScene='crater'
  for _,shot in ipairs({'sortie-brief','sortie-countdown'})do local before=b.easy.driverCalls or 0
   host.Update(1/60,{ready=true,playing=false,shot=shot,age=0,time=0})
   check(b.easy.driverCalls==before+1 and b.easy.lastVictim==b.cart,'actual host advances battlefield before player control: '..shot)
  end
 end
 if mode=='normal'or mode=='skip-playing'or mode=='cancel-playing'then
  host.StartSortie();local place=b.easy.places[1]
  check(b.stage==1 and b.easy.damageMultiplier==8 and #b.easy.places==1,'handoff alone enables easy vulnerability')
  local expected=REFERENCE.handoff
  check(place.pos[1]==expected.pos[1] and place.pos[3]==expected.pos[3] and place.pos[2]==expected.pos[2] and place.yaw==expected.yaw and b.easy.damageMultiplier==expected.mult,'executed source easy handoff transform and multiplier')
 end
 if mode=='normal'then b.easy.alive=false;b.entries[3].unit.alive=false;b.cart.alive=false;old.alive=false end
 if mode=='normal'then host.EndSortie()
 elseif mode:find('skip')then host.Shot('tvcut',{time=3})
 else host.Dispose()end
 if mode=='normal'or mode:find('skip')then
  local reference;for _,case in ipairs(REFERENCE.cleanups)do if case.mode==mode then reference=case end end
  check(pool.activated and b.player==held and s.vehicle==held.vehicle and s.weapons==held.weapons,'source hero restored through actual prebuilt pool: '..mode)
  local pose=held.places[1]
  check(pose.pos[1]==150 and pose.pos[3]==-214 and math.abs(pose.pos[2]-(ground(nil,150,-214)+1.5))<1e-9 and pose.yaw==0,'source hero cleanup transform: '..mode)
  check(reference.hero and reference.spawn.yaw==pose.yaw and reference.spawn.pos[1]==pose.pos[1] and reference.spawn.pos[2]==pose.pos[2] and reference.spawn.pos[3]==pose.pos[3],'executed source endPlay hero result: '..mode)
  check(b.stage==0 and b.damageScale==1 and s.scope==false and s.firing==false and s.accumulator==0,'script control and damage reset: '..mode)
  for index,e in ipairs(b.entries)do if e.unit~=b.player then local expected=reference.units[index-1]
   check(e.unit.damageMultiplier==expected.mult and e.unit.alive==expected.alive and e.unit.spawns==expected.spawned and e.unit.externalControl==expected.external,'executed source endPlay enemy state: '..mode..'/'..index)
  end end
  check(mode~='normal'or not b.cart.alive,'dead cart is not respawned')
  local pauses=s.pauses;local placements=#held.places;host.EndSortie();host.Shot('tvcut',{time=4})
  check(s.pauses==pauses and #held.places==placements and old.disposes==1,'repeat cleanup does not switch or dispose twice: '..mode)
  cleanup[#cleanup+1]={mode=mode,hero=true,position=pose.pos,damage=b.damageScale,stage=b.stage}
 else check(not pool.activated and not host.state.session and pool.disposed and held.disposes==1,'cancel disposes held hero without activating it: '..mode)end
 host.Dispose();host.Dispose();host.EndSortie();check(s.disposes==1,'terminal disposal and late cleanup once: '..mode)
end
module('urhox-libs/UI',{})
module('core.ResourceData',{Read=function()return INTRO_DATA end})
module('app.ResourceGate',{New=function()return{}end})
module('ui.IntroPage',{New=function()return{imageWarmup={ready=true}}end})
module('intro.IntroSortie',{New=function()return{done=true}end})
module('audio.IntroAudio',{New=function()return{Update=noop,Music=noop,StopMusic=noop,StopVoice=noop,StopSfx=noop,
 Voice=function(_,id)return INTRO_DATA.durations[id]or 2 end,Sfx=function()return{StopImmediate=noop}end}end})
local Session=require 'intro.IntroSession'
for _,skip in ipairs({'none','sortie-brief','sortie-countdown','sortie-play'})do
 local host,s,b,pool=create();host.Update=noop
 host.UseScene=noop
 local shot=host.Shot;host.Shot=function(id,I)shot(id,I);if id==skip then I:Skip()end end
 local I=Session.New({},host);I.active=true;I.ready=true;I.clicked=true;I.audioReady=true;I.sceneReady=true
 I.thread=coroutine.create(function()I:Run()end)
 local reached=false
 for frame=1,30000 do
  if I.shot=='sortie-brief'and I.age>=2.2 then I.advance=true end
  if I.shot==skip then I:Skip()end
  I:Update(1/120,true)
  assert(not I.failed,I.error)
  if I.shot=='familiar'or I.shot=='tvcut'then
   check(pool.activated and s.pauses==1,'actual Session.Run '..skip..' reaches cleanup exactly once')
   check(I.shot==(skip=='none'and'familiar'or'tvcut'),'actual Session.Run reaches expected next shot: '..skip)
   reached=true;break
  end
 end
 check(reached,'actual Session.Run completes sortie branch: '..skip)
 host.Dispose();host.Dispose();check(s.disposes==1,'actual Session.Run teardown once: '..skip)
end
if not HISTORICAL then
 for _,name in ipairs({'Config','render.VehicleView','scene.Hangar','controls.OrbitCamera','app.HotReload','render.Quality'})do module(name,{})end
 module('urhox-libs/UI',{Shutdown=noop})
 module('ui.GarageHud',{Dispose=noop})
 module('audio.UiSound',{Dispose=noop})
 module('audio.StoryComms',{Shutdown=noop})
 local targetFlushes=0
 module('render.RenderTargetLifetime',{Flush=function()targetFlushes=targetFlushes+1 end})
 local App=require('app.HangarApp');local app=setmetatable({},App)
 local order={};local completed=0
 app:RetireOpening(function(checkpoint)for _=1,40 do order[#order+1]='old';checkpoint()end end,function()completed=completed+1 end)
 app:AdvanceOpeningRetirements(false)
 check(completed==0 and app.openingRetirements,'real app queue leaves a suspended old retirement')
 app.scene={newMatch=true};app.mode='trial'
 app:RetireOpening(function(checkpoint)order[#order+1]='new';checkpoint()end,function()completed=completed+1 end)
 while app.openingRetirements do app:AdvanceOpeningRetirements(false)end
 check(completed==2 and order[#order]=='new' and app.scene.newMatch,'real app advances old and newer jobs in order without clearing replacement scene')
 app:RetireOpening(function(checkpoint)for _=1,40 do checkpoint()end end,function()completed=completed+1 end)
 app:AdvanceOpeningRetirements(false)
 app.mapTransition={Stop=noop};app.vehicleGate={Cancel=noop};app.loader={Cancel=noop}
 app.toasts={Dispose=noop};app.music={Dispose=noop};app.previews={Dispose=noop};app.store={Flush=noop}
 app.ambience={Dispose=noop} -- SoundSource device is outside this retirement fixture.
 app.graphicsSettings={Dispose=function()check(completed==3 and not app.openingRetirements,'real Stop drains all old native jobs before graphics disposal')end}
 app.previousState={};cache={};renderer={};input={}
 app:Stop();app:Stop()
 check(app.stopped and completed==3,'real Stop synchronously completes a suspended job exactly once')
 local released=0;local counts={};local gc=collectgarbage
 local cycleDone=false
 local fakeMode='generational'
 local function ModeCall(kind)
  if kind=='incremental' or kind=='generational' then
   local previous=fakeMode;fakeMode=kind;return previous
  end
 end
 local function CallCount(kind)
  local count=0;for _,entry in ipairs(counts)do if entry==kind then count=count+1 end end
  return count
 end
 collectgarbage=function(kind)
  counts[#counts+1]=kind
  if kind=='step' then return cycleDone end
  return ModeCall(kind)
 end
 environmentBakeCache={ClearCache=noop}
 local beforeFlush=targetFlushes
 app:DeferAssetRelease(function()released=released+1 end,true)
 check(not app:ReleaseSettledAssets() and released==0 and app.pendingAssetRelease~=nil,'unfinished incremental GC keeps the release callback pending')
 check(not app:ReleaseSettledAssets() and released==0,'another unfinished incremental step preserves the callback')
 app:DeferAssetRelease(function()released=released+1 end,true)
 check(app.assetReleaseFrames==3 and not app:ReleaseSettledAssets() and released==0,'appending retirement work preserves the collection fence and frame delay')
 cycleDone=true
 check(not app:ReleaseSettledAssets() and released==0 and app.pendingAssetRelease~=nil,'mid-cycle appended work waits beyond the currently completing cycle')
 check(app:ReleaseSettledAssets() and CallCount('step')>0 and released==2,'completed incremental GC releases every queued callback once')
 check(targetFlushes==beforeFlush,'opening resource release leaves protected render targets to background collection')
 local fullBefore=CallCount('collect')
 app:DeferAssetRelease(function()released=released+1 end);app:ReleaseSettledAssets()
 check(CallCount('collect')==fullBefore+1 and released==3,'normal non-opening release retains full collection policy')
 check(targetFlushes==beforeFlush+1,'normal non-opening release retains explicit render-target Flush')
 cycleDone=false
 app:DeferAssetRelease(function()released=released+1 end,true)
 app:ReleaseSettledAssets()
 app:DeferAssetRelease(function()released=released+1 end)
 fullBefore=CallCount('collect')
 check(not app.assetReleaseIncremental and app:ReleaseSettledAssets() and CallCount('collect')==fullBefore+1 and released==5,'nonincremental map release upgrades pending opening collection and runs both callbacks once')
 collectgarbage=function(kind)
  counts[#counts+1]=kind
  if kind~='step' then return ModeCall(kind) end
  app:DeferAssetRelease(function()released=released+1 end,true)
  return true
 end
 app:DeferAssetRelease(function()released=released+1 end,true)
 check(not app:ReleaseSettledAssets() and released==5 and app.assetReleaseFrames==3,'reentrant finalizer keeps the new frame fence and all pending callbacks')
 collectgarbage=function(kind)
  counts[#counts+1]=kind
  if kind=='step' then return true end
  return ModeCall(kind)
 end
 check(app:ReleaseSettledAssets() and released==7,'reentrant queued callbacks release exactly once after their own fence')
 app:DeferAssetRelease(function()app:DeferAssetRelease(function()released=released+1 end,true)end,true)
 check(app:ReleaseSettledAssets() and app.pendingAssetRelease~=nil,'release callback may schedule a later independent release')
 check(app:ReleaseSettledAssets() and released==8,'later independent release is not overwritten')
 collectgarbage=gc
end
return {count=#checks,checks=checks,ai=ai,cleanup=cleanup,selection=selected}
