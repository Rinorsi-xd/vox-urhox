local Platform=require "urhox-libs.Platform.PlatformUtils"
local M={}
M.profiles={
    mobile={name="mobile",reflectionScale=0.25,reflectionMax=384,reflectionHz=10,shadowMapSize=1024,maxFps=30,
        thrusterSteps=12,hoverSteps=8,equipmentFar=70,equipmentLod=25,exhaustParticles=96,
        weaponFxRigs=12,weaponMotes=192,weaponSwirlSegments=20,weaponArcSegments=640,weaponArcsPerRig=8},
    desktop={name="desktop",reflectionScale=0.5,reflectionMax=960,reflectionHz=30,shadowMapSize=2048,maxFps=60,
        thrusterSteps=32,hoverSteps=12,equipmentFar=140,equipmentLod=55,exhaustParticles=384,
        weaponFxRigs=24,weaponMotes=768,weaponSwirlSegments=40,weaponArcSegments=2048,weaponArcsPerRig=16},
}
function M.Select()
    local name=Platform.IsDesktopPlatform() and "desktop" or "mobile"
    for _,arg in ipairs(GetArguments()) do local requested=arg:match("^%-quality=(.+)$");if M.profiles[requested] then name=requested end end
    return M.profiles[name]
end
M.current={};for k,v in pairs(M.Select()) do M.current[k]=v end
return M
