-- Reticle chips use the equipped weapon type; both drill rigs share one icon.
local Parts=require('parts.Defs').PARTS
local M={}
function M.For(parts)
    local paths,seen={},{}
    for _,part in ipairs(parts or {}) do
        local kind=part.type or part[1]
        local def=Parts[kind]
        if def and def.weapon then
            local icon=kind=='fuyuanDrill' and 'tianyuanDrill' or kind
            if not seen[icon] then
                seen[icon]=true
                paths[#paths+1]='UI/WeaponIcons/'..icon..'.png'
                paths[#paths+1]='UI/WeaponIcons/Hurt/'..icon..'.png'
            end
        end
    end
    return paths
end
return M
