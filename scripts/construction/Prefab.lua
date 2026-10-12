local presets=require("parts.Defs").DATA.presets
local M={}
M.keys={raceCar='buildRaceCar',empty='buildEmpty',megaMech='buildMegaMech',scorpion='buildScorpion',
    hawk='buildHawk',feather='buildFeather',vanguard='buildVanguard',tianyuan='buildDrillTank',fuyuan='buildFuyuanTank',gruntTianyuan='buildGruntOne',gruntFuyuan='buildFuyuanGrunt',
    fox='buildFox',trooper='buildTrooper',miniAssault='buildMiniAssault',miniScout='buildMiniScout',miniHeavy='buildMiniHeavy'}
local function Build(bp,key)
    local data=assert(presets[key])
    bp:Clear();bp.name=data.name
    for _,part in ipairs(data.parts) do bp:Add(part) end
    return bp
end
function M.BuildRaceCar(bp) return Build(bp,"buildRaceCar") end
function M.BuildEmpty(bp) return Build(bp,"buildEmpty") end
function M.Create(bp,id) return Build(bp,assert(M.keys[id],'Unknown prefab: '..tostring(id))) end
return M
