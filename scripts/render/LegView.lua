-- Resolve world-locked feet against the interpolated visual body, not last tick.
local Math=require "core.Math3"
local Coord=require "core.Coord"
local Rig=require "render.PartRig"
local CELL=require("Config").CELL
local M={};M.__index=M
function M.New(view,vehicle)
    local self=setmetatable({items={},vehicle=vehicle},M)
    for _,leg in ipairs(vehicle.spec.legs) do
        local vis=view.visuals[leg.partId]
        if vis and vis.rig.joints then self.items[#self.items+1]={id=leg.partId,vis=vis,error=0} end
    end
    return self
end
function M:Update(alpha,dt)
    local decay=math.exp(-math.min(.1,dt)*22)
    for _,item in ipairs(self.items) do
        local s=self.vehicle.legStates[item.id];local vis=item.vis
        if s and s.drillDriven and s.target then
            item.error=Rig.SetLegTarget(vis,s.target,s.bladeAngle).error*CELL
        elseif s and (s.grounded or s.swing) and s.foot then
            local foot=s.grounded and s.foot or s.previous and Math.Mix(s.previous,s.foot,alpha) or s.foot
            local target=vis.node:WorldToLocal(Coord.Vec(table.unpack(foot)))
            local pose=Rig.SetLegTarget(vis,{-target.x,target.y,target.z},s.bladeAngle)
            item.error=pose.error*CELL
        else
            for _,name in ipairs({'hip','link1','link2','blade'}) do
                local n=vis.rig.joints[name];n.rotation=n.rotation:Slerp(Quaternion.IDENTITY,1-decay)
            end
            item.error=0
        end
    end
end
function M.ToeWorld(item)
    local o=item.vis.data.segments.info.origins
    local p=item.vis.rig.joints.blade:LocalToWorld(Coord.Vec(table.unpack(Math.Sub(o.toe,o.blade))))
    return {-p.x,p.y,p.z}
end
return M
