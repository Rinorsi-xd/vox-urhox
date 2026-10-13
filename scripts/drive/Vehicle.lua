local Math=require "core.Math3"
local Coord=require "core.Coord"
local Setup=require "drive.VehicleSetup"
local Suspension=require "drive.RaySuspension"
local Contact=require "drive.ContactControl"
local Hover=require "drive.HoverControl"
local Thrusters=require "drive.ThrusterControl"
local Legs=require "drive.LegControl"
local LegHitboxes=require "drive.LegHitboxes"
local RotorMotion=require 'drive.RotorMotion'
---@class Vehicle
---@field node Node
---@field native RigidBody
---@field flightTarget number|nil
local Vehicle={}
Vehicle.__index=Vehicle
local function Vec(v) return Coord.Vec(table.unpack(v)) end
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
function Vehicle.New(space,spec)
    assert(spec.ok,"Vehicle requires a valid connected spec")
    local self=setmetatable({},Vehicle);self:init(space,spec);return self
end
function Vehicle:init(space,spec)
    self.space=space;self.spec=spec;self.mass=spec.motion.mass
    self.wheels,self.capabilities=Setup.Wheels(spec)
    self.node=space.scene:CreateChild("VehicleBody")
    self.native=self.node:CreateComponent("RigidBody")
    local b=self.native
    b:DisableMassUpdate();b.friction=.55;b.restitution=.05
    b.linearDamping=.02;b.angularDamping=.6;b.linearRestThreshold=0;b.angularRestThreshold=0
    b.collisionLayer=2;b.collisionMask=0xffff;b.ccdRadius=.15;b.ccdMotionThreshold=.1
    self.rotors=RotorMotion.New(spec.rotors);self.rotorShapes={}
    for _,list in ipairs({spec.boxes,spec.hulls}) do for _,h in ipairs(list) do
        local shape=self.node:CreateComponent("CollisionShape")
        local rotation=h.quat and Quat(h.quat) or Quaternion.IDENTITY
        if h.shape then
            local geo=self.node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,POINT_LIST)
            for i=1,#h.shape,3 do geo:DefineVertex(Vec({h.shape[i],h.shape[i+1],h.shape[i+2]})) end
            geo:Commit();geo.enabled=false
            shape:SetCustomConvexHull(geo,Vector3.ONE,Vec(h.center),rotation)
        else shape:SetBox(Vector3(h.half[1]*2,h.half[2]*2,h.half[3]*2),Vec(h.center),rotation) end
        if h.rotor then self.rotorShapes[#self.rotorShapes+1]={shape=shape,item=h} end
    end end
    for _,w in ipairs(self.wheels) do if not w.track then
        local orientation=math.abs(w.axle[1])>.5 and Quaternion(90,Vector3.FORWARD) or Quaternion(90,Vector3.RIGHT)
        local shape=self.node:CreateComponent('CollisionShape');shape:SetCylinder(w.radius*1.8,w.width*.9,Vec(w.conn),orientation)
        if w.rotor then self.rotorShapes[#self.rotorShapes+1]={shape=shape,item=w,wheel=true,orientation=orientation} end
    end end
    b:EnableMassUpdate()
    -- Register as dynamic only after the compound shape has valid mass/inertia.
    -- Setting mass while mass updates are disabled leaves Bullet's world treating
    -- the object as static, even though later impulses change its velocity.
    b.mass=self.mass
    self.body=space:Register(b,{type="vehicle",ref=self})
    local com=self.body.localCom();Setup.Handling(self,{com.x,com.y,com.z})
    self.suspension=Suspension.New(self);self.vc=self.suspension.api
    self.hoverStates={};self.thrusterOutputs={};self.thrusterDirections={}
    self.speed=0;self.telemetry={speed=0,contact=0,wheels=#self.wheels,boosting=false}
    self.flightTarget=nil;self.liftTilt=0;self.landingTime=0;self.hoverHeightScale=1;self.disposed=false
    self.legControl=#spec.legs>0 and Legs.New(self) or nil
    self.legStates=self.legControl and self.legControl.states or {}
    self.legHitboxes=LegHitboxes.New(self)
end
function Vehicle:Place(pos,yaw)
    self.body.setTranslation({x=pos[1],y=pos[2]-self.spec.bounds.min[2]+.15,z=pos[3]})
    self.body.setRotation({x=0,y=math.sin(yaw/2),z=0,w=math.cos(yaw/2)})
    self.body.setLinvel({x=0,y=0,z=0});self.body.setAngvel({x=0,y=0,z=0});self.body.resetForces()
    self.steer=0;self.flightTarget=nil;self.liftTilt=0;self.landingTime=0;self.hoverHeightScale=1
    self.vPrev=0;self.aLong=0;self.aLat=0
    self.thrusterOutputs={};self.thrusterDirections={};self.hoverStates={}
    RotorMotion.Restore(self.rotors);self:ApplyRotors()
    if self.legControl then self.legControl:Reset();self.legHitboxes:Update() end
    for _,w in ipairs(self.wheels) do w.lenPrev=nil end
    self.suspension:Sample()
end
function Vehicle:Yaw()
    local f=Math.Rotate(self.body.rotation(),{0,0,1});return math.atan(f[1],f[3])
end
function Vehicle:GetState()
    local b=self.body
    return {p=b.translation(),q=b.rotation(),lv=b.linvel(),av=b.angvel(),steer=self.steer,
        flightTarget=self.flightTarget,liftTilt=self.liftTilt,hoverHeightScale=self.hoverHeightScale,
        legs=self.legControl and self.legControl:Snapshot() or nil,rotors=RotorMotion.Snapshot(self.rotors)}
end
function Vehicle:SetState(s)
    local b=self.body;b.setTranslation(s.p);b.setRotation(s.q);b.setLinvel(s.lv);b.setAngvel(s.av)
    self.steer=s.steer;self.flightTarget=s.flightTarget;self.liftTilt=s.liftTilt or 0
    self.hoverHeightScale=Math.Clamp(s.hoverHeightScale or 1,.6,1.35)
    RotorMotion.Restore(self.rotors,s.rotors);self:ApplyRotors()
    if self.legControl then self.legControl:Restore(s.legs);self.legHitboxes:Update() end
    self.suspension:Sample()
end
function Vehicle:StepRotors(aim,step,dt)
    if #self.rotors==0 then return end
    local p=self.body.translation();local localAim=aim and Math.Unrotate(self.body.rotation(),Math.Sub(aim,{p.x,p.y,p.z}))
    RotorMotion.Step(self.rotors,localAim,step,dt);self:ApplyRotors()
end
function Vehicle:ApplyRotors()
    if #self.rotors==0 then return end
    local changed=not self.rotorAppliedAngles
    self.rotorAppliedAngles=self.rotorAppliedAngles or {}
    for i,r in ipairs(self.rotors) do
        if self.rotorAppliedAngles[i]~=r.angle then changed=true;self.rotorAppliedAngles[i]=r.angle end
    end
    if not changed then return end
    for _,list in ipairs({self.spec.boxes,self.spec.hulls,self.spec.sensors}) do RotorMotion.Follow(self.rotors,list,{'center'},{},{'quat'}) end
    RotorMotion.Follow(self.rotors,self.wheels,{'conn','center'},{'axle','contactAxle','down'})
    RotorMotion.Follow(self.rotors,self.spec.hovers,{'pos'},{'dir'})
    RotorMotion.Follow(self.rotors,self.spec.thrusters,{'pos','pivot'},{'dir'})
    -- Compound shapes keep the original inertia/mass while moving kinematically
    -- within the vehicle, matching the source turntables rather than free joints.
    self.native:DisableMassUpdate()
    for _,c in ipairs(self.rotorShapes) do local item=c.item;local pose=self.rotors[item.rotor].pose
        c.shape.position=Vec(c.wheel and item.conn or item.center)
        c.shape.rotation=c.wheel and Quat(pose.q)*c.orientation or Quat(item.quat)
    end
    self.native:EnableMassUpdate();self.rayBounds=nil
end
function Vehicle:Step(cmd,dt)
    if self.disposed then return end
    self.body.resetForces()
    local q=self.body.rotation();local velocity=self.body.linvel();local vel={velocity.x,velocity.y,velocity.z}
    local up,fwd=Math.Rotate(q,{0,1,0}),Math.Rotate(q,{0,0,1});self.speed=Math.Dot(vel,fwd)
    local frame={up=up,fwd=fwd,vel=vel,speed=self.speed,q=q}
    local lifts=false;for _,t in ipairs(self.spec.thrusters) do if t.dir[2]>.7 then lifts=true end end
    if self.hoverMode and not lifts then self.hoverHeightScale=Math.Clamp(self.hoverHeightScale+Math.Clamp(cmd.climb or 0,-1,1)*.4*dt,.6,1.35) end
    self.suspension:Sample()
    local ground=Contact.Step(self,cmd,dt,frame)
    local hover=Hover.Step(self,ground.wheelSupport)
    local motion=Hover.Motion(self,cmd,frame)
    local legs=self.legControl and self.legControl:Step(cmd,dt,ground.wheelSupport+hover.hoverForce) or {}
    self.legHitboxes:Update()
    local flight=Thrusters.Step(self,cmd,dt,ground.contact,math.max(0,ground.wheelSupport+hover.hoverForce+(legs.legVerticalSupport or 0)))
    self.suspension:Apply(dt)
    self.telemetry={speed=self.speed,totalSpeed=Math.Length(vel),vmax=self.spec.motion.topSpeed}
    for _,values in ipairs({ground,hover,motion,legs,flight}) do for key,value in pairs(values) do self.telemetry[key]=value end end
end
function Vehicle:WheelPose(index)
    local w,s=self.wheels[index],self.suspension.states[index]
    local length=s.grounded and s.length or w.rest
    return {steer=s.steer,spin=-s.spin*w.spinSign,lift=w.rest*(1-w.sag0)-length-w.drop}
end
function Vehicle:WheelTravel(index) return -self.suspension.states[index].spin*self.wheels[index].radius end
function Vehicle:Dispose()
    if self.disposed then return end
    self.disposed=true;self.space:Unregister(self.native);self.node:Remove()
end
return Vehicle
