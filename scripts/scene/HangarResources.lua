local M={}
---@type string[]|nil
local paths
function M.For(parts)
    paths=paths or require('core.ResourceData').Read('Hangar/Resources.json')
    local result={table.unpack(paths)}
    if parts then
        for _,path in ipairs(require('parts.Dependencies').For(parts)) do result[#result+1]=path end
    end
    return result
end
return M
