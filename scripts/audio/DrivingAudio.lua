local DrivingEvents=require("audio.DrivingEvents")

local Data=require('core.ResourceData').Read('Combat/DrivingSounds.json')
local Mix=require 'audio.DrivingMix'
local V=require 'core.Math3'
local NEUTRAL={}
-- Remote loop keys are built once; concatenating them every frame only made garbage.
local REMOTE={};for _,id in ipairs(Mix.ids) do REMOTE[id]='remote:'..id end
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;return paths
end
function M.New(scene) local self=setmetatable({},M);self:init(scene);return self end
function M:init(scene)
    self.root=scene:CreateChild('DrivingAudio');self.sounds={};self.loops={};self.loopSources={};self.loopTails={};self.voices={};self.last={};self.counts={}
    self.localMix=Mix.New();self.remoteMix=Mix.New();self.best=Mix.New();self.events=DrivingEvents.New()
    self.time=0;self.cursor=0;self.volume=.65;self.duck=1;self.active=false;self.disposed=false;self.stepPitch=1;self.silent=true
    self.listener={0,0,0};self.right={1,0,0}
    self.focus=function() return input.focus and not input.minimized end
    self.emit=function(id,amount) self:Play(id,amount*self.eventGain,self.eventPan) end
    for id,cue in pairs(Data.cues) do local sound=assert(cache:GetResource('Sound',cue.path),cue.path);sound.looped=cue.loop;self.sounds[id]=sound end
end
function M:Source(name)
    local source=self.root:CreateChild(name):CreateComponent('SoundSource');source:SetSoundType('VoxDriving');return source
end
function M:Audible() return not self.disposed and self.active and self.volume>0 and self.focus() end
function M:Stop()
    if self.silent then return end;self.silent=true
    for _,slot in ipairs(self.loopSources) do slot.source:StopImmediate();Levels.SetGain(slot.source,0) end
    for _,loop in pairs(self.loops) do loop.gain=0;loop.released=true end
    self.loopTails={}
    for _,voice in ipairs(self.voices) do voice.source:StopImmediate();Levels.SetGain(voice.source,0) end
    self.events:Clear()
end
function M:SetActive(active)
    local nextActive=active==true
    if self.active and not nextActive then self:Stop() end;self.active=nextActive
end
function M:Spatial(vehicle)
    local p=vehicle.body.translation();local dx,dy,dz=p.x-self.listener[1],p.y-self.listener[2],p.z-self.listener[3]
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    return distance>=240 and 0 or 1/(1+(distance/18)^2),distance>0 and V.Clamp((dx*self.right[1]+dy*self.right[2]+dz*self.right[3])/distance,-.85,.85) or 0
end
-- Threshold hysteresis. Below .005 the voice follows exactly the authored release
-- tail (gain*exp(-dt/release), five tau). If the amount comes back inside that
-- tail the same voice continues instead of restarting the sample from zero,
-- which is what made threshold jitter (speed .15, hover force, distance cut)
-- stutter and churn the 20-source pool. A real release ends at the same time.
function M:Hold(loop,dt)
    local step=math.max(0,dt);loop.hold=(loop.hold or 0)+step
    if loop.hold>=loop.release*5 then
        loop.released=true;loop.hold=nil;loop.gain=0;loop.source:StopImmediate();Levels.SetGain(loop.source,0);return
    end
    loop.gain=loop.gain*math.exp(-step/loop.release)
    loop.pitch=loop.pitch+(loop.pitchTarget-loop.pitch)*(1-math.exp(-step/.12))
    loop.pan=loop.pan+(loop.panTarget-loop.pan)*(1-math.exp(-step/.08))
    Levels.SetGain(loop.source,loop.gain);loop.source.frequency=self.sounds[loop.id]:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
