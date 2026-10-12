-- Emulate host ownership using the actual engine scene, camera and viewport.
-- This checks our contract, not editor-native input behavior.
local App=require "app.HangarApp"
---@type Scene|nil
local hostScene=nil
---@type HangarApp|nil
local embedded=nil
---@type Viewport|nil
local hostViewport=nil
---@type Node|nil
local hostCamera=nil
local previous={}
V.atFrame(65,function()
    VOX_HANGAR.app:Stop()
    hostScene=Scene()
    V.assert(hostScene:LoadXML(cache:GetFile("Scenes/OrbitalHangar.xml")),"host scene loads")
    hostCamera=hostScene:GetChild("Camera")
    hostViewport=Viewport:new(hostScene,hostCamera:GetComponent("Camera"))
    renderer:SetViewport(0,hostViewport)
    cache.autoReloadResources=true
    previous={hdr=renderer.hdrRendering,shadow=renderer.shadowMapSize,mode=input.mouseMode}
    embedded=App.New();embedded:Start(hostScene)
    V.assert(not embedded.ownsScene,"embedded app borrows host scene")
    V.assert(embedded.camera.node==hostCamera,"host camera node remains alive")
    V.assert(renderer:GetViewport(0)==hostViewport,"host viewport is preserved on start")
    V.assert(cache.autoReloadResources,"host resource watching remains enabled")
    embedded:ToggleGallery(13)
end)
for frame=66,95 do V.atFrame(frame,function() embedded:Update(1/60) end) end
V.atFrame(100,function()
    embedded:Stop();embedded:Stop();embedded:Update(1/60)
    V.assert(hostScene:GetChild("OrbitalHangar")~=nil,"stop preserves borrowed scene")
    V.assert(hostScene:GetChild("Camera")==hostCamera,"stop preserves host camera")
    V.assert(renderer:GetViewport(0)==hostViewport,"stop preserves host viewport")
    V.assert(hostScene:GetChild("Car")==nil and hostScene:GetChild("Gallery")==nil,"stop removes owned instances")
    V.assert(hostScene:GetChild("ReflectionCamera")==nil,"stop removes owned reflection")
    V.assert(cache.autoReloadResources and renderer.hdrRendering==previous.hdr and renderer.shadowMapSize==previous.shadow and input.mouseMode==previous.mode,"stop restores host settings")
    renderer:SetViewport(0,nil)
    hostScene:Dispose();hostScene=nil;hostViewport=nil;hostCamera=nil;embedded=nil
    collectgarbage("collect")
end)
