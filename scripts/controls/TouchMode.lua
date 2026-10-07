-- Device policy is shared by the home, builder and driving UI.
local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
function M.Enabled()
    if M.override~=nil then return M.override end
    for _,arg in ipairs(GetArguments()) do if arg=='-touch' then return true end end
    -- DPR describes pixel density, not input hardware: Retina PCs stay on PC UI.
    return Platform.IsMobilePlatform() or input.touchEmulation
end
function M.Scale(surface)
    local UI=require 'urhox-libs/UI'
    if not M.Enabled() then return UI.Scale.DPR end
    -- Existing dense builder keeps its source composition. Driving uses a
    -- larger touch layout; UI scales drawing and pointer hit tests together.
    return UI.Scale.DESIGN_RESOLUTION(surface=='drive' and 960 or 1100,surface=='home' and 760 or surface=='build' and 640 or 540)
end
function M.Apply(surface) require('urhox-libs/UI').SetScale(M.Scale(surface)) end
return M
