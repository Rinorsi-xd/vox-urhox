local Assets=require 'parts.PartAssets'
local M={}
---@type table<string, string[]>|nil
local paths
function M.For(parts)
    paths=paths or require('core.ResourceData').Read('Parts/Dependencies.json')
    local result,seen={},{}
    for _,part in ipairs(parts) do
        local key=Assets.Key(part.type,part.rot)
        for _,path in ipairs(assert(paths[key],'Missing dependency index: '..key)) do
            if not seen[path] then seen[path]=true;result[#result+1]=path end
        end
    end
    return result
end
return M
