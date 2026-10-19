-- Rechargeable ground-started burst, ported from H5 95fbd5c6.
local V=require 'core.Math3'
local M={};M.__index=M
function M.Available(v)
    return #v.spec.thrusters>0 and not v.legMode and #(v.spec.wings or {})==0
        and (#v.wheels>0 or v.hoverMode) and v.flightTarget==nil
end
function M.Tuning(count)
    local gain=count<=2 and math.max(0,count)/2 or 1+.2*(1-.5^(count-2))
    return {duration=2.2*gain,speed=1+1.4*gain,acceleration=120*gain}
end
function M.New(count)
    local self=setmetatable({},M);self.tuning=M.Tuning(count);self:Reset();return self
end
function M:Reset()
    self.left=self.tuning.duration;self.active=false;self.delay=0;self.held=false;self.power=0;self.recovering=false
end
function M:Snapshot()
    return {left=self.left,active=self.active,delay=self.delay,held=self.held,power=self.power,recovering=self.recovering}
end
function M:Restore(state)
    self:Reset();for k,value in pairs(state or {}) do self[k]=value end
    self.left=V.Clamp(self.left,0,self.tuning.duration)
end
function M:Finish() self.active=false;self.delay=1.2;self.recovering=true end
function M:Cancel() if self.active then self:Finish() end;self.power=0;self.recovering=false end
function M:Prepare(v,cmd,dt,frame)
    self.tuning=M.Tuning(#v.spec.thrusters);self.left=math.min(self.left,self.tuning.duration)
    self.available=M.Available(v);self.grounded=false
    for _,s in ipairs(v.suspension.states) do if s.grounded then self.grounded=true;break end end
    if v.hoverMode then for _,s in pairs(v.hoverStates) do if (s.G or 0)>0 and (s.force or 0)>0 then self.grounded=true;break end end end
    local pressed=cmd.groundBoost and not self.held;self.held=cmd.groundBoost==true
    local allowed=self.available and (cmd.throttle or 0)>.1 and not cmd.handbrake and (cmd.climb or 0)==0
    if self.active and (not allowed or not self.held) then self:Finish() end
    if pressed and allowed and self.grounded and frame.up[2]>.5 and self.left>1e-9 then self.active=true end
    if self.active then
        self.left=math.max(0,self.left-dt);self.delay=1.2
        if self.left<1e-9 then self.left=0;self:Finish() end
    else
        local refill=math.max(0,dt-self.delay);self.delay=math.max(0,self.delay-dt)
        self.left=math.min(self.tuning.duration,self.left+refill*self.tuning.duration/5)
    end
    if not self.available then self.recovering=false end
    self.power=self.power+((self.active and 1 or 0)-self.power)*(1-math.exp(-dt*(self.active and 14 or 5)))
    self.normalTop=math.max(1,v.spec.motion.topSpeed or 0,v.spec.motion.thrusterSpeed or 0)
    self.limit=self.normalTop*self.tuning.speed;self.speed=math.sqrt(frame.vel[1]^2+frame.vel[3]^2)
    if self.recovering and self.speed<=self.normalTop*1.01 then self.recovering=false end
    local excess=self.recovering and V.Clamp((self.speed/self.normalTop-1)/math.max(.001,self.tuning.speed-1),0,1) or 0
    self.handling=self.available and 1-.55*math.max(self.power,excess) or 1
    if self.handling>=1 then return cmd end
    local result={};for k,value in pairs(cmd) do result[k]=value end
    result.steer=(cmd.steer or 0)*self.handling;result.strafe=(cmd.strafe or 0)*self.handling;return result
end
function M:Apply(v,frame)
    local active=self.active and self.available
    if active then
        local dy=self.grounded and 0 or frame.fwd[2]
        local length=math.max(1e-9,math.sqrt(frame.fwd[1]^2+dy^2+frame.fwd[3]^2))
        local speed=self.grounded and self.speed or V.Length(frame.vel)
        local force=v.mass*math.min(self.tuning.acceleration,math.max(0,self.limit-speed)/.18)*self.power
        v.body.addForce({x=frame.fwd[1]/length*force,y=dy/length*force,z=frame.fwd[3]/length*force},true)
        for _,t in ipairs(v.spec.thrusters) do v.thrusterOutputs[t.partId]=math.max(v.thrusterOutputs[t.partId] or 0,self.power) end
    elseif self.available and self.grounded and self.recovering and self.speed>self.normalTop then
        local drag=v.mass*math.min(18,(self.speed-self.normalTop)*2.5)/self.speed
        v.body.addForce({x=-frame.vel[1]*drag,y=0,z=-frame.vel[3]*drag},true)
    end
    return {groundBoostAvailable=self.available,groundBoost=active,groundBoostLeft=self.left,
        groundBoostDuration=self.tuning.duration,groundBoostRechargeDelay=self.delay,
        groundBoostRecharging=not active and self.delay==0 and self.left<self.tuning.duration,
        groundBoostLimit=self.limit,groundBoostSteering=self.handling,
        groundBoostFx=self.available and self.power*V.Clamp((self.speed/self.normalTop-.4)/.8,0,1) or 0}
end
return M
