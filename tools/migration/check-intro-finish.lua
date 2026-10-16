package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks={};local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local none=function()end
local function module(name,value)package.loaded[name]=value end
local current
local UI={GetFocus=none,ClearFocus=none,SetRoot=none,PushOverlay=none,RegisterGlobalComponent=function()current.registered=current.registered+1 end}
module('urhox-libs/UI',UI);module('core.Coord',{})
module('construction.Blueprint',{})
module('core.ResourceData',{Read=function()return {audio={},durations={},lines={},caps={}}end})
module('app.SceneLoader',{New=function()return {Cancel=none,Update=none}end})
module('app.ResourceGate',{New=function()return {Cancel=function()current.cancelGate=current.cancelGate+1 end}end})
module('scene.Crater',{Release=function()current.release=current.release+1 end})
module('ui.GarageHud',{Create=function()current.hud=current.hud+1 end,Refresh=none})
module('Config',{TIERS={1}})
module('ui.IntroPage',{New=function()return {imageWarmup={ready=true},Close=function()current.close=current.close+1 end}end})
module('audio.AudioLevels',{Get=function(kind)return kind=='voice' and .6 or kind=='music' and .75 or 1 end,
 MusicGain=function(value)return value end,On=function()local c=current;c.watchers=c.watchers+1;return function()c.watchers=c.watchers-1 end end})
audio={PauseSoundType=none,ResumeSoundType=none}
Scene=function()
 local c=current
 local root={CreateComponent=function()
  return {SetSoundType=none,Play=function(self,sound,frequency,gain)self.sound=sound;self.frequency=frequency;self.gain=gain;self.playing=true end,
   Seek=none,StopImmediate=function(self)self.playing=false;c.sourceStops=c.sourceStops+1 end}
 end}
 return {CreateChild=function()return root end,Dispose=function()c.audioDispose=c.audioDispose+1 end}
end
input={};MM_ABSOLUTE=1;KEY_SPACE=2;KEY_RETURN=3;KEY_ESCAPE=4;KEY_1=5;KEY_2=6;KEY_3=7
local Session=require('intro.IntroSession');local Host=require('app.OpeningHost');local Retirement=require('app.OpeningRetirement')
local Tail=require('audio.IntroAudioTail')
Time={GetSystemTime=function()return current.wallMs end}
local function New()
 Tail.CancelAll()
 local c={close=0,cancelGate=0,audioDispose=0,sourceStops=0,watchers=0,wallMs=0,release=0,hud=0,home=0,registered=0,tutorial=0,pauses=0,worldDispose=0,sceneDispose=0,restores=0,hidden=0,cameraQueries=0}
 current=c
 local hall={};local app={scene=hall,mode='hangar',tier=1,car={SetVisible=function()c.visible=true end},camera={node={},camera={}},
 graphicsSettings={Show=function()c.restores=c.restores+1 end,ReleasePost=none},
 HomeView=function()c.home=c.home+1 end,
 RetireOpening=function(_,work,done)c.job=Retirement.New(work,done)end,
 DeferAssetRelease=function(_,release,incremental)check(incremental,'actual host preserves incremental settled release');c.releaseLater=release end}
 app.tutorial={page={},Start=function()c.tutorial=c.tutorial+1 end}
 local host=Host.New(app);local s=host.state
 local I=Session.New(app,host);app.opening=I;app.openingRestoreOwner=s
 local sound={name='fixture',length=60,SetLooped=none,GetFrequency=function()return 44100 end}
 I.audio.sounds={voice=sound,music=sound,blip=sound};I.audio:Voice('voice');I.audio:Music('music');I.audio:Sfx('blip')
 I.active=true;I.time=100;I.age=6.4;I.shot='gate';I.stage='reality';I.name='Test'
 s.hall=hall;s.hallCamera=app.camera.camera;s.oldPose={position='restored-position',rotation='restored-rotation',fov=48};s.oldCarVisible=true
 s.hallActor={SetVisible=function()c.hidden=c.hidden+1 end,Dispose=none}
 s.garage={root={SetEnabledRecursive=none},Dispose=none}
 s.session={Pause=function()c.pauses=c.pauses+1 end,Dispose=function()c.worldDispose=c.worldDispose+1 end}
 s.scene={GetChildren=function()return{}end,Dispose=function()c.sceneDispose=c.sceneDispose+1 end}
 host.GetCamera=function()c.cameraQueries=c.cameraQueries+1 end
 host.Update=function()error('cinematic host must stop during exit')end
 return I,host,app,c
