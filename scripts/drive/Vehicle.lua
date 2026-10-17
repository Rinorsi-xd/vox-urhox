local MechControl=require("drive.MechControl")
local MechHitboxes=require("drive.MechHitboxes")
local WingControl=require("drive.WingControl")
local Rotations=require("core.Rotations")
local Config=require("Config")

local Math=require "core.Math3"
local Coord=require "core.Coord"
local Setup=require "drive.VehicleSetup"
local Suspension=require "drive.RaySuspension"
local Contact=require "drive.ContactControl"
local Stability=require 'drive.ChassisStability'
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
    if #(spec.wings or {})>0 then
        -- Rapier: 1/(1+d*dt); Bullet: (1-d)^dt. Match the fixed 60 Hz step.
        b.linearDamping=1-(1+.02/60)^(-60)
        b.angularDamping=1-(1+.6/60)^(-60)
    end
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
    self.mechControl=#(spec.mechLegs or {})>0 and MechControl.New(self) or nil
    self.mechStates=self.mechControl and self.mechControl.states or {}
    self.mechHitboxes=#(spec.mechLegs or {})>0 and MechHitboxes.New(self) or nil
end
function Vehicle:Place(pos,yaw)
    if self.drill then self.drill:Cancel() end
    self.body.setTranslation({x=pos[1],y=pos[2]-self.spec.bounds.min[2]+.15,z=pos[3]})
    self.body.setRotation({x=0,y=math.sin(yaw/2),z=0,w=math.cos(yaw/2)})
    self.body.setLinvel({x=0,y=0,z=0});self.body.setAngvel({x=0,y=0,z=0});self.body.resetForces()
    self.steer=0;self.flightTarget=nil;self.liftTilt=0;self.landingTime=0;self.hoverHeightScale=1
    self.wingState=nil
    self.vPrev=0;self.aLong=0;self.aLat=0;self.airT=0;self.popBefore=nil;self.stability=nil
    self.thrusterOutputs={};self.thrusterDirections={};self.hoverStates={}
    RotorMotion.Restore(self.rotors);self:ApplyRotors()
    if self.legControl then self.legControl:Reset();self.legHitboxes:Update() end
    if self.mechControl then self.mechControl:Reset();self.mechHitboxes:Update() end
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
        legs=self.legControl and self.legControl:Snapshot() or nil,mech=self.mechControl and self.mechControl:Snapshot() or nil,
        chassis={vPrev=self.vPrev,aLong=self.aLong,aLat=self.aLat,airT=self.airT,drifting=self.drifting,landingTime=self.landingTime},
        wing=self.wingState,rotors=RotorMotion.Snapshot(self.rotors)}
end
function Vehicle:SetState(s)
    local b=self.body;b.setTranslation(s.p);b.setRotation(s.q);b.setLinvel(s.lv);b.setAngvel(s.av)
    self.steer=s.steer;self.flightTarget=s.flightTarget;self.liftTilt=s.liftTilt or 0
    self.hoverHeightScale=Math.Clamp(s.hoverHeightScale or 1,.6,1.7)
    RotorMotion.Restore(self.rotors,s.rotors);self:ApplyRotors()
    if self.legControl then self.legControl:Restore(s.legs);self.legHitboxes:Update() end
    if self.mechControl then self.mechControl:Restore(s.mech);self.mechHitboxes:Update() end
    if s.wing and self.spec.wings and #self.spec.wings>0 then self.wingState=s.wing end
    for key,value in pairs(s.chassis or {}) do self[key]=value end
    self.suspension:Sample()
end
function Vehicle:StepRotors(aim,step,dt)
    if self.drill and self.drill:ControlsBody() then return end
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
    RotorMotion.Follow(self.rotors,self.spec.wings,{'pos'},{'n','s','c'})
    for _,wing in ipairs(self.spec.wings or {}) do
        for _,surface in ipairs(wing.surfaces) do surface.rotor=wing.rotor end
        RotorMotion.Follow(self.rotors,wing.surfaces,{'pos'})
    end
    self.wingSurfaces=nil
    -- Compound shapes keep the original inertia/mass while moving kinematically
    -- within the vehicle, matching the source turntables rather than free joints.
    self.native:DisableMassUpdate()
    for _,c in ipairs(self.rotorShapes) do local item=c.item;local pose=self.rotors[item.rotor].pose
        c.shape.position=Vec(c.wheel and item.conn or item.center)
        c.shape.rotation=c.wheel and Quat(pose.q)*c.orientation or Quat(item.quat)
    end
    self.native:EnableMassUpdate();self.rayBounds=nil;self.rayStaticBounds=nil
