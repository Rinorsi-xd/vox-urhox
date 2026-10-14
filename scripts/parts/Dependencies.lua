local Assets=require 'parts.PartAssets'
local M={}
---@type table<string, string[]>|nil
local paths
function M.For(parts)
    paths=paths or require('core.ResourceData').Read('Parts/Dependencies.json')
    local result,seen={},{}
    for _,part in ipairs(parts) do
        if require('parts.Defs').PARTS[part.type].drill and not seen.drillSpeed then
            seen.drillSpeed=true;result[#result+1]='Shaders/BLGL/Combat/DrillSpeed.shader'
        end
        local key=Assets.Key(part.type,part.rot)
        -- Turntable mode keys replace the authored rig synchronously and undo
        -- can restore it immediately. Warm only this part's three alternatives.
        local keys={key}
        if require('parts.Defs').PARTS[part.type].rotor then keys={'rotor','rotorSpin','rotorStep'} end
        for _,variant in ipairs(keys) do for _,path in ipairs(assert(paths[variant],'Missing dependency index: '..variant)) do
            if not seen[path] then seen[path]=true;result[#result+1]=path end
        end end
    end
    return result
end
function M.FromBlueprint(data)
    local result={}
    for _,part in ipairs(data.parts or {}) do result[#result+1]={type=part[1],rot=part[5]} end
    return M.For(result)
end
function M.Ready(parts)
    for _,path in ipairs(M.For(parts)) do if not cache:Exists(path) then return false end end
    return true
end
return M
