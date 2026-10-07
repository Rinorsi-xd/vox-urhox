-- Generated balance data comes from H5 weaponStats(), never a second hand-maintained table.
local data=require("core.ResourceData").Read("Combat/Weapons.json")
local M={ENERGY=data.energy,KINDS=data.kinds,FULL=data.full,STATS=data.stats}
function M.Kind(typeId)
    for _,kind in ipairs({"mg","laser","sniper"}) do
        if typeId:sub(1,#kind)==kind then return kind end
    end
    return typeId
end
function M.Stats(typeId) return M.STATS[typeId] end
function M.Dps(s) return s.rate and s.damage*s.rate or s.damage/s.interval end
function M.DamageAtDistance(stats,distance)
    local f=stats.falloff
    if not f or distance<=f[1] then return stats.damage end
    if distance>=f[2] then return stats.damage*f[3] end
    return stats.damage*(1-(1-f[3])*(distance-f[1])/(f[2]-f[1]))
end
return M
