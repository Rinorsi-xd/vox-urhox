package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local Transition=require 'app.WebMapTransition'
local released,swept=0,0
local t=Transition.New(function() released=released+1 end,function() swept=swept+1 end)
local a=t:Begin(true)
Check(not t:CanStart(false,1,true) and released==0,'Unpresented cover preserves old hall')
Check(not t:CanStart(true,2,true) and released==1,'Presented cover releases hall exactly once')
for _=1,5 do Check(not t:CanStart(true,2,true),'Repeated updates do not substitute for presented frames') end
Check(not t:CanStart(true,4,true) and swept==0,'Two retirement frames cannot begin map decoding')
Check(not t:CanStart(true,5,false) and swept==0,'Background resource work blocks sweep')
Check(t:CanStart(true,5,true) and swept==1 and released==1,'Three presented frames then settled sweep allow map')
Check(t:CanStart(true,6,true) and swept==1,'Ready state does not repeat disposal or sweep')
Check(t:Commit(a) and not t:IsCurrent(a),'Success commits and clears transition ownership')
Check(not t:Cancel(a) and not t:BeginRecovery(),'Late cancel cannot recover committed world')
local b=t:Begin(true)
Check(not t:Cancel(b) and not t:IsRestoring(),'Cancel before cover keeps hall without recovery')
local c=t:Begin(true);t:CanStart(true,2,true)
Check(t:Cancel(c) and t:IsRestoring(),'Cancel after release requests hall recovery')
Check(not t:CanStart(true,8,true),'Canceled map cannot load while recovery is queued')
Check(t:BeginRecovery() and not t:BeginRecovery(),'Recovery starts once outside loader cancel callback')
t:PrepareRecovery()
Check(not t:CanStart(true,2,true),'Recovery opens its own cover fence')
Check(t:CanStart(true,5,true),'Recovery also settles candidate cleanup before hall load')
t:PrepareRecovery()
Check(not t:CanStart(true,2,true),'Failed recovery retry resets presented frame fence')
Check(t:CanStart(true,5,true),'Retry can release prior failed candidate resources')
t:Restored();Check(not t:IsRestoring(),'Installed hall clears recovery')
local d=t:Begin(false)
Check(t:CanStart(true,2,false) and released==2,'Native and small-map path keeps existing hall ownership')
Check(not t:Cancel(c) and t:IsCurrent(d),'Old cancellation cannot cancel newer transition')
t:Stop();Check(not t:CanStart(true,99,true) and not t:Cancel(d) and not t:BeginRecovery(),'Stop suppresses late callbacks and recovery')
local partial=Transition.New(function() error('partial disposal') end,function() end)
local p=partial:Begin(true);local ready,message=partial:CanStart(true,2,true)
Check(not ready and message:find('partial disposal') and partial:Cancel(p) and partial:IsRestoring(),'Partial release failure restores rather than reusing old nodes')

local settled=false
local retry=Transition.New(function() end,function() return settled end)
retry:Begin(true);retry:CanStart(true,2,true)
Check(not retry:CanStart(true,5,true) and retry.current.state=='retiring','Unfinished collection retains transition retirement ownership')
settled=true
Check(retry:CanStart(true,6,true) and retry.current.state=='ready','Only a completed retry opens the map preparation gate')

local now=0
Time={GetSystemTime=function() return now end}
local background=0
local calls={}
local function Record(name) calls[#calls+1]=name end
cache={GetNumBackgroundLoadResources=function() return background end,ReleaseAllResources=function(_,force) Check(force==false,'Resource cache sweep is non-forced');Record('cache') end}
environmentBakeCache={ClearCache=function() Record('environment') end}
package.loaded['urhox-libs/UI']={Panel=function(props)return {props=props}end,
    SetRoot=function(root)Check(root.props.pointerEvents=='none','Loading placeholder does not intercept input');Record('loading-root')end}
package.loaded['Config']={TIERS={{}}}
local blueprint={List=function() return {} end}
package.loaded['construction.Blueprint']={New=function() return blueprint end}
package.loaded['construction.Prefab']={BuildRaceCar=function(bp) return bp end}
package.loaded['render.VehicleView']={}
package.loaded['scene.Hangar']={}
package.loaded['controls.OrbitCamera']={}
package.loaded['app.HotReload']={}
package.loaded['render.Quality']={}
local web=true
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return web end}
package.loaded['app.ResourceGate']={New=function() return {Cancel=function() Record('gate-cancel') end,Start=function(_,_,done) done(true) end} end}
package.loaded['render.RenderTargetLifetime']={Flush=function() Record('render-retire') end,Update=function() end}
package.loaded['render.WindowViewports']={Set=function(_,value) Check(value==nil,'Old viewport detached');Record('viewport') end}
local home=false
local Hud={GetState=function() return home end,Dispose=function() Record('hud');home=false end,SetMode=function(text) Record('message:'..text) end}
package.loaded['ui.GarageHud']=Hud
package.loaded['ui.LiveryPage']={Leave=function() Record('livery') end}
local App=require 'app.HangarApp'
local Loader=require 'app.SceneLoader'
local function Owned(name)
    return {name=name,Dispose=function(self) if not self.disposed then self.disposed=true;self.disposeCount=(self.disposeCount or 0)+1;Record(name) end end,
        StopAsyncLoading=function() Record('stop-async') end,GetComponents=function() return {} end}
