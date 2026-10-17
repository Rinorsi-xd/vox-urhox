-- Retained audio scene; page transitions never dispose a playing voice.
local IntroAudioTail=require("audio.IntroAudioTail")

local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local loud={alarm=-7.9,blip=-22.9,clang=-8,confirm=-12.9,crt_on=-27.2,door_open=-10.4,heartbeat=-4.3,holo_shatter=-9.8,
 laser_big=-6.5,laser_boom=-3.9,laser_charge=-11.5,pigeon=-4.8,scratch=-9,scribble=-30.1,shred=-12.1,slam=-4.6,spotlight=-13.4,stamp=-9.2,tv_cut=-8.6,whoosh=-8.6}
function M.New(data)
 IntroAudioTail.CancelAll()
 local self=setmetatable({},M);self:init(data);return self
end
function M:init(data)
 self.data=data;self.scene=Scene();self.root=self.scene:CreateChild('IntroAudio');self.sounds={};self.queue={};self.sources={};self.music={};self.musicIndex=0
 self.voice=self.root:CreateComponent('SoundSource');self.voice:SetSoundType('VoxIntroVoice')
 self.voices={{source=self.voice}}
 for i=1,10 do local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroSfx');self.sources[i]={source=source} end
 for i=1,2 do local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroMusic');self.music[i]={source=source,level=0,target=0,base=0} end
 for id,path in pairs(data.audio) do self.queue[#self.queue+1]={id=id,path=path} end
 table.sort(self.queue,function(a,b)return a.id<b.id end)
 self.prepared=0;self.active=true;self.voiceUntil=0;self.time=0;self.duck=.55;self.sfxSerial=0;self.voiceSerial=0
 self.voiceLevel=Levels.Get('voice')/.6;self.sfxLevel=Levels.Get('sfx');self.musicLevel=Levels.MusicGain(Levels.Get('music'))/Levels.MusicGain(.75)
 self.unwatch={Levels.On('voice',function(value) self.voiceLevel=value/.6;self:UpdateVoiceGains() end),
  Levels.On('sfx',function(value) self.sfxLevel=value;for _,slot in ipairs(self.sources) do if slot.base then slot.source.gain=slot.base*value*self:SfxLevel(slot)*self:MasterLevel() end end end),
  Levels.On('music',function(value) self.musicLevel=Levels.MusicGain(value)/Levels.MusicGain(.75);self:UpdateGains() end)}
end
function M:PrepareNext()
 local item=table.remove(self.queue,1);if not item then return true end
 local sound=cache:GetResource('Sound',item.path)
 if not sound or sound.length<=0 then return false,'开篇音频无法读取：'..item.path end
 self.sounds[item.id]=sound;self.prepared=self.prepared+1;return #self.queue==0
end
function M:Duration(id) return self.sounds[id] and self.sounds[id].length or self.data.durations[id] or 0 end
function M:Voice(id)
 local sound=self.sounds[id]
 if not self.active or not sound or sound.length<=0 then return 0 end
 local slot=nil
 for _,candidate in ipairs(self.voices) do if not candidate.source.playing and not candidate.source.fadingOut then slot=candidate;break end end
 if not slot then
  local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroVoice')
  slot={source=source};self.voices[#self.voices+1]=slot
 end
 self.voiceSerial=self.voiceSerial+1;slot.token=self.voiceSerial
 self.voice=slot.source;slot.stopFade=nil;slot.stopAt=nil;slot.untilAt=self.time+sound.length
 self.voice:Play(sound,0,.9*self.voiceLevel*self:MasterLevel());self.voiceUntil=self.time+sound.length;self:Duck(true);return sound.length,slot.token
end
function M:IsVoicePlaying(token)
 if not self.active or not token then return false end
 for _,slot in ipairs(self.voices) do if slot.token==token then
  -- IsPlaying is false during the engine's native fade-out.
  return slot.source.sound~=nil and (slot.source.playing or slot.source.fadingOut)==true
 end end
 return false
end
function M:StopVoice()
 for _,slot in ipairs(self.voices) do if slot.source.playing then
  slot.stopFade={from=self:SfxLevel(slot),start=self.time,duration=.08};slot.stopAt=self.time+.1;slot.untilAt=nil
 end end
 self.voiceUntil=0;self:Duck(false);self:UpdateVoiceGains()
end
function M:Snapshot()
 if not self.active then return {active=false,time=self.time,prepared=self.prepared,voiceUntil=0,voice={playing=false,timePosition=0,frequency=0,gain=0,resource='',length=0},music={}} end
 local function Source(source)
  local sound=source.sound
  return {playing=source.playing,timePosition=source.timePosition,frequency=source.frequency,gain=source.gain,
   resource=sound and sound.name or '',length=sound and sound.length or 0}
 end
 local music={};for i,slot in ipairs(self.music) do music[i]=Source(slot.source) end
 return {active=self.active,time=self.time,prepared=self.prepared,voiceUntil=self.voiceUntil,voice=Source(self.voice),music=music}
end
function M:Sfx(id,opt)
 if not self.active then return end
 opt=opt or {}
 local variant=opt.lowpass and self.data.audioDsp and self.data.audioDsp[id..':'..tostring(opt.lowpass)]
 local sound=variant and self.sounds[variant] or self.sounds[id] or self.sounds['sfx_'..id];if not sound then return end
 local slot=nil
 for _,candidate in ipairs(self.sources) do
  if not candidate.source.playing and not candidate.source.fadingOut and not candidate.stopAt and not candidate.fadeWallAt then slot=candidate;break end
 end
 -- Preserve authored overlap and pending stop handles; reuse the idle high-water pool.
 if not slot then
  local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroSfx')
  slot={source=source};self.sources[#self.sources+1]=slot
 end
 slot.source:StopImmediate();slot.stopFade=nil;slot.fadeWallAt=nil;self.sfxSerial=self.sfxSerial+1;slot.token=self.sfxSerial;sound:SetLooped(opt.loop==true)
 local norm=loud[id] and math.min(2,10^((-12-loud[id])/20)) or 1
 slot.base=(opt.vol or 1)*norm*.9
 slot.source:Play(sound,sound:GetFrequency()*(opt.rate or 1),slot.base*self.sfxLevel*self:MasterLevel())
 slot.fadeWallAt=opt.stopAfter and opt.stopFade and Time:GetSystemTime()+opt.stopAfter*1000 or nil
 slot.fadeDuration=opt.stopFade
 slot.stopAt=opt.stopAfter and not opt.stopFade and self.time+opt.stopAfter or nil
 return slot.source,slot.token
end
function M:SfxLevel(slot)
 local fade=slot.stopFade;if not fade then return 1 end
 if fade.duration<=0 then return 0 end
 return fade.from*(1-math.max(0,math.min(1,(self.time-fade.start)/fade.duration)))
end
function M:StopSfx(source,fade,token)
 if not self.active or not source then return false end
 for _,slot in ipairs(self.sources) do if slot.source==source then
  if not slot.base or token and token~=slot.token then return false end
  local duration=math.max(0,fade==nil and .05 or fade)
  slot.fadeWallAt=nil
  slot.stopFade={from=self:SfxLevel(slot),start=self.time,duration=duration}
  slot.stopAt=self.time+duration+.02
  slot.source.gain=slot.base*self.sfxLevel*self:SfxLevel(slot)*self:MasterLevel()
  return true
 end end
 return false
end
function M:Music(id,opt)
 opt=opt or {};local duration=opt.fade==nil and .8 or opt.fade;self:StopMusic(duration);self.musicIndex=self.musicIndex==1 and 2 or 1
 local slot=self.music[self.musicIndex];local sound=self.sounds[id];if not sound then return end
 slot.source:StopImmediate();sound:SetLooped(opt.loop~=false);slot.base=(opt.vol or 1)*.9
 slot.level=duration>0 and 0 or slot.base;slot.target=slot.base;slot.fade=duration;slot.fadeFrom=slot.level;slot.fadeStart=self.time;slot.stopAt=nil
 slot.source:Play(sound,0,slot.level*self:DuckLevel()*self.musicLevel*self:MasterLevel());if opt.offset then slot.source:Seek(opt.offset%sound.length) end
end
function M:StopMusic(fade)
 local duration=math.max(0,fade==nil and .6 or fade)
 for _,slot in ipairs(self.music) do
  slot.level=self:MusicLevel(slot);slot.fadeFrom=slot.level;slot.fadeStart=self.time;slot.target=0;slot.fade=duration;slot.stopAt=self.time+duration+.02
 end
end
function M:MusicLevel(slot)
 if not slot.fadeStart then return slot.level end
 local t=slot.fade<=0 and 1 or math.max(0,math.min(1,(self.time-slot.fadeStart)/slot.fade))
 return slot.fadeFrom+(slot.target-slot.fadeFrom)*t
end
function M:UpdateVoiceGains()
 for _,slot in ipairs(self.voices) do slot.source.gain=.9*self.voiceLevel*self:SfxLevel(slot)*self:MasterLevel() end
end
function M:DuckLevel(at)
 local fade=self.duckFade;if not fade then return self.duck end
 local t=math.max(0,math.min(1,((at or self.time)-fade.start)/fade.duration))
 return fade.from+(fade.target-fade.from)*t
end
function M:Duck(on,at)
 local start=at or self.time
 self.duckFade={from=self:DuckLevel(start),target=on and .24 or .55,start=start,duration=on and .15 or .6}
end
function M:UpdateGains()
 local duck=self:DuckLevel();local master=self:MasterLevel()
 self:UpdateVoiceGains()
 for _,slot in ipairs(self.sources) do if slot.base then slot.source.gain=slot.base*self.sfxLevel*self:SfxLevel(slot)*master end end
 for _,slot in ipairs(self.music) do slot.source.gain=slot.level*duck*self.musicLevel*master end
end
function M:MasterLevel()
 if not self.tail then return 1 end
 return math.max(0,1-self.tail.elapsed/self.tail.duration)
end
function M:BeginTail()
 if not self.active or self.tail then return false end
 -- Approximate the focused audio clock independently of clamped frame dt.
 local now=Time:GetSystemTime()
 self.tail={elapsed=0,lastWall=now,focused=self.focused~=false,duration=1.2,deadline=now+1400}
 return true
end
function M:Update(dt,focused)
 if not self.active then return end
 local isFocused=focused~=false
 if self.tail then
  local now=Time:GetSystemTime();local tail=self.tail
  if now>=tail.deadline then self:Dispose();return end
  -- A focus boundary has no exact timestamp; discard that uncertain interval.
  if isFocused and tail.focused then tail.elapsed=tail.elapsed+math.max(0,now-tail.lastWall)/1000 end
  tail.lastWall=now;tail.focused=isFocused
 end
 self.focused=isFocused
 -- Source tv-cut uses a wall timer even while its audio context is suspended.
 for _,slot in ipairs(self.sources) do if slot.fadeWallAt and Time:GetSystemTime()>=slot.fadeWallAt then
  local start=self.time+(isFocused and dt or 0)
  slot.stopFade={from=self:SfxLevel(slot),start=start,duration=slot.fadeDuration};slot.stopAt=start+slot.fadeDuration+.02;slot.fadeWallAt=nil
 end end
 for _,kind in ipairs({'VoxIntroVoice','VoxIntroSfx','VoxIntroMusic'}) do
  if focused==false then audio:PauseSoundType(kind) else audio:ResumeSoundType(kind) end
 end
 if focused==false then return end
 self.time=self.time+dt
 local master=self:MasterLevel();local speaking=false
 for _,slot in ipairs(self.voices) do
  if slot.untilAt then
   if self:IsVoicePlaying(slot.token) then speaking=true else slot.untilAt=nil end
  end
  if slot.stopAt and self.time>=slot.stopAt then slot.source:StopImmediate();slot.stopAt=nil end
 end
 self:UpdateVoiceGains()
 if self.voiceUntil>0 and not speaking then self.voiceUntil=0;self:Duck(false) end
 for _,slot in ipairs(self.sources) do
  if slot.base then slot.source.gain=slot.base*self.sfxLevel*self:SfxLevel(slot)*master end
  if slot.stopAt and self.time>=slot.stopAt then slot.source:StopImmediate();slot.stopAt=nil end
 end
 for _,slot in ipairs(self.music) do
  slot.level=self:MusicLevel(slot)
  slot.source.gain=slot.level*self:DuckLevel()*self.musicLevel*master
  if slot.stopAt and self.time>=slot.stopAt then slot.source:StopImmediate();slot.stopAt=nil end
 end
end
function M:Dispose()
 if not self.active then return end;self.active=false
 for _,off in ipairs(self.unwatch) do off() end;self.unwatch={}
 -- Retained Lua source handles outlive Scene disposal; detach and release each owner.
 local function Release(slots)
  for _,slot in ipairs(slots) do slot.source:StopImmediate();slot.source:Remove();slot.source:Dispose() end
 end
 Release(self.voices);Release(self.sources);Release(self.music)
 self.scene:Dispose();self.sounds={}
end
return M
