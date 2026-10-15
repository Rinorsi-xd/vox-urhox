-- Feet stay in world space through interpolation; IK is shared with hit sensors.
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local Rig=require 'render.PartRig'
local IK=require 'parts.MechIK'
local CELL=require('Config').CELL
local M={};M.__index=M
function M.New(view,vehicle)
    local self=setmetatable({},M);self:init(view,vehicle);return self
end
function M:init(view,vehicle)
    self.vehicle=vehicle;self.items={}
    for _,leg in ipairs(vehicle.spec.mechLegs or {}) do
        local vis=view.visuals[leg.partId]
        if vis and vis.rig.mech then self.items[#self.items+1]={id=leg.partId,vis=vis,error=0} end
    end
end
function M:Update(alpha,dt)
    for _,item in ipairs(self.items) do
        local state=self.vehicle.mechStates[item.id];local vis=item.vis
        for _,model in ipairs(vis.shieldModels or {}) do model.instanceCustomData=Vector4(state and state.pulse or 0,0,0,0) end
        if state and state.foot then
            local foot=state.grounded and state.foot or state.previous and V.Mix(state.previous,state.foot,alpha) or state.foot
            local p=vis.node:WorldToLocal(Coord.Vec(foot[1],foot[2]+(state.soleLift or 0),foot[3]))
            local target=state.drillDriven and state.target or {-p.x,p.y,p.z}
            local pose=IK.Solve(vis.data.segments.type,target,state.pitch,state.toe,state.yaw)
            Rig.SetMechPose(vis,pose,math.max(state.vane or 0,state.jet or 0));item.error=pose.error*CELL
        end
    end
end
function M.StandOn(vis,floorY)
    local info=vis.data.segments.info;local toe=info.joints.toe
    local at=vis.node:LocalToWorld(Coord.Vec(table.unpack(toe)))
    local ground=vis.node:LocalToWorld(Coord.Vec(toe[1],info.groundY,toe[3]))
    local target=toe
    if ground.y<(floorY or 0)-.01 then
        local p=vis.node:WorldToLocal(Vector3(at.x,(floorY or 0)+at.y-ground.y,at.z))
        target={-p.x,math.max(p.y,toe[2]-info.standHeight*.5),p.z}
    end
    Rig.SetMechPose(vis,IK.Solve(vis.data.segments.type,target),0)
end
return M