end
function Vehicle:Step(cmd,dt)
    if self.disposed then return end
    if self.drill and self.drill:ControlsBody() then self.popBefore=nil;self:SyncDrillPose();return end
    local bodyReads <close> = self.body.beginReadScope()
    if self.mechControl then
        local up=Math.Rotate(self.body.rotation(),{0,1,0});local v=self.body.linvel()
        self.downTime=up[2]<math.cos(math.rad(55)) and Math.Length({v.x,v.y,v.z})<3 and (self.downTime or 0)+dt or 0
        if self.downTime>1.5 then
            self.downTime=0;local p=self.body.translation()
            self:Place({p.x,p.y+self.spec.bounds.radius*.6,p.z},self:Yaw())
        end
    end
    for _,states in ipairs({self.legStates,self.mechStates}) do for _,s in pairs(states) do s.drillDriven=false end end
    self.body.resetForces()
    local q=self.body.rotation();local velocity=self.body.linvel();local vel={velocity.x,velocity.y,velocity.z}
    local previous=self.telemetry
    self.popBefore={y=velocity.y,grounded=(previous.contact or 0)>0 or (previous.legContacts or 0)>0 or (previous.hovers or 0)>0}
    local up,fwd=Math.Rotate(q,{0,1,0}),Math.Rotate(q,{0,0,1});self.speed=Math.Dot(vel,fwd)
    local frame={up=up,fwd=fwd,vel=vel,speed=self.speed,q=q}
    local lifts=false;for _,t in ipairs(self.spec.thrusters) do if t.dir[2]>.7 then lifts=true end end
    if self.hoverMode and not lifts then self.hoverHeightScale=Math.Clamp(self.hoverHeightScale+Math.Clamp(cmd.climb or 0,-1,1)*.6*dt,.6,1.7) end
    self.suspension:Sample()
    local ground=Contact.Step(self,cmd,dt,frame)
    local flyingWing=self.spec.wings and #self.spec.wings>0 and (ground.contact==0 or self.wingState and self.wingState.phase=='takeoff')
    if Stability.Wants(self) and not flyingWing then Stability.Step(self,dt,frame,ground.contact) end
    local hover=Hover.Step(self,ground.wheelSupport)
    local motion=Hover.Motion(self,cmd,frame)
    local legs=self.legControl and self.legControl:Step(cmd,dt,ground.wheelSupport+hover.hoverForce) or {}
    self.legHitboxes:Update()
    local mech=self.mechControl and self.mechControl:Step(cmd,dt,ground.wheelSupport+hover.hoverForce+(legs.legVerticalSupport or 0)) or {}
    if self.mechHitboxes then self.mechHitboxes:Update() end
    local previousWingLift=math.max(0,self.wingState and self.wingState.lift or 0)
    local support=math.max(0,ground.wheelSupport+hover.hoverForce+(legs.legVerticalSupport or 0)+(mech.legVerticalSupport or 0)+(mech.mechJetLift or 0)+previousWingLift)
    local flight=Thrusters.Step(self,cmd,dt,ground.contact,support)
    local wing=WingControl.Step(self,cmd,dt,ground.contact,math.max(0,support-previousWingLift))
    local over=self.body.translation().y-200
    if over>0 then
        local x=over/20
        self.body.addForce({x=0,y=-self.mass*(9.81*1.8*x*x+math.max(0,velocity.y)*1.2*x),z=0},true)
    end
    self.suspension:Apply(dt)
    self.telemetry={speed=self.speed,totalSpeed=Math.Length(vel),vmax=self.spec.motion.topSpeed}
    for _,values in ipairs({ground,hover,motion,legs,mech,flight,wing}) do for key,value in pairs(values) do self.telemetry[key]=value end end
    self.telemetry.boosting=not not (flight.boosting or mech.boosting)
end
-- Apply after Bullet integration and before visual pose capture. Ground impact
-- may add at most the source 4 m/s upward; intentional flight/jumps are exempt.
function Vehicle:PostStep()
    local before,t=self.popBefore,self.telemetry;self.popBefore=nil
    if self.disposed or not before or not before.grounded or t.legJumped or t.mechJet or t.mechBoost
        or t.boosting or (t.wingLift or 0)>0 or self.drill and self.drill:ControlsBody() then return end
    local velocity=self.body.linvel()
    if velocity.y>before.y+4 then self.body.setLinvel({x=velocity.x,y=before.y+4,z=velocity.z},true) end
end
function Vehicle:SyncDrillPose()
    local q=self.body.rotation();local p=Math.Array(self.body.translation());local velocity=Math.Array(self.body.linvel())
    for _,states in ipairs({self.legStates,self.mechStates}) do for _,s in pairs(states) do
        local l=s.leg
        local point=s.target and Math.Add(l.origin,Math.Scale(Rotations.ApplyRot(l.rot,s.target),Config.CELL)) or l.toeRest or l.toe
        s.previous=s.foot;s.foot=Math.Add(Math.RotateUnit(q,point),p);s.drillDriven=true
        s.grounded=false;s.support=nil;s.contact=nil;s.ground=nil;s.swing=nil;s.sw=nil
        s.mode='free';s.available=false;s.force=0;s.jet=0;s.pulse=0
    end end
    if self.mechControl then self.mechControl.aPrev=velocity end
    if self.mechHitboxes then self.mechHitboxes:Update() end
    self.legHitboxes:Update();self.speed=Math.Dot(velocity,Math.RotateUnit(q,{0,0,1}))
    self.telemetry.speed=self.speed;self.telemetry.totalSpeed=Math.Length(velocity);self.telemetry.boosting=false;self.telemetry.legContacts=0
end
function Vehicle:WheelPose(index)
    local w,s=self.wheels[index],self.suspension.states[index]
    local length=s.grounded and s.length or w.rest
    return {steer=s.steer,spin=-s.spin*w.spinSign,lift=w.rest*(1-w.sag0)-length-w.drop}
end
function Vehicle:WheelTravel(index) return -self.suspension.states[index].spin*self.wheels[index].radius end
function Vehicle:Dispose()
    if self.disposed then return end
    if self.drill then self.drill:Cancel() end
    self.disposed=true;self.space:Unregister(self.native);self.node:Dispose()
    self.native=nil;self.node=nil;self.space=nil;self.drill=nil
    self.suspension=nil;self.vc=nil;self.legControl=nil;self.legHitboxes=nil
    self.mechControl=nil;self.mechHitboxes=nil;self.rotorShapes={}
    self.legStates={};self.mechStates={};self.wheels={};self.hoverStates={}
end
return Vehicle
