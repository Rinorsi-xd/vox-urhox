-- Dynamic massless analytic sensors, exactly the four source IK segment boxes.
-- The solid mounting plate stays in VehicleSpec; sensors never hold up a car.
local VehicleSpec=require("drive.VehicleSpec")

local V=require('core.Math3')
local Rot=require('core.Rotations')
local IK=require('parts.MechIK')
local CELL=require('Config').CELL
local M={};M.__index=M
local joints={thigh='hip',shin='knee',tarsus='ankle',foot='ball'}
function M.New(vehicle)
    local self=setmetatable({vehicle=vehicle,items={}},M)
    for _,leg in ipairs(vehicle.spec.mechLegs or {}) do local info=IK.Data(leg.type)
        for _,name in ipairs({'thigh','shin','tarsus','foot'}) do local bounds=info.segmentBounds[name];local half={}
            for i=1,3 do half[i]=math.max(.02,(bounds.max[i]-bounds.min[i])*CELL/2*.9) end
            self.items[#self.items+1]={leg=leg,name=name,partId=leg.partId,half=half,segmentCenter=V.Scale(V.Add(bounds.min,bounds.max),.5)}
        end
    end;self:Update();return self
end
function M:Update()
    local vehicle=self.vehicle;local poses={}
    for _,item in ipairs(self.items) do
        local l=item.leg;local pose=poses[l.partId];if not pose then local s=vehicle.mechStates and vehicle.mechStates[l.partId];pose=s and vehicle.mechControl:Pose(s) or IK.Solve(l.type,IK.Data(l.type).joints.toe);poses[l.partId]=pose end
        local angle=pose.thigh;if item.name~='thigh' then angle=angle+pose.shin end;if item.name=='tarsus' or item.name=='foot' then angle=angle+pose.tarsus end;if item.name=='foot' then angle=angle+pose.foot end
        local q=V.QMul(V.QMul({x=0,y=math.sin(pose.yaw/2),z=0,w=math.cos(pose.yaw/2)},{x=0,y=0,z=math.sin(pose.roll/2),w=math.cos(pose.roll/2)}),{x=math.sin(angle/2),y=0,z=0,w=math.cos(angle/2)})
        local localPoint=V.Add(pose.points[joints[item.name]],V.RotateUnit(q,item.segmentCenter))
        item.center=V.Add(l.origin,V.Scale(Rot.ApplyRot(l.rot,localPoint),CELL));item.quat=V.QMul(VehicleSpec.GEOMETRY.rotations[l.rot+1],q)
    end
    if #self.items>0 then vehicle.rayBounds=nil end
end
return M
