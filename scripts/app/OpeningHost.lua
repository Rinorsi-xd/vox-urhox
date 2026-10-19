-- Opening owns its crater; the authored garage is borrowed and restored.
local DriveMaps=require("app.DriveMaps")
local ResourceData=require("core.ResourceData")
local ImportedDependencies=require("parts.Dependencies")
local WeaponIconResources=require("ui.WeaponIconResources")
local MissileView=require("render.MissileView")
local SceneLoader=require("app.SceneLoader")
local UI=require("urhox-libs/UI")
local Crater=require("scene.Crater")
local OpeningRetirement=require("app.OpeningRetirement")
local CommsCard=require("ui.CommsCard")
local ResourceGate=require("app.ResourceGate")
local IntroWarmup=require("intro.IntroWarmup")
local VehicleView=require("render.VehicleView")
local IntroAssembly=require("intro.IntroAssembly")
local IntroGarage=require("intro.IntroGarage")
local CraterWorld=require("drive.CraterWorld")
local CraterPhysics=require("drive.CraterPhysics")
local IntroSortieCar=require("intro.IntroSortieCar")
local IntroBattle=require("intro.IntroBattle")
local IntroSortieUi=require("ui.IntroSortieUi")
local IntroMontagePool=require("intro.IntroMontagePool")
local IntroShots=require("intro.IntroShots")
local ReticleState=require("ui.ReticleState")
local DriveAim=require("controls.DriveAim")
local ChaseState=require("controls.ChaseState")
local IntroStrike=require("intro.IntroStrike")
local IntroSceneCapture=require("intro.IntroSceneCapture")
local ViewportCapture=require("render.BossSceneCapture")
local WindowViewports=require("render.WindowViewports")
local SourceDraw=require("ui.SourceDraw")
local Config=require("Config")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local BP=require 'construction.Blueprint'
local Coord=require 'core.Coord'
local M={}
local function ValidProfile(p) return type(p)=='table' and type(p.name)=='string' and utf8.len(p.name)~=nil and p.name:find('%S')~=nil and type(p.signedAt)=='number' end
M.ValidProfile=ValidProfile
function M.Dependencies(app,data)
 local resources={};local map=DriveMaps.crater
 for _,path in ipairs(ResourceData.Read(map.resources)) do resources[#resources+1]=path end
 local parts={}
 local sources={app.blueprint:ToTable(),data.actors.hero,data.actors.cart}
 for _,actor in ipairs(data.actors.invaders) do sources[#sources+1]=actor.blueprint end
 for _,source in ipairs(data.actors.hovers or {}) do sources[#sources+1]=source end
 for _,source in ipairs(sources) do for _,p in ipairs(BP.New():Load(source):List()) do parts[#parts+1]=p end end
 for _,path in ipairs(ImportedDependencies.For(parts)) do resources[#resources+1]=path end
 for _,path in ipairs(WeaponIconResources.For(parts)) do resources[#resources+1]=path end
 for _,name in ipairs({'audio.WeaponAudio','audio.DrivingAudio','audio.CombatFeedbackAudio'}) do
  for _,path in ipairs(DeferredModules[name].Dependencies()) do resources[#resources+1]=path end
 end
 resources[#resources+1]='Equipment/plasma-flow.png'
 resources[#resources+1]='Shaders/BLGL/UI/CommsPortrait.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/Dove.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/SkyBeam.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/AssemblyFlash.shader'
 resources[#resources+1]='Shaders/BLGL/RestoreFlash.shader'
 resources[#resources+1]=data.images.dove
 for _,path in ipairs(MissileView.Dependencies()) do resources[#resources+1]=path end
 return resources
end
function M.New(app)
 local state={app=app,loader=SceneLoader.New(),activeScene='garage',captures={},sortieCaptures={}}
 state.loader.prepareBudgetMs=5
 local host={state=state}
 local function ClearCaptureImage(name)
  for vg,images in pairs(state.captureImages or {}) do
   local image=images[name]
   if image and image>0 then nvgDeleteVideo(vg,image) end
   images[name]=nil
  end
 end
 local function CancelCapture(I)
  local capture=state.pendingCapture;state.pendingCapture=nil;state.captureViewport=nil;state.captureWanted=nil
  if capture then capture:Dispose() end
  if I then I.capturePending=false end
 end
 local function ResumeTutorial()
  local pending=state.pendingTutorial;state.pendingTutorial=nil
  if not pending or app.stopped or app.openingRestoreOwner~=state or app.opening or app.mode~='hangar' or app.build or app.scene~=state.hall or app.tutorial~=pending.tutorial then return end
  UI.RegisterGlobalComponent('vox-tutorial',pending.tutorial.page)
  if pending.start then pending.tutorial:Start() end
 end
 local function DisposeWorld(checkpoint)
  if state.scene then app.graphicsSettings:ReleasePost(state.scene) end
  if state.session then state.session:Dispose(checkpoint);state.session=nil;state.world=nil
  elseif state.world then state.world:Dispose(checkpoint);state.world=nil end
 end
 local function RetireCrater(incremental)
  if state.craterRetired then return end
  state.craterRetired=true
  local session,world,scene,strike=state.session,state.world,state.scene,state.strike
  local release=session and session.ReleaseAssets or Crater.Release
  if incremental and session and not state.finishPaused then session:Pause() end
  if scene then scene.updateEnabled=false;app.graphicsSettings:ReleasePost(scene) end
  if state.warmup and state.warmup.disposed then state.warmup=nil end
  if state.sortieUi then state.sortieUi:Dispose();state.sortieUi=nil end
  -- Detach before yielding: UI/probes must never observe a half-disposed trial.
  state.session=nil;state.world=nil;state.scene=nil;state.strike=nil;state.strikePending=nil;state.strikeAt=nil
  CancelCapture(state.intro)
  state.montageTarget=nil;state.wreckCamera=nil
  state.assetReleasePending=true
  local function Work(checkpoint)
   if session then session:Dispose(checkpoint) elseif world then world:Dispose(checkpoint) end
   if strike then strike:Dispose() end
   if scene then OpeningRetirement.Nodes(scene,checkpoint);scene:Dispose() end
  end
  local function Done()
   app:DeferAssetRelease(function()
    release();state.assetReleasePending=false;ResumeTutorial()
   end,true)
  end
  if incremental and not app.stopped and app.RetireOpening then app:RetireOpening(Work,Done)
  else Work();Done() end
 end
 host.Begin=function(I)
  app.openingRestoreOwner=state
  state.intro=I;state.tutorial=app.tutorial;state.tutorialPage=app.tutorial and app.tutorial.page
  state.hall=app.scene;state.hallCamera=app.camera.camera;state.oldPose={position=app.camera.node.position,rotation=app.camera.node.rotation,fov=app.camera.camera.fov}
  state.oldCarVisible=app.car.root.enabled;app.car:SetVisible(false)
  DeferredModules['ui.GarageHud'].Dispose()
  if app.tutorial then
   app.tutorial.visible=false;app.tutorial.page:CancelInput();app.tutorial:DetachVoice()
   UI.UnregisterGlobalComponent('vox-tutorial')
  end
 end
 host.TakeTutorialPortrait=function(I,portrait,context)
  local tutorial=state.tutorial
  if state.disposed or app.stopped or app.openingRestoreOwner~=state or app.opening~=I or state.intro~=I
   or not I.signed or I.failed or app.mode~='hangar' or app.build or app.scene~=state.hall
   or not tutorial or tutorial.disposed or app.tutorial~=tutorial or tutorial.page~=state.tutorialPage
   or not I.page or I.page.portrait~=portrait then return false end
  return CommsCard.AdoptPortrait(portrait,context)
 end
 host.CancelPrefetch=function(I)
  if I and state.prefetchIntro~=I then return end
  local gate=state.prefetchGate
  state.prefetchGate=nil;state.prefetchIntro=nil;state.resources=nil
  if gate then gate:Cancel() end
 end
 host.Prefetch=function(I,done,fail)
  if state.disposed or app.stopped or state.prefetchIntro==I then return end
  host.CancelPrefetch()
  state.prefetchIntro=I;state.resources=M.Dependencies(app,I.data)
  local requested={DriveMaps.crater.scene}
  for _,path in ipairs(state.resources) do requested[#requested+1]=path end
  state.prefetchGate=ResourceGate.New()
  -- Download bytes only. Native decode/construction stays behind audioReady.
  state.prefetchGate:Start(requested,function(ok,message)
   if state.disposed or app.stopped or state.prefetchIntro~=I then return end
   if ok then done() else fail(message) end
  end)
 end
 host.Prepare=function(I,done,fail)
  local map=DriveMaps.crater
  local resources=state.prefetchIntro==I and state.resources or M.Dependencies(app,I.data)
  state.prepareFail=fail
  state.loader:Load(map.scene,function(scene)
   -- Same as a trial: replace the authored LUT tonemap with the platform's
   -- path before warmup. Phones have no crater post chain, and the raw .cube
   -- LUT sampled there returns stale VRAM (garbled promo frames).
   app.graphicsSettings:Apply(scene)
   state.scene=scene;state.warmup=IntroWarmup.New(state,host,done);state.warmup:Next()
  end,fail,{resources=resources,webWarmup=map.webWarmup,
   cleanup=DisposeWorld,
   prepare=function(scene,checkpoint)
    state.hallActor=VehicleView.New(app.scene,'OpeningHero')
    local hero=BP.New():Load(I.data.actors.hero)
    for i,p in ipairs(hero:List()) do state.hallActor:AddPart(p);checkpoint(.02*i/hero:Size(),'intro-hall-actor') end
    state.hallActor.joined:Update();state.hallActor.root.position=Vector3(0,0,0)
    state.assembly=IntroAssembly.New(state.hallActor,hero)
    state.garage=IntroGarage.New(app.scene,I.data,function(p,s)checkpoint(.02+p*.03,s)end)
    local world=CraterWorld.New(scene,true);state.world=world
    CraterPhysics.Build(world,function(p,s)checkpoint(p*.5,s)end)
    local source=IntroSortieCar.Select(app.blueprint:ToTable())
    local trial=DeferredModules['app.TrialSession'].New(scene,BP.New():Load(source),app,map,world,
     function(p,s)checkpoint(.5+p*.46,s)end,function(s)state.session=s end,
     function(session,_,progress)return IntroBattle.New(session,I.data,source,progress)end)
    local battle=trial.combat
    state.sortieUi=IntroSortieUi.New(trial)
    trial.view:ResetPose();trial.view:Update(1);trial:ResetCamera();trial:PostUpdate(1)
    IntroMontagePool.New(trial,battle,I.data.actors.hero,function(p)checkpoint(.96+p*.04,'intro-montage-view')end)
    app.graphicsSettings:RetainPost(scene,trial.camera:GetCamera())
   end})
 end
 host.UseScene=function(name)
  if state.activeScene==name and state.shownScene then return end
  state.activeScene=name
  local scene=name=='crater' and state.scene or state.hall
  local cam=name=='crater' and state.session.camera:GetCamera() or state.hallCamera
  app.graphicsSettings:Show(scene,cam)
  state.shownScene=scene
 end
 host.GetCamera=function()return state.activeScene=='crater' and state.session and state.session.camera:GetCamera() or state.hallCamera end
 host.GroundAt=function(x,z)return state.world and state.world:GroundAt(x,z) or 0 end
 host.StartSortie=function(I)
  state.session.combat:StartSortie()
  if state.sortieUi then state.sortieUi:BeginPlay(I.page) end
 end
 host.SortieInput=function(I,touch)
  local visual=state.sortieUi;if not visual or not state.session then return end
  if I.playing or I.shot=='sortie-brief' then visual:UsePointer(touch) elseif touch then visual.NoteTouch() end
 end
 host.CaptureSortie=function(I)
  if I.playing or I.shot=='sortie-brief' and I.age>=2.2 then return state.session.pointer:Capture() end
  return false
 end
 host.SortieStatus=function()
  local s=state.session;if not s or not s.combat then return nil end
  local c=s.combat;return {controlling=s.pointer.captured,pos=c.player:Position(),yaw=c.player.alive and c.player.vehicle:Yaw() or 0,
   enemyHit=not c.easy.alive or c.easy:Health()<.9,playerAlive=c.player.alive,target=(state.montageTarget or c.easy):Position(),missileLaunched=state.missileLaunched,missileLaunchAt=state.missileAt}
 end
 host.SortieStep=function(step,I)
  local s=state.session;s.combat.stage=step
  if step==3 then state.captureWanted='charge';I.capturePending=true
  elseif step==4 then
   state.lockAge=0;state.nextLockBeep=0;state.strikeAt=I.time;state.strikePending=true;state.strikeSound=false;I.audio:Sfx('blip',{vol=.5})
  elseif step==5 then
   local p=s.combat.player:Position();local camera=s.camera:GetCamera();state.wreckCamera={position=camera.node.position,point=Coord.Vec(p[1],p[2]+.8,p[3]),fov=camera.fov}
   if state.strike then I.audio:Sfx('laser_boom',{vol=1}) end;s.combat:Kill(s.combat.player)
  end
 end
 host.SortieHit=function()
  local s=state.session
  if s.combat.easy.alive then s.combat:Kill(s.combat.easy) end
  s.trauma=math.max(s.trauma or 0,.4)
 end
 host.CaptureWreck=function(I)state.captureWanted='wreck';I.capturePending=true end
 host.SortieDamageScale=function(scale)state.session.combat.damageScale=scale end
 host.EndSortie=function()
  if state.sortieUi then state.sortieUi:EndPlay() end
  if not state.sortieStarted or state.disposed or not state.session then return end
  state.sortieStarted=false
  state.strikePending=nil;state.strikeAt=nil
  if state.strike then state.strike:Dispose();state.strike=nil end
  local s=state.session;s:Pause();s.combat:EndSortie()
  local hero=s.combat.montage:Activate()
  hero.vehicle:Place({150,host.GroundAt(150,-214)+1.5,-214},0)
  s.yaw=0;s.pitch=0;s.scope=false;s.firing=false;s.aimPoint=nil;s.accumulator=0
  s.view:ResetPose();s.view:Update(1,0,s.fxContext);s:ResetCamera()
 end
 host.Shot=function(id,I)
  I.payslipShot=nil
  if id=='payslip' then
   local cart=state.session.combat.cart
   IntroShots.BeginPayslip(I,cart,function(origin,direction,length)
    return state.world.space:Raycast(origin,direction,length,cart and cart.vehicle and cart.vehicle.body)
   end)
  end
  if id=='sortie-brief' then I.sortieCountdownFrom=nil;state.sortieStarted=true;state.session.combat:BeginSortie()
  elseif id=='sortie-countdown' then
   local p=state.session.camera:GetCamera().node.position
   I.sortieCountdownFrom={-p.x,p.y,p.z}
  elseif id=='tvcut' then host.EndSortie() end
  app.graphicsSettings:SetSceneVisible(id~='familiar' and id~='galaxy')
  if state.garage then state.garage:Shot(id) end
  if id=='tvcut' or id=='comms' or id=='contract' or id=='gate' then
   state.hallActor:SetVisible(false);app.car:SetVisible(true)
  else state.hallActor:SetVisible(id=='m-build');app.car:SetVisible(false) end
  if id=='m-build' then
   state.assembly:Begin();state.buildParts=state.assembly.parts
   state.buildIndex=0;state.buildDrops=state.assembly.drops;state.nextClang=0
  end
  if id=='m-drive' or id=='m-missile' or id=='recruit' then
   local s=state.session;local u=s.combat.player
   if id=='m-drive' then u=s.combat.montage:Activate()
   elseif not u.alive then u:Spawn();s.combat:SyncPlayer() end
   s.combat.damageScale=0
   if id=='m-drive' then
    u.vehicle:Place({66,host.GroundAt(66,-174)+1.5,-174},0);s.view:ResetPose();s.combat.stage=0;s.combat.driversParked=true
    for i,e in ipairs(s.combat.entries) do if e.driver then
     if not e.unit.alive then e.unit:Spawn() end
     local x=-160-(i-2)*16;e.unit.vehicle:Place({x,host.GroundAt(x,-150)+1.5,-150},0)
    end end
    for _,cfg in ipairs({{2,64,-104,math.pi},{3,79,-109,math.pi+.4},{5,50,-111,math.pi-.5}}) do
     local actor=s.combat.entries[cfg[1]].unit;actor.vehicle:Place({cfg[2],host.GroundAt(cfg[2],cfg[3])+1.5,cfg[3]},cfg[4])
    end
    state.montageTarget=s.combat.entries[2].unit
    for index,group in ipairs(s.weapons.groups) do if group.kind=='missile' then s.weapons:Select(index);break end end
    for _,group in ipairs(s.weapons.groups) do for _,weapon in ipairs(group.weapons) do if weapon.stats.lockMin then
     local stats={};for key,value in pairs(weapon.stats) do stats[key]=value end;stats.lockMin=0;weapon.stats=stats
    end end end
   end
  end
  if id=='m-missile' then
   state.missileLaunched=false;state.missileAt=nil
   local target=state.montageTarget or state.session.combat.easy;if not target.alive then target:Spawn() end
  end
  if id=='recruit' then I.recruitAt=I.time end
  -- Comms is the irreversible return to the hall; no later shot uses crater.
  if id=='comms' then RetireCrater(true) end
 end
 host.Update=function(dt,I)
  state.loader:Update(dt)
  if state.warmup and not state.warmup.disposed then return end
  if I.failed or not I.ready then return end
  if not state.session then
   if state.hallActor and state.hallActor.root.enabled and state.activeScene=='garage' then state.hallActor:UpdateIdle(dt,I.time) end
   if state.garage then state.garage:Update(dt,I,state.hallCamera) end
   return
  end
  local s=state.session;local command={throttle=0,steer=0,handbrake=true}
  if I.playing then
   if input:GetKeyPress(KEY_ESCAPE) then s:Pause() end
   s.pointer:Poll(dt)
   if s.pointer.captured then
    command=s.controls:Read();local dx,dy=s.controls:TakeLook()
    local group=s.weapons:Group()
    local sensitivity=(s.scope and ReticleState.ScopeFov(48,group and group.kind)/48 or 1)*DriveAim.Look(s,dt)
    s.yaw,s.pitch=ChaseState.Look(s.yaw,s.pitch,dx,dy,sensitivity,s.vehicle.spec.wings~=nil and #s.vehicle.spec.wings>0)
    if s.combat.player.alive then s.controls:Command(command,s.vehicle,-math.rad(s.yaw),-math.rad(s.pitch)) end
    for index,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}) do
     if input:GetKeyPress(key) then s.weapons:Select(index);break end
    end
   end
  elseif I.shot=='m-drive' then
   local p=state.montageTarget:Position();command={throttle=1,steer=math.sin(I.age*2.6)*.5,aim={p[1],p[2]+1,p[3]}}
  elseif I.shot=='m-missile' then
   local p=(state.montageTarget or s.combat.easy):Position()
   command={throttle=0,steer=0,handbrake=true,firing=I.missileFiring~=false,aim={p[1],p[2]+1,p[3]}}
   if #s.weapons.projectiles>0 and not state.missileLaunched then state.missileLaunched=true;state.missileAt=I.age end
  end
  if state.activeScene=='crater' then s:Tick(math.min(dt,.05),command) end
  if I.playing and state.sortieUi then state.sortieUi:Update(dt,I) end
  if state.strikePending or state.strike then
   local age=I.time-state.strikeAt
   if state.strikePending then
    if not s.combat.player.alive then state.strikePending=nil
    elseif age>=1.8 then
     -- The source samples the moving player after the lock, at beam fire time.
     state.strikePending=nil;state.strike=IntroStrike.New(state.scene,s.combat.player:Position())
    elseif age>(state.nextLockBeep or 0) then local k=age/1.8;state.nextLockBeep=age+.36-k*.3;I.audio:Sfx('blip',{vol=.5,rate=1.4+k}) end
   end
   if state.strike then
    state.strike:Update(dt,age)
    if age>=1.8 and not state.strikeSound then state.strikeSound=true;I.audio:Sfx('laser_big',{vol=1}) end
    if age>=2.75 then state.strike:Dispose();state.strike=nil end
   end
  end
  if state.hallActor and state.hallActor.root.enabled and state.activeScene=='garage' then state.hallActor:UpdateIdle(dt,I.time) end
  if state.garage then state.garage:Update(dt,I,state.hallCamera) end
  if I.shot=='m-build' and state.buildParts then
   state.assembly:Update(I.age,I.time,I.data.durations.vo_n08 or 3);state.buildIndex=state.assembly.index
   if I.time>state.nextClang then state.nextClang=I.time+.2;I.audio:Sfx('clang',{vol=.35,rate=.9+math.random()*.3}) end
  end
 end
 host.CameraShot=function(id,age,I,camera)
  if not I.ready or not camera then return end
  if I.playing then
   if I.sortie and I.sortie.step==5 and state.wreckCamera then
    local pose=state.wreckCamera;local offset=pose.position-pose.point;offset.y=0;local outward=offset.normalized
    local k=math.min(1,I.sortie.elapsed/2.4);local amount=1-(1-k)^2
    camera.node.position=pose.position+outward*(amount*14)+Vector3(0,amount*9,0);camera.node:LookAt(pose.point);camera.fov=pose.fov
   else state.session:PostUpdate(1/60) end
   return
  end
  local at,look,fov=IntroShots.Camera(id,age,I)
  if at and state.activeScene=='crater' and (id=='m-drive' or id=='m-salvage' or id=='recruit' or id=='peacekeeper' or id=='master' or id=='mechanic' or id=='motto' or id=='disclaimer') then
   local p=state.session.combat.player:Position();local target={p[1],p[2]+1.5,p[3]}
   at,state.cameraLift=IntroShots.SafeCamera(at,target,function(origin,direction,length)
    return state.world.space:Raycast(origin,direction,length,state.session.combat.cart and state.session.combat.cart.vehicle and state.session.combat.cart.vehicle.body)
   end,state.cameraLift)
  end
  if at then camera.node.position=Coord.Vec(table.unpack(at));camera.node:LookAt(Coord.Vec(table.unpack(look)));camera.fov=fov end
  if state.activeScene=='crater' and state.session.environment then state.session.environment:Update(1/60,camera.node) end
 end
 host.FramePresented=function(I)
  if state.disposed then return end
  state.loader:FramePresented()
  if state.warmup and not state.warmup.disposed then
   local ok,err=pcall(state.warmup.Presented,state.warmup)
   if not ok then state.warmup:Dispose();state.prepareFail(tostring(err)) end
   return
  end
  if state.captureWanted then
   if state.activeScene~='crater' or I.failed or I.finishing then CancelCapture(I);return end
   -- 在最终 3D viewport 上取 GPU 快照，保留后效；不将失败的屏幕读回上传成 0×0 纹理。
   local viewport=WindowViewports.Get(0)
   if state.pendingCapture and state.captureViewport~=viewport then
    state.pendingCapture:Dispose();state.pendingCapture=nil;state.captureViewport=nil
   end
   if graphics:GetWidth()<=0 or graphics:GetHeight()<=0 then return end
   if not state.pendingCapture then
    local ok,capture=pcall(ViewportCapture.New,viewport)
    if not ok then
     print('[IntroCapture] 无法创建 '..state.captureWanted..': '..tostring(capture));CancelCapture(I);return
    end
    state.pendingCapture=capture;state.captureViewport=viewport;return
   end
   local capture=state.pendingCapture
   if not capture:Presented() then return end
   local name=state.captureWanted;local texture=capture.texture
   if texture and texture:GetWidth()>0 and texture:GetHeight()>0 then
    ClearCaptureImage(name)
    local previous=state.sortieCaptures[name];if previous then previous:Dispose() end
    state.sortieCaptures[name]=capture;state.captures[name]=texture
    state.pendingCapture=nil;state.captureViewport=nil;state.captureWanted=nil;I.capturePending=false
    print('[IntroCapture] '..name..' '..texture:GetWidth()..'x'..texture:GetHeight()..' GPU')
   else print('[IntroCapture] 忽略无效快照 '..name);CancelCapture(I) end
  end
 end
 host.BeginLeaveCapture=function()
  if state.leaveCapture then state.leaveCapture:Dispose() end
  state.captures.leave=nil
  state.leaveCapture=IntroSceneCapture.New(state.hall,state.hallCamera)
 end
 host.PresentLeaveCapture=function()
  local capture=state.leaveCapture
  if not capture or not capture:Presented() then return false end
  state.captures.leave=capture.texture
  return true
 end
 host.CancelLeaveCapture=function()
  if state.leaveCapture and not state.leaveCapture.ready then state.leaveCapture:Dispose();state.leaveCapture=nil end
 end
 host.DrawCapture=function(vg,name,r)
  local texture=state.captures[name];if not texture or texture:GetWidth()<=0 or texture:GetHeight()<=0 or r.w<=0 or r.h<=0 then return false end
  state.captureImages=state.captureImages or {};state.captureImages[vg]=state.captureImages[vg] or {}
  local images=state.captureImages[vg]
  if images[name]==nil then images[name]=nvgCreateVideo(vg,texture) end
  local image=images[name];if not image or image<=0 then return false end
  if r.points then SourceDraw.Path(vg,r.points) else nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h) end
  local scale=math.max(r.w/texture:GetWidth(),r.h/texture:GetHeight());local width,height=texture:GetWidth()*scale,texture:GetHeight()*scale
  nvgFillPaint(vg,nvgImagePattern(vg,r.x+(r.w-width)/2,r.y+(r.h-height)/2,width,height,0,image,1));nvgFill(vg)
  return true
 end
 host.SaveProfile=function(name,signedAt)
  local data={name=name,signedAt=signedAt};local ok,err=app.store:Write('intro-profile',data,ValidProfile)
  if ok then app.profile=data end;return ok,err
 end
 local function RestoreHall()
  if state.hallRestored or app.stopped or app.openingRestoreOwner~=state or app.scene~=state.hall or not state.oldPose then return end
  app.car:SetVisible(state.oldCarVisible);app.camera.node.position=state.oldPose.position;app.camera.node.rotation=state.oldPose.rotation;app.camera.camera.fov=state.oldPose.fov
  app.graphicsSettings:Show(state.hall,state.hallCamera);state.hallRestored=true
 end
 host.BeginFinish=function(I)
  if state.disposed or state.finishBegan or app.stopped or app.openingRestoreOwner~=state or app.opening~=I then return end
  state.finishBegan=true
  if state.session then state.session:Pause();state.finishPaused=true end
  if state.scene then state.scene.updateEnabled=false end
  if state.hallActor then state.hallActor:SetVisible(false) end
  if state.garage then state.garage.root:SetEnabledRecursive(false) end
  RestoreHall()
 end
 host.Finish=function(I)
  if app.stopped or app.openingRestoreOwner~=state or app.opening~=I or app.mode=='trial' or app.scene~=state.hall then return end
  app.opening=nil;app.mode='hangar';DeferredModules['ui.GarageHud'].Create(app);DeferredModules['ui.GarageHud'].Refresh(app.blueprint,Config.TIERS[app.tier]);app:HomeView('hangar')
  if app.tutorial then
   state.pendingTutorial={tutorial=app.tutorial,start=not I.failed}
   if not state.assetReleasePending then ResumeTutorial() end
  end
 end
 host.Dispose=function(I)
  if state.disposed then return end;state.disposed=true
  CancelCapture(I)
  if I then I.payslipShot=nil end
  host.CancelPrefetch()
  if state.warmup then state.warmup:Dispose() end
  state.warmup=nil;state.intro=nil;state.tutorial=nil;state.tutorialPage=nil;state.prepareFail=nil
  if state.sortieUi then state.sortieUi:Dispose();state.sortieUi=nil end
  state.loader:Cancel()
  -- These roots belong to the borrowed hall, which may be replaced before a
  -- queued crater retirement finishes. End their lifetime before returning it.
  if state.hallActor then state.hallActor:SetVisible(false) end
  if state.garage then state.garage.root:SetEnabledRecursive(false) end
  if state.assembly then state.assembly:Dispose() end
  if state.hallActor then state.hallActor:Dispose();state.hallActor=nil end
  if state.garage then state.garage:Dispose();state.garage=nil end
  state.assembly=nil;state.buildParts=nil;state.buildDrops=nil
  if state.scene then state.scene.updateEnabled=false;app.graphicsSettings:ReleasePost(state.scene) end
  for vg,images in pairs(state.captureImages or {}) do for _,image in pairs(images) do if image>0 then nvgDeleteVideo(vg,image) end end end
  for _,capture in pairs(state.sortieCaptures) do capture:Dispose() end
  if state.leaveCapture then state.leaveCapture:Dispose();state.leaveCapture=nil end
  state.captures={};state.sortieCaptures={};state.captureImages=nil
  state.shownScene=nil;state.montageTarget=nil;state.wreckCamera=nil
  RestoreHall()
  state.oldPose=nil;state.app=nil
  RetireCrater(I and I.completed and not I.failed)
 end
 return host
end
return M
