-- Massless combat sensors. They share the controller IK and never support physics.
-- Four oriented segment boxes per leg; base hull remains in VehicleSpec.
local V=require "core.Math3"
local Rot=require "core.Rotations"
local Assets=require "parts.PartAssets"
local IK=require "parts.LegIK"
local Spec=require "drive.VehicleSpec"
local CELL=require("Config").CELL
local M={};M.__index=M
function M.New(vehicle)
    local self=setmetatable({vehicle=vehicle,items={}},M)
    for _,leg in ipairs(vehicle.spec.legs) do
        local info=Assets.Get(leg.type,leg.rot).segments.info
        for _,name in ipairs({'hip','link1','link2','blade'}) do
            local bounds=info.segmentBounds[name];local half={}
            for i=1,3 do half[i]=math.max(.015,(bounds.max[i]-bounds.min[i])*CELL/2) end
            self.items[#self.items+1]={leg=leg,name=name,info=info,partId=leg.partId,
                segmentCenter=V.Scale(V.Add(bounds.min,bounds.max),.5),half=half}
        end
    end
    self:Update();return self
end
function M:Update()
    if #self.items==0 then return end
    local poses={}
    for _,item in ipairs(self.items) do
        local leg,name=item.leg,item.name;local state=self.vehicle.legStates[leg.partId]
        local pose=poses[leg.partId]
        if not pose then pose=IK.Solve(item.info,state and state.target or item.info.origins.toe,state and state.bladeAngle or 0);poses[leg.partId]=pose end
        local angle=name=='hip' and 0 or name=='link1' and pose.first or name=='link2' and pose.first+pose.second or pose.first+pose.second+pose.blade
        local q=V.QMul({x=0,y=math.sin(pose.yaw/2),z=0,w=math.cos(pose.yaw/2)},
            {x=0,y=0,z=math.sin(angle/2),w=math.cos(angle/2)})
        local origin=pose.points[({hip='hip',link1='shoulderJoint',link2='elbow',blade='knee'})[name]]
        item.center=V.Add(leg.origin,V.Scale(Rot.ApplyRot(leg.rot,V.Add(origin,V.Rotate(q,item.segmentCenter))),CELL))
        item.quat=V.QMul(Spec.GEOMETRY.rotations[leg.rot+1],q)
    end
    if #self.items>0 then self.vehicle.rayBounds=nil end
end
return M
