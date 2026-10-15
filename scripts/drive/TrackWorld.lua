-- One imported layout drives collision and rendering. All units are metres.
--   finite ground mesh, top y=0 -> flat support without large-box ray normal noise
--   tilted boxes / closed convex wedges -> ramps, banks, walls and steps
--   cone cylinders -> dynamic impact bodies, radius .3, height .75, mass 4
--   target boxes -> .3 x 2.2 x 2, centre y=1.6, disabled when destroyed
-- Ray suspension excludes its own chassis and triggers; raised tracks keep the
-- finite side/end faces, so ramp edges and airborne wheels remain unsupported.
local Coord=require "core.Coord"
local Assets=require "scene.TrackAssets"
local Space=require "physics.Space"
local CarUnit=require "combat.CarUnit"
local Debris=require "combat.Debris"
local Vehicle=require "drive.Vehicle"
local VehicleRay=require "combat.VehicleRay"
local M={};M.__index=M
local function Vec(v) return Coord.Vec(table.unpack(v)) end
local function Rotation(v)
    local d=180/math.pi
    return Quaternion(v[1]*d,Vector3.RIGHT)*Quaternion(-v[2]*d,Vector3.UP)*Quaternion(-v[3]*d,Vector3.FORWARD)
end
function M.New(scene)
    local self=setmetatable({},M);self:init(scene);return self
