-- Detached connected groups keep their original body-space geometry. Native
-- compound boxes/hulls/cylinders collide with ground and cars for five seconds.
-- No suspension or gameplay controller; initial velocity is sampled at new COM.
local Spec=require "drive.VehicleSpec"
local Coord=require "core.Coord"
local V=require "core.Math3"
local M={LIFE=5,MAX_PIECES=60};M.__index=M
local function Vec(v) return Coord.Vec(table.unpack(v)) end
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
local function CylinderAxis(a)
    local up=Vec(V.Normalize(a));return Quaternion(Vector3.UP,up)
end
function M.New(space)
    return setmetatable({space=space,pieces={},events={},nextId=1,time=0},M)
end
function M:SavePose(p)
    p.previous=p.current;local b=p.body;local t=b.translation();p.current={p={t.x,t.y,t.z},q=b.rotation()}
end
function M:Spawn(parts,pose,velocity,kick)
    local shape=Spec.Debris(parts)
    if #shape.boxes+#shape.hulls+#shape.wheels==0 then return end
    local node=self.space.scene:CreateChild("Debris"..self.nextId)
    node.position=Coord.Vec(pose.p.x,pose.p.y,pose.p.z);node.rotation=Quat(pose.q)
    local native=node:CreateComponent("RigidBody");native:DisableMassUpdate()
    native.friction=.7;native.restitution=.15;native.linearDamping=.1;native.angularDamping=.3
    native.collisionLayer=8;native.ccdRadius=.1;native.ccdMotionThreshold=.1
    for _,list in ipairs({shape.boxes,shape.hulls}) do for _,b in ipairs(list) do
        node:CreateComponent("CollisionShape"):SetBox(Vector3(b.half[1]*2,b.half[2]*2,b.half[3]*2),Vec(b.center),b.quat and Quat(b.quat) or Quaternion.IDENTITY)
    end end
    for _,w in ipairs(shape.wheels) do
        node:CreateComponent("CollisionShape"):SetCylinder(w.radius*2,w.width,Vec(w.center),CylinderAxis(w.axle))
    end
    native:EnableMassUpdate();native.mass=shape.mass
    local p={id=self.nextId,node=node,native=native,parts=parts,age=0,bornAt=self.time,mass=shape.mass};self.nextId=self.nextId+1
    p.body=self.space:Register(native,{type="debris",ref=p})
    local com=p.body.center();local v=velocity({com.x,com.y,com.z});kick=kick or {0,0,0}
    p.body.setLinvel({x=v[1]+kick[1],y=v[2]+kick[2],z=v[3]+kick[3]})
    p.body.setAngvel({x=(math.random()-.5)*4,y=(math.random()-.5)*4,z=(math.random()-.5)*4})
    self:SavePose(p);p.previous=p.current
    self.pieces[#self.pieces+1]=p;self.events[#self.events+1]={type="spawn",piece=p}
    while #self.pieces>M.MAX_PIECES do self:Remove(self.pieces[1]) end
    return p
end
function M:Remove(piece)
    for i,p in ipairs(self.pieces) do if p==piece then
        table.remove(self.pieces,i);self.space:Unregister(p.native);p.node:Dispose()
        self.events[#self.events+1]={type="remove",piece=p};return
    end end
end
-- Use the world's clock, before respawn and physics. Summing an independent
-- age after physics left a wreck colliding with its replacement for 1-2 steps.
function M:Advance(time)
    self.time=time
    for i=#self.pieces,1,-1 do
        local p=self.pieces[i];p.age=time-p.bornAt
        if p.age>=M.LIFE or p.body.translation().y< -20 then self:Remove(p) end
    end
end
function M:CapturePoses() for _,p in ipairs(self.pieces) do self:SavePose(p) end end
function M:Clear() while #self.pieces>0 do self:Remove(self.pieces[#self.pieces]) end end
return M
