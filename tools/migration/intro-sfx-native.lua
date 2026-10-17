-- Isolated entry; real IntroAudio, SoundSource, resources and device mixer.
local Levels=require 'audio.AudioLevels'
local Intro=require 'audio.IntroAudio'
local output
for _,arg in ipairs(GetArguments())do output=arg:match('^%-probe%-output=(.+)$')or output end
local report={status='RUNNING',checks={},observations={},boundary='Real Native Audio device, SoundSource and production IntroAudio. Source/gain/lifetime feedback only; no PCM loopback, audible mix/compressor equality, Web or sustained mobile performance claim.'}
local player=nil ---@type table|nil
local thread=nil ---@type thread|nil
local focused=true
local finished=false
local begun=0
local function Now()return Time:GetSystemTime()end
local function Check(ok,label)
 report.checks[#report.checks+1]={pass=ok==true,label=label,wallMs=Now()-begun}
 assert(ok,label)
end
local function Record(label,data)report.observations[#report.observations+1]={label=label,wallMs=Now()-begun,data=data}end
local function Sources()
 local list=audio:GetSoundSources();assert(list~=nil,'Audio:GetSoundSources feedback unavailable')
 return #list
end
local function Source(source)
 return {playing=source.playing,fadingOut=source.fadingOut,timePosition=source.timePosition,frequency=source.frequency,gain=source.gain,soundType=source.soundType}
end
local function Wait(seconds)
 local untilAt=Now()+seconds*1000
 repeat coroutine.yield()until Now()>=untilAt
end
local function Finish(ok,message)
 if finished then return end;finished=true
 if player and player.active then pcall(function()player:Dispose()end)end
 audio:ResumeSoundType('VoxIntroSfx')
 report.status=ok and 'PASS' or 'FAIL';report.error=message;report.elapsedMs=Now()-begun
 local file=assert(io.open(assert(output,'Missing -probe-output'),'wb'));file:write(cjson.encode(report));file:close()
 print('INTRO_SFX_NATIVE_RESULT '..cjson.encode({status=report.status,checks=#report.checks,elapsedMs=report.elapsedMs,error=message}))
 engine:Exit()
end
local function Run()
 Record('device',{initialized=audio.initialized,playing=audio.playing,mixRate=audio.mixRate,stereo=audio.stereo,sampleSize=audio.sampleSize})
 Check(audio.initialized and audio.playing and audio.mixRate>0,'real audio device and mixer are active')
 local baseline=Sources();Record('baselineSources',{count=baseline})
 Levels.Init(nil)
 player=Intro.New({audio={sfx_alarm='Intro/Audio/sfx_alarm.mp3',sfx_blip='Intro/Audio/sfx_blip.mp3',
  sfx_scribble='Intro/Audio/sfx_scribble.mp3',sfx_tv_cut='Intro/Audio/sfx_tv_cut.mp3'},durations={}})
 repeat local done,message=player:PrepareNext();assert(message==nil,message);if done then break end until false
 local resources={};for id,sound in pairs(player.sounds)do resources[id]={length=sound.length,frequency=sound:GetFrequency(),compressed=sound.compressed,dataSize=sound.dataSize}end
 Record('realResources',resources)
 local loop,loopToken=player:Sfx('alarm',{vol=.001,loop=true})
 local all={loop};for i=1,12 do all[#all+1]=player:Sfx('blip',{vol=.001,rate=.8+i*.015,loop=true})end
 Check(#player.sources==13,'actual pool grows beyond ten simultaneous sources')
 local seen={};for _,source in ipairs(all)do Check(not seen[source],'every overlapping source has its own native identity');seen[source]=true end
 Wait(.25)
 local advanced=0;for _,source in ipairs(all)do
  Check(source.playing and source.soundType=='VoxIntroSfx','retained native source remains playing on actual SFX bus')
  if source.timePosition>0 then advanced=advanced+1 end
 end
 Record('concurrentMixer',{retained=#all,timePositionsAdvanced=advanced,registeredSources=Sources(),loop=Source(loop)})
 Check(advanced==13,'actual mixer advances all thirteen source positions')
 local full=loop.gain
 Check(player:StopSfx(loop,.2,loopToken),'original loop handle owns its stop under pressure')
 Wait(.08);Record('fadeMidpoint',Source(loop))
 Check(loop.playing and loop.gain>0 and loop.gain<full,'actual native gain decreases during production stop envelope')
 Wait(.17);Record('fadeEnd',Source(loop))
 Check(not loop.playing and not loop.fadingOut,'production stop deadline invokes native StopImmediate')
 local reused,nextToken=player:Sfx('alarm',{vol=.001,loop=true})
 Check(reused==loop and nextToken~=loopToken,'only completed native slot reused with fresh token')
 Check(not player:StopSfx(loop,.1,loopToken),'stale source callback rejected after real reuse')
 reused:SetDeclickEnabled(true);reused:Stop()
 local nativeFade=Source(reused);Record('nativeStopFeedback',nativeFade)
 local replacement=player:Sfx('alarm',{vol=.001,loop=true})
 if nativeFade.fadingOut then
  Check(replacement~=reused,'native non-playing fadingOut source protected by real flag')
  report.nativeFadeFlag='OBSERVED_AND_PROTECTED'
 else
  report.nativeFadeFlag='UNAVAILABLE_AT_OBSERVATION';Record('nativeFadeBoundary',{note='Stop did not expose fadingOut at immediate sample; no fake coverage claimed.'})
 end
 Wait(.15)
 Check(replacement.playing,'replacement remains playing after previous native stop tail')
 Levels.Set('sfx',0);Wait(.1)
 Check(replacement.playing and replacement.gain==0,'mute keeps native source playback alive')
 Levels.Set('sfx',.65);Check(replacement.gain>0,'unmute restores production gain')
 focused=false;player:Update(0,false)
 Check(audio:IsSoundTypePaused('VoxIntroSfx'),'production focus suspension reaches actual audio bus')
 local paused=Source(replacement);Wait(.15);local afterPause=Source(replacement)
 Record('nativeFocusPause',{before=paused,after=afterPause,clock=player.time})
 Check(math.abs(afterPause.timePosition-paused.timePosition)<.04,'paused native mixer source position stays within one buffer tolerance')
 focused=true;player:Update(0,true)
 Check(not audio:IsSoundTypePaused('VoxIntroSfx'),'focus restore resumes actual sound bus')
 local resumedAt=replacement.timePosition;Wait(.12)
 Check(replacement.playing and replacement.timePosition~=resumedAt,'native source playback resumes after focus restore')
 local registered=Sources();Record('preDispose',{count=registered,slots=#player.sources})
 Check(registered>=baseline+16,'expanded scene sources registered in actual audio subsystem')
 player:Dispose()
 -- Never query disposed source userdata. Query the owning Audio subsystem instead.
 Wait(.1);local remaining=Sources();Record('postDispose',{count=remaining,baseline=baseline})
 Check(remaining==baseline,'scene Dispose unregisters every retained native SoundSource')
 Check(not player.active and player:Sfx('alarm')==nil,'disposed production owner cannot restart playback')
 Check(Sources()==baseline,'disposed Sfx request cannot allocate a new native source')
 Finish(true)
end
function Start()
 begun=Now();engine:SetMaxFps(60);engine:SetMaxInactiveFps(60)
 thread=coroutine.create(Run)
 SubscribeToEvent('Update','IntroSfxNativeUpdate')
end
function IntroSfxNativeUpdate(_,data)
 if finished then return end
 if Now()-begun>25000 then Finish(false,'25-second probe deadline');return end
 local ok,message=xpcall(function()
  if player and player.active then player:Update(data:GetFloat('TimeStep'),focused)end
  local resumed,errorMessage=coroutine.resume(thread);assert(resumed,errorMessage)
 end,debug.traceback)
 if not ok then Finish(false,tostring(message))end
end
function Stop()
 UnsubscribeFromEvent('Update')
 if not finished then Finish(false,'Runtime stopped before probe completion')end
end
