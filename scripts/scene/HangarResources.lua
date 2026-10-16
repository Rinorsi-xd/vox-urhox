local ResourceData=require("core.ResourceData")
local Dependencies=require("parts.Dependencies")

local M={}
---@type string[]|nil
local paths
function M.For(parts)
    paths=paths or ResourceData.Read('Hangar/Resources.json')
    local result={table.unpack(paths)}
    if parts then
        for _,path in ipairs(Dependencies.For(parts)) do result[#result+1]=path end
    end
    return result
end
return M