end
local function MakeApp()
    local app=setmetatable({ownsScene=true,mode='hangar',scene=Owned('old-scene'),hangar=Owned('old-hangar'),car=Owned('old-car'),
        camera={},previews=Owned('previews'),blueprint=blueprint,vehicleGate={Cancel=function() end},
        ambience={Update=function() end,Dispose=function() end},
        toasts={Push=function(_,message) Record('toast:'..message) end},stopped=false},App)
    app.graphicsSettings={SetSceneVisible=function(self) self.suspendedViewport={old=true} end,
        ParkPost=function() Record('post') end,ReleasePost=function() Record('retained-post') end,
        Apply=function() Record('apply') end,tonemap=Owned('tonemap')}
    app.loadingFlow={active=false,pageFrames=2,Open=function(self) self.active=true;Record('flow-open') end,
        Finish=function(self) if self.finishError then error('finish error') end;self.finished=true end,
        Fail=function(self,message) self.failed=message end}
    app.loader=Loader.New()
    app.mapTransition=Transition.New(function() app:ReleaseMapHangar() end,function() return app:ReleaseSettledAssets() end)
    return app
end
local app=MakeApp()
local original=app.scene
app.gallery=Owned('gallery');app.vehicleSwitch=Owned('switch');app.warehouse=Owned('warehouse')
app.build=Owned('build');app.tutorial={DetachVoice=function() Record('voice') end};home={livery={}}
app:DeferAssetRelease(function() Record('previous-map-release') end)
app:ReleaseMapHangar()
Check(original.disposed and app.scene==nil and app.hangar==nil and app.car==nil and app.camera==nil,'Actual hall teardown clears scene and visual ownership')
Check(app.graphicsSettings.suspendedViewport==nil and app.graphicsSettings.tonemap==nil,'No suspended viewport or tonemap retains old scene')
Check(app.build==nil and app.gallery==nil and app.warehouse==nil and app.vehicleSwitch==nil,'Actual hall teardown includes build/gallery/warehouse/switch')
Check(app.pendingAssetRelease~=nil and app.assetReleaseFrames==3,'Hall sweep joins shared deferred resource queue')
local first=#calls;app:ReleaseSettledAssets()
Check(calls[first+1]=='render-retire' and calls[first+2]=='environment' and calls[first+3]=='previous-map-release' and calls[first+4]=='cache','Actual shared sweep preserves retire/environment/previous callback/cache order')
Check(app.pendingAssetRelease==nil,'Settled sweep drains callbacks once')

local map={id='crater',name='crater',scene='Scenes/Crater.xml',prepareWorld='fixture.Physics',world='fixture.World'}
package.loaded['app.DriveMaps']={crater=map,trial={id='trial',name='trial',scene='Scenes/TrialTrack.xml'}}
local createdWorld,createdSession=false,false
local activateError=false
package.loaded['fixture.World']={New=function(scene) local world=Owned('world');world.scene=scene;createdWorld=world;return world end}
package.loaded['fixture.Physics']={Build=function(_,checkpoint) checkpoint(1,'world') end}
package.loaded['app.TrialSession']={New=function(scene,_,_,_,world,_,retain)
    local session=Owned('session');session.scene=scene;session.world=world
    session.Activate=function() if activateError then error('activation error') end end
    session.Pause=function() end
    local dispose=session.Dispose
    session.Dispose=function(self) if not self.disposed then world:Dispose();dispose(self);self.scene=nil end end
    retain(session);createdSession=session;return session
end}
local function Begin(shouldRelease)
    local current=MakeApp();local old=current.scene
    Check(current:EnterTrial('crater'),'Actual EnterTrial starts map loader')
    local token=current.mapTransition.current
    if shouldRelease then
        current.mapTransition:CanStart(true,2,true)
        Check(old.disposed and current.scene==nil,'Web heavy map tears down old scene before candidate preparation')
        Check(current.mapTransition:CanStart(true,5,true),'Actual heavy-map fence unblocks preparation')
    end
    return current,token,old
end
local function Prepare(current)
    local scene=Owned('new-scene');current.loader.pending=scene
    current.loader.options.prepare(scene,function() end)
    current.loader.phase='activate'
    return scene,createdWorld,createdSession
