-- Opening owns its crater; the authored garage is borrowed and restored.
local BP=require 'construction.Blueprint'
local Coord=require 'core.Coord'
local M={}
local function ValidProfile(p) return type(p)=='table' and type(p.name)=='string' and (utf8.len(p.name) or 99)<=10 and p.name~='' and type(p.signedAt)=='number' end
M.ValidProfile=ValidProfile
function M.Dependencies(app,data)
 local resources={};local map=require('app.DriveMaps').crater
 for _,path in ipairs(require('core.ResourceData').Read(map.resources)) do resources[#resources+1]=path end
 local parts={}
 local sources={app.blueprint:ToTable(),data.actors.hero,data.actors.cart}
 for _,actor in ipairs(data.actors.invaders) do sources[#sources+1]=actor.blueprint end
 for _,source in ipairs(data.actors.hovers or {}) do sources[#sources+1]=source end
 for _,source in ipairs(sources) do for _,p in ipairs(BP.New():Load(source):List()) do parts[#parts+1]=p end end
 for _,path in ipairs(require('parts.Dependencies').For(parts)) do resources[#resources+1]=path end
 for _,path in ipairs(require('ui.WeaponIconResources').For(parts)) do resources[#resources+1]=path end
 resources[#resources+1]='Shaders/BLGL/UI/CommsPortrait.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/Dove.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/SkyBeam.shader'
 resources[#resources+1]='Intro/Shaders/BLGL/AssemblyFlash.shader'
 resources[#resources+1]='Shaders/BLGL/RestoreFlash.shader'
 resources[#resources+1]=data.images.dove
 return resources
end
function M.New(app)
 local state={app=app,loader=require('app.SceneLoader').New(),activeScene='garage',captures={}}
 local host={state=state}
 local function ResumeTutorial()
  local pending=state.pendingTutorial;state.pendingTutorial=nil
  if not pending or app.stopped or app.openingRestoreOwner~=state or app.opening or app.mode~='hangar' or app.build or app.scene~=state.hall or app.tutorial~=pending.tutorial then return end
  require('urhox-libs/UI').RegisterGlobalComponent('vox-tutorial',pending.tutorial.page)
  if pending.start then pending.tutorial:Start() end
 end
 local function DisposeWorld()
  if state.scene then app.graphicsSettings:ReleasePost(state.scene) end
  if state.session then state.session:Dispose();state.session=nil;state.world=nil
  elseif state.world then state.world:Dispose();state.world=nil end
 end
 host.Begin=function(I)
  app.openingRestoreOwner=state
  state.intro=I;state.hall=app.scene;state.hallCamera=app.camera.camera;state.oldPose={position=app.camera.node.position,rotation=app.camera.node.rotation,fov=app.camera.camera.fov}
  state.oldCarVisible=app.car.root.enabled;app.car:SetVisible(false)
  require('ui.GarageHud').Dispose()
  if app.tutorial then
   app.tutorial.visible=false;app.tutorial.page:CancelInput();app.tutorial:DetachVoice()
   require('urhox-libs/UI').UnregisterGlobalComponent('vox-tutorial')
  end
 end
 host.Prepare=function(I,done,fail)
  local map=require('app.DriveMaps').crater;local resources=M.Dependencies(app,I.data)
  state.prepareFail=fail
  state.loader:Load(map.scene,function(scene)
   state.scene=scene;state.warmup=require('intro.IntroWarmup').New(state,host,done);state.warmup:Next()
  end,fail,{resources=resources,webWarmup=map.webWarmup,
   cleanup=DisposeWorld,
   prepare=function(scene,checkpoint)
    state.hallActor=require('render.VehicleView').New(app.scene,'OpeningHero')
    local hero=BP.New():Load(I.data.actors.hero)
    for i,p in ipairs(hero:List()) do state.hallActor:AddPart(p);checkpoint(.02*i/hero:Size(),'intro-hall-actor') end
    state.hallActor.joined:Update();state.hallActor.root.position=Vector3(0,0,0)
    state.assembly=require('intro.IntroAssembly').New(state.hallActor,hero)
    state.garage=require('intro.IntroGarage').New(app.scene,I.data,function(p,s)checkpoint(.02+p*.03,s)end)
    local world=require('drive.CraterWorld').New(scene,true);state.world=world
    require('drive.CraterPhysics').Build(world,function(p,s)checkpoint(p*.5,s)end)
    local source=app.blueprint:ToTable();local spec=require('drive.VehicleSpec').Build(BP.New():Load(source))
    if not spec.ok or #spec.weapons==0 then source=require('construction.Prefab').BuildRaceCar(BP.New()):ToTable() end
    local setUnits=world.SetUnits;world.SetUnits=function()end
    local trial=require('app.TrialSession').New(scene,BP.New():Load(source),app,map,world,function(p,s)checkpoint(.5+p*.3,s)end,function(s)state.session=s end)
    world.SetUnits=setUnits
    trial.vehicle:Dispose();trial.vehicle=nil;trial.view:Dispose();trial.view=nil
    local battle=require('intro.IntroBattle').New(trial,I.data,source,function(p,s)checkpoint(.8+p*.1,s)end)
    trial.combat=battle;trial.vehicle=battle.player.vehicle;trial.weapons=battle.player.weapons
    state.sortieUi=require('ui.IntroSortieUi').New(trial)
    trial.view=require('render.DriveView').New(scene,battle.player.bp,trial.vehicle,function(p)checkpoint(.9+p*.03,'intro-player-view')end,function(view)trial.view=view end);trial.view:ResetPose();trial.view:Update(1)
    trial.combatView:Consume(world,function(p)checkpoint(.93+p*.03,'intro-enemy-views')end);trial:ResetCamera();trial:PostUpdate(1)
    require('intro.IntroMontagePool').New(trial,battle,I.data.actors.hero,function(p)checkpoint(.96+p*.04,'intro-montage-view')end)
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
 host.StartSortie=function()state.session.combat.stage=1 end
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
  if step==3 then s.combat:Kill(s.combat.easy);state.captureWanted='charge';I.capturePending=true
  elseif step==4 then
   state.lockAge=0;state.nextLockBeep=0;state.strikeAt=I.time;state.strike=require('intro.IntroStrike').New(state.scene,s.combat.player:Position());I.audio:Sfx('blip',{vol=.5})
  elseif step==5 then
   local p=s.combat.player:Position();local camera=s.camera:GetCamera();state.wreckCamera={position=camera.node.position,point=Coord.Vec(p[1],p[2]+.8,p[3]),fov=camera.fov}
   if state.strike then I.audio:Sfx('laser_boom',{vol=1}) end;s.combat:Kill(s.combat.player)
  end
 end
 host.CaptureWreck=function(I)state.captureWanted='wreck';I.capturePending=true end
 host.SortieDamageScale=function(scale)state.session.combat.damageScale=scale end
 host.EndSortie=function()if state.session then state.session:Pause() end end
 host.Shot=function(id,I)
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
    u.vehicle:Place({66,host.GroundAt(66,-174)+1.5,-174},0);s.view:ResetPose();s.combat.stage=0
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
 end
 host.Update=function(dt,I)
  state.loader:Update(dt)
  if state.warmup and not state.warmup.disposed then return end
  if not state.session or I.failed or not I.ready then return end
  local s=state.session;local command={throttle=0,steer=0,handbrake=true}
  if I.playing then
   if input:GetKeyPress(KEY_ESCAPE) then s:Pause() end
   s.pointer:Poll(dt)
   if s.pointer.captured then
    command=s.controls:Read();local dx,dy=s.controls:TakeLook()
    s.yaw,s.pitch=require('controls.ChaseState').Look(s.yaw,s.pitch,dx,dy,1,false)
   end
  elseif I.shot=='m-drive' then command={throttle=1,steer=math.sin(I.age*2.6)*.5,aim=state.montageTarget:Position()}
  elseif I.shot=='m-missile' then
   command={throttle=0,steer=0,handbrake=true,firing=true,aim=(state.montageTarget or s.combat.easy):Position()}
   if #s.weapons.projectiles>0 and not state.missileLaunched then state.missileLaunched=true;state.missileAt=I.age end
  end
  if state.activeScene=='crater' then s:Tick(math.min(dt,.05),command) end
  if I.playing and state.sortieUi then state.sortieUi:Update(dt) end
  if state.strike then
   local age=I.time-state.strikeAt;state.strike:Update(dt,age)
   if age<1.8 and age>(state.nextLockBeep or 0) then local k=age/1.8;state.nextLockBeep=age+.36-k*.3;I.audio:Sfx('blip',{vol=.5,rate=1.4+k}) end
   if age>=1.8 and not state.strikeSound then state.strikeSound=true;I.audio:Sfx('laser_big',{vol=1}) end
   if age>=2.75 then state.strike:Dispose();state.strike=nil end
  end
  if state.hallActor and state.activeScene=='garage' then state.hallActor:UpdateIdle(dt,I.time) end
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
  local at,look,fov=require('intro.IntroShots').Camera(id,age,I)
  if at and state.activeScene=='crater' and (id=='m-drive' or id=='m-salvage' or id=='recruit' or id=='peacekeeper' or id=='master' or id=='mechanic' or id=='motto') then
   local p=state.session.combat.player:Position();local target={p[1],p[2]+1.5,p[3]}
   at,state.cameraLift=require('intro.IntroShots').SafeCamera(at,target,function(origin,direction,length)
    return state.world.space:Raycast(origin,direction,length,state.session.combat.cart and state.session.combat.cart.vehicle and state.session.combat.cart.vehicle.body)
   end,state.cameraLift)
  end
  if at then camera.node.position=Coord.Vec(table.unpack(at));camera.node:LookAt(Coord.Vec(table.unpack(look)));camera.fov=fov end
  if state.activeScene=='crater' and state.session.environment then state.session.environment:Update(1/60,camera.node) end
 end
 host.FramePresented=function(I)
  state.loader:FramePresented()
  if state.warmup and not state.warmup.disposed then
   local ok,err=pcall(state.warmup.Presented,state.warmup)
   if not ok then state.warmup:Dispose();state.prepareFail(tostring(err)) end
   return
  end
  if state.captureWanted and state.activeScene=='crater' then
   -- Screenshot reads the presented backbuffer; allow the UI-free frame to
   -- pass through the renderer before copying it into the comic texture.
   state.captureFrames=(state.captureFrames or 0)+1;if state.captureFrames<3 then return end
   local image=Image:new();graphics:TakeScreenShot(image);local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetData(image);image:Dispose()
   state.captures[state.captureWanted]=texture;state.captureWanted=nil;state.captureFrames=0;I.capturePending=false
  end
 end
 host.DrawCapture=function(vg,name,r)
  local texture=state.captures[name];if not texture then return false end
  state.captureImages=state.captureImages or {};state.captureImages[vg]=state.captureImages[vg] or {}
  local images=state.captureImages[vg];images[name]=images[name] or nvgCreateVideo(vg,texture)
  if r.points then require('ui.SourceDraw').Path(vg,r.points) else nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h) end
  local scale=math.max(r.w/texture:GetWidth(),r.h/texture:GetHeight());local width,height=texture:GetWidth()*scale,texture:GetHeight()*scale
  nvgFillPaint(vg,nvgImagePattern(vg,r.x+(r.w-width)/2,r.y+(r.h-height)/2,width,height,0,images[name],1));nvgFill(vg)
  return true
 end
 host.SaveProfile=function(name,signedAt)
  local data={name=name,signedAt=signedAt};local ok,err=app.store:Write('intro-profile',data,ValidProfile)
  if ok then app.profile=data end;return ok,err
 end
 host.Finish=function(I)
  if app.stopped or app.openingRestoreOwner~=state or app.opening~=I or app.mode=='trial' or app.scene~=state.hall then return end
  app.opening=nil;app.mode='hangar';require('ui.GarageHud').Create(app);require('ui.GarageHud').Refresh(app.blueprint,require('Config').TIERS[app.tier]);app:HomeView('hangar')
  if app.tutorial then
   state.pendingTutorial={tutorial=app.tutorial,start=not I.failed}
   if not state.assetReleasePending then ResumeTutorial() end
  end
 end
 host.Dispose=function()
  if state.disposed then return end;state.disposed=true
  local release=state.session and state.session.ReleaseAssets or require('scene.Crater').Release
  if state.warmup then state.warmup:Dispose() end
  state.warmup=nil;state.intro=nil;state.prepareFail=nil
  if state.sortieUi then state.sortieUi:Dispose();state.sortieUi=nil end
  state.loader:Cancel()
  DisposeWorld()
  if state.strike then state.strike:Dispose();state.strike=nil end
  if state.scene then state.scene:Dispose();state.scene=nil end
  if state.assembly then state.assembly:Dispose() end
  if state.hallActor then state.hallActor:Dispose();state.hallActor=nil end
  state.assembly=nil;state.buildParts=nil;state.buildDrops=nil
  if state.garage then state.garage:Dispose();state.garage=nil end
  for vg,images in pairs(state.captureImages or {}) do for _,image in pairs(images) do nvgDeleteVideo(vg,image) end end
  for _,texture in pairs(state.captures) do texture:Dispose() end;state.captures={};state.captureImages=nil
  state.captureWanted=nil;state.captureFrames=nil;state.shownScene=nil;state.montageTarget=nil;state.wreckCamera=nil
  if not app.stopped and app.openingRestoreOwner==state and app.scene==state.hall and state.oldPose then
   app.car:SetVisible(state.oldCarVisible);app.camera.node.position=state.oldPose.position;app.camera.node.rotation=state.oldPose.rotation;app.camera.camera.fov=state.oldPose.fov
   app.graphicsSettings:Show(state.hall,state.hallCamera)
  end
  state.oldPose=nil;state.app=nil;state.assetReleasePending=true
  -- Native views and captures must retire before sweeping the cache; only
  -- afterwards may the tutorial request its own portraits and voice resources.
  app:DeferAssetRelease(function()
   release();state.assetReleasePending=false;ResumeTutorial()
  end)
 end
 return host
end
return M
