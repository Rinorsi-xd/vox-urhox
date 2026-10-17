-- Ray suspension and bounded tire impulses. Suspension follows the source Rapier
-- spring/damping model; rigid collision integration remains native Bullet.
-- Origin -> suspension rest + tire radius; no ground hit means zero support.
-- Tire impulses share one friction ellipse, so braking/side grip cannot exceed load.
local TerrainObstacles=require("drive.TerrainObstacles")
local Rotors=require("construction.Rotors")

local Math=require "core.Math3"
local M={}
M.__index=M
local function Vec(v) return {x=v[1],y=v[2],z=v[3]} end
local function Array(v) return {v.x,v.y,v.z} end
local DOWN={0,-1,0}
local UP={0,1,0}
local function ScaledVec(v,k) return {x=v[1]*k,y=v[2]*k,z=v[3]*k} end
local function Normalized(x,y,z)
    local length=math.sqrt(x*x+y*y+z*z)
    local inv=length>0 and 1/length or 1
    return {x*inv,y*inv,z*inv}
end
local function Denominator(body,ground,point,direction)
    return math.max(1e-9,body.impulseDenominator(point,direction)+(ground and ground.impulseDenominator(point,direction) or 0))
end
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
    for i,w in ipairs(v.wheels) do
        local down=Math.Rotate(q,w.down or DOWN)
        local s=self.states[i]
        s.hard=Math.Add(position,Math.Rotate(q,w.conn))
        local hit=v.space:Raycast(s.hard,down,w.rest+w.radius,body,nil,false,TerrainObstacles.SUPPORT_MASK)
        s.grounded=hit~=nil;s.groundBody=hit and hit.body or nil
        if hit then
            s.point=hit.point;s.normal=hit.normal;s.length=Math.Clamp(hit.dist-w.radius,w.rest-w.maxTravel,w.rest+w.maxTravel)
            local dot=Math.Dot(s.normal,down)
            local point=Vec(s.point)
            local velocity=body.velocityAtPoint(point)
            local ground=hit.body and hit.body.velocityAtPoint(point)
            local gx,gy,gz=0,0,0
            if ground then gx,gy,gz=ground.x,ground.y,ground.z end
            local projected=s.normal[1]*(velocity.x-gx)+s.normal[2]*(velocity.y-gy)+s.normal[3]*(velocity.z-gz)
            local inv=dot>=-.1 and 10 or -1/dot
            local speed=dot>=-.1 and 0 or projected*inv
            local damping=speed<0 and w.compression or w.relaxation
            s.force=math.max(0,(w.stiffness*(w.rest-s.length)*inv-damping*speed)*v.mass)
        else
            local distance=w.rest+w.radius
            s.length=w.rest;s.force=0;s.normal=Math.Scale(down,-1)
            s.point={s.hard[1]+down[1]*distance,s.hard[2]+down[2]*distance,s.hard[3]+down[3]*distance}
        end
    end
end
function M:Apply(dt)
    local v=self.vehicle;local body=v.body;local q=body.rotation();local up=Math.Rotate(q,UP)
    local grounded=0
    for i,w in ipairs(v.wheels) do
        local s=self.states[i]
        if s.grounded then
            grounded=grounded+1
            body.applyImpulseAtPoint(ScaledVec(s.normal,math.min(s.force,w.maxForce)*dt),Vec(s.point),true)
        end
    end
    -- Calculate all contact impulses before applying any, matching the source order.
    for i,w in ipairs(v.wheels) do
        local s=self.states[i];s.forwardImpulse=0;s.sideImpulse=0;s.skid=1
        local cy,sy=math.cos(s.steer),math.sin(s.steer);local a=w.contactAxle
        local turned=w.rotor and Math.Rotate(Rotors.AxisQuat(Math.Scale(w.down,-1),s.steer),a) or {a[1]*cy+a[3]*sy,a[2],-a[1]*sy+a[3]*cy}
        local axle=Math.Rotate(q,turned)
        local dot=Math.Dot(axle,s.normal)
        local ax,ay,az=axle[1]-s.normal[1]*dot,axle[2]-s.normal[2]*dot,axle[3]-s.normal[3]*dot
        s.axle=Normalized(ax,ay,az)
        s.forward=Normalized(s.normal[2]*s.axle[3]-s.normal[3]*s.axle[2],
            s.normal[3]*s.axle[1]-s.normal[1]*s.axle[3],s.normal[1]*s.axle[2]-s.normal[2]*s.axle[1])
        if s.grounded then
            local point=Vec(s.point)
            local pv=body.velocityAtPoint(point)
            local ground=s.groundBody;local gv=ground and ground.velocityAtPoint(point)
            local gx,gy,gz=0,0,0
            if gv then gx,gy,gz=gv.x,gv.y,gv.z end
            local rx,ry,rz=pv.x-gx,pv.y-gy,pv.z-gz
            local sideSpeed=rx*s.axle[1]+ry*s.axle[2]+rz*s.axle[3]
            s.sideImpulse=-.2*sideSpeed/Denominator(body,ground,point,Vec(s.axle))*s.side
            -- ContactControl already apportions the requested brake impulse by
            -- wheel load; dividing again weakens braking as wheel count grows.
            local forwardSpeed=rx*s.forward[1]+ry*s.forward[2]+rz*s.forward[3]
            s.forwardImpulse=s.engine~=0 and s.engine*dt or Math.Clamp(-forwardSpeed/Denominator(body,ground,point,Vec(s.forward)),-s.brake,s.brake)
            local length=math.sqrt((s.forwardImpulse*.5)^2+s.sideImpulse^2)
            local cap=s.force*dt*w.friction
            if length>cap and length>0 then s.skid=cap/length;s.forwardImpulse=s.forwardImpulse*s.skid;s.sideImpulse=s.sideImpulse*s.skid end
        end
    end
    for i,w in ipairs(v.wheels) do
        local s=self.states[i]
        if s.grounded then
            body.applyImpulseAtPoint(ScaledVec(s.forward,s.forwardImpulse),Vec(s.point),true)
            -- Source raycast controller defaults rollInfluence to 0.1.
            local center=body.center()
            local height=up[1]*(s.point[1]-center.x)+up[2]*(s.point[2]-center.y)+up[3]*(s.point[3]-center.z)
            local amount=height*.9
            local sidePoint={x=s.point[1]-up[1]*amount,y=s.point[2]-up[2]*amount,z=s.point[3]-up[3]*amount}
            body.applyImpulseAtPoint(ScaledVec(s.axle,s.sideImpulse),sidePoint,true)
            local velocity=body.velocityAtPoint(Vec(s.hard))
            s.deltaSpin=(velocity.x*s.forward[1]+velocity.y*s.forward[2]+velocity.z*s.forward[3])*dt/w.radius
        end
        s.spin=s.spin+s.deltaSpin;s.deltaSpin=s.deltaSpin*.99
    end
end
return M
