-- Generated balance data comes from H5 weaponStats(), never a second hand-maintained table.
local data=require("core.ResourceData").Read("Combat/Weapons.json")
local M={ENERGY=data.energy,KINDS=data.kinds,FULL=data.full,STATS=data.stats}
function M.Kind(typeId)
    for _,kind in ipairs({"mg","laser","sniper","missile"}) do
        if typeId:sub(1,#kind)==kind then return kind end
    end
    return typeId
end
function M.Stats(typeId) return M.STATS[typeId] end
function M.Dps(s) return s.rate and s.damage*s.rate or s.damage/s.interval end
function M.DamageAtDistance(stats,distance)
    local f=stats.falloff
    local damage=stats.damage
    if f and distance>f[1] then damage=damage*(distance>=f[2] and f[3] or 1-(1-f[3])*(distance-f[1])/(f[2]-f[1])) end
    local ramp=stats.rampUp
    if ramp and distance<ramp[2] then damage=damage*(distance<=ramp[1] and ramp[3] or ramp[3]+(1-ramp[3])*(distance-ramp[1])/(ramp[2]-ramp[1])) end
    return damage
end
return M
