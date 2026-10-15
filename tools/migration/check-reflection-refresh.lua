-- Source clipping cannot be evaluated with a stale image: remove a visible
-- marker first. Read the real reflection, without adding a second probe scene.
local app,h,marker,material,originalViewMask,originalUpdateMode
local results={}
local function Capture(name)
    local image=h.reflTex:GetImage();assert(image,'reflection readback unavailable')
    local pink=0
    for y=0,image.height-1 do for x=0,image.width-1 do
        local p=image:GetPixel(x,y)
        if p.r>.25 and p.b>.25 and p.g<math.min(p.r,p.b)*.5 then pink=pink+1 end
    end end
    results[name]={pink=pink,width=image.width,height=image.height,time=h.time}
    image:SavePNG('docs/migration/evidence/reflection-refresh-'..name..'.png');image:Dispose()
    return pink
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;h=app.hangar;app.camera:Step(.65);app.camera.autoSpin=false
    originalViewMask=app.camera.camera.viewMask;app.camera.camera.viewMask=originalViewMask & ~64
    originalUpdateMode=h.reflTex.renderSurface.updateMode
    marker=app.scene:CreateChild('ReflectionRefreshMarker');marker.position=Vector3(2,2,0);marker.scale=Vector3(2,2,2)
    local model=marker:CreateComponent('StaticModel');model:SetModel(cache:GetResource('Model','Models/Box.mdl'));model.viewMask=64
    material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/VoxPBR.shader'))
    material:SetShaderParameter('base_color',Variant(Color(1,0,1)));material:SetShaderParameter('emission_color',Variant(Color(1,0,1)));material:SetShaderParameter('emission_strength',Variant(4.0));model.material=material
end)
V.atFrame(80,function()
    V.assert(Capture('visible')>100,'positive control: reflected magenta marker is visible')
    marker.enabled=false;h.reflTex.renderSurface:QueueUpdate()
end)
V.atFrame(110,function()
    Capture('removed-manual');h.reflTex.renderSurface.updateMode=SURFACE_UPDATEALWAYS
end)
V.atFrame(140,function()
    Capture('removed-always')
    local f=assert(io.open('docs/migration/evidence/reflection-refresh-measurements.json','w'));f:write(cjson.encode(results));f:close()
    V.assert(results['removed-manual'].pink<10,'manual reflection refresh removes hidden geometry')
    V.assert(results['removed-always'].pink<10,'always-updated reflection removes hidden geometry')
    marker.position=Vector3(2,-2,0);marker.enabled=true
end)
V.atFrame(165,function()
    Capture('below-clipped');h.reflCam.useClipping=false
    material:SetShaderParameter('planar_clip_plane',Variant(Vector4(0,0,0,0)))
end)
V.atFrame(190,function()
    Capture('below-unclipped')
    local f=assert(io.open('docs/migration/evidence/reflection-refresh-measurements.json','w'));f:write(cjson.encode(results));f:close()
    V.assert(results['below-clipped'].pink<10,'floor clip excludes submerged geometry')
    V.assert(results['below-unclipped'].pink>100,'disabled clip exposes submerged positive control')
    marker:Remove();material:Dispose();app.camera.camera.viewMask=originalViewMask;h.reflTex.renderSurface.updateMode=originalUpdateMode;h.reflCam.useClipping=true
    V.finish()
end)
