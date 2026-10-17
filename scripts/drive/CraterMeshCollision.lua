-- Cross section: visual rock /\___/\ keeps its hollow foot and gaps.
-- A convex hull would bridge those gaps: /=======\ and stop the chassis early.
-- Static visual triangles support wheels, weapons and cameras on layer 1.
-- Native world transforms are baked offline; headless runs need no visual nodes.
local Data=require 'core.ResourceData'
local M={}

function M.Read()
    local data=Data.Read('Crater/DrivingCollision.json')
    assert(data.version==1 and type(data.skipBlocks)=='table' and type(data.meshes)=='table',
        'Invalid crater driving collision descriptors')
    return data
end

function M.Build(world,checkpoint,data)
    assert(not world.assetNamespace,'Crater visual collisions must not apply to another map')
    assert(not world.drivingMeshCollisionCount,'Crater visual collisions already built')
    data=data or M.Read()
    world.drivingMeshCollisionCount=0
    world.drivingMeshTriangleCount=0
    for i,d in ipairs(data.meshes) do
        local node=world.root:CreateChild('DrivingSurface_'..d.nodeId)
        node.position=Vector3(table.unpack(d.position))
        node.rotation=Quaternion(table.unpack(d.rotation))
        node.scale=Vector3(table.unpack(d.scale))
        local model=assert(cache:GetResource('Model',d.model),'Missing driving mesh: '..d.model)
        node:CreateComponent('CollisionShape'):SetTriangleMesh(model,0)
        local body=node:CreateComponent('RigidBody')
        body.collisionLayer=1;body.friction=data.friction
        world.space:Register(body,{type='ground'})
        world.drivingMeshCollisionCount=world.drivingMeshCollisionCount+1
        world.drivingMeshTriangleCount=world.drivingMeshTriangleCount+d.triangles
        if checkpoint then checkpoint(i/#data.meshes,'driving-meshes') end
    end
    print('[CraterMeshCollision] Visual meshes='..world.drivingMeshCollisionCount..
        ' triangles='..world.drivingMeshTriangleCount..' skipped layout blocks='..#data.skipBlocks)
end
return M
