local TouchMode=require("controls.TouchMode")

local Platform=require "urhox-libs.Platform.PlatformUtils"
local M={}
M.profiles={
    mobile={name="mobile",reflectionScale=0.25,reflectionMax=384,reflectionHz=10,shadowMapSize=1024,maxFps=30,maxSimSteps=3,
        thrusterSteps=12,hoverSteps=8,equipmentFar=70,equipmentLod=25,exhaustParticles=96,
        -- No crater-source MSAA: on phone WebGL the FP16 multisampled target's
        -- resolve texture is never written, so the post chain samples stale VRAM.
        weaponFxRigs=12,weaponMotes=192,weaponSwirlSegments=20,weaponArcSegments=640,weaponArcsPerRig=8,
        postMsaa=1,fxaa=true},
    desktop={name="desktop",reflectionScale=0.5,reflectionMax=960,reflectionHz=30,shadowMapSize=2048,maxFps=60,maxSimSteps=6,
        thrusterSteps=32,hoverSteps=12,equipmentFar=140,equipmentLod=55,exhaustParticles=384,
        weaponFxRigs=24,weaponMotes=768,weaponSwirlSegments=40,weaponArcSegments=2048,weaponArcsPerRig=16,
        postMsaa=2,fxaa=true}, -- 4x on the FP16 source cost ~+10 ms on M1; 2x ~+3 ms.
}
function M.Select()
    local name=Platform.IsDesktopPlatform() and "desktop" or "mobile"
    for _,arg in ipairs(GetArguments()) do local requested=arg:match("^%-quality=(.+)$");if M.profiles[requested] then name=requested end end
    return M.profiles[name]
end
M.current={};for k,v in pairs(M.Select()) do M.current[k]=v end
function M.FrameLimit()
    -- Web uses conservative rendering budgets on both device classes.
    -- A desktop browser still needs the desktop input/render cadence.
    for _,arg in ipairs(GetArguments()) do if arg:match('^%-quality=') then return M.current.maxFps end end
    if Platform.IsWebPlatform() and not TouchMode.Enabled() then return M.profiles.desktop.maxFps end
    return M.current.maxFps
end
function M.Apply(level)
    local base=M.Select();for k,v in pairs(base) do M.current[k]=v end
    if level=='low' then
        M.current.reflectionScale=.2;M.current.reflectionMax=256;M.current.reflectionHz=6;M.current.shadowMapSize=512
        M.current.weaponFxRigs=6;M.current.weaponMotes=96;M.current.weaponArcsPerRig=4
    elseif level=='medium' then
        M.current.reflectionScale=.25;M.current.reflectionMax=384;M.current.reflectionHz=10;M.current.shadowMapSize=1024
        M.current.weaponFxRigs=12;M.current.weaponMotes=192;M.current.weaponArcsPerRig=8
    end
    renderer.shadowMapSize=M.current.shadowMapSize
end
return M
