local Data=require('core.ResourceData').Read('Endless/Sounds.json')
local Vec=require('core.Math3')
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
local cues={drop='loot_drop',dropCollected='loot_pickup',waveClear='wave_clear',supplyShown='supply_open',supplyChosen='supply_choose',charge='urgent_warning'}
local flow={countdown_tick=true,wave_start=true,boss_warning=true,urgent_warning=true,game_over=true}
function M.Dependencies() local out={};for _,cue in pairs(Data.cues) do out[#out+1]=cue.path end;return out end
function M.New(scene)
    return setmetatable({root=scene:CreateChild('EndlessAudio'),voices={},last={},counts={},clock=0,cursor=0,tick=false,volume=.65},M)
end
function M:Stop() for _,source in ipairs(self.voices) do source:StopImmediate() end end
function M:Play(id,point,camera)
    local cue=Data.cues[id];if self.disposed or self.volume<=0 or not cue or not input.focus or input.minimized or self.clock-(self.last[id] or -999)<cue.gap then return false end
    local gain,pan=1,0
    if point and camera then
        local p=camera.worldPosition;local delta=Vec.Sub(point,{-p.x,p.y,p.z});local distance=Vec.Length(delta);local r=camera.worldRotation*Vector3.RIGHT
        gain=distance>=240 and 0 or 1/(1+(distance/24)^2);pan=distance>0 and Vec.Clamp(Vec.Dot(delta,{-r.x,r.y,r.z})/distance,-.85,.85) or 0
    end
    if gain<=.005 then return false end
    self.last[id]=self.clock;self.cursor=self.cursor%10+1;local source=self.voices[self.cursor]
    if not source then source=self.root:CreateChild('EndlessCue'..self.cursor):CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');self.voices[self.cursor]=source end
    local sound=cache:GetResource('Sound',cue.path)
    source:StopImmediate();Levels.Play(source,sound,0,cue.gain*gain*self.volume,pan,nil,'feedback')
    if flow[id] then Levels.FeedbackFor(sound.length) end
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Event(e,camera)
    if e.type=='dropCollected' and e.reason=='overflow' then return end
    local id=e.type=='waveStart' and (e.boss and 'boss_warning' or 'wave_start') or cues[e.type]
    if id then self:Play(id,e.type=='drop' and e.drop.pos or nil,camera) end
end
function M:Update(dt,run,camera,volume)
    if self.disposed then return end
    self.clock=self.clock+math.max(0,dt);self.volume=volume~=nil and math.max(0,math.min(1,volume)) or self.volume
    if self.volume<=0 or not input.focus or input.minimized or run.state=='editing' then self:Stop();return end
    local tick=run.state=='countdown' and math.ceil(run.countdown) or false
    if tick~=self.tick and tick and tick>0 and tick<=5 then self:Play('countdown_tick',nil,camera) end;self.tick=tick
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self:Stop();self.root:Dispose();self.voices={};self.root=nil
end
return M
