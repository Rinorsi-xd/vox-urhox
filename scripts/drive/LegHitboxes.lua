-- Massless combat sensors. They share the controller IK and never support physics.
-- Four oriented segment boxes per leg; base hull remains in VehicleSpec.
local V=require "core.Math3"
local Rot=require "core.Rotations"
local Assets=require "parts.PartAssets"
local IK=require "parts.LegIK"
local Spec=require "drive.VehicleSpec"
local CELL=require("Config").CELL
local M={};M.__index=M
local JOINTS={hip='hip',link1='shoulderJoint',link2='elbow',blade='knee'}
local function Center(leg,origin,q,point)
    -- Preserve Rotate/Add/ApplyRot/Scale/Add operation grouping without their
    -- intermediate vector tables.
    local x,y,z,w=q.x,q.y,q.z,q.w
    local ix=w*point[1]+y*point[3]-z*point[2]
    local iy=w*point[2]+z*point[1]-x*point[3]
    local iz=w*point[3]+x*point[2]-y*point[1]
    local iw=-x*point[1]-y*point[2]-z*point[3]
    local vx=origin[1]+(ix*w-iw*x-iy*z+iz*y)
    local vy=origin[2]+(iy*w-iw*y-iz*x+ix*z)
    local vz=origin[3]+(iz*w-iw*z-ix*y+iy*x)
    local m=Rot.ROTATIONS[leg.rot].m;local base=leg.origin
    return {base[1]+(m[1]*vx+m[2]*vy+m[3]*vz)*CELL,
        base[2]+(m[4]*vx+m[5]*vy+m[6]*vz)*CELL,
        base[3]+(m[7]*vx+m[8]*vy+m[9]*vz)*CELL}
end
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
-- Leg states only change inside the controller step, which then calls Update.
-- Only combat rays and drill sweeps read the boxes, so solve them on first read.
function M:Update()
    if #self.items==0 then return end
    self.dirty=true;self.vehicle.rayBounds=nil
end
function M:Items()
    if self.dirty then self.dirty=false;self:Refresh() end
    return self.items
end
function M:Refresh()
    local poses={}
    for _,item in ipairs(self.items) do
        local leg,name=item.leg,item.name;local state=self.vehicle.legStates[leg.partId]
        local pose=poses[leg.partId]
        if not pose then
            pose=IK.Solve(item.info,state and state.target or item.info.origins.toe,state and state.bladeAngle or 0)
            pose.hitboxYaw={x=0,y=math.sin(pose.yaw/2),z=0,w=math.cos(pose.yaw/2)}
            poses[leg.partId]=pose
        end
        local angle=name=='hip' and 0 or name=='link1' and pose.first or name=='link2' and pose.first+pose.second or pose.first+pose.second+pose.blade
        local q=V.QMul(pose.hitboxYaw,
            {x=0,y=0,z=math.sin(angle/2),w=math.cos(angle/2)})
        local origin=pose.points[JOINTS[name]]
        item.center=Center(leg,origin,q,item.segmentCenter)
        item.quat=V.QMul(Spec.GEOMETRY.rotations[leg.rot+1],q)
    end
end
return M
