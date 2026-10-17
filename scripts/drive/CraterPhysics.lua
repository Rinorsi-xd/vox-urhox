-- Cross section (metres): source hull floors/ramps above the terrain grid.
--   deck ======      openings remain open; no broad building box seals them
--         / ramp      wall |   hanging geometry is never flattened
-- terrain /\/\____ 2 m cell triangles, same diagonal as source physics
-- Static layer 1 supports suspension, weapons and camera; own vehicle is layer 2.
-- Rocks use their visible triangles, leaving recessed feet and cracks open:
--     /\     /\       not a convex bridge across the gap: /\____/\
local CraterLayout=require("drive.CraterLayout")
local CraterMeshCollision=require("drive.CraterMeshCollision")
local ResourceData=require("core.ResourceData")
local TerrainObstacles=require("drive.TerrainObstacles")
local CameraObstacles=require("controls.CameraObstacles")

local Coord=require 'core.Coord'
local M={}
local function Body(world,node,friction)
    local b=node:CreateComponent('RigidBody');b.friction=friction or .85;b.collisionLayer=1
    world.space:Register(b,{type='ground'})
    return b
end
function M.Build(world,checkpoint)
    CraterLayout.Fill(world.layout,checkpoint and function(p) checkpoint(p*.15,'data') end)
    local function Progress(p,phase) if checkpoint then checkpoint(.15+p*.85,phase) end end
    local layout=world.layout;local t=layout.terrain;local n=t.n;local size=t.size;local step=size/n;local h=t.heights
    local driving=not world.assetNamespace and CraterMeshCollision.Read() or nil
    local skip={}
    if driving then for _,index in ipairs(driving.skipBlocks) do skip[index]=true end end
    for x=0,n-1,32 do for z=0,n-1,32 do
        local node=world.root:CreateChild('Terrain_'..x..'_'..z)
        local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,TRIANGLE_LIST)
        local function Vertex(i,j) geo:DefineVertex(Coord.Vec(-size/2+i*step,h[i*(n+1)+j+1],-size/2+j*step)) end
        for i=x,math.min(n-1,x+31) do for j=z,math.min(n-1,z+31) do
            -- X mirror reverses the triangle winding.
            Vertex(i,j);Vertex(i+1,j+1);Vertex(i,j+1)
            Vertex(i,j);Vertex(i+1,j);Vertex(i+1,j+1)
        end
            -- Yield within a terrain chunk while its geometry is still private.
            -- Keep the same 100 collision bodies and exact source triangles.
            Progress(.55*(x*n+z*32+(i-x+1)*32)/(n*n),'terrain')
        end
        geo:Commit();node:CreateComponent('CollisionShape'):SetCustomTriangleMesh(geo);geo.enabled=false;Body(world,node,.9)
        Progress(.55*(x*n+z*32+1024)/(n*n),'terrain')
    end end
    for i,b in ipairs(layout.blocks) do
        if not b.noPhysics and not skip[i] then
        if b.kind=='bound' then
            local lo=b.pos[2]-b.size[2]/2
            b.size={b.size[1],260-lo,b.size[3]};b.pos={b.pos[1],(260+lo)/2,b.pos[3]}
        end
        local node=world.root:CreateChild('Hull'..i);node.position=Coord.Vec(table.unpack(b.pos))
        local r=b.rot;local d=180/math.pi
        if b.rotation then local q=b.rotation;node.rotation=Quaternion(q[4],q[1],-q[2],-q[3])
        else node.rotation=Quaternion(r[1]*d,Vector3.RIGHT)*Quaternion(-r[2]*d,Vector3.UP)*Quaternion(-r[3]*d,Vector3.FORWARD) end
        local shape=node:CreateComponent('CollisionShape')
        if b.triangles then
            local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,TRIANGLE_LIST)
            local p=b.triangles;local idx=b.indices
            for k=1,#idx,3 do for _,j in ipairs({idx[k]+1,idx[k+2]+1,idx[k+1]+1}) do geo:DefineVertex(Coord.Vec(p[j*3-2],p[j*3-1],p[j*3])) end end
            geo:Commit();shape:SetCustomTriangleMesh(geo);geo.enabled=false
        elseif b.vertices then
            local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,POINT_LIST)
            for k=1,#b.vertices,3 do geo:DefineVertex(Coord.Vec(b.vertices[k],b.vertices[k+1],b.vertices[k+2])) end
            geo:Commit();shape:SetCustomConvexHull(geo);geo.enabled=false
        elseif b.radius then shape:SetCylinder(b.radius*2,b.height)
        else shape:SetBox(Vector3(table.unpack(b.size))) end
        local native=Body(world,node,b.friction)
        if world.AttachBlockPhysics then world:AttachBlockPhysics(native,b) end
        end
        if i%4==0 then Progress(.55+(driving and .25 or .4)*i/#layout.blocks,'hulls') end
    end
    if driving then
        CraterMeshCollision.Build(world,function(p) Progress(.8+.15*p,'rock-surfaces') end,driving)
    end
    local boulders=ResourceData.Read((world.assetNamespace or 'Crater')..'/Boulders.json')
    TerrainObstacles.Build(world,boulders,function(p) Progress(.95+.03*p,'boulders') end)
    if not world.assetNamespace then CameraObstacles.Build(world,function(p) Progress(.98+.02*p,'camera') end) end
    print('[CraterPhysics] Source heightfield '..n..'x'..n..', authored blocks '..#layout.blocks..', boulders '..world.boulderCount)
end
return M