end
function M:Loop(key,id,amount,pitch,pan,dt)
    local cue=Data.cues[id];amount=self:Audible() and amount or 0
    local loop=self.loops[key]
    if amount<=.005 then
        if loop and not loop.released and loop.pitchTarget and loop.source.playing then self:Hold(loop,dt)
        else self:ReleaseLoop(key) end
        return false
    end
    if loop then loop.hold=nil end
    if not loop or loop.released or not loop.source.playing then
        local slot=nil ---@type table|nil
        for _,candidate in ipairs(self.loopSources) do if not candidate.source.playing and candidate.key==key then slot=candidate;break end end
        if not slot then for _,candidate in ipairs(self.loopSources) do if not candidate.source.playing then slot=candidate;break end end end
        if not slot then
            if #self.loopSources>=20 then return false end
            slot={source=self:Source(key)};self.loopSources[#self.loopSources+1]=slot
        end
        local previous=slot.key and self.loops[slot.key]
        if slot.key~=key and previous and previous.source==slot.source then self.loops[slot.key]=nil end
        slot.key=key;slot.id=id
        loop={source=slot.source,id=id,gain=0,pitch=1,pan=0,release=cue.release};self.loops[key]=loop
    end
    self.silent=false
    local step=math.max(0,dt);local target=cue.gain*math.min(1,amount)*self.volume
    local alpha=1-math.exp(-step/cue.attack)
    loop.gain=loop.gain+(target-loop.gain)*alpha
    loop.pitchTarget=V.Clamp(pitch,.65,1.5);loop.panTarget=pan
    loop.pitch=loop.pitch+(loop.pitchTarget-loop.pitch)*(1-math.exp(-step/.12))
    loop.pan=loop.pan+(loop.panTarget-loop.pan)*(1-math.exp(-step/.08))
    local sound=self.sounds[id]
    if not loop.source.playing then
        Levels.Play(loop.source,sound,sound:GetFrequency()*loop.pitch,loop.gain,loop.pan,nil,'driving');self.counts[id]=(self.counts[id] or 0)+1
    end
    Levels.SetGain(loop.source,loop.gain);loop.source.frequency=sound:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
    return true
end
function M:ReleaseLoop(key)
    local loop=self.loops[key]
    if not loop or loop.released then return end
    -- Releasing removes the active key; a restart must not reclaim its tail.
    loop.released=true;loop.releaseAge=loop.hold or 0;loop.hold=nil;self.loopTails[#self.loopTails+1]=loop
end
function M:UpdateLoopTails(dt)
    local step=math.max(0,dt)
    for i=#self.loopTails,1,-1 do local loop=self.loopTails[i]
        loop.releaseAge=loop.releaseAge+step
        loop.gain=loop.gain*math.exp(-step/loop.release)
        loop.pitch=loop.pitch+(loop.pitchTarget-loop.pitch)*(1-math.exp(-step/.12))
        loop.pan=loop.pan+(loop.panTarget-loop.pan)*(1-math.exp(-step/.08))
        Levels.SetGain(loop.source,loop.gain);loop.source.frequency=self.sounds[loop.id]:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
        if loop.releaseAge>=loop.release*5 then loop.source:StopImmediate();Levels.SetGain(loop.source,0);loop.gain=0;table.remove(self.loopTails,i) end
    end
end
function M:Play(id,amount,pan)
    local cue=Data.cues[id]
    if not cue or cue.loop or not self:Audible() or amount<=.005 or self.time-(self.last[id] or -999)<cue.gap then return false end
    self.last[id]=self.time;self.cursor=self.cursor+1
    self.silent=false
    local index,oldest=nil,1
    for i,voice in ipairs(self.voices) do if not voice.source.playing and not index then index=i end;if voice.order<self.voices[oldest].order then oldest=i end end
    index=index or (#self.voices<3 and #self.voices+1) or oldest
    local voice=self.voices[index];if not voice then voice={source=self:Source('Mech'..index)};self.voices[index]=voice end
    local pitch=1
    if id=='mech_step' then
        pitch=.94+math.random()*.12
        if math.abs(pitch-self.stepPitch)<.025 then pitch=pitch<1 and math.min(1.06,pitch+.05) or math.max(.94,pitch-.05) end
        self.stepPitch=pitch
    end
    voice.source:StopImmediate();voice.order=self.cursor
    local sound=self.sounds[id];Levels.Play(voice.source,sound,sound:GetFrequency()*pitch,cue.gain*math.max(0,math.min(1,amount))*self.volume,pan or 0,nil,'driving')
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Observe(vehicle,dt,remote)
    if not self:Audible() or not vehicle or vehicle.disposed then return end
    local gain,pan=1,0;if remote then gain,pan=self:Spatial(vehicle);gain=gain*.4 end
    self.eventGain=gain;self.eventPan=pan;self.events:Observe(vehicle,dt,self.emit)
end
function M:Update(dt,vehicle,command,camera,entries,speaking)
    if self.disposed then return end;self.time=self.time+math.max(0,dt)
    local p=camera.worldPosition;local right=camera.worldRotation*Vector3.RIGHT
    self.listener[1]=-p.x;self.listener[2]=p.y;self.listener[3]=p.z
    self.right[1]=-right.x;self.right[2]=right.y;self.right[3]=right.z
    if not self:Audible() then self:Stop();return end
    self.silent=false
    if vehicle and not vehicle.disposed then Mix.Fill(self.localMix,vehicle,command)
    else for _,mix in ipairs(self.localMix) do mix.amount=0;mix.pitch=1 end end
    for _,mix in ipairs(self.best) do mix.amount=0;mix.pitch=1;mix.pan=0 end
    for _,entry in ipairs(entries or {}) do local unit=entry.unit
        if unit.alive and unit.vehicle and unit.vehicle~=vehicle and not unit.vehicle.disposed then
            local gain,pan=self:Spatial(unit.vehicle)
            if gain>=.015 then
                Mix.Fill(self.remoteMix,unit.vehicle,NEUTRAL)
                for i,mix in ipairs(self.remoteMix) do local amount=mix.amount*gain*.36
                    if amount>self.best[i].amount then self.best[i].amount=amount;self.best[i].pitch=mix.pitch;self.best[i].pan=pan end
                end
            end
        end
    end
    for i,mix in ipairs(self.localMix) do
        self:Loop(mix.id,mix.id,mix.amount,mix.pitch,0,dt)
        local best=self.best[i];self:Loop(REMOTE[mix.id],mix.id,best.amount,best.pitch,best.pan,dt)
    end
    self:UpdateLoopTails(dt)
end
function M:Snapshot()
    local out={active=self:Audible(),loops={},counts=self.counts,voices=#self.voices}
    for key,loop in pairs(self.loops) do out.loops[key]={playing=loop.source.playing,gain=loop.source.gain,frequency=loop.source.frequency,pan=loop.source.panning} end
    return out
end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.root:Dispose();self.sounds={};self.loops={};self.loopSources={};self.loopTails={};self.voices={}
end
return M
