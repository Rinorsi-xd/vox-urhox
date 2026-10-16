-- Hoisted presentation/native imports are outside these method-level checks.
-- Fail if a checked method starts consuming an excluded dependency.
local M={}
function M.Exclude(names)
    for _,name in ipairs(names) do
        package.loaded[name]=setmetatable({},{__index=function(_,key)
            error('Unexpected off-scope dependency: '..name..'.'..tostring(key),2)
        end})
    end
end
function M.Salvage()
    M.Exclude({'parts.Dependencies','render.SalvageFx','render.SalvageExplosion',
        'salvage.Director','render.SalvageView','audio.SalvageAudio','salvage.Cinematics',
        'combat.DriverActions','drive.RotorMotion','combat.PlayerViewSync'})
end
return M
