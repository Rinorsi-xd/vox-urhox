-- Frozen approved WAV samples and event/state mixing; ten voices, three loops.
local Data=require('core.ResourceData').Read('Combat/WeaponSounds.json')
local V=require 'core.Math3'
local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.Dependencies()
    local paths={};for _,cue in pairs(Data.cues) do paths[#paths+1]=cue.path end;return paths
end
function M.New(scene)
    local self=setmetatable({},M);self:init(scene);return self
end
function M:init(scene)
    self.root=scene:CreateChild('WeaponAudio');self.sounds={};self.slots={};self.voiceIds={};self.started={};self.loops={};self.loopSources={};self.loopTails={};self.last={};self.counts={}
    self.cursor=0;self.time=0;self.active=false;self.volume=.65;self.duck=1;self.disposed=false;self.nextPing=0
    self.focus=function() return input.focus and not input.minimized end
    for id,cue in pairs(Data.cues) do
        local sound=assert(cache:GetResource('Sound',cue.path),cue.path);sound.looped=cue.loop;self.sounds[id]=sound
    end
end
function M:Source(name)
    local source=self.root:CreateChild(name):CreateComponent('SoundSource');source:SetSoundType('VoxWeapons');return source
end
function M:Audible() return not self.disposed and self.active and self.volume>0 and self.focus() end
function M:Spatial(point,reference)
    if not point or not self.listener then return 1,0 end
    local delta=V.Sub(point,self.listener);local distance=V.Length(delta)
    return distance>=240 and 0 or 1/(1+(distance/reference)^2),distance>0 and V.Clamp(V.Dot(delta,self.right)/distance,-.85,.85) or 0
end
function M:Play(id,amount,pan)
    local cue=Data.cues[id]
    if not cue or cue.loop or not self:Audible() or self.time-(self.last[id] or -999)<cue.gap then return false end
    self.last[id]=self.time;self.cursor=self.cursor+1
    local same,oldest,oldestSame,free=0,1,nil,nil
    for i,source in ipairs(self.slots) do
        if not source.playing and not free then free=i end
        if self.started[i]<self.started[oldest] then oldest=i end
        if source.playing and self.voiceIds[i]==id then
            same=same+1;if not oldestSame or self.started[i]<self.started[oldestSame] then oldestSame=i end
        end
    end
    local index=same>=3 and oldestSame or free or (#self.slots<10 and #self.slots+1) or oldest
    local source=self.slots[index]
    if not source then source=self:Source('Voice'..index);self.slots[index]=source end
    self.voiceIds[index]=id;self.started[index]=self.cursor
    source:StopImmediate();local sound=self.sounds[id];local pitch=cue.jitter and .97+math.random()*.06 or 1
    Levels.Play(source,sound,sound:GetFrequency()*pitch,cue.gain*math.max(0,math.min(1,amount or 1))*self.volume,pan or 0,nil,id=='energy_online' and 'feedback' or 'weapons')
    self.counts[id]=(self.counts[id] or 0)+1;return true
end
function M:Loop(id,amount,pitch,pan,dt)
    local cue=Data.cues[id];amount=self:Audible() and amount or 0
    local loop=self.loops[id]
    if amount<=.005 then self:ReleaseLoop(id);return false end
    if not loop or loop.released or not loop.source.playing then
        local slot=nil
        for _,candidate in ipairs(self.loopSources) do if not candidate.source.playing and candidate.id==id then slot=candidate;break end end
        if not slot then for _,candidate in ipairs(self.loopSources) do if not candidate.source.playing then slot=candidate;break end end end
        if not slot then
            if #self.loopSources>=20 then return false end
            slot={source=self:Source(id)};self.loopSources[#self.loopSources+1]=slot
        end
        local previous=slot.id and self.loops[slot.id]
        if slot.id~=id and previous and previous.source==slot.source then self.loops[slot.id]=nil end
        slot.id=id;loop={source=slot.source,amount=0,pitch=1,pan=0,release=cue.release};self.loops[id]=loop
    end
    local step=math.max(0,dt)
    local target=cue.gain*math.min(1,amount)*self.volume
    local alpha=1-math.exp(-step/cue.attack)
    loop.amount=loop.amount+(target-loop.amount)*alpha
    loop.pitchTarget=V.Clamp(pitch or 1,.65,1.5);loop.panTarget=pan or 0
    loop.pitch=loop.pitch+(loop.pitchTarget-loop.pitch)*(1-math.exp(-step/.12))
    loop.pan=loop.pan+(loop.panTarget-loop.pan)*(1-math.exp(-step/.08))
    local sound=self.sounds[id]
    if not loop.source.playing then Levels.Play(loop.source,sound,sound:GetFrequency()*loop.pitch,loop.amount,loop.pan,nil,'weapons') end
    Levels.SetGain(loop.source,loop.amount);loop.source.frequency=sound:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
    return true
end
function M:ReleaseLoop(id)
    local loop=self.loops[id]
    if not loop or loop.released then return end
    -- H5 deletes the active key immediately; its old source keeps a five-tau tail.
    loop.released=true;loop.releaseAge=0;self.loopTails[#self.loopTails+1]=loop
end
function M:UpdateLoopTails(dt)
    local step=math.max(0,dt)
    for i=#self.loopTails,1,-1 do local loop=self.loopTails[i]
        loop.releaseAge=loop.releaseAge+step
        loop.amount=loop.amount*math.exp(-step/loop.release)
        loop.pitch=loop.pitch+(loop.pitchTarget-loop.pitch)*(1-math.exp(-step/.12))
        loop.pan=loop.pan+(loop.panTarget-loop.pan)*(1-math.exp(-step/.08))
        Levels.SetGain(loop.source,loop.amount);loop.source.frequency=loop.source.sound:GetFrequency()*loop.pitch;loop.source.panning=loop.pan
        if loop.releaseAge>=loop.release*5 then loop.source:StopImmediate();Levels.SetGain(loop.source,0);loop.amount=0;table.remove(self.loopTails,i) end
    end
end
function M:Stop()
    for _,source in ipairs(self.slots) do source:StopImmediate() end
    for _,slot in ipairs(self.loopSources) do slot.source:StopImmediate();Levels.SetGain(slot.source,0) end
    for _,loop in pairs(self.loops) do loop.amount=0;loop.released=true end
    self.loopTails={}
    self.lockedRef=nil;self.nextPing=0
end
function M:SetActive(active)
    self.active=active==true;if not self.active or not self.focus() then self:Stop() end
end
function M:Consume(events,remote)
    for _,e in ipairs(events) do
        local gain,pan=self:Spatial(e.pos,e.type=='blast' and 32 or 24)
        if gain>.005 then
            if e.type=='shot' and e.kind=='sniper' then
                if not remote then self:ReleaseLoop('sniper_charge') end
                self:Play('sniper_fire',gain,pan)
            elseif e.type=='shot' and e.kind=='missile' then self:Play('missile_eject',gain,pan);self:Play('missile_launch',gain,pan)
            elseif e.type=='blast' and e.kind=='missile' then self:Play('missile_blast',gain,pan) end
        end
        local id=e.type=='mechanism' and e.cue or e.type=='energy' and e.state=='online' and not remote and 'energy_online'
        if e.type=='shot' and (e.kind=='mg' or e.kind=='laser') then id=e.kind..'_fire'
        elseif e.type=='dry' and not remote then id='weapon_dry'
        elseif e.type=='impact' or e.type=='beam' and e.hit then id=e.material=='metal' and 'hit_metal' or 'hit_ground' end
        if id then
            local point=e.pos or e.to;local distance=point and self.listener and V.Length(V.Sub(point,self.listener)) or 0
            if distance<=180 then local amount,p=self:Spatial(point,32)
                if not remote and (e.type=='shot' or e.type=='dry' or e.type=='mechanism' or e.type=='energy') then amount=1 end
                self:Play(id,amount,p)
            end
        end
    end
end
function M:Update(dt,system,camera,entries,speaking)
    if self.disposed then return end;self.time=self.time+math.max(0,dt)
    local p=camera.worldPosition;local right=camera.worldRotation*Vector3.RIGHT
    self.listener={-p.x,p.y,p.z};self.right={-right.x,right.y,right.z}
    if not self:Audible() then self:Stop();return end
    self:UpdateLoopTails(dt)
    local spin=0;for _,g in ipairs(system.groups) do for _,w in ipairs(g.weapons) do spin=math.max(spin,w.spin or 0) end end
    self:Loop('mg_motor',spin>.02 and .25+spin*.75 or 0,.65+spin*.5,0,dt)
    local group=system:Group();local windup=0
    if group and group.kind=='sniper' then for _,w in ipairs(group.weapons) do windup=math.max(windup,w.windup) end end
    self:Loop('sniper_charge',windup>0 and .45+windup*.55 or 0,.75+windup*.6,0,dt)
    local flight,pan=0,0
    local function Projectiles(weapons)
        for _,projectile in ipairs(weapons.projectiles) do if projectile.s.homing and projectile.life>0 then
            local gain,panning=self:Spatial(projectile.pos,30);local age=math.max(0,projectile.age or 0)
            gain=gain*(age>=1.25 and 0 or math.exp(-3*age)*math.min(1,(1.25-age)/.25))
            if gain>flight then flight,pan=gain,panning end
        end end
    end
    Projectiles(system)
    for _,entry in ipairs(entries or {}) do if entry.unit.alive and entry.unit.weapons~=system then Projectiles(entry.unit.weapons) end end
    self:Loop('missile_flight',flight,1,pan,dt)
    local info=system:LockInfo()
    if not info or not info.ref or not info.inside then self.lockedRef=nil;self.nextPing=0;return end
    if info.locked then
        if info.ref~=self.lockedRef then self:Play('missile_lock') end;self.lockedRef=info.ref
    else
        self.lockedRef=nil
        if system.time>=self.nextPing then self:Play('missile_scan');self.nextPing=system.time+.5-info.progress*.3 end
    end
end
function M:Dispose()
    if self.disposed then return end;self:Stop();self.disposed=true;self.root:Dispose();self.slots={};self.loops={};self.loopSources={};self.sounds={}
end
return M
