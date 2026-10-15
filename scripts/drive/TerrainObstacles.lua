-- Rapier obstacle membership 0x8000 maps to native 0x1000: native 0x8000
-- is already reserved for camera surfaces. Query masks exclude both sensors
-- and medium support; weapon/camera queries still see real rock silhouettes.
local Coord=require 'core.Coord'
local M={LAYER=0x1000,SUPPORT_MASK=0x6fff,TUNING={minRadius=1.6,mediumFactor=2.5,passFactor=2.5,
    friction=.8,heightScale=1.25,sink=.25}}
function M.Classify(radius)
    local t=M.TUNING
    if radius<t.minRadius then return nil end
    local medium=radius<t.minRadius*t.mediumFactor
    return {layer=medium and M.LAYER or 1,mask=medium and radius<t.minRadius*t.passFactor and 0xfffd or 0xffff}
end
function M.Build(world,boulders,checkpoint)
    -- Driving chassis layer 2 passes medium rocks; support rays pass through.
    -- hull matches visible rock /
    --                        /  \   < wheel suspension queries ground below
    -- ground _______________/____\____; large hulls still block the chassis.
    world.boulderCount=0;world.boulderHullCount=0;world.mediumBoulderCount=0
    for i,b in ipairs(boulders) do
        local group=M.Classify(b.r)
        if group then
            local node=world.root:CreateChild('Boulder'..i)
            local body=node:CreateComponent('RigidBody');body.friction=M.TUNING.friction
            body.collisionLayer=group.layer;body.collisionMask=group.mask
            local shape=node:CreateComponent('CollisionShape');local pts=b.pts;local count=0
            -- JSON exports typed Float32Array keys as "0", "1", ... .
            if pts then while pts[tostring(count)]~=nil do count=count+1 end;if count==0 then count=#pts end end
            if count>=12 and count%3==0 then
                local geo=node:CreateComponent('CustomGeometry');geo:BeginGeometry(0,POINT_LIST)
                for k=0,count-1,3 do
                    local function At(index) return pts[tostring(index)] or pts[index+1] end
                    geo:DefineVertex(Coord.Vec(At(k),At(k+1),At(k+2)))
                end
                geo:Commit();shape:SetCustomConvexHull(geo);geo.enabled=false
                world.boulderHullCount=world.boulderHullCount+1
            else
                local radius=math.min(b.r,b.h*M.TUNING.heightScale)
                node.position=Coord.Vec(b.x,b.y-radius*M.TUNING.sink,b.z);shape:SetSphere(radius*2)
            end
            world.space:Register(body,{type='ground'})
            world.boulderCount=world.boulderCount+1
            if group.layer==M.LAYER then world.mediumBoulderCount=world.mediumBoulderCount+1 end
        end
        if checkpoint and i%4==0 then checkpoint(i/#boulders) end
    end
    if checkpoint then checkpoint(1) end
end
return M
