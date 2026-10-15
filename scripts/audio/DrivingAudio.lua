local Data=require('core.ResourceData').Read('Combat/DrivingSounds.json')
local Mix=require 'audio.DrivingMix'
local V=require 'core.Math3'
local NEUTRAL={}
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;return paths
end
function M.New(scene) local self=setmetatable({},M);self:init(scene);return self end
function M:init(scene)
    self.root=scene:CreateChild('DrivingAudio');self.sounds={};self.loops={};self.voices={};self.last={};self.counts={}
    self.localMix=Mix.New();self.remoteMix=Mix.New();self.best=Mix.New();self.events=require('audio.DrivingEvents').New()
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
    for _,loop in pairs(self.loops) do loop.source:StopImmediate();Levels.SetGain(loop.source,0);loop.gain=0 end
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
function M:Loop(key,id,amount,pitch,pan,dt)
    local cue=Data.cues[id];local loop=self.loops[key]
    local live=amount>.005
    if not loop and not live then return end
    if not loop then loop={source=self:Source(key),gain=0,pitch=pitch,pan=pan};self.loops[key]=loop end
    local target=live and cue.gain*math.min(1,amount)*self.volume*self.duck or 0
    local alpha=1-math.exp(-math.max(0,dt)/(live and cue.attack or cue.release))
    loop.gain=loop.gain+(target-loop.gain)*alpha
    loop.pitch=loop.pitch+(V.Clamp(pitch,.65,1.5)-loop.pitch)*(1-math.exp(-math.max(0,dt)/.12))
    loop.pan=loop.pan+(pan-loop.pan)*(1-math.exp(-math.max(0,dt)/.08))
    local sound=self.sounds[id]
    if live and not loop.source.playing then
        Levels.Play(loop.source,sound,sound:GetFrequency()*loop.pitch,loop.gain,loop.pan);self.counts[id]=(self.counts[id] or 0)+1
    end
    Levels.SetGain(loop.source,loop.gain);loop.source.frequency=sound:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
    if not live and loop.gain<.0001 then loop.source:StopImmediate();loop.gain=0 end
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
    local sound=self.sounds[id];Levels.Play(voice.source,sound,sound:GetFrequency()*pitch,math.min(1,cue.gain*amount*self.volume*self.duck),pan or 0)
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Observe(vehicle,dt,remote)
    if not self:Audible() or not vehicle or vehicle.disposed then return end
    local gain,pan=1,0;if remote then gain,pan=self:Spatial(vehicle);gain=gain*.4 end
    self.eventGain=gain;self.eventPan=pan;self.events:Observe(vehicle,dt,self.emit)
end
function M:Update(dt,vehicle,command,camera,entries,speaking)
    if self.disposed then return end;self.time=self.time+math.max(0,dt);self.duck=speaking and .3 or 1
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
        local best=self.best[i];self:Loop('remote:'..mix.id,mix.id,best.amount,best.pitch,best.pan,dt)
    end
end
function M:Snapshot()
    local out={active=self:Audible(),loops={},counts=self.counts,voices=#self.voices}
    for key,loop in pairs(self.loops) do out.loops[key]={playing=loop.source.playing,gain=loop.source.gain,frequency=loop.source.frequency,pan=loop.source.panning} end
    return out
end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.root:Dispose();self.sounds={};self.loops={};self.voices={}
end
return M
