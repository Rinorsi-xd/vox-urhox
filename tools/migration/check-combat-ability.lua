local Unit=require 'combat.CarUnit'
V.atFrame(44,function()
    local file=assert(io.open('tools/migration/source-combat-ability.json'))
    local source=cjson.decode(file:read('*a'));file:close()
    for _,row in ipairs(source.cases) do
        local parts=row.type=='empty' and {} or {{type=row.type}}
        local unit=setmetatable({bp={List=function()return parts end},original={{type=row.originallyArmed and 'laser1' or 'cube'}}},Unit)
        V.assert(unit:LostCombatAbility()==row.expected,'source remaining category '..row.type..' originally armed='..tostring(row.originallyArmed))
    end
    V.finish()
end)
