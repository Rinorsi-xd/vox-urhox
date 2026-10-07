-- Source carVisual + ThrusterRig/HoverRig joint animation. Reads actuator output;
-- never feeds display smoothing or rotations back into physical thrust.
local Math=require "core.Math3"
local Coord=require "core.Coord"
local Spec=require "drive.VehicleSpec"
local M={};M.__index=M
function M.New(view,bp,vehicle,previous)
    local self=setmetatable({vehicle=vehicle,items={}},M)
    local retained={};for _,item in ipairs(previous and previous.items or {}) do retained[item.id]=item end
    for _,p in ipairs(bp:List()) do
        local vis=view.visuals[p.id]
        if vis and (vis.rig.gimbal or vis.rig.rings) then
            local old=retained[p.id]
            self.items[#self.items+1]=old and old.vis==vis and old or {id=p.id,vis=vis,rotation=Spec.GEOMETRY.rotations[p.rot+1],motor=0,angles={}}
        end
    end
    return self
end
function M:Reset()
    for _,item in ipairs(self.items) do item.motor=0;item.angles={} end
    self:Update(0)
end
function M:Update(dt)
    local vehicle=self.vehicle
    for _,item in ipairs(self.items) do
        local vis=item.vis;local r=vis.rig;local info=vis.data.segments.info
        if r.gimbal then
            local output=vehicle.thrusterOutputs[item.id] or 0
            local target=math.sqrt(Math.Clamp(output,0,1))
            item.motor=item.motor+(target-item.motor)*(1-math.exp(-dt*(target>item.motor and 6 or 3.5)))
            if item.motor<.0005 then item.motor=0 end
            local direction=vehicle.thrusterDirections[item.id]
            local exhaust=direction and Math.Unrotate(item.rotation,Math.Scale(direction,-1)) or info.exhaustDir
            r.gimbal.rotation=Quaternion(Coord.Vec(table.unpack(info.exhaustDir)),Coord.Vec(table.unpack(exhaust)))
            for i,node in ipairs(r.rotors) do
                local name=vis.data.segments.rotors[i].name
                local speed=name=='fan' and 7.2 or name=='ring' and 1.65 or ((i-1)%2==1 and -1 or 1)*(1.8+(i-1)*.22)
                local angle=(item.angles[i] or 0)+dt*speed*item.motor;item.angles[i]=angle
                node.rotation=Quaternion(-angle*180/math.pi,info.family=='pod' and Vector3.FORWARD or Vector3.UP)
            end
        else
            local state=vehicle.hoverStates[item.id]
            local output=state and state.force/math.max(1,state.maxForce) or 0
            for i,node in ipairs(r.rings) do
                local angle=(item.angles[i] or 0)+dt*output*(info.tier==4 and i==2 and -1 or 1)*8;item.angles[i]=angle
                node.rotation=Quaternion(-angle*180/math.pi,Vector3.UP)
            end
        end
    end
end
return M
