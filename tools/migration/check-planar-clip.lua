-- GPU coverage: keep visible portions of intersecting meshes/volumes, discard
-- submerged reflection pixels, and preserve the very same main-view geometry.
local app,h,marker,model,material
local results={}
local cases={
    {name='opaque',shader='VoxPBR'},
    {name='coat',shader='VoxPBRCoat'},
    {name='paint',shader='VoxPaint'},
    {name='emission',shader='VoxGlowPaint'},
    {name='hologram',shader='VoxHoloPaint'},
    {name='animated',shader='VoxDecorDouble'},
    {name='weapon',shader='Weapon'},
    {name='hangar',shader='Hangar/Surface'},
    {name='transparent',shader='Hangar/Glass'},
    {name='thruster',shader='Equipment/Thruster',volume=true},
    {name='hover',shader='Equipment/Hover',volume=true},
    {name='tilted-thruster',shader='Equipment/Thruster',volume=true,tilted=true},
}
local function Count(image,volume)
    local n=0
    for y=0,image.height-1 do for x=0,image.width-1 do
        local p=image:GetPixel(x,y)
        if volume then
            if p.b>.03 and p.b>p.r*1.5 then n=n+1 end
        elseif p.r>.03 and p.b>.03 and p.g<math.min(p.r,p.b)*.5 then n=n+1 end
    end end
    return n
end
local function Capture(spec,phase,screen)
    local image
    if screen then image=Image:new();assert(graphics:TakeScreenShot(image)) else image=assert(h.reflTex:GetImage()) end
    local n=Count(image,spec.volume)
    if spec.name=='opaque' or spec.name=='transparent' or spec.volume then
        assert(image:SavePNG('docs/migration/evidence/planar-clip-'..spec.name..'-'..phase..'.png'))
    end
    image:Dispose()
    results[spec.name][phase]=n
    print('[PlanarClip] '..spec.name..' '..phase..' pixels='..n)
    return n
end
local function Plane(on)
    material:SetShaderParameter('planar_clip_plane',Variant(on and Vector4(0,1,0,0) or Vector4(0,0,0,0)))
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;h=app.hangar;app.camera:Step(.65);app.camera.autoSpin=false
    _G.VOX_DEBUG={time=10}
    renderer:GetViewport(0):SetRect(IntRect(0,0,1280,720))
    local UI=require 'urhox-libs/UI';UI.SetRoot(UI.Panel{width='100%',height='100%',pointerEvents='none'})
    -- Isolate the same object in both views; no opaque floor can hide a bug in
    -- the main-view check, and no other coloured scene object can pass a control.
    for _,kind in ipairs({'StaticModel','CustomGeometry'}) do
        for _,drawable in ipairs(app.scene:GetComponents(kind,true)) do drawable.viewMask=drawable.viewMask & ~64 end
    end
    app.camera.camera.viewMask=64;h.reflCam.viewMask=64
    marker=app.scene:CreateChild('PlanarClipMarker');marker.position=Vector3(2,3,0);marker.scale=Vector3(2,2,2)
    model=marker:CreateComponent('StaticModel');model:SetModel(cache:GetResource('Model','Models/Box.mdl'));model.viewMask=64
    model.instanceColor=Color(1,0,1,1);model.instanceCustomData=Vector4(1,.2,2,16)
end)
for index,spec in ipairs(cases) do
    local start=60+(index-1)*84
    V.atFrame(start,function()
        if material then material:Dispose() end
        material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/'..spec.shader..'.shader'))
        material:SetShaderParameter('base_color',Variant(Color(1,0,1,.65)))
        material:SetShaderParameter('emission_color',Variant(Color(1,0,1)))
        material:SetShaderParameter('emission_strength',Variant(4.0))
        material:SetShaderParameter('animation_time',Variant(0.0))
        model.material=material;Plane(true)
        marker.position=Vector3(2,3,0);marker.rotation=spec.tilted and Quaternion(35,20,15) or Quaternion.IDENTITY
        marker.scale=spec.tilted and Vector3(2,1.5,3) or Vector3(2,2,2)
        results[spec.name]={shader=spec.shader}
    end)
    V.atFrame(start+12,function()
        V.assert(Capture(spec,'above')>20,spec.name..' visible positive control')
        marker.position=Vector3(2,-3,0)
    end)
    V.atFrame(start+24,function()
        V.assert(Capture(spec,'below')<10,spec.name..' clips submerged reflection')
        V.assert(Capture(spec,'main-below',true)>20,spec.name..' preserves submerged geometry in normal view')
        Plane(false)
    end)
    V.atFrame(start+36,function()
        V.assert(Capture(spec,'below-unclipped')>20,spec.name..' unclipped submerged positive control')
        marker.position=Vector3(2,0,0);Plane(true)
    end)
    V.atFrame(start+48,function()
        V.assert(Capture(spec,'partial')>20,spec.name..' retains above-floor part of intersecting object')
        Plane(false)
    end)
    V.atFrame(start+60,function()
        local all=Capture(spec,'partial-unclipped');local clipped=results[spec.name].partial
        V.assert(all>clipped+20,spec.name..' trims only submerged part of intersecting object')
        Plane(true)
    end)
    V.atFrame(start+72,function()
        local repeated=Capture(spec,'partial-restored');local previous=results[spec.name].partial
        V.assert(math.abs(repeated-previous)<math.max(15,previous*.03),spec.name..' clip updates without stale reflection')
        local f=assert(io.open('docs/migration/evidence/planar-clip-measurements.json','w'));f:write(cjson.encode(results));f:close()
    end)
end
V.atFrame(60+#cases*84,function()
    marker:Remove();material:Dispose();_G.VOX_DEBUG=nil;V.finish()
end)