end
function M:init(scene)
    self.scene=scene;self.space=Space.New(scene);self.layout=Assets.data.layout
    self.root=scene:CreateChild("TrialPhysics");self.cones={};self.targets={};self.time=0
    self.stats={shots=0,hits=0,damage=0,kills=0}
    self.metrics=require('drive.TrialMetrics').New(self.layout.drag)
    self.units={};self.fx={};self.viewEvents={};self.debris=Debris.New(self.space)
    self.env={stats=self.stats,castRay=function(...) return self:CastRay(...) end,sweepDrill=function(...) return self:SweepDrill(...) end,
        hit=function(...) self:Hit(...) end,lockables=function(...) return self:Lockables(...) end,
        explode=function(...) return self:Explode(...) end}
    local ground=self.root:CreateChild("Ground")
    -- Same 400 x 2 x 400 m solid footprint as H5, but planar triangle normals.
    -- Box.mdl is the documented 1 m unit cube; this collider is static only.
    ground:CreateComponent("CollisionShape"):SetTriangleMesh(assert(cache:GetResource("Model","Models/Box.mdl")),0,
        Vector3(self.layout.size,2,self.layout.size),Vector3(0,-1,0))
    local floor=ground:CreateComponent("RigidBody");floor.friction=.9;floor.collisionLayer=1
    self.space:Register(floor,{type="ground"})
    for i,b in ipairs(self.layout.blocks) do
        local node=self.root:CreateChild("Block"..i);node.position=Vec(b.pos);node.rotation=Rotation(b.rot)
        local shape=node:CreateComponent("CollisionShape")
        if b.vertices then
            local mesh=node:CreateComponent("CustomGeometry");mesh:BeginGeometry(0,TRIANGLE_LIST)
            for _,index in ipairs(b.indices) do
                mesh:DefineVertex(Coord.Vec(b.vertices[index*3+1],b.vertices[index*3+2],b.vertices[index*3+3]))
            end
            mesh:Commit();shape:SetCustomConvexHull(mesh);mesh.enabled=false
        else shape:SetBox(Vector3(table.unpack(b.size))) end
        local body=node:CreateComponent("RigidBody");body.friction=b.friction;body.collisionLayer=1
        self.space:Register(body,{type="obstacle"})
    end
    for i,s in ipairs(self.layout.signs) do if s.solid~=false then
        local top=s.pos[2]+.8;local n=self.root:CreateChild("SignCollision"..i)
        n.position=Coord.Vec(s.pos[1],top/2,s.pos[3]);n.rotation=Rotation({0,s.rotY,0})
        n:CreateComponent("CollisionShape"):SetBox(Vector3(3.2,top,.3))
        local b=n:CreateComponent("RigidBody");b.collisionLayer=1;self.space:Register(b,{type="sign"})
    end end
    for i,p in ipairs(self.layout.cones) do
        local n=self.root:CreateChild("Cone"..i);n.position=Coord.Vec(p[1],.375,p[2])
        n:CreateComponent("CollisionShape"):SetCylinder(.6,.75)
        local b=n:CreateComponent("RigidBody");b.mass=4;b.friction=.7;b.restitution=.2;b.linearDamping=.3;b.angularDamping=.6;b.collisionLayer=4
        local c={node=n,home=n.position};c.body=self.space:Register(b,{type="cone",ref=c});Assets.Attach(n,Assets.data.cones)
        self.cones[#self.cones+1]=c
    end
    for i,t in ipairs(self.layout.targets) do
        local n=self.root:CreateChild("Target"..i);n.position=Coord.Vec(t.pos[1],0,t.pos[2])
        local shape=n:CreateComponent("CollisionShape");shape:SetBox(Vector3(.3,2.2,2),Vector3(0,1.6,0))
        local b=n:CreateComponent("RigidBody");b.collisionLayer=4;b.kinematic=t.kind=="moving"
        local target={node=n,native=b,definition=t,hp=t.hp,alive=true,respawn=0,fall=0,hitAt=-9,pos={t.pos[1],1.6,t.pos[2]}}
        target.body=self.space:Register(b,{type="target",ref=target})
        Assets.Attach(n,Assets.data.targetBase)
        target.board=n:CreateChild("Board");target.board.position=Vector3(0,.5,0)
        target.models=Assets.Attach(target.board,Assets.data.targetBoard)
        self.targets[#self.targets+1]=target
    end
end
function M:NewVehicle(spec,unit)
    local vehicle=Vehicle.New(self.space,spec)
    self.space.bodies[vehicle.node:GetID()].owner={type="car",ref=unit}
    return vehicle
end
function M:SetUnits(bp,combat)
    for _,unit in ipairs(self.units) do unit:Dispose() end
    self.units={};self.debris:Clear()
    local source=bp:ToTable()
    local prefab=require("construction.Prefab").BuildRaceCar(require("construction.Blueprint").New()):ToTable()
    for _,spot in ipairs(self.layout.unitSpots) do
        self.units[#self.units+1]=CarUnit.New(self,spot.who=="self" and source or prefab,{name=spot.name,spawn=spot,combat=combat==true})
    end
end
function M:CastRay(origin,direction,length,excluded)
    local best=self.space:Raycast(origin,direction,length,excluded,"car")
    for _,unit in ipairs(self.units) do if unit.alive and unit.vehicle.body~=excluded then
        local hit=VehicleRay.Cast(unit.vehicle,origin,direction,best and best.dist or length)
        if hit and (not best or hit.dist<best.dist) then
            hit.owner={type="car",ref=unit,partId=hit.partId};best=hit
        end
    end end
    return best
end
function M:SweepDrill(...)
    self.drillSweep=self.drillSweep or require('physics.DrillSweep').New(self)
    return self.drillSweep:Cast(...)
end
function M:Lockables(excluded,team,accept)
    local out={}
    for _,t in ipairs(self.targets) do if t.alive then out[#out+1]=t end end
    for _,u in ipairs(self.units) do
        if u.alive and u.vehicle.body~=excluded and (not team or team=='neutral' or u.team~=team) and (not accept or accept(u)) then
            u:Position();out[#out+1]=u
        end
    end
    return out
end
-- Sphere around impact -> exposed targets/parts receive source falloff; self is
-- excluded. Ray occlusion protects targets; each car distributes one damage pool
-- across its visible parts. Boundary edge == radius retains 30 percent damage.
function M:Explode(point,radius,damage,excluded,accept,cast)
    local V=require 'core.Math3'
    for _,t in ipairs(self.targets) do if t.alive then
        local delta=V.Sub(t.pos,point);local d=V.Length(delta);local edge=math.max(0,d-1)
        if edge<=radius then
            local dir=V.Scale(delta,1/(d>0 and d or 1))
            local los=cast and cast(point,dir,d,excluded) or self:CastRay(point,dir,d,excluded)
            if not los or los.owner and los.owner.ref==t then
                self:Hit({owner={type='target',ref=t},point=t.pos},damage*(1-edge/radius*.7),dir,0,0)
            end
        end
    end end
    for _,u in ipairs(self.units) do
        if u.alive and u.vehicle.body~=excluded and (not accept or accept(u)) and V.Length(V.Sub(u:Position(),point))<=radius+u.spec.bounds.radius then
            if u:Explode(point,radius,damage)>0 then self.stats.hits=self.stats.hits+1 end
        end
    end
    local function Push(body,k0,mass)
        local p=body.translation();local delta={p.x-point[1],p.y-point[2],p.z-point[3]};local d=V.Length(delta)
        if d>radius*2 then return end
        local f=1-d/(radius*2);local k=k0*f/(d>0 and d or 1)
        body.applyImpulse({x=delta[1]*k,y=8*f*mass/4,z=delta[3]*k},true)
    end
    for _,c in ipairs(self.cones) do Push(c.body,25,4) end
    for _,p in ipairs(self.debris.pieces) do Push(p.body,6*p.mass,p.mass) end
end
function M:RecordDamage(unit,amount,point,opts)
    if self.feedbackPlayer and (unit==self.feedbackPlayer or self.attacker and self.attacker~=self.feedbackPlayer) then return end
    self.stats.damage=self.stats.damage+amount;self.metrics:Damage(self.time,unit,amount,point,false,opts)
end
function M:RecordKill(unit,pos)
    if unit==self.feedbackPlayer then self.fx[#self.fx+1]={type='explode',pos=pos,radius=3};return end
    self.fx[#self.fx+1]={type="explode",pos=pos,radius=3}
    if unit.lastHitBy and unit.lastHitBy~=self.feedbackPlayer then return end
    self.stats.kills=self.stats.kills+1
    self.metrics:Damage(self.time,unit,0,pos,true)
end
function M:Hit(hit,damage,direction,impulse,pierce)
    local o=hit.owner;if not o then return end
    if o.type=="target" and o.ref.alive then
        local t=o.ref;local amount=math.min(t.hp,damage);t.hp=t.hp-amount;t.hitAt=self.time
        self.stats.hits=self.stats.hits+1;self.stats.damage=self.stats.damage+amount
        if t.hp<=.001 then
            t.alive=false;t.respawn=self.time+4;t.native.enabled=false;self.stats.kills=self.stats.kills+1
        end
        self.metrics:Damage(self.time,t,amount,hit.point,not t.alive)
    elseif o.type=="car" then
        self.stats.hits=self.stats.hits+1;o.ref:HitRay(hit,damage,direction,pierce)
        if impulse>0 and o.ref.vehicle then
            o.ref.vehicle.body.applyImpulseAtPoint({x=direction[1]*impulse,y=direction[2]*impulse,z=direction[3]*impulse},
                {x=hit.point[1],y=hit.point[2],z=hit.point[3]})
        end
    elseif (o.type=="cone" or o.type=="debris") and impulse>0 then
        o.ref.body.applyImpulseAtPoint({x=direction[1]*impulse,y=(direction[2]+.3)*impulse,z=direction[3]*impulse},
            {x=hit.point[1],y=hit.point[2],z=hit.point[3]})
    end
end
function M:Step(dt)
    self.time=self.time+dt
    self.debris:Advance(self.time)
    for _,unit in ipairs(self.units) do unit:Flush();unit:Step(dt) end
    for _,t in ipairs(self.targets) do
        local d=t.definition
        if d.kind=="moving" then t.node.position=Coord.Vec(d.pos[1],0,d.pos[2]+d.amp*math.sin(self.time*d.speed/d.amp)) end
        local p=t.node.position;t.pos[1],t.pos[2],t.pos[3]=-p.x,p.y+1.6,p.z
        if not t.alive and self.time>=t.respawn then t.alive=true;t.hp=d.hp;t.native.enabled=true end
    end
    self.space:Step(dt)
    for _,unit in ipairs(self.units) do unit:SavePose() end
    self.debris:CapturePoses()
    self.metrics:Step(self.time)
end
function M:GroundAt(x,z) return 0 end
function M:Reset()
    for _,t in ipairs(self.targets) do
        t.alive=true;t.hp=t.definition.hp;t.native.enabled=true;t.hitAt=-9;t.fall=0
    end
    for _,c in ipairs(self.cones) do
        c.body.setTranslation({x=-c.home.x,y=c.home.y,z=c.home.z})
        c.body.setRotation({x=0,y=0,z=0,w=1});c.body.setLinvel({x=0,y=0,z=0});c.body.setAngvel({x=0,y=0,z=0})
    end
    self.debris:Clear();for _,u in ipairs(self.units) do u:Spawn() end
    for k in pairs(self.stats) do self.stats[k]=0 end
    self.metrics:Reset();self.fx={}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.drillSweep then self.drillSweep:Dispose();self.drillSweep=nil end
    for _,unit in ipairs(self.units) do unit:Dispose() end
    self.units={};self.debris:Clear();self.fx={};self.viewEvents={};self.debris.events={}
    self.root:Dispose();self.space:Dispose();self.cones={};self.targets={}
    self.root=nil;self.scene=nil;self.env=nil;self.metrics=nil;self.feedbackPlayer=nil;self.attacker=nil
    self.debris.space=nil;self.space=nil;self.layout=nil
end
return M
