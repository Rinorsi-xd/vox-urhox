-- Frozen WebAudio reveal/heartbeat, rendered offline. Four reusable 2D voices;
-- no oscillators, audio context, delayed callback or per-frame table allocation.
local Data=require('core.ResourceData').Read('Salvage/RevealSounds.json')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;return paths
end
function M.New(scene)
    local self=setmetatable({},M);self:init(scene);return self
end
function M:init(scene)
    self.root=scene:CreateChild('SalvageAudio');self.sounds={};self.voices={};self.counts={};self.cursor=0
    self.active=false;self.disposed=false;self.volume=.6
    self.focus=function() return input.focus and not input.minimized end
    for id,cue in pairs(Data.cues) do self.sounds[id]=assert(cache:GetResource('Sound',cue.path),cue.path) end
end
function M:Play(id)
    if self.disposed or not self.active or not self.focus() or self.volume<=0 or not self.sounds[id] then return false end
    local index=false
    for i,source in ipairs(self.voices) do if not source.playing then index=i;break end end
    if not index then self.cursor=self.cursor%4+1;index=#self.voices<4 and #self.voices+1 or self.cursor end
    local source=self.voices[index]
    if not source then source=self.root:CreateChild('Reveal'..index):CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');self.voices[index]=source end
    source:StopImmediate();Levels.Play(source,self.sounds[id],0,math.min(1,self.volume))
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Event(event)
    if event.type=='suspense' then return self:Play('suspense') end
    if event.type=='reveal' then return self:Play('reveal'..math.max(0,math.min(5,math.floor(event.item.r)))) end
    return false
end
function M:Stop() for _,source in ipairs(self.voices) do source:StopImmediate() end end
function M:SetActive(active)
    self.active=active==true and not self.disposed
    if not self.active or not self.focus() then self:Stop() end
end
function M:Snapshot() return {counts=self.counts,voices=#self.voices,active=self.active and self.focus() and not self.disposed} end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.active=false
    self.root:Dispose();self.voices={};self.sounds={};self.root=nil;self.focus=nil
end
return M