end
local function Step(I,dt,focused)current.wallMs=current.wallMs+dt*1000;I:Update(dt,focused)end
local function TailStep(dt,focused)current.wallMs=current.wallMs+dt*1000;Tail.Update(dt,focused)end
check(REFERENCE.animation.options.duration==700 and REFERENCE.animation.frames[1].opacity==1 and REFERENCE.animation.frames[2].opacity==0,'executed frozen finish animates opacity 1 to 0 over 700 ms')
local function Has(list,value)for _,entry in ipairs(list)do if entry==value then return true end end end
check(Has(REFERENCE.before,'camera') and Has(REFERENCE.before,'scene') and not Has(REFERENCE.before,'home'),'executed frozen finish restores scene and camera before home')
check(Has(REFERENCE.after,'remove') and Has(REFERENCE.after,'home') and Has(REFERENCE.after,'tutorial') and REFERENCE.realitySkipIgnored,'executed frozen finish removes overlay then resumes home/tutorial; reality skip is ignored')
check(REFERENCE.before[1][1]=='audio' and REFERENCE.before[1][2]==1.2,'executed frozen finish starts 1.2 second audio fade before scene restoration')
do
 local I,host,app,c=New();local retained=I.audio;I:Finish();I:Finish()
 check(I.active and I.finishing and not I.completed and I.fadeOutAt==100 and I.fadeOutDuration==.7,'actual session keeps overlay alive with source fade duration')
 check(#I.log==1 and c.pauses==1 and c.restores==1 and c.hud==0 and c.close==0 and not c.job,'repeated finish starts one fade without early retirement or home')
 check(app.camera.node.position=='restored-position' and app.camera.camera.fov==48,'actual host restores authored hall camera at fade start')
 I:Advance();check(not I.advance and not I:Skip() and not I:Choose(1) and not I:Submit('late'),'exit ignores advance/skip/choice/signature commands')
 check(I:KeyDown(KEY_SPACE,false) and not I.holding,'exit consumes keys without new holds')
 I:Camera();check(c.cameraQueries==0,'exit cannot overwrite restored camera with gate shot')
 Step(I,.349,true);Step(I,.350,false)
 check(I.active and I.finishing and c.close==0 and c.home==0,'actual lifecycle remains open at 699 ms, including loss of focus')
 Step(I,.002,true)
 check(not I.active and I.disposed and I.completed and not I.finishing and c.close==1 and I.audio==nil and c.audioDispose==0,'actual lifecycle closes visual once after 700 ms and hands off live audio')
 check(retained.active and c.watchers==3,'tail retains only audio lifetime and volume watchers after visual exit')
 check(c.hud==1 and c.home==1 and c.tutorial==0 and c.registered==0 and c.job,'home waits for fade while tutorial retains existing retirement fence')
 check(c.restores==1 and c.pauses==1 and c.worldDispose==0,'completion reuses restored hall and one pause, leaving owned world queued')
 Retirement.Step(c.job,true)
 check(c.worldDispose==1 and c.sceneDispose==1 and c.releaseLater and c.tutorial==0,'native world retirement completes before settled release')
 c.releaseLater();check(c.release==1 and c.tutorial==1 and c.registered==1,'tutorial resumes only after fade and existing settled release')
 I:Finish();I:Update(100,true);host.Finish(I)
 check(c.close==1 and c.hud==1 and c.home==1 and c.tutorial==1,'late duplicate completion cannot repeat teardown or home/tutorial')
 TailStep(.698,false);check(retained.active and c.audioDispose==0,'unfocused tail stays owned before absolute 1.4 second deadline')
 TailStep(.002,false);check(not retained.active and c.audioDispose==1 and c.watchers==0,'unfocused tail releases at absolute deadline without waiting for audio clock')
end
do
 local I,host,app,c=New();local retained=I.audio;I:Finish();Step(I,.701,true)
 check(retained.voice.gain>0 and retained.voice.gain<.9 and c.audioDispose==0,'successful visual handoff preserves an audible decaying voice tail')
 Retirement.Step(c.job,true);c.releaseLater();c.job=nil;c.releaseLater=nil
 local weak=setmetatable({I,host,app.scene},{__mode='v'});I=nil;host=nil;app=nil;collectgarbage('collect')
 check(weak[1]==nil and weak[2]==nil and weak[3]==nil and retained.active,'independent audio tail does not retain intro session, host or hall scene')
 TailStep(.499,true)
 check(math.abs(retained.voice.gain)<1e-9 and retained.active and c.audioDispose==0,'master envelope reaches zero at 1.2 seconds without early disposal')
 TailStep(.199,true);check(retained.active and c.audioDispose==0,'silent audio scene remains alive through 1399 ms')
 TailStep(.002,true);check(not retained.active and c.audioDispose==1 and c.watchers==0,'audio scene and watchers release once after 1.4 seconds')
 Tail.CancelAll();TailStep(1,true);check(c.audioDispose==1,'tail completion and later Stop cannot double-dispose audio')
end
do
 local I,host,app,c=New();local retained=I.audio;I:Finish();Step(I,.701,true)
 local replacement=require('audio.IntroAudio').New({audio={},durations={}})
 check(not retained.active and replacement.active and c.audioDispose==1 and c.watchers==3,'new intro audio replaces an already handed-off tail immediately')
 replacement:Dispose();TailStep(2,true)
 check(c.audioDispose==2 and c.watchers==0,'replacement and cancelled tail finish with no orphan audio watchers')
end
do
 local I,_,_,c=New();I:Finish();c.wallMs=350;I:Update(.001,true)
 check(I.active and I.finishing and math.abs(I.fadeOutElapsed-.35)<1e-9 and math.abs(I.time-I.fadeOutAt-.001)<1e-9,'fade exposes true wall elapsed independently from clamped cinematic dt')
 c.wallMs=701;I:Update(.001,true)
 check(I.completed and c.close==1 and c.home==1 and I.fadeOutElapsed==.701,'701 ms wall jump completes visual fade even when cinematic dt advances only 2 ms')
 Retirement.Step(c.job,true);c.releaseLater();Tail.CancelAll()
end
for _,mode in ipairs({'cancel','stop','replacement'})do
 local I,host,app,c=New();I:Finish();Step(I,.2,true)
 if mode=='stop'then app.stopped=true elseif mode=='replacement'then app.opening={};app.openingRestoreOwner={};app.scene={};app.mode='trial'end
 I:Dispose();I:Dispose();I:Update(100,true);I:Finish()
 check(not I.completed and not I.active and not I.finishing and c.close==1 and c.worldDispose==1 and not c.job,'partial fade '..mode..' cancels synchronously without successful retirement')
 check(c.hud==0 and c.home==0 and c.tutorial==0 and c.registered==0,'partial fade '..mode..' never dispatches delayed home/tutorial')
 TailStep(2,true);check(c.audioDispose==1 and c.watchers==0,'partial fade '..mode..' leaves no tail or watchers')
end
do
 local I,host,_,c=New();host.Update=none;host.Shot=none;host.UseScene=none
 I.part='gate';I.ready=true;I.clicked=true;I.audioReady=true;I.sceneReady=true;I.age=0
 I.thread=coroutine.create(function()I:Run()end)
 for _=1,2000 do Step(I,.01,true);assert(not I.failed,I.error);if I.finishing then break end end
 check(I.finishing and I.shot=='gate' and not I.completed and c.hud==0,'actual gate Run reaches fade instead of immediate home')
 local started=I.fadeOutAt;Step(I,.699,true)
 check(I.active and I.time-started<.7 and c.close==0,'actual gate Run preserves full 700 ms exit interval')
 Step(I,.002,true);check(I.completed and c.close==1 and c.home==1 and I.audio==nil and c.audioDispose==0,'actual gate Run commits home after fade while audio tail remains independent')
 Retirement.Step(c.job,true);c.releaseLater()
 Tail.CancelAll();check(c.audioDispose==1 and c.watchers==0,'post-handoff Stop cancels audio tail immediately')
end
do
 local I,_,_,c=New();I.failed=true;I:Finish()
 check(I.disposed and not I.completed and not I.finishing and c.close==1 and not c.job,'error close remains immediate and never marks successful completion')
 check(c.audioDispose==1 and c.watchers==0,'error close immediately releases audio and all volume watchers')
end
return {count=#checks,checks=checks}
