package.path='scripts/?.lua;'..package.path
local checks,played=0,0
local function Check(value,message) checks=checks+1;assert(value,message) end
local pending={}
local function SoundSource()
    return {SetSoundType=function() end,StopImmediate=function(self) self.playing=false end}
end
Scene=function() return {CreateChild=function() return {CreateComponent=function() return SoundSource() end} end,Dispose=function() end} end
cache={GetResourceAsync=function(_,_,path,callback) pending[path]=callback end}
audio={PauseSoundType=function() end,ResumeSoundType=function() end}
package.preload['audio.AudioLevels']=function() return {
    Play=function(source,sound) source.playing=true;source.sound=sound;played=played+1 end,
    RawGain=function() return .4 end,SetGain=function() end,SetSpeaking=function() end,
} end
package.preload['ui.CommsCard']=function() return {Tick=function() end,Dispose=function() end} end
package.preload['audio.StoryCommsCues']=function() return {Dependencies=function() return {} end,New=function() return {
 Play=function() end,Update=function() end,Dispose=function() end,
} end} end
input={focus=true,minimized=false}
local C=require 'audio.StoryComms'
local data={voices={q={path='quote.ogg',text={'Quote test'}}}}
local function Ready() local callback=pending['quote.ogg'];Check(type(callback)=='function','quote requests asynchronous original recording');callback({length=1.2}) end
for _,sample in ipairs(SOURCE.cases) do
    C.Shutdown();pending={};played=0
    local voice=C.New(nil,data)
    if sample.cardLength>0 then voice.card={age=0,length=sample.cardLength,typing=0} end
    local initial=voice.card;voice.queue={'stale','stale2'}
    voice:PrepareResultQuote('Quote test')
    Check(voice.card==initial and #voice.queue==0,'result preserves current line and drops queued chatter')
    for _,step in ipairs(sample.trace) do
        if step.ready then Ready() end
        voice:Update(.2,step.focused)
        Check(played==step.played,'actual source quote ready/current-line/.9s playback timing')
        Check((voice.card~=nil)==step.card and #voice.queue==step.queue,'actual source retained card and cleared queue state')
        Check(#voice.log==played,'quote appears in existing playback evidence log once')
    end
    Check(played<=1,'quote cannot repeat after result frames')
end
for _,action in ipairs({'hide','dispose','owner','reclaim','shutdown'}) do
    C.Shutdown();pending={};played=0
    local voice=C.New(nil,data);voice:PrepareResultQuote('Quote test')
    local callback=pending['quote.ogg']
    if action=='hide' then voice:Hide()
    elseif action=='dispose' then voice:Dispose()
    elseif action=='shutdown' then C.Shutdown()
    else local next=C.New(nil,data);if action=='reclaim' then voice:Use() end end
    callback({length=1.2})
    for i=1,20 do voice:Update(.2,true) end
    Check(played==0,'late quote never plays after '..action)
end
C.Shutdown();pending={};played=0
local voice=C.New(nil,data);voice:PrepareResultQuote('no matching recording')
Check(voice.resultQuote==nil and next(pending)==nil,'unrecorded source line is silently absent')
voice:PrepareResultQuote('Quote test');Ready();voice:Update(1,true)
Check(voice.card==nil and #voice.log==1 and played==1,'quote-only playback never invents a communications card')
local source=voice.source;voice:Hide();C.Tick(.4)
Check(not source.playing,'leaving after quote playback fades the active voice')
C.Shutdown()
return {result='PASS',checks=checks,sourceScenarios=#SOURCE.cases,
 boundary='Actual Lua StoryComms.New/PrepareResultQuote/Update/Hide/Dispose/ownership/Shutdown with audio/resource doubles versus actual frozen StoryHud.result/update timing, plus actual MissionData/resource dependencies and original OGG external decoding. No UrhoX decoder, audible continuity, Web or native audio acceptance.'}
