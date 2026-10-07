-- Values are converted from current H5 shared/parts/defs.js.
local data=require("core.ResourceData").Read("Parts/Catalog.json")
local Defs={LIST=data.parts,CATEGORIES=data.categories,RETIRED_TYPES=data.retired,PARTS={},DATA=data}
for _,d in ipairs(Defs.LIST) do Defs.PARTS[d.id]=d end
Defs.PARTS.thruster=Defs.PARTS.thrusterUp2
function Defs.PartsIn(category)
    local result={}
    for _,d in ipairs(Defs.LIST) do if d.cat==category then result[#result+1]=d end end
    return result
end
return Defs
