-- Ray suspension and bounded tire impulses. Suspension follows the source Rapier
-- spring/damping model; rigid collision integration remains native Bullet.
-- Origin -> suspension rest + tire radius; no ground hit means zero support.
-- Tire impulses share one friction ellipse, so braking/side grip cannot exceed load.
local Math=require "core.Math3"
local M={}
M.__index=M
local function Vec(v) return {x=v[1],y=v[2],z=v[3]} end
local function Array(v) return {v.x,v.y,v.z} end
function M.New(vehicle)
    local self=setmetatable({},M);self:init(vehicle);return self
end
function M:init(vehicle)
    self.vehicle=vehicle;self.states={}
    for i,w in ipairs(vehicle.wheels) do
        self.states[i]={grounded=false,length=w.rest,force=0,normal={0,1,0},point={0,0,0},hard={0,0,0},
            engine=0,brake=0,steer=0,side=1,spin=0,deltaSpin=0,skid=1}
    end
    local states=self.states
    self.api={
        wheelIsInContact=function(i) return states[i].grounded end,
        wheelSuspensionForce=function(i) return states[i].force end,
        wheelSuspensionLength=function(i) return states[i].length end,
        wheelHardPoint=function(i) return Vec(states[i].hard) end,
        wheelContactNormal=function(i) return Vec(states[i].normal) end,
        wheelEngineForce=function(i) return states[i].engine end,
        wheelBrake=function(i) return states[i].brake end,
        setWheelEngineForce=function(i,v) states[i].engine=v end,
        setWheelBrake=function(i,v) states[i].brake=v end,
        setWheelSteering=function(i,v) states[i].steer=v end,
        setWheelSideFrictionStiffness=function(i,v) states[i].side=v end,
    }
end
function M:Sample()
    local v=self.vehicle;local body=v.body;local q=body.rotation();local position=Array(body.translation())
    local down=Math.Rotate(q,{0,-1,0})
    for i,w in ipairs(v.wheels) do
        local s=self.states[i]
        s.hard=Math.Add(position,Math.Rotate(q,w.conn))
        local hit=v.space:Raycast(s.hard,down,w.rest+w.radius,body)
        s.grounded=hit~=nil;s.groundBody=hit and hit.body or nil
        if hit then
            s.point=hit.point;s.normal=hit.normal;s.length=Math.Clamp(hit.dist-w.radius,w.rest-w.maxTravel,w.rest+w.maxTravel)
            local dot=Math.Dot(s.normal,down)
            local velocity=body.velocityAtPoint(Vec(s.point))
            local ground=hit.body and hit.body.velocityAtPoint(Vec(s.point)) or {x=0,y=0,z=0}
            local projected=Math.Dot(s.normal,{velocity.x-ground.x,velocity.y-ground.y,velocity.z-ground.z})
            local inv=dot>=-.1 and 10 or -1/dot
            local speed=dot>=-.1 and 0 or projected*inv
            local damping=speed<0 and w.compression or w.relaxation
            s.force=math.max(0,(w.stiffness*(w.rest-s.length)*inv-damping*speed)*v.mass)
        else
            s.length=w.rest;s.force=0;s.normal=Math.Scale(down,-1);s.point=Math.Add(s.hard,Math.Scale(down,w.rest+w.radius))
        end
    end
end
function M:Apply(dt)
    local v=self.vehicle;local body=v.body;local q=body.rotation();local up=Math.Rotate(q,{0,1,0})
    local grounded=0
    for i,w in ipairs(v.wheels) do
        local s=self.states[i]
        if s.grounded then
            grounded=grounded+1
            body.applyImpulseAtPoint(Vec(Math.Scale(s.normal,math.min(s.force,w.maxForce)*dt)),Vec(s.point),true)
        end
    end
    -- Calculate all contact impulses before applying any, matching the source order.
    for i,w in ipairs(v.wheels) do
        local s=self.states[i];s.forwardImpulse=0;s.sideImpulse=0;s.skid=1
        local cy,sy=math.cos(s.steer),math.sin(s.steer);local a=w.contactAxle
        local axle=Math.Rotate(q,{a[1]*cy+a[3]*sy,a[2],-a[1]*sy+a[3]*cy})
        s.axle=Math.Normalize(Math.Sub(axle,Math.Scale(s.normal,Math.Dot(axle,s.normal))))
        s.forward=Math.Normalize(Math.Cross(s.normal,s.axle))
        if s.grounded then
            local pv=body.velocityAtPoint(Vec(s.point))
            local ground=s.groundBody;local gv=ground and ground.velocityAtPoint(Vec(s.point)) or {x=0,y=0,z=0}
            local relative={pv.x-gv.x,pv.y-gv.y,pv.z-gv.z}
            local function Denominator(direction)
                local p,d=Vec(s.point),Vec(direction)
                return math.max(1e-9,body.impulseDenominator(p,d)+(ground and ground.impulseDenominator(p,d) or 0))
            end
            s.sideImpulse=-.2*Math.Dot(relative,s.axle)/Denominator(s.axle)*s.side
            s.forwardImpulse=s.engine~=0 and s.engine*dt or Math.Clamp(-Math.Dot(relative,s.forward)/Denominator(s.forward)/math.max(1,grounded),-s.brake,s.brake)
            local length=math.sqrt((s.forwardImpulse*.5)^2+s.sideImpulse^2)
            local cap=s.force*dt*w.friction
            if length>cap and length>0 then s.skid=cap/length;s.forwardImpulse=s.forwardImpulse*s.skid;s.sideImpulse=s.sideImpulse*s.skid end
        end
    end
    for i,w in ipairs(v.wheels) do
        local s=self.states[i]
        if s.grounded then
            body.applyImpulseAtPoint(Vec(Math.Scale(s.forward,s.forwardImpulse)),Vec(s.point),true)
            -- Source raycast controller defaults rollInfluence to 0.1.
            local center=Array(body.center());local height=Math.Dot(up,Math.Sub(s.point,center))
            local sidePoint=Math.Sub(s.point,Math.Scale(up,height*.9))
            body.applyImpulseAtPoint(Vec(Math.Scale(s.axle,s.sideImpulse)),Vec(sidePoint),true)
            s.deltaSpin=Math.Dot(Array(body.velocityAtPoint(Vec(s.hard))),s.forward)*dt/w.radius
        end
        s.spin=s.spin+s.deltaSpin;s.deltaSpin=s.deltaSpin*.99
    end
end
return M
