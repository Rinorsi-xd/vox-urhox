-- Frozen approved samples; ten reusable voices, one queue loop, one radio.
local ResourceGate=require("app.ResourceGate")

local Data=require('core.ResourceData').Read('Combat/FlowSounds.json')
local Levels=require 'audio.AudioLevels'
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
    self.gate=ResourceGate.New()
    self.sounds={};self.preparation={};self.preparationIndex=1;self.decoding={};self.decodeCursor=1;self.failure=nil;self.downloadReady=false
end
function M:Prepare(queue,checkpoint)
    self.gate:Cancel();self.ready=false;self.failure=nil;self.downloadReady=false
    self.sounds={};self.preparation={};self.preparationIndex=1;self.decoding={};self.decodeCursor=1
    local paths,seen={},{}
    for _,path in ipairs(M.Dependencies(queue)) do if not seen[path] then seen[path]=true;paths[#paths+1]=path end end
    table.sort(paths)
    for i,path in ipairs(paths) do
        local sound=cache:GetExistingResource('Sound',path)
        if not sound or sound.length<=0 then
            if checkpoint then sound=assert(cache:GetResource('Sound',path),'Cannot prepare battle sound: '..path)
            else self.preparation[#self.preparation+1]=path end
        end
        if sound and sound.length>0 then self.sounds[path]=sound
        elseif checkpoint then error('Invalid battle sound: '..path) end
        if checkpoint then checkpoint(i/#paths,'battle-audio') end
    end
    if #self.preparation==0 then self.ready=true;return end
    self.gate:Start(paths,function(ok,message)
        if self.disposed then return end
        -- Download completion may hold native locks; only signal the next Update.
        self.downloadReady=ok==true;self.failure=not ok and tostring(message) or nil
    end)
end
function M:PreparePending()
    if self.ready or self.failure or not self.downloadReady then return end
    local path=self.preparation[self.preparationIndex]
    if path then
        self.preparationIndex=self.preparationIndex+1
        local sound=cache:GetExistingResource('Sound',path)
        if sound and sound.length>0 then self.sounds[path]=sound
        else
            cache:BackgroundLoadResource('Sound',path,true)
            self.decoding[#self.decoding+1]={path=path,at=self.time}
        end
    end
    local pending=self.decoding
    for _=1,math.min(4,#pending) do
        if #pending==0 then break end
        local index=self.decodeCursor;local item=pending[index]
        local sound=cache:GetExistingResource('Sound',item.path)
        if sound and sound.length>0 then
            self.sounds[item.path]=sound;pending[index]=pending[#pending];table.remove(pending)
        elseif self.time-item.at>20 then self.failure='Battle sound preparation timed out: '..item.path;return
        else
            -- Decoded but unreferenced sounds can be evicted before this poll; requeue when idle.
            if (item.requeues or 0)<3 and cache:GetNumBackgroundLoadResources()==0 then
                item.requeues=(item.requeues or 0)+1;cache:BackgroundLoadResource('Sound',item.path,true)
            end
            self.decodeCursor=index+1
        end
        if self.decodeCursor>#pending then self.decodeCursor=1 end
    end
    self.ready=self.preparationIndex>#self.preparation and #pending==0
end
function M:Source(name)
    local node=self.root:CreateChild(name);local source=node:CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');return source
end
function M:Play(id)
    if self.disposed or not self.ready or not input.focus or input.minimized then return false end
    local cue=Data.cues[id];if not cue or self.time-(self.last[id] or -999)<cue.gap then return false end
    if cue.pool then cue=Data.cues[cue.pool[math.random(1,#cue.pool)]] end
    local sound=self.sounds[cue.path];if not sound then return false end
    self.last[id]=self.time
    self.cursor=self.cursor%10+1;local source=self.slots[self.cursor]
    if not source then source=self:Source('Feedback'..self.cursor);self.slots[self.cursor]=source end
    source:StopImmediate();Levels.Play(source,sound,0,cue.gain,nil,nil,'feedback');Levels.FeedbackFor(sound.length);return true
end
function M:Queue(enabled)
    self.search=enabled
    if not enabled then if self.loop then self.loop:StopImmediate() end;return end
    if not self.ready or self.disposed or not input.focus or input.minimized then return end
    if not self.loop then self.loop=self:Source('Search') end
    if not self.loop.playing then local cue=Data.cues.match_search;local sound=self.sounds[cue.path];if sound then sound.looped=true;Levels.Play(self.loop,sound,0,cue.gain,nil,nil,'feedback') end end
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
    self:PreparePending()
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
            local sound=self.sounds['Sounds/Match/'..id..'.wav']
            if sound then Levels.Play(self.voice,sound,0,.7,nil,'voice') end
        end
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.gate:Cancel();self.search=false;self.voiceAt=nil
    -- Lua still references these components after the scene dies; stop them explicitly.
    if self.loop then self.loop:StopImmediate();self.loop=nil end
    if self.voice then self.voice:StopImmediate();self.voice=nil end
    for _,source in ipairs(self.slots) do source:StopImmediate() end
    self.scene:Dispose();self.slots={};self.sounds={};self.preparation={};self.decoding={}
end
return M
