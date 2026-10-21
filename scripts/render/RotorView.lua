-- Absolute source poses avoid parenting drift. Joined surfaces and decals are
-- partitioned once at bind time; animation changes transforms, never vertices.
local JoinedMesh=require("render.JoinedMesh")

local R=require 'construction.Rotors'
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local CELL=require('Config').CELL
local RotorDisc=require 'render.RotorDisc'
local M={};M.__index=M
local function Quat(q) return Quaternion(q.w,q.x,-q.y,-q.z) end
function M.New(view,vehicle)
    local self=setmetatable({},M);self:init(view,vehicle);return self
end
function M:init(view,vehicle)
    self.view=view;self.vehicle=vehicle;self.rest={};self.poses={}
    view.rotorJoined=view.rotorJoined or {};view.rotorOwners=vehicle.spec.rotorOf
    local retained={[view.joined]={}}
    for id,vis in pairs(view.visuals) do
        local p=vis.part
        if view.rotorOwners[id] then self.rest[id]={position=vis.node.position,rotation=vis.node.rotation} end
        if vis.joined then local owner=view.rotorOwners[id];local mesh=view.joined
            if owner then
                view.rotorJoined[owner]=view.rotorJoined[owner] or JoinedMesh.New(view.root)
                mesh=view.rotorJoined[owner];mesh:SetXray(view.xray~=nil)
            end;mesh:Add(p);retained[mesh]=retained[mesh] or {};retained[mesh][id]=true
        end
        if R.Is(p.type) and vis.head then
            RotorDisc.Bind(vis,p)
        end
    end
    -- Damage changes membership, not the identity of every surviving surface.
    local function Reconcile(mesh)
        local keep=retained[mesh] or {}
        for id in pairs(mesh.parts) do if not keep[id] then mesh:Remove(id) end end
    end
    Reconcile(view.joined)
    for owner,mesh in pairs(view.rotorJoined) do
        if not retained[mesh] then mesh:Dispose();view.rotorJoined[owner]=nil else Reconcile(mesh) end
    end
    view.joined:Update();for _,mesh in pairs(view.rotorJoined) do mesh:Update() end
    view.livery:PartsChanged();view.livery:Update()
end
function M:Update(alpha)
    local rotors=self.vehicle.rotors
    if #rotors==0 then return end
    for i,r in ipairs(rotors) do
        local a=r.prev+(r.angle-r.prev)*alpha
        self.poses[i]=R.Pose(r.parent and self.poses[r.parent] or R.IDENT,r.pivot,r.axis,a)
    end
    for id,rest in pairs(self.rest) do local vis=self.view.visuals[id]
        if vis then local owner=self.view.rotorOwners[id];local pose=owner and self.poses[owner]
            if pose then
                local at=R.Apply(pose,{-rest.position.x*CELL,rest.position.y*CELL,rest.position.z*CELL})
                vis.node.position=Coord.Vec(table.unpack(V.Scale(at,1/CELL)))
                vis.node.rotation=Quat(pose.q)*rest.rotation
            else vis.node.position=rest.position;vis.node.rotation=rest.rotation end
        end
    end
    for _,r in ipairs(rotors) do local vis=self.view.visuals[r.partId]
        if vis and vis.head then local a=r.prev+(r.angle-r.prev)*alpha
            RotorDisc.Update(vis,a,r.sign)
        end
    end
    for owner,mesh in pairs(self.view.rotorJoined) do local pose=self.poses[owner]
        mesh.root.position=Coord.Vec(table.unpack(V.Scale(pose.t,1/CELL)));mesh.root.rotation=Quat(pose.q)
    end
    for _,mesh in pairs(self.view.livery.meshes) do local pose=mesh.owner and self.poses[mesh.owner]
        mesh.node.position=pose and Coord.Vec(table.unpack(V.Scale(pose.t,1/CELL))) or Vector3.ZERO
        mesh.node.rotation=pose and Quat(pose.q) or Quaternion.IDENTITY
    end
end
return M
