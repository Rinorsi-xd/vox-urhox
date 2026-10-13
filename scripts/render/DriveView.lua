-- Presentation consumes vehicle state. It never changes the native rigid body.
local Config=require "Config"
local Rot=require "core.Rotations"
local Spec=require "drive.VehicleSpec"
local Math=require "core.Math3"
local Coord=require 'core.Coord'
local Rig=require "render.PartRig"
local View=require "render.VehicleView"
local Actuators=require "render.ActuatorView"
local Legs=require "render.LegView"
local Equipment=require "render.EquipmentEffects"
local M={};M.__index=M
function M.New(scene,bp,vehicle)
    local self=setmetatable({},M)
    self.equipment=Equipment.New(scene)
    self.view=View.New(scene,"DrivenCar");self.view:Rebuild(bp);self:Bind(bp,vehicle)
    return self
end
function M:Bind(bp,vehicle)
    self.vehicle=vehicle;self.parts={};self.wheels={};self.tracks={}
    -- Damage retains surviving visual nodes. Rebind from authored coordinates,
    -- never from their last animated position, before applying saved rotor poses.
    for _,p in ipairs(bp:List()) do
        self.parts[p.id]=p;local vis=self.view.visuals[p.id]
        if vis then vis.node.position=View.PartLocalPos(p);vis.node.rotation=Coord.RotQuat(p.rot) end
    end
    local tracks={}
    for i,w in ipairs(vehicle.wheels) do
        local p=self.parts[w.partId];local vis=self.view.visuals[w.partId]
        if vis and vis.rig.steer then
            self.wheels[#self.wheels+1]={i=i,vis=vis,up=Math.Unrotate(Spec.GEOMETRY.rotations[p.rot+1],{0,1,0})}
        elseif vis and w.track and not w["end"] and not tracks[w.partId] then
            tracks[w.partId]=true;local forward=Rot.ApplyRot(p.rot,{1,0,0})[3]
            self.tracks[#self.tracks+1]={i=i,vis=vis,sign=forward<0 and -1 or 1}
            vis.node.position=View.PartLocalPos(p)-Vector3(0,w.drop/Config.CELL,0)
        end
    end
    self.actuators=Actuators.New(self.view,bp,vehicle,self.actuators)
    self.rotors=require('render.RotorView').New(self.view,vehicle)
    self.legs=Legs.New(self.view,vehicle)
    self.equipment:Bind(self.view,vehicle)
    self:ResetPose(false)
    self:Update(1,0)
end
function M:ResetPose(resetActuators)
    self.current={p=self.vehicle.native.position,q=self.vehicle.native.rotation};self.previous=self.current
    if self.actuators and resetActuators~=false then self.actuators:Reset() end
    if self.equipment and resetActuators~=false then self.equipment:Reset() end
    if resetActuators~=false then self.view:ResetWeaponPresentation() end
end
function M:SavePose()
    self.previous=self.current;self.current={p=self.vehicle.native.position,q=self.vehicle.native.rotation}
end
function M:Update(alpha,dt,context)
    local root=self.view.root
    root.position=self.previous.p:Lerp(self.current.p,alpha);root.rotation=self.previous.q:Slerp(self.current.q,alpha)
    self.rotors:Update(alpha)
    for _,w in ipairs(self.wheels) do
        local pose=self.vehicle:WheelPose(w.i);Rig.SetWheel(w.vis,w.up,pose.lift/Config.CELL,pose.steer,pose.spin)
    end
    for _,t in ipairs(self.tracks) do Rig.SetTrack(t.vis,-self.vehicle:WheelTravel(t.i)/Config.CELL*t.sign) end
    self.actuators:Update(dt or 0)
    self.legs:Update(alpha,dt or 0)
    self.equipment:Update(dt or 0,context)
end
function M:Dispose() self.equipment:Dispose();self.view:Dispose() end
return M
