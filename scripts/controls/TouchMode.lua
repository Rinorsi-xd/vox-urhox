-- Device policy is shared by the home, builder and driving UI.
local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
function M.Enabled()
    if M.override~=nil then return M.override end
    for _,arg in ipairs(GetArguments()) do if arg=='-touch' then return true end end
    if Platform.IsMobilePlatform() or input.touchEmulation then return true end
    if GetPlatform()=='Web' then
        if input:GetNumTouches()>0 then M.webTouch=true end
        if M.webTouch then return true end
        local dpr=math.max(1,graphics:GetDPR())
        local w,h=graphics:GetWidth()/dpr,graphics:GetHeight()/dpr
        -- Compact Web windows need larger targets before the first touch arrives.
        return math.min(w,h)<=600 or math.max(w,h)<=1100
    end
    return false
end
function M.Scale(surface)
    local UI=require 'urhox-libs/UI'
    -- Frozen H5 uiScale.js uses the same 1920x1080 canvas for outgame and
    -- editor surfaces. A 20:9 screen expands its logical width to 2400.
    if surface=='home' or surface=='build' then return UI.Scale.DESIGN_RESOLUTION(1920,1080) end
    if not M.Enabled() then return UI.Scale.DPR end
    return UI.Scale.DESIGN_RESOLUTION(960,540)
end
function M.Apply(surface)
    M.surface=surface;M.width=graphics:GetWidth();M.height=graphics:GetHeight();M.enabled=M.Enabled()
    require('urhox-libs/UI').SetScale(M.Scale(surface))
end
function M.Update(surface)
    if M.surface~=surface or M.width~=graphics:GetWidth() or M.height~=graphics:GetHeight() or M.enabled~=M.Enabled() then M.Apply(surface) end
end
return M
