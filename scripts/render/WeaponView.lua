-- Consumes actual fixed-step weapon state. Visual interpolation never changes aim/damage.
local Rig=require "render.PartRig"
local Presentation=require 'render.WeaponPresentation'
local Coord=require 'core.Coord'
local M={}
function M.Update(vehicleView,system,alpha,dt,time,effects)
    alpha=math.max(0,math.min(1,alpha or 1))
    for _,group in ipairs(system.groups) do for _,weapon in ipairs(group.weapons) do
        local vis=vehicleView.visuals[weapon.id]
        if vis and vis.rig.head then
            local motion=vis.weaponMotion
            if motion and dt then Presentation.Update(vis,dt,time,weapon,system,true) end
            Rig.SetWeapon(vis,weapon.prevYaw+(weapon.yaw-weapon.prevYaw)*alpha,
                weapon.prevPitch+(weapon.pitch-weapon.prevPitch)*alpha,weapon.spinAngle,dt and motion and motion.recoil,dt and motion and motion.kick)
            if motion and dt then
                Presentation.Apply(vis) -- articulated spin includes its authored pivot and kick
                if effects then for _,e in ipairs(motion.emits) do
                    local p=vis.rig.head:LocalToWorld(Coord.Vec(table.unpack(e.p)));effects:EquipmentEmit(e.kind,{-p.x,p.y,p.z})
                end end
            end
        end
    end end
end
return M