end
app,a=Begin(true)
local candidate,world,session=Prepare(app)
app.loader:Commit()
Check(app.scene==candidate and app.trial==session and app.mode=='trial' and app.loader.state=='ready','Actual Loader.Commit installs prepared session')
Check(not candidate.disposed and not world.disposed and not session.disposed,'Successful commit keeps new world and session alive')
Check(a.state=='committed' and not app.mapTransition:IsRestoring(),'Successful install commits transition')
app.loader:Cancel()
Check(not candidate.disposed and not world.disposed and not session.disposed,'Later loader cancellation cannot destroy committed world')

app,a=Begin(false);original=app.scene;app.loader:Cancel()
Check(not original.disposed and app.pendingMap==nil and not app.mapTransition:IsRestoring(),'Actual cancel before cover preserves old scene')
app,a=Begin(true);candidate,world,session=Prepare(app);app.loader:Cancel()
Check(candidate.disposed and world.disposed and session.disposed and app.pendingMap==nil,'Actual cancel cleans partially prepared candidate ownership')
Check(app.mapTransition:IsRestoring() and app.mapTransition:BeginRecovery(),'Actual cancel queues non-reentrant hall recovery')

app,a=Begin(true);candidate,world,session=Prepare(app);app.loader:Fail('download failure')
Check(app.loader.state=='failed' and app.loadingFlow.failed=='download failure','Actual Loader.Fail presents original error')
Check(candidate.disposed and world.disposed and session.disposed and app.mapTransition:IsRestoring(),'Actual failed map candidate is released and hall restore queued')

app,a=Begin(true);candidate,world,session=Prepare(app);activateError=true;app.loader:Commit();activateError=false
Check(app.loader.state=='failed' and session.disposed and world.disposed and candidate.disposed,'Activation failure disposes prepared candidate')
Check(app.mapTransition:IsRestoring() and app.trial==nil,'Activation failure never installs candidate and queues recovery')

app,a=Begin(true);candidate,world,session=Prepare(app);app.loadingFlow.finishError=true;app.loader:Commit()
Check(app.loader.state=='failed' and session.disposed and world.disposed and candidate.disposed,'Post-activation failure cleans candidate after tentative app ownership')
Check(app.scene==nil and app.trial==nil and app.mapTransition:IsRestoring(),'Tentative app fields clear before recovery on post-activation error')

app,a=Begin(false)
local staleReady,staleError,staleCancel=app.loader.onReady,app.loader.onError,app.loader.options.cancel
app.loader:Cancel();Check(app:EnterTrial('crater'),'New transition starts after canceled request')
local latest=app.mapTransition.current;local pending=app.pendingMap
staleCancel();staleError('late failure')
Check(app.mapTransition:IsCurrent(latest) and app.pendingMap==pending and not app.loadingFlow.failed,'Late old cancel/error cannot affect newer request')
local ok=pcall(staleReady,Owned('obsolete-scene'))
Check(not ok and app.mapTransition:IsCurrent(latest) and not app.trial,'Late old ready cannot install an obsolete world')

web=false;app,a=Begin(false)
Check(app.mapTransition:CanStart(true,2,true) and app.scene~=nil and not a.released,'Native path retains old hall until existing successful commit')
web=true;app=MakeApp();Check(app:EnterTrial('trial'),'Small trial map starts normally')
Check(app.mapTransition:CanStart(true,2,true) and app.scene~=nil,'Small trial map retains existing lifecycle')

package.loaded['audio.StoryComms']={Tick=function() end}
package.loaded['audio.IntroAudioTail']={Update=function() end,CancelAll=function() end}
package.loaded['audio.UiSound']={Update=function() end,Dispose=function() end}
package.loaded['audio.GameMusicState']={FromApp=function() return {scene='hangar'} end}
package.loaded['audio.GameAmbience']={FromApp=function() return nil end}
package.loaded['audio.AudioLevels']={MixContext=function() end}
package.loaded['storage.BlueprintStore']={UpdateAll=function() end}
package.loaded['app.ResourceGate'].UpdatePending=function() end
package.loaded['scene.HangarResources']={For=function() return {'Scenes/OrbitalHangar.xml'} end}
input={focus=true,GetMouseButtonPress=function() return false end,GetKeyPress=function() return false end}
MOUSEB_LEFT=1;KEY_RETURN=2;KEY_SPACE=3;KEY_ESCAPE=4
local function RecoveryApp()
    local current=Begin(true)
    current.music={Update=function() end}
    current.previews.Update=function() end
    current.graphicsSettings.Update=function() end
    current.loadingFlow.Advance=function() end
    current.loadingFlow.Observe=function() end
    current.loadingFlow.Open=function(self,definition)
        self.active=true;self.map=definition;self.pageVisible=true;self.pageFrames=0;self.failed=nil;self.finished=false
    end
    current.loader.canStart=function()
        local ready,message=current.mapTransition:CanStart(current.loadingFlow.pageFrames>=2,current.loadingFlow.pageFrames,background==0)
        if message then current.loader:Fail(message) end
        return ready
    end
    current.loader:Cancel()
    return current
