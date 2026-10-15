local originalStore=nil
local I=nil
local started=false;local contractAt=nil;local gateAt=nil;local returned=false
local sequence={};local originalStart=nil;local originalRegister=nil;local readyObserved=false;local disposalObserved=false
local UI=require 'urhox-libs/UI'
local function QueueContract()
 local queue={};local events={};local defer=require('app.HangarApp').DeferAssetRelease
 defer(queue,function()events[#events+1]='first'end)
 defer(queue,function()events[#events+1]='second'end)
 V.assert(#events==0 and queue.assetReleaseFrames==3,'actual asset release method preserves deferred three-frame gate')
 for frame=1,3 do
  queue.assetReleaseFrames=queue.assetReleaseFrames-1
  if frame<3 then V.assert(#events==0,'queued asset release remains deferred at frame '..frame)
  else local release=queue.pendingAssetRelease;queue.pendingAssetRelease=nil;release() end
 end
 V.assert(#events==2 and events[1]=='first' and events[2]=='second','actual asset release method preserves both callbacks once in registration order')
 V.assert(queue.pendingAssetRelease==nil,'drained callback queue retains no old callback')
end
local function LateTutorialContract(reason)
 local scene={};local events={};local app={scene=scene,mode='hangar'}
 function app:DeferAssetRelease(release) self.release=release end
 local host=require('app.OpeningHost').New(app);local state=host.state;app.openingRestoreOwner=state;state.hall=scene
 state.session={ReleaseAssets=function()events[#events+1]='release'end,Dispose=function()events[#events+1]='dispose'end}
 local tutorial={page={},Start=function()events[#events+1]='start'end};app.tutorial=tutorial
 host.Dispose();host.Dispose();state.pendingTutorial={tutorial=tutorial,start=true}
 if reason=='stopped' then app.stopped=true
 elseif reason=='reopened' then app.openingRestoreOwner={}
 elseif reason=='trial' then app.mode='trial'
 elseif reason=='build' then app.build={}
 elseif reason=='scene' then app.scene={}
 elseif reason=='tutorial' then app.tutorial={} end
 app.release()
 V.assert(#events==2 and events[1]=='dispose' and events[2]=='release','disposed opening releases once and cannot start a late tutorial after '..reason)
 V.assert(not state.assetReleasePending and not state.pendingTutorial,'late '..reason..' callback clears its pending gate')
end
local function PartialPreparationContract()
 local crater=require 'scene.Crater';local original=crater.Release;local calls=0
 crater.Release=function()calls=calls+1 end
 local app={stopped=true};function app:DeferAssetRelease(release)self.release=release end
 local host=require('app.OpeningHost').New(app);host.Dispose();host.Dispose();crater.Release=original
 V.assert(calls==0 and host.state.assetReleasePending,'partial opening preparation captures fallback release without executing early')
 app.release();V.assert(calls==1 and not host.state.assetReleasePending,'partial opening preparation sweeps fallback resources exactly once')
end
local function Shot(path)
 local image=Image:new();V.assert(graphics:TakeScreenShot(image),'opening native screenshot available')
 V.assert(image:SavePNG(path),'opening screenshot saved');image:Dispose()
end
local function Poll()
 local app=VOX_HANGAR and VOX_HANGAR.app
 if not app or app.loadingFlow.active then return end
 if not started then
  QueueContract()
  PartialPreparationContract()
  for _,reason in ipairs({'stopped','reopened','trial','build','scene','tutorial'}) do LateTutorialContract(reason) end
  started=true;originalStore=app.store;app.store=require('storage.BlueprintStore').New('vox-intro-host-validation')
  originalStart=app.tutorial.Start;app.tutorial.Start=function(self,...)sequence[#sequence+1]='start';return originalStart(self,...)end
  originalRegister=UI.RegisterGlobalComponent;UI.RegisterGlobalComponent=function(id,page,...)
   if id=='vox-tutorial' then sequence[#sequence+1]='register' end
   return originalRegister(id,page,...)
  end
  V.assert(app:StartOpening('contract'),'real opening app entry starts')
  I=app.opening
  -- Hidden validation has no OS focus. Natural Web tests retain actual focus
  -- and pointer semantics; this fixture supplies focus to exercise the host.
  local update=I.Update;I.Update=function(self,dt)return update(self,dt,true)end
  return
 end
 if I.failed then V.assert(false,'real opening failed: '..tostring(I.error));I:Finish();app.store=originalStore;V.finish();return end
 if I.ready and not readyObserved then
  readyObserved=true
  local state=I.host.state
  local release=state.session.ReleaseAssets
  state.session.ReleaseAssets=function()
   sequence[#sequence+1]='release'
   V.assert(not state.scene and not state.session and not state.world and not state.warmup and not state.intro,'actual opening releases resources after native world and warmup owners are cleared')
   V.assert(not state.captureImages and next(state.captures)==nil and not state.shownScene,'actual opening releases resources after comic/render owners are cleared')
   return release()
  end
  V.assert(state.scene and state.session and state.session.world.space,'real crater scene and native world prepared')
  V.assert(#state.session.combat.entries==9,'actual player 7 original enemies and company cart instantiated')
  V.assert(state.session.combat.player.alive,'player has actual damageable CarUnit')
  V.assert(not state.session.practice and state.session.world.feedbackPlayer==state.session.combat.player,'opening controller and damage attribution do not retain a disposed practice player')
  V.assert(state.hall==app.scene and app.scene:GetChild('OpeningHero'),'borrowed hall and original hero actor retained')
  I:Advance()
 end
 if I.shot=='contract' and not contractAt then contractAt=I.time end
 if contractAt and I.shot=='contract' and I.time-contractAt>.25 and not I.signed then
  V.assert(I.page.signatureRect and I.page.termRect and I.page.nameField:IsVisible(),'native text field signature and terms rendered')
  V.assert(I.page.portrait and I.page.portrait.ready,'GPU source portrait prepared')
  Shot('docs/migration/evidence/intro-contract-native.png')
  I.ink=35;V.assert(I:Submit('验收机修师'),'real validated profile storage accepts signature')
  local profile=app.store:Read('intro-profile',require('app.OpeningHost').ValidProfile)
  V.assert(profile and profile.name=='验收机修师','intro profile written and read through validator')
 end
 if I.shot=='gate' and not gateAt then gateAt=I.time end
 if gateAt and I.shot=='gate' and I.time-gateAt>1.5 and not I.gateShot then I.gateShot=true;Shot('docs/migration/evidence/intro-gate-native.png') end
 if not I.active and not disposalObserved then
  disposalObserved=true;local state=I.host.state
  V.assert(state.assetReleasePending and state.pendingTutorial and #sequence==0,'finished opening waits for actual deferred release before registering or starting tutorial')
  I.host.Dispose();V.assert(state.assetReleasePending and #sequence==0,'repeated actual host disposal neither releases early nor requeues')
  V.assert(app.scene==state.hall and app.car.root.enabled,'finish restores borrowed hall and original vehicle')
  V.assert(app.opening==nil and require('ui.GarageHud').GetState()~=nil,'finish restores actual interactive homepage')
 end
 if disposalObserved and not I.host.state.assetReleasePending and not returned then
  returned=true
  V.assert(#sequence==3 and sequence[1]=='release' and sequence[2]=='register' and sequence[3]=='start','actual deferred asset release precedes tutorial global registration and Start exactly once')
  V.assert(app.tutorial.rules.running,'opening finish starts original tutorial')
  app.tutorial.Start=originalStart;UI.RegisterGlobalComponent=originalRegister
  app.tutorial:Skip();app.store=originalStore
  for _,suffix in ipairs({'-a.json','-b.json'}) do local path='vox-intro-host-validation-intro-profile'..suffix;if fileSystem:FileExists(path) then fileSystem:Delete(path) end end
  V.finish()
 end
end
for frame=1,2450 do V.atFrame(frame,Poll) end
V.atFrame(2455,function()V.assert(returned,'real opening reaches hall without stalls');V.finish()end)
