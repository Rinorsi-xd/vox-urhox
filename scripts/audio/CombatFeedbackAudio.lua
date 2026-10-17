-- Source WAV feedback, bounded voices and an event-driven repair loop.
local Data=require('core.ResourceData').Read('Combat/FeedbackSounds.json')
local Mix=require 'audio.RecoveryMix'
local V=require 'core.Math3'
local DAMAGE={vehicleCollision='vehicle_collision',unitKilled='vehicle_destroy',shieldRaise='shield_up',shieldUp='shield_up',shieldHit='shield_hit',shieldDown='shield_down',hullBreach='shield_down'}
local DAMAGE_CUES={vehicle_collision=true,vehicle_destroy=true,part_break=true,part_detach=true,shield_up=true,shield_hit=true,shield_down=true}
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
-- 源 RecoveryMix.pitchLine：维修时叠一根很轻的正弦「音调线」，随血量从 E4 升到 E5（repairPitchHz = 330·2^h），
-- 音量 0.045 × repairAmount，不做空间化。采样是 330 Hz 的 11 个整周期（1470 个采样 @44.1 kHz，单声道 16 位），
-- 循环无缝，音高靠播放频率调整。
local LINE_HZ,LINE_RATE,LINE_PATH=330,44100,'Sounds/CombatFeedback/repair_pitch_line.wav'
-- 源 WebAudio setTargetAtTime 的逐帧近似（与原有维修循环的增益平滑一致，按 60 fps 推进）
local function Approach(current,target,tc) return current+(target-current)*(1-math.exp(-1/60/tc)) end
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;paths[#paths+1]=LINE_PATH;return paths
end
function M.New(scene) local self=setmetatable({},M);self:init(scene);return self end
function M:init(scene)
    self.root=scene:CreateChild('CombatFeedbackAudio');self.sounds={};self.voices={};self.counts={};self.last={};self.pending={}
    self.time=0;self.cursor=0;self.active=false;self.disposed=false;self.volume=.65;self.duck=1;self.mix=Mix.New();self.silent=true
    self.seen=setmetatable({},{__mode='k'});self.listener={0,0,0};self.right={1,0,0};self.killAt=-math.huge
    self.focus=function() return input.focus and not input.minimized end
    self.emit=function(id,point,rate) local gain,pan=self:Spatial(point,18);self:Play(id,gain,pan,rate) end
    for id,cue in pairs(Data.cues) do local sound=assert(cache:GetResource('Sound',cue.path),cue.path);sound.looped=cue.loop;self.sounds[id]=sound end
    self.lineSound=assert(cache:GetResource('Sound',LINE_PATH),LINE_PATH);self.lineSound.looped=true
end
function M:Source(name)
    local source=self.root:CreateChild(name):CreateComponent('SoundSource');source:SetSoundType('VoxFeedback');return source
end
function M:Audible() return not self.disposed and self.active and self.volume>0 and self.focus() end
function M:Spatial(point,reference)
    if not point then return 1,0 end
    local delta=V.Sub(point,self.listener);local distance=V.Length(delta)
    return distance>=240 and 0 or 1/(1+(distance/reference)^2),distance>0 and V.Clamp(V.Dot(delta,self.right)/distance,-.85,.85) or 0
end
function M:Play(id,amount,pan,rate)
    local cue=Data.cues[id];amount=math.max(0,math.min(1,amount or 1))
    if not cue or cue.loop or amount<=.005 or not self:Audible() or self.time-(self.last[id] or -999)<cue.gap then return false end
    self.last[id]=self.time
    self.silent=false
    local sample=id
    if cue.pool then sample=cue.pool[math.random(1,#cue.pool)];cue=Data.cues[sample] end
    self.cursor=self.cursor+1
    local free,oldest,same,oldestSame=nil,1,0,nil
    for i,voice in ipairs(self.voices) do
        if not voice.source.playing and not free then free=i end
        if voice.order<self.voices[oldest].order then oldest=i end
        if voice.source.playing and voice.id==id then same=same+1;if not oldestSame or voice.order<self.voices[oldestSame].order then oldestSame=i end end
    end
    local index=same>=3 and oldestSame or free or (#self.voices<10 and #self.voices+1) or oldest
    local voice=self.voices[index];if not voice then voice={source=self:Source('Feedback'..index)};self.voices[index]=voice end
    voice.source:StopImmediate();voice.order=self.cursor;voice.id=id
    local sound=self.sounds[sample];local pitch=rate or (cue.jitter and .97+math.random()*.06 or 1)
    Levels.Play(voice.source,sound,sound:GetFrequency()*pitch,cue.gain*amount*self.volume,pan or 0,nil,DAMAGE_CUES[id] and 'damage' or 'feedback')
    if id=='kill_confirm' or id=='objective_gain' or id=='game_over' then Levels.FeedbackFor(sound.length) end
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Hit(tier)
    if tier=='kill' then self.killAt=self.time end
    return self:Play(tier=='kill' and 'kill_confirm' or tier=='break' and 'break_tick' or 'hit_tick')
end
function M:Destroy(gain,pan)
    if not self:Audible() or (gain or 1)<=.005 then return false end
    if #self.pending>=10 then table.remove(self.pending,1) end
    self.pending[#self.pending+1]={at=self.time+.12,gain=gain or 1,pan=pan or 0}
    self.silent=false;return true
end
function M:Kill(streak)
    self:Hit('kill');self:Destroy(.7,0)
    local n=math.min(streak or 1,5)
    if n>1 then self:Play('objective_gain',.6+.1*n) end
end
function M:ScoreTick() return self:Play('score_tick') end
function M:Stop()
    if self.silent then return end;self.silent=true
    for _,voice in ipairs(self.voices) do voice.source:StopImmediate();Levels.SetGain(voice.source,0) end
    if self.loop then self.loop:StopImmediate();Levels.SetGain(self.loop,0) end
    if self.line then self.line:StopImmediate();Levels.SetGain(self.line,0) end
    self.pending={};self.mix:Reset()
end
function M:SetActive(active)
    local nextActive=active==true
    if self.active and not nextActive then self:Stop() end;self.active=nextActive
end
function M:Update(dt,camera,speaking)
    if self.disposed then return end;self.time=self.time+math.max(0,dt)
    local p=camera.worldPosition;local right=camera.worldRotation*Vector3.RIGHT
    self.listener[1]=-p.x;self.listener[2]=p.y;self.listener[3]=p.z
    self.right[1]=-right.x;self.right[2]=right.y;self.right[3]=right.z
    if not self:Audible() then self:Stop();return end
    -- Match source setTimeout registration order when several deaths coincide.
    while self.pending[1] and self.time>=self.pending[1].at do
        local e=table.remove(self.pending,1)
        self:Play('vehicle_destroy',e.gain*(self.time-self.killAt<.4 and .71 or 1),e.pan)
    end
end
function M:Consume(events,unit)
    if not self:Audible() then return end
    self.silent=false
    for _,e in ipairs(events) do if not self.seen[e] then
        self.seen[e]=true
        local id=DAMAGE[e.type]
        if e.type=='partRemoved' then id=e.reason=='disconnect' and 'part_detach' or 'part_break' end
        if id then
            local point=e.point or e.pos or e.unit and e.unit:Position();local gain,pan=self:Spatial(point,32);gain=gain*(e.strength or 1)
            if id=='vehicle_destroy' then
                self:Destroy(gain,pan)
            else self:Play(id,gain,pan) end
        end
    end end
    self.mix:Consume(events,unit,self.emit)
    local amount=self.mix.amount
    local sound=self.sounds.repair_loop
    if amount>.005 then
        if not self.loop then self.loop=self:Source('Repair') end
        local gain,pan=self:Spatial(self.mix.position,18)
        local volume=Data.cues.repair_loop.gain*amount*gain*self.volume
        local target=sound:GetFrequency()*self.mix.rate
        if not self.loop.playing then Levels.Play(self.loop,sound,target,0,pan,nil,'feedback') end
        Levels.SetGain(self.loop,Approach(Levels.RawGain(self.loop),volume,.12))
        self.loop.frequency=Approach(self.loop.frequency,target,.12);self.loop.panning=pan
    elseif self.loop and self.loop.playing then
        -- 源 setLoop 收尾：增益按 0.06 s 时间常数淡出后再停，不硬切
        local faded=Approach(Levels.RawGain(self.loop),0,.06);Levels.SetGain(self.loop,faded)
        if faded<1e-4 then self.loop:StopImmediate();Levels.SetGain(self.loop,0) end
    end
    self:PitchLine(amount>.005,self.mix.health or 1)
end
function M:PitchLine(on,health)
    if on and not (self.line and self.line.playing) then
        if not self.line then self.line=self:Source('RepairPitch') end
        Levels.Play(self.line,self.lineSound,LINE_RATE*2^math.max(0,math.min(1,health)),0,0,nil,'feedback')
    end
    if not self.line or not self.line.playing then return end
    if on then
        local h=math.max(0,math.min(1,health))
        Levels.SetGain(self.line,Approach(Levels.RawGain(self.line),.045*Mix.Amount(h)*self.volume,.06))
        self.line.frequency=Approach(self.line.frequency,LINE_RATE*2^h,.06)
    else
        local faded=Approach(Levels.RawGain(self.line),0,.05);Levels.SetGain(self.line,faded)
        if faded<1e-4 then self.line:StopImmediate();Levels.SetGain(self.line,0) end
    end
end
function M:Snapshot()
    return {active=self:Audible(),counts=self.counts,voices=#self.voices,pending=#self.pending,
        repair={playing=self.loop and self.loop.playing or false,gain=self.loop and self.loop.gain or 0,rate=self.mix.rate,amount=self.mix.amount,
            line=self.line and self.line.playing or false,lineHz=self.line and self.line.playing and self.line.frequency/LINE_RATE*LINE_HZ or 0}}
end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.root:Dispose();self.sounds={};self.voices={}
end
return M
