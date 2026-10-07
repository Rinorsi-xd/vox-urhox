local presets=require("parts.Defs").DATA.presets
local M={}
local function Build(bp,key)
    local data=assert(presets[key])
    bp:Clear();bp.name=data.name
    for _,part in ipairs(data.parts) do bp:Add(part) end
    return bp
end
function M.BuildRaceCar(bp) return Build(bp,"buildRaceCar") end
function M.BuildTank(bp) return Build(bp,"buildTank") end
function M.BuildEmpty(bp) return Build(bp,"buildEmpty") end
return M
