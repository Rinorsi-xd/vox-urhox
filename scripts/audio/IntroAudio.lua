-- Retained audio scene; page transitions never dispose a playing voice.
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local loud={alarm=-7.9,blip=-22.9,clang=-8,confirm=-12.9,crt_on=-27.2,door_open=-10.4,heartbeat=-4.3,holo_shatter=-9.8,
 laser_big=-6.5,laser_boom=-3.9,laser_charge=-11.5,pigeon=-4.8,scratch=-9,scribble=-30.1,shred=-12.1,slam=-4.6,spotlight=-13.4,stamp=-9.2,tv_cut=-8.6,whoosh=-8.6}
function M.New(data)
 local self=setmetatable({},M);self:init(data);return self
end
function M:init(data)
 self.data=data;self.scene=Scene();self.root=self.scene:CreateChild('IntroAudio');self.sounds={};self.queue={};self.sources={};self.music={};self.musicIndex=0
 self.voice=self.root:CreateComponent('SoundSource');self.voice:SetSoundType('VoxIntroVoice')
 for i=1,10 do local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroSfx');self.sources[i]={source=source} end
 for i=1,2 do local source=self.root:CreateComponent('SoundSource');source:SetSoundType('VoxIntroMusic');self.music[i]={source=source,level=0,target=0,base=0} end
 for id,path in pairs(data.audio) do self.queue[#self.queue+1]={id=id,path=path} end
 table.sort(self.queue,function(a,b)return a.id<b.id end)
 self.prepared=0;self.active=true;self.voiceUntil=0;self.time=0
 self.voiceLevel=Levels.Get('voice')/.6;self.sfxLevel=Levels.Get('sfx');self.musicLevel=Levels.MusicGain(Levels.Get('music'))/Levels.MusicGain(.75)
 self.unwatch={Levels.On('voice',function(value) self.voiceLevel=value/.6;self.voice.gain=.9*self.voiceLevel end),
  Levels.On('sfx',function(value) self.sfxLevel=value;for _,slot in ipairs(self.sources) do if slot.base then slot.source.gain=slot.base*value end end end),
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
 self.voice:StopImmediate();local sound=self.sounds[id]
 if not sound then return 0 end
 self.voice:Play(sound,0,.9*self.voiceLevel);self.voiceUntil=self.time+sound.length;return sound.length
end
function M:StopVoice() self.voice:StopImmediate();self.voiceUntil=0 end
function M:Snapshot()
 local function Source(source)
  local sound=source.sound
  return {playing=source.playing,timePosition=source.timePosition,frequency=source.frequency,gain=source.gain,
   resource=sound and sound.name or '',length=sound and sound.length or 0}
 end
 local music={};for i,slot in ipairs(self.music) do music[i]=Source(slot.source) end
 return {active=self.active,time=self.time,prepared=self.prepared,voiceUntil=self.voiceUntil,voice=Source(self.voice),music=music}
end
function M:Sfx(id,opt)
 opt=opt or {};local sound=self.sounds[id] or self.sounds['sfx_'..id];if not sound then return end
 local slot=nil
 for _,candidate in ipairs(self.sources) do if not candidate.source.playing then slot=candidate;break end end
 if not slot then slot=self.sources[1] end
 slot.source:StopImmediate();sound:SetLooped(opt.loop==true)
 local norm=loud[id] and math.min(2,10^((-12-loud[id])/20)) or 1
 slot.base=(opt.vol or 1)*norm*.9
 slot.source:Play(sound,sound:GetFrequency()*(opt.rate or 1),slot.base*self.sfxLevel)
 slot.stopAt=opt.stopAfter and self.time+opt.stopAfter or nil
 return slot.source
end
function M:Music(id,opt)
 opt=opt or {};self:StopMusic(opt.fade or .8);self.musicIndex=self.musicIndex==1 and 2 or 1
 local slot=self.music[self.musicIndex];local sound=self.sounds[id];if not sound then return end
 slot.source:StopImmediate();sound:SetLooped(opt.loop~=false);slot.base=(opt.vol or 1)*.9
 slot.level=opt.fade and opt.fade>0 and 0 or slot.base;slot.target=slot.base;slot.fade=opt.fade or .8
 slot.source:Play(sound,0,slot.level*.55*self.musicLevel);if opt.offset then slot.source:Seek(opt.offset%sound.length) end
end
function M:StopMusic(fade)
 for _,slot in ipairs(self.music) do slot.target=0;slot.fade=fade or .6 end
end
function M:UpdateGains()
 local duck=self.time<self.voiceUntil and .24 or .55
 for _,slot in ipairs(self.music) do slot.source.gain=slot.level*duck*self.musicLevel end
end
function M:Update(dt,focused)
 for _,kind in ipairs({'VoxIntroVoice','VoxIntroSfx','VoxIntroMusic'}) do
  if focused==false then audio:PauseSoundType(kind) else audio:ResumeSoundType(kind) end
 end
 if focused==false then return end
 self.time=self.time+dt
 for _,slot in ipairs(self.sources) do if slot.stopAt and self.time>=slot.stopAt then slot.source:StopImmediate();slot.stopAt=nil end end
 for _,slot in ipairs(self.music) do
  local delta=dt/math.max(.001,slot.fade or .8)
  if slot.level<slot.target then slot.level=math.min(slot.target,slot.level+delta*math.max(.001,slot.base))
  else slot.level=math.max(slot.target,slot.level-delta*math.max(.001,slot.base)) end
  local duck=self.time<self.voiceUntil and .24 or .55;slot.source.gain=slot.level*duck*self.musicLevel
  if slot.level==0 and slot.target==0 and slot.source.playing then slot.source:StopImmediate() end
 end
end
function M:Dispose()
 if not self.active then return end;self.active=false
 for _,off in ipairs(self.unwatch) do off() end;self.unwatch={}
 self.voice:StopImmediate();for _,s in ipairs(self.sources) do s.source:StopImmediate() end
 for _,s in ipairs(self.music) do s.source:StopImmediate() end
 self.scene:Dispose();self.sounds={}
end
return M
