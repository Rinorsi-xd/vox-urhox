-- Device policy is shared by the home, builder and driving UI.
local ImportedUI=require("urhox-libs/UI")

local Platform=require 'urhox-libs.Platform.PlatformUtils'
local M={}
function M.Compact()
    if M.compactOverride~=nil then return M.compactOverride end
    if M.compact~=nil then return M.compact end
    local forced,touch=nil,false
    for _,arg in ipairs(GetArguments()) do
        if arg=='-compact=0' then forced=false elseif arg=='-compact=1' then forced=true end
        if arg=='-touch' then touch=true end
    end
    local native=GetNativePlatform and GetNativePlatform() or GetPlatform()
    touch=touch or native=='Android' or native=='iOS' or native=='HarmonyOS' or input.touchEmulation
    -- Web（手机浏览器、云真机）上 native 不一定报移动系统；沿用 Enabled() 的视口判断，
    -- 明确是桌面系统的浏览器不算。源 homeScale.js 的条件同为「触屏 + 屏幕短边 ≤ 600」。
    if not touch and GetPlatform()=='Web' and native~='Windows' and native~='Mac' then touch=M.Enabled() end
    local dpr=math.max(1,graphics:GetDPR())
    -- Lua exposes native platform, not browser screen/pointer media queries.
    -- Freeze the initial CSS viewport/device decision as homeScale.js does.
    M.compact=forced
    if forced==nil then M.compact=touch and math.min(graphics:GetWidth(),graphics:GetHeight())/dpr<=600 end
    return M.compact
end
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
    local UI=ImportedUI
    if surface=='home' or surface=='build' or surface=='home-page' then
        -- 手机紧凑界面：机库按 600 高排（源 homeScale.js）；模式选择/剧情/工坊/涂装/打捞这些按 PC 设计的页面
        -- 用接近 PC 的 972 高画布排版再整体缩小，和 H5 手机版一样，不会挤爆
        local height=M.Compact() and (surface=='home-page' and 972 or 600) or 1080
        return UI.Scale.DESIGN_RESOLUTION(height*16/9,height)
    end
    if not M.Enabled() then return UI.Scale.DPR end
    return UI.Scale.DESIGN_RESOLUTION(960,540)
end
function M.Apply(surface)
    M.surface=surface;M.width=graphics:GetWidth();M.height=graphics:GetHeight();M.enabled=M.Enabled()
    ImportedUI.SetScale(M.Scale(surface))
end
function M.Update(surface)
    if M.surface~=surface or M.width~=graphics:GetWidth() or M.height~=graphics:GetHeight() or M.enabled~=M.Enabled() then M.Apply(surface) end
end
return M
