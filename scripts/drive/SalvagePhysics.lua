-- Source collider layout, metres:
--   terrain /\/\__ 4 m grid      platform ==== with open ramps/doors
--   box/cylinder/sphere hulls follow each source transform; mesh hulls retain
--   their triangles. The outer polygon is a 240 m wall, never an interior box.
-- Layer 1 supports wheels, weapon rays and camera. No duplicate camera mesh.
local Coord=require 'core.Coord'
local M={}
function M.Build(world,checkpoint)
    local data=require('core.ResourceData').Read('Salvage/Physics.json');world.physicsData=data
    local total=#data.terrain+#data.colliders+#world.layout.salvage.gameplay.walls;local done=0;local sphereChunks={}
    local function Body(node)
        local body=node:CreateComponent('RigidBody');body.collisionLayer=1;body.friction=.8
        world.space:Register(body,{type='ground'});done=done+1
        if checkpoint then checkpoint(done/total,'salvage-collision') end
    end
    for i,d in ipairs(data.terrain) do
        local node=world.root:CreateChild('Terrain'..i)
        node:CreateComponent('CollisionShape'):SetTriangleMesh(assert(cache:GetResource('Model',d.model)),0)
        Body(node)
    end
    for i,d in ipairs(data.colliders) do
        if d.type=='ball' then
            local key=math.floor(d.pos[1]/128)..':'..math.floor(d.pos[3]/128)
            local n=sphereChunks[key];if not n then n=world.root:CreateChild('Rocks'..key);sphereChunks[key]=n end
            n:CreateComponent('CollisionShape'):SetSphere(d.diameter,Coord.Vec(table.unpack(d.pos)))
            done=done+1;if checkpoint then checkpoint(done/total,'salvage-rocks') end
        else
        local node=world.root:CreateChild('Hull'..i);node.position=Coord.Vec(table.unpack(d.pos))
        local q=d.quat;node.rotation=Quaternion(q[4],q[1],-q[2],-q[3])
        local shape=node:CreateComponent('CollisionShape')
        if d.type=='box' then shape:SetBox(Vector3(table.unpack(d.size)))
        elseif d.type=='cyl' then shape:SetCylinder(d.diameter,d.height)
        elseif d.type=='ball' then shape:SetSphere(d.diameter)
        elseif d.type=='mesh' then shape:SetTriangleMesh(assert(cache:GetResource('Model',d.model)),0)
        else error('Unknown salvage collider '..tostring(d.type)) end
        Body(node)
        end
    end
    for _,node in pairs(sphereChunks) do
        local body=node:CreateComponent('RigidBody');body.collisionLayer=1;body.friction=.8;world.space:Register(body,{type='ground'})
    end
    for i,d in ipairs(world.layout.salvage.gameplay.walls) do
        local ax,az,bx,bz=d.a[1],d.a[2],d.b[1],d.b[2];local length=math.sqrt((bx-ax)^2+(bz-az)^2)
        local x,z=(ax+bx)/2,(az+bz)/2
        local node=world.root:CreateChild('Boundary'..i);node.position=Coord.Vec(-x,world:GroundAt(-x,z)+40,z)
        node.rotation=Quaternion(-math.atan(-(bx-ax),bz-az)*180/math.pi,Vector3.UP)
        node:CreateComponent('CollisionShape'):SetBox(Vector3(3,240,length+1.2));Body(node)
    end
    print('[SalvagePhysics] Offline terrain='..#data.terrain..' hulls='..#data.colliders..' boundary='..#world.layout.salvage.gameplay.walls)
end
return M