end
app=RecoveryApp()
local actualLoad=app.loader.Load
local loads=0
app.loader.Load=function(self,...) loads=loads+1;return actualLoad(self,...) end
app:Update(.016)
Check(loads==1 and app.loader.state=='loading' and app.loadingFlow.map.boot and app.loadingFlow.map.id=='hangar','Actual Update starts covered boot hall recovery on next tick')
Check(app.loader.beginDownload~=nil and app.mapTransition:IsRestoring(),'Actual recovery stays paused before presented page')
app.loadingFlow.pageFrames=2;app:Update(.016)
Check(app.loader.beginDownload~=nil,'Actual recovery begins renderer fence after two page frames')
app.loadingFlow.pageFrames=4;app:Update(.016)
Check(app.loader.beginDownload~=nil,'Actual recovery waits three presented retirement frames')
app.loadingFlow.pageFrames=5;app:Update(.016)
Check(app.loader.beginDownload==nil and app.loader.phase=='scene','Actual Update resumes hall loading only after shared sweep')
app.loader:Fail('restore download failure')
app:Update(.016)
Check(loads==1 and app.loadingFlow.failed=='restore download failure','Failed recovery remains on boot retry page without looping automatically')
app:Reload()
Check(loads==2 and app.mapTransition:Snapshot().state=='restore','Actual Reload retry resets restore state')
app.loadingFlow.pageFrames=2;app:Update(.016)
Check(app.loader.beginDownload~=nil,'Actual recovery retry respects a new page fence')
app.loadingFlow.pageFrames=5;app:Update(.016)
local recovered=Owned('recovered-scene')
app.Install=function(self,scene) self.scene=scene;self.mode='hangar';self.hangar=Owned('recovered-hangar') end
app.loader.pending=recovered;app.loader.phase='activate';app.loader:Commit()
Check(app.loader.state=='ready' and app.scene==recovered and app.loadingFlow.finished and not app.mapTransition:IsRestoring(),'Actual recovery Reload callback installs hall and clears recovery after loading finish')
Check(not recovered.disposed,'Recovered hall belongs to app after loader commit')

-- Independent review: stop during preparation and the covered render fence.
app,a=Begin(true);candidate,world,session=Prepare(app)
local stoppedCancel=app.loader.options.cancel
app.previousState={autoReload=false,hdr=false,shadowSize=256,shadows=false,mouseMode=1,maxFps=60,inactiveFps=10}
app.store={Flush=function() Record('store-flush') end}
app.toasts.Dispose=function() Record('toasts-dispose') end
app.music={Dispose=function() Record('music-dispose') end}
app.graphicsSettings.Dispose=function() Record('graphics-dispose') end
app.loadingFlow.Dispose=function() Record('flow-dispose') end
package.loaded['urhox-libs/UI'].Shutdown=function() Record('ui-shutdown') end
package.loaded['render.WindowViewports'].Stop=function() Record('viewports-stop') end
package.loaded['audio.StoryComms'].Shutdown=function() Record('comms-shutdown') end
renderer={};engine={}
app:Stop()
Check(app.stopped and app.mapTransition.stopped,'Actual Stop stops transition before loader cleanup')
Check(candidate.disposed and world.disposed and session.disposed,'Actual Stop releases in-flight candidate/world/session')
Check(not app.mapTransition:IsRestoring() and app.mapTransition:Snapshot().state=='idle','Actual Stop cannot queue hall recovery')
stoppedCancel()
Check(not app.mapTransition:IsRestoring(),'Late canceled token after actual Stop cannot restore')
app:Stop()
Check(candidate.disposeCount==1 and session.disposeCount==1,'Actual repeated Stop remains idempotent')
local posts,graphicsPosts=0,0
app=MakeApp();app.trial={PostUpdate=function() posts=posts+1 end}
app.graphicsSettings.PostUpdate=function() graphicsPosts=graphicsPosts+1 end
app.loadingFlow.active=true;app.loadingFlow.finished=false
app:PostUpdate(.016)
Check(posts==0 and graphicsPosts==1,'Actual PostUpdate suppresses unfinished covered trial')
app.loadingFlow.finished=true;app:PostUpdate(.016)
Check(posts==1 and graphicsPosts==2,'Actual PostUpdate warms successfully installed covered candidate')
app.stopped=true;app:PostUpdate(.016)
Check(posts==1 and graphicsPosts==2,'Actual PostUpdate does nothing after Stop')
return {checks=checks}
