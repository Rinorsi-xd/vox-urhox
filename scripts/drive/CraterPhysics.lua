-- Cross section (metres): source hull floors/ramps above the terrain grid.
--   deck ======      openings remain open; no broad building box seals them
--         / ramp      wall |   hanging geometry is never flattened
-- terrain /\/\____ 2 m cell triangles, same diagonal as source physics
-- Static layer 1 supports suspension, weapons and camera; own vehicle is layer 2.
local Coord=require 'core.Coord'
local M={}
local function Body(world,node,friction)
    local b=node:CreateComponent('RigidBody');b.friction=friction or .85;b.collisionLayer=1
    world.space:Register(b,{type='ground'})
end
function M.Build(world,checkpoint)
    require('drive.CraterLayout').Fill(world.layout,checkpoint and function(p) checkpoint(p*.15,'data') end)
    local function Progress(p,phase) if checkpoint then checkpoint(.15+p*.85,phase) end end
    local layout=world.layout;local t=layout.terrain;local n=t.n;local size=t.size;local step=size/n;local h=t.heights
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
    for i,b in ipairs(layout.blocks) do if not b.noPhysics then
        local node=world.root:CreateChild('Hull'..i);node.position=Coord.Vec(table.unpack(b.pos))
        local r=b.rot;local d=180/math.pi
        node.rotation=Quaternion(r[1]*d,Vector3.RIGHT)*Quaternion(-r[2]*d,Vector3.UP)*Quaternion(-r[3]*d,Vector3.FORWARD)
        local shape=node:CreateComponent('CollisionShape')
        if b.vertices then
            local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,POINT_LIST)
            for k=1,#b.vertices,3 do geo:DefineVertex(Coord.Vec(b.vertices[k],b.vertices[k+1],b.vertices[k+2])) end
            geo:Commit();shape:SetCustomConvexHull(geo);geo.enabled=false
        else shape:SetBox(Vector3(table.unpack(b.size))) end
        Body(world,node,b.friction)
        if i%4==0 then Progress(.55+.4*i/#layout.blocks,'hulls') end
    end end
    -- Source scatter contract: ground-embedded spheres, radius limited by height.
    -- Tiny pebbles remain visual; r >= 0.9 m boulders stop wheels and projectiles.
    local boulders=require('core.ResourceData').Read('Crater/Boulders.json')
    world.boulderCount=0
    for i,b in ipairs(boulders) do if b.r>=.9 then
        local radius=math.min(b.r,b.h*1.25)
        local node=world.root:CreateChild('Boulder'..i);node.position=Coord.Vec(b.x,b.y-radius*.25,b.z)
        node:CreateComponent('CollisionShape'):SetSphere(radius*2);Body(world,node,.8)
        world.boulderCount=world.boulderCount+1
        if i%8==0 then Progress(.95+.03*i/#boulders,'boulders') end
    end end
    require('controls.CameraObstacles').Build(world,function(p) Progress(.98+.02*p,'camera') end)
    print('[CraterPhysics] Source heightfield '..n..'x'..n..', authored blocks '..#layout.blocks..', boulders '..world.boulderCount)
end
return M
