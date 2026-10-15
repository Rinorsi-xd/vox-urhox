-- ThirdPersonCamera solves the boom position. Source state owns its framing,
-- obstruction distance and target smoothing; aiming is parallel to the boom.
local ThirdPerson=require 'urhox-libs.Camera.ThirdPersonCamera'
local Coord=require 'core.Coord'
local M={}
function M.Create(scene,farClip)
    return ThirdPerson.Create(scene,{modes={normal={distance=8,offset=Vector3.ZERO,fov=48}},
        collisionMask=0,minDistance=.000001,transitionSpeed=math.huge,
        collisionApproachSpeed=math.huge,collisionRecoverySpeed=math.huge,farClip=farClip or 2600})
end
function M.Apply(camera,target,dt,pose,yaw,pitch)
    local node=camera:GetNode()
    if pose.eye then node.position=Coord.Vec(table.unpack(pose.eye))
    else
        target.position=Coord.Vec(table.unpack(pose.target))
        local mode=camera:GetMode()=='sourceA' and 'sourceB' or 'sourceA'
        camera:SetModeConfig(mode,{distance=pose.distance,offset=Vector3.ZERO,fov=48})
        camera:SetMode(mode);camera:Update(math.max(.000001,dt),target,yaw,pose.boomPitch)
    end
    node.rotation=Quaternion(yaw,Vector3.UP)*Quaternion(pitch,Vector3.RIGHT)
end
return M
