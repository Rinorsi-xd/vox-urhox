-- Paint channel capability comes from model metadata, never GPU model loading.
local Data=require 'core.ResourceData'
local M={};local shells={}
function M.HasShell(type)
    if type=='thruster' then type='thrusterUp2' end
    if shells[type]==nil then
        local data=Data.Read('Parts/Rigs/'..type..'.json');local found=false
        for _,layer in ipairs(data.whole.layers) do for _,slot in ipairs(layer.slots) do if slot=='armorWhite' then found=true end end end
        shells[type]=found
    end
    return shells[type]
end
function M.Field(part,channel)
    local two=M.HasShell(part.type)
    if channel=='accent' then return two and 'color' or nil end
    return two and 'shellColor' or 'color'
end
return M
