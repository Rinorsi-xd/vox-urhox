-- Frozen WebAudio reveal/heartbeat, rendered offline. Four reusable 2D voices;
-- no oscillators, audio context, delayed callback or per-frame table allocation.
local Data=require('core.ResourceData').Read('Salvage/RevealSounds.json')
local Samples=require('core.ResourceData').Read('Endless/Sounds.json')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local alerts={vaultStart={id='urgent_warning',strength=.7},vaultOpened={id='supply_open',strength=1},airdropLanded={id='wave_start',strength=.8}}
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end
    for _,cue in pairs(alerts) do paths[#paths+1]=Samples.cues[cue.id].path end;return paths
end
function M.New(scene)
    local self=setmetatable({},M);self:init(scene);return self
end
function M:init(scene)
    self.root=scene:CreateChild('SalvageAudio');self.sounds={};self.voices={};self.sampleVoices={};self.counts={};self.cursor=0;self.sampleCursor=0
    self.active=false;self.disposed=false;self.volume=.6;self.last={}
    self.focus=function() return input.focus and not input.minimized end
    self.clock=function() return Time:GetSystemTime()/1000 end
    for id,cue in pairs(Data.cues) do self.sounds[id]=assert(cache:GetResource('Sound',cue.path),cue.path) end
    for _,cue in pairs(alerts) do local path=Samples.cues[cue.id].path;self.sounds[cue.id]=assert(cache:GetResource('Sound',path),path) end
end
function M:Play(id,strength)
    if self.disposed or not self.active or not self.focus() or self.volume<=0 or Levels.Get('sfx')<=0 or not self.sounds[id] then return false end
    local cue=Samples.cues[id];local now=self.clock()
    if cue and now-(self.last[id] or -math.huge)<cue.gap then return false end
    local voices=cue and self.sampleVoices or self.voices;local limit=cue and 10 or 4;local index=false
    for i,source in ipairs(voices) do if not source.playing then index=i;break end end
    if not index then
        if cue then self.sampleCursor=self.sampleCursor%limit+1;index=#voices<limit and #voices+1 or self.sampleCursor
        else self.cursor=self.cursor%limit+1;index=#voices<limit and #voices+1 or self.cursor end
    end
    local source=voices[index]
    if not source then source=self.root:CreateChild((cue and 'Sample' or 'Reveal')..index):CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');voices[index]=source end
    source:StopImmediate()
    Levels.Play(source,self.sounds[id],0,self.volume*(cue and cue.gain or 1)*math.max(0,math.min(1,strength or 1)),0,nil,cue and 'feedback' or nil)
    if cue then self.last[id]=now end
    if id=='urgent_warning' or id=='wave_start' then Levels.FeedbackFor(self.sounds[id].length) end
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Event(event)
    if event.type=='suspense' then return self:Play('suspense') end
    if event.type=='reveal' then return self:Play('reveal'..math.max(0,math.min(5,math.floor(event.item.r)))) end
    local cue=alerts[event.type];if cue then return self:Play(cue.id,cue.strength) end
    return false
end
function M:Stop()
    for _,source in ipairs(self.voices) do source:StopImmediate() end
    for _,source in ipairs(self.sampleVoices) do source:StopImmediate() end
end
function M:SetActive(active)
    self.active=active==true and not self.disposed
    if not self.active or not self.focus() or Levels.Get('sfx')<=0 then self:Stop() end
end
function M:Snapshot() return {counts=self.counts,voices=#self.voices+#self.sampleVoices,active=self.active and self.focus() and not self.disposed} end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.active=false
    self.root:Dispose();self.voices={};self.sampleVoices={};self.sounds={};self.last={};self.root=nil;self.focus=nil;self.clock=nil
end
return M
