-- Original story/radio.js cues, uiSound gain trims, gaps and voice limits.
local Data=require('core.ResourceData').Read('Story/Radio/Radio.json')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.Data() return Data end
function M.Dependencies()
    local out={'Story/Radio/Radio.json'}
    for _,cue in pairs(Data.cues) do out[#out+1]=cue.path end
    table.sort(out);return out
end
function M.New()
    local self=setmetatable({},M);self:init();return self
end
function M:init()
    self.scene=Scene();self.root=self.scene:CreateChild('StoryRadio')
    self.time=0;self.order=0;self.last={};self.slots={};self.sounds={};self.volume=.6;self.active=true;self.disposed=false
    self.focus=function() return input.focus and not input.minimized end
    for name,cue in pairs(Data.cues) do self.sounds[name]=assert(cache:GetResource('Sound',cue.path),cue.path) end
end
function M:Gain(name,strength)
    local cue=Data.cues[name];if not cue then return 0 end
    return cue.gain*math.max(0,math.min(1,strength or cue.strength))*self.volume*Data.master.scale
end
function M:Play(name,strength)
    local cue=Data.cues[name]
    if not cue or self.disposed or not self.active or self.volume<=0 or not self.focus() or self.time-(self.last[name] or -999)<cue.gap then return false end
    local free,oldest,same,oldestSame=nil,1,0,nil
    for i,slot in ipairs(self.slots) do
        if not slot.source.playing and not free then free=i end
        if slot.order<self.slots[oldest].order then oldest=i end
        if slot.source.playing and slot.id==cue.id then same=same+1;if not oldestSame or slot.order<self.slots[oldestSame].order then oldestSame=i end end
    end
    local index=same>=3 and oldestSame or free or (#self.slots<10 and #self.slots+1) or oldest
    local slot=self.slots[index]
    if not slot then slot={source=self.root:CreateChild('Cue'..index):CreateComponent('SoundSource')};self.slots[index]=slot end
    self.last[name]=self.time;self.order=self.order+1;slot.order=self.order;slot.id=cue.id
    slot.source:SetSoundType(cue.bus=='weapons' and 'VoxWeapons' or 'VoxFeedback')
    local sound=self.sounds[name]
    slot.source:StopImmediate();Levels.Play(slot.source,sound,0,self:Gain(name,strength),nil,nil,cue.bus)
    if name=='open' or name=='intercept' or name=='install' or name=='alert' or name=='done' then Levels.FeedbackFor(sound.length) end
    return true
end
function M:Update(dt,focus)
    if self.disposed then return end
    self.time=self.time+math.max(0,dt)
    self.active=focus~=false and self.focus()
    if not self.active or self.volume<=0 then for _,slot in ipairs(self.slots) do slot.source:StopImmediate() end end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.scene:Dispose();self.slots={};self.sounds={}
end
return M
