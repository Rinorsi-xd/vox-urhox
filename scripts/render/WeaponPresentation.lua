local Materials=require("parts.Materials")

local Motion=require 'render.WeaponMotion'
local Coord=require 'core.Coord'
local Config=require 'Config'
local profiles=require('core.ResourceData').Read('Parts/WeaponMotion.json')
local MaterialData=require('parts.Defs').DATA.materials
local M={}
M.slots={heatGlow=true,chargeGlow=true,glowBlue=true,glowRed=true}
local function Vec(p) return Coord.Vec(table.unpack(p)) end
function M.Create(vis,typeId)
    local profile=profiles[typeId];if not profile then return end
    -- Private visual RNG avoids changing gameplay randomness or other vehicles.
    local seed=math.max(1,math.floor(vis.variation*2147483646))
    local function Random() seed=(seed*48271)%2147483647;return seed/2147483647 end
    vis.weaponMotion=Motion.New(typeId,vis.data,profile,Random)
    vis.weaponMaterials={};vis.weaponBases={};vis.weaponProfile=profile
end
function M.Material(vis,slot)
    if vis.weaponMaterials[slot] then return vis.weaponMaterials[slot] end
    local source=MaterialData[slot]
    local material=Materials.New('Weapon.shader')
    local c=source and source.color or {.02,.02,.02};local e=source and source.emission
    local fallback=Config.HexLinear(slot=='heatGlow' and 0xff7a22 or 0xfff1dc)
    local emission=e and Color(e[1],e[2],e[3]) or fallback
    local intensity=source and source.intensity or slot=='heatGlow' and .3 or 2.2
    material:SetShaderParameter('base_color',Variant(Color(c[1],c[2],c[3])))
    material:SetShaderParameter('roughness_value',Variant(source and source.rough or .4))
    material:SetShaderParameter('metallic_value',Variant(source and source.metal or 0))
    material:SetShaderParameter('emission_color',Variant(emission));material:SetShaderParameter('emission_strength',Variant(intensity))
    local g=vis.data.weapon
    material:SetShaderParameter('flow_span',Variant(Vector4(vis.weaponProfile.z0,g.muzzle[3],g.pivot[1],g.pivot[3])))
    vis.weaponMaterials[slot]=material;vis.weaponBases[slot]={intensity=intensity,color=emission}
    return material
end
function M.Apply(vis)
    local motion=vis.weaponMotion
    for index,pose in pairs(motion.poses) do
        local node=vis.rig.parts[index].node;node.position=Vec(pose.p);node:SetScale(Vector3(table.unpack(pose.scale)))
        node.enabled=pose.visible~=false
        if type(pose.axis)=='table' then
            node.rotation=Quaternion(pose.angle*180/math.pi,Vector3(pose.axis[1],-pose.axis[2],-pose.axis[3]))
        else node.rotation=Quaternion(pose.angle*180/math.pi*(pose.axis=='x' and 1 or -1),pose.axis=='x' and Vector3.RIGHT or Vector3.FORWARD) end
    end
    if motion.spinPose and vis.rig.spin then
        local p=vis.data.weapon.spin;vis.rig.spin.position=Vec({p[1],p[2],p[3]+motion.spinPose.buzz})
        vis.rig.spin.rotation=Quaternion(-motion.spinPose.angle*180/math.pi,Vector3.FORWARD)
    end
    for slot,material in pairs(vis.weaponMaterials) do
        local base=vis.weaponBases[slot];local state=motion.material[slot] or {};local intensity=state.intensity or base.intensity*(state.factor or 1)
        local color=base.color
        if state.colorMix then
            local heat=slot=='heatGlow' and vis.weaponMotion.kind=='mg'
            local from=Config.HexLinear(heat and 0xff7a22 or 0x1a9dff)
            local to=Config.HexLinear(heat and 0xffc46a or 0xa8e6ff);color=from:Lerp(to,state.colorMix)
        end
        material:SetShaderParameter('emission_color',Variant(color));material:SetShaderParameter('emission_strength',Variant(intensity))
        local f=motion.flow
        material:SetShaderParameter('flow_state',Variant(Vector4(f.phase,f.freq,f.amp,f.power)))
        material:SetShaderParameter('flow_sweep',Variant(Vector2(f.sweep,f.sweepI)))
    end
end
function M.Update(vis,dt,time,w,system,deferApply)
    if w then vis.weaponMotion:SetState(w,time,system) end
    vis.weaponMotion:Update(time,dt);if not deferApply then M.Apply(vis) end
end
function M.Dispose(vis)
    for _,material in pairs(vis.weaponMaterials or {}) do material:Dispose() end
    vis.weaponMaterials=nil;vis.weaponMotion=nil
end
function M.Reset(vis)
    local old=vis.weaponMotion
    local fresh=Motion.New(old.type,vis.data,vis.weaponProfile,old.random)
    -- Preserve physical weapon state and shot baseline; only visual transients reset.
    for _,k in ipairs({'live','charge','windup','spinV','spinRate','spinAngle','offline','lastShot','power','open','lock','tubes','mphase','reload','readyAt'}) do fresh[k]=old[k] end
    fresh.eject.x=old.offline and 1 or 0
    vis.weaponMotion=fresh;fresh:Update(old.t or 0,0);M.Apply(vis)
    vis.head.position=Vector3.ZERO;vis.head.rotation=Quaternion.IDENTITY
    if vis.rig.pod then vis.rig.pod.position=Vector3.ZERO;vis.rig.pod.rotation=Quaternion.IDENTITY end
end
return M
