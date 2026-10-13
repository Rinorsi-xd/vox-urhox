-- Frozen approved samples; ten reusable voices, one queue loop, one radio.
local Data=require('core.ResourceData').Read('Combat/FlowSounds.json')
local M={};M.__index=M
function M.Dependencies(queue)
    local paths={}
    for id,cue in pairs(Data.cues) do if queue or id~='match_search' and id~='match_found_latch' then paths[#paths+1]=cue.path end end
    if queue then for _,id in ipairs(Data.foundVoice) do paths[#paths+1]='Sounds/Match/'..id..'.wav' end end
    return paths
end
function M.New()
    local self=setmetatable({},M);self:init();return self
end
function M:init()
    self.scene=Scene();self.root=self.scene:CreateChild('BattleFlowAudio');self.time=0;self.cursor=0;self.last={};self.slots={};self.ready=false;self.disposed=false
    self.gate=require('app.ResourceGate').New()
end
function M:Prepare(queue)
    self.gate:Start(M.Dependencies(queue),function(ok) if not self.disposed then self.ready=ok end end)
end
function M:Source(name)
    local node=self.root:CreateChild(name);local source=node:CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');return source
end
function M:Play(id)
    if self.disposed or not self.ready or not input.focus or input.minimized then return false end
    local cue=Data.cues[id];if not cue or self.time-(self.last[id] or -999)<cue.gap then return false end
    self.last[id]=self.time
    if cue.pool then cue=Data.cues[cue.pool[math.random(1,#cue.pool)]] end
    self.cursor=self.cursor%10+1;local source=self.slots[self.cursor]
    if not source then source=self:Source('Feedback'..self.cursor);self.slots[self.cursor]=source end
    source:StopImmediate();source:Play(cache:GetResource('Sound',cue.path),0,math.min(1,cue.gain));return true
end
function M:Queue(enabled)
    self.search=enabled
    if not enabled then if self.loop then self.loop:StopImmediate() end;return end
    if not self.ready or self.disposed or not input.focus or input.minimized then return end
    if not self.loop then self.loop=self:Source('Search') end
    if not self.loop.playing then local cue=Data.cues.match_search;local sound=cache:GetResource('Sound',cue.path);sound.looped=true;self.loop:Play(sound,0,math.min(1,cue.gain)) end
end
function M:Found()
    self:Queue(false);self:Play('match_found_latch');self.voiceAt=self.time+.38
end
function M:Event(e)
    local id
    if e.type=='roundStart' or e.type=='halfStart' then id='engage'
    elseif e.type=='roundEnd' and e.winner then id=e.winner=='blue' and 'round_win' or 'round_lose'
    elseif e.type=='suddenDeath' or e.type=='overtime' then id='urgent_warning'
    elseif e.type=='pointTaken' and e.team=='blue' then id='objective_gain'
    elseif e.type=='pointLost' and e.team=='blue' then id='objective_loss'
    elseif e.type=='checkpoint' then id=e.attack=='blue' and 'objective_gain' or 'objective_loss'
    elseif e.type=='matchOver' and e.winner then id=e.winner=='blue' and 'match_victory' or 'game_over' end
    if id then self:Play(id) end
end
function M:Countdown(remaining,active)
    local tick=active and math.ceil(remaining) or false
    if tick~=self.tick and tick and tick>0 and tick<=5 then self:Play('countdown_tick') end
    self.tick=tick
end
function M:Update(dt)
    if self.disposed then return end;self.time=self.time+math.max(0,dt)
    if self.search then self:Queue(true) end
    if not input.focus or input.minimized then
        if self.loop then self.loop:StopImmediate() end
        if self.voice then self.voice:StopImmediate() end
        for _,source in ipairs(self.slots) do source:StopImmediate() end
        self.voiceAt=nil
    elseif self.voiceAt and self.time>=self.voiceAt then
        self.voiceAt=nil
        if self.ready then
            if not self.voice then self.voice=self:Source('FoundRadio') end
            local id=Data.foundVoice[math.random(1,#Data.foundVoice)]
            self.voice:Play(cache:GetResource('Sound','Sounds/Match/'..id..'.wav'),0,.7)
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.gate:Cancel();self.scene:Dispose();self.slots={}
end
return M
