-- Camera-only copies of opaque building surfaces, owned by the map lifetime.
-- Section: car ---- ray ---- [trim / ceiling mesh] -- [coarse driving hull]
-- The camera stops at the visible surface. Trigger bodies never push a vehicle;
-- gameplay rays ignore triggers in physics.Space. Transparent FX are excluded.
-- Edge cases: signs protruding from walls, ceiling beams, gaps in open doors.
-- Use triangle meshes, never a building-wide box that would seal those gaps.
local Data=require 'core.ResourceData'
local M={LAYER=0x8000}
function M.Build(world,checkpoint)
    local materials=Data.Read('Crater/Materials.json')
    local moving={}
    for _,d in ipairs(Data.Read('Crater/Dynamics.json')) do moving[d.id]=true end
    local candidates={}
    for _,name in ipairs({'fortress_own','fortress_enemy','ship','props'}) do
        local group=world.scene:GetChild(name)
        if group then for _,model in ipairs(group:GetComponents('StaticModel',true)) do
            local material=model.material
            local index=material and tonumber(material.name:match('material%-(%d+)%.xml'))
            local definition=index and materials[index]
            local animated=false
            local node=model.node
            while node and node~=group do
                if moving[node:GetID()] then animated=true;break end
                node=node.parent
            end
            if definition and not animated and definition.kind~='fx' and definition.kind~='shield' and definition.kind~='glass' then
                candidates[#candidates+1]=model
            end
        end end
    end
    world.cameraObstacleCount=0
    for i,model in ipairs(candidates) do
        local node=world.root:CreateChild('CameraSurface_'..model.node:GetID())
        node.position=model.node.worldPosition;node.rotation=model.node.worldRotation;node.scale=model.node.worldScale
        local body=node:CreateComponent('RigidBody')
        body.collisionLayer=M.LAYER;body.trigger=true
        node:CreateComponent('CollisionShape'):SetTriangleMesh(model.model,0)
        world.cameraObstacleCount=world.cameraObstacleCount+1
        if checkpoint then checkpoint(i/#candidates) end
    end
end
return M
