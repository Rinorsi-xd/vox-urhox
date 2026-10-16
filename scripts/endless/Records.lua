local BlueprintCode=require("storage.BlueprintCode")
local Inventory=require("endless.Inventory")

local M={}
local Numbers=require('storage.RecordNumbers')
local Number=Numbers.NonNegative
local Integer=Numbers.Count
function M.Best(data)
    if type(data)~='table' or not Integer(data.wave) or data.wave<1 or not Number(data.score) or not Number(data.damage) or not Number(data.time) then return false end
    if type(data.seed)=='number' then if not Number(data.seed) then return false end elseif type(data.seed)~='string' or #data.seed>256 then return false end
    if type(data.kills)~='table' then return false end
    for _,role in ipairs({'assault','heavy','sniper','hover','boss'}) do if not Integer(data.kills[role]) then return false end end
    return pcall(BlueprintCode.Validate,data.blueprint)
end
function M.Run(data)
    if not M.Best(data) or data.version~=1 or not Integer(data.tier) or data.tier<1 or data.tier>5 or not Integer(data.lives) or data.lives<1 or data.lives>3 then return false end
    if not Integer(data.credits) or not Integer(data.repairs) or not Integer(data.weaponDrought) or type(data.inventory)~='table' or type(data.supplies)~='table' or #data.supplies>3 then return false end
    local Inv=Inventory;for id,n in pairs(data.inventory) do if not Inv.Limited(id) or not Integer(n) then return false end end
    for _,choice in ipairs(data.supplies) do
        if type(choice)~='table' or type(choice.name)~='string' or not Integer(choice.tier) or choice.tier<1 or choice.tier>5 then return false end
        if choice.kind=='part' then if not Inv.Limited(choice.type) or choice.id~=choice.type then return false end
        elseif choice.kind~='repair' or choice.id~='repair' then return false end
    end
    return true
end
return M
