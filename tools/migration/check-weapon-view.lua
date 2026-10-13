local Weapons=require "combat.WeaponSystem"
local Loadout=require "combat.WeaponLoadout"
local WeaponView=require "render.WeaponView"
local VehicleView=require "render.VehicleView"
local Coord=require "core.Coord"
local Rot=require "core.Rotations"
local Defs=require "combat.WeaponDefs"
local Math=require 'core.Math3'
local function Vec(v) return Coord.Vec(v[1],v[2],v[3]) end
V.atFrame(55,function()
    local f=assert(io.open('tools/migration/source-weapon-motion.json'));local fixtures=cjson.decode(f:read('*a'));f:close()
    local source={};for _,case in ipairs(fixtures.cases) do source[case.type]=case.steps[200] end
    local view=VehicleView.New(VOX_HANGAR.scene,"WeaponViewVerification")
    local pos={2,3,-4};local quat={x=0,y=math.sin(.2),z=0,w=math.cos(.2)}
    view.root.position=Vec(pos);view.root.rotation=Quaternion(quat.w,quat.x,-quat.y,-quat.z)
    for typeId in pairs(Defs.STATS) do
        for _,rotation in ipairs({Rot.IDENTITY,0,23}) do
            local part={id=1,type=typeId,pos={2,1,-3},rot=rotation,color=0xffcc22}
            local vis=view:AddPart(part)
            local system=Weapons.New({weapons={Loadout.Part(part)}})
            local state={pos=pos,quat=quat,aim={14,7,80},firing=true}
            local env={stats={shots=0},castRay=function() return nil end,hit=function() error("Unexpected hit") end}
            for _=1,120 do system:Step(1/60,state,env) end
            WeaponView.Update(view,system,1)
            local w=system.groups[1].weapons[1]
            local sample=source[typeId]
            if vis.rig.pod then
                w.yaw=sample.yaw;w.prevYaw=w.yaw;w.pitch=sample.pitch+sample.kick;w.prevPitch=w.pitch
                WeaponView.Update(view,system,1)
            end
            for barrel,muzzle in ipairs(vis.data.weapon.muzzles or {vis.data.weapon.muzzle}) do
                local expected=Vec(system:Muzzle(w,state,barrel).pos)
                if vis.rig.pod then
                    local localPoint=Math.Add({part.pos[1],part.pos[2]+.5,part.pos[3]},Rot.ApplyRot(part.rot,sample.aimMuzzles[barrel]))
                    expected=Vec(Math.Add(pos,Math.Rotate(quat,Math.Scale(localPoint,require('Config').CELL))))
                end
                local actual=(vis.rig.pod or vis.rig.head):LocalToWorld(Vec(muzzle))
                V.assert((actual-expected):Length()<0.00002,typeId.." rotation "..rotation.." barrel "..barrel..(vis.rig.pod and ' frozen H5 visual tilt hierarchy' or ' simulation/render muzzle alignment'))
            end
            if vis.rig.spin then V.assert(w.spinAngle>0,typeId.." actual firing spins barrels") end
            view:Clear()
        end
    end
    view:Dispose()
    V.assert(VOX_HANGAR.scene:GetChild("WeaponViewVerification")==nil,"weapon verification view released")
    V.finish()
end)
