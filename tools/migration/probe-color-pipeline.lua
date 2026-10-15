-- Isolated neutral patches using scaffold-3d-scene's scene/camera/HDR setup.
-- Test resources stay outside shipped scripts/assets.
local Exposure=require 'render.FixedExposure'
local scene,camera,zone
local refFile=File('tools/migration/crater-color-reference.json',FILE_READ)
local reference=cjson.decode(refFile:ReadString());refFile:Dispose()
local values=reference.inputs
local results={}
local settings,done
local builds={}
local function Shot(name)
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture '..name)
    local pixels={}
    for i=1,#values do
        local screen=camera:WorldToScreenPoint(Vector3((i-4.5)*.8,0,0))
        local color=im:GetPixel(math.floor(screen.x*im.width),math.floor(screen.y*im.height))
        pixels[i]={color.r,color.g,color.b}
    end
    results[name]=pixels;im:SavePNG('.tmp/color-'..name..'.png');im:Dispose()
end
local function Create()
    cache:AddResourceDir('tools/migration/probes',false)
    scene=Scene();scene:CreateComponent('Octree')
    zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(-100,100)
    zone:SetAttribute('Bloom Enable',Variant(true));zone.bloomMode=BLOOM_MODE_UE;zone.bloomUEIntensity=0;zone.vignetteEnabled=false
    zone.tonemapMode=TONEMAP_MODE_NONE;zone:SetAttribute('Auto Exposure Enable',Variant(false))
    renderer.hdrRendering=true
    local node=scene:CreateChild('Camera');node.position=Vector3(0,0,-10);camera=node:CreateComponent('Camera');camera.orthographic=true;camera.orthoSize=4
    for i,value in ipairs(values) do
        local n=scene:CreateChild('Patch'..i);n.position=Vector3((i-4.5)*.8,0,0);n.scale=Vector3(.65,2,.1)
        local m=n:CreateComponent('StaticModel');m.model=cache:GetResource('Model','Models/Box.mdl')
        local mat=Material:new();assert(mat:SetSurfaceShader('Shaders/BLGL/ColorProbe.shader'))
        mat:SetShaderParameter('tint',Variant(Vector4(value[1],value[2],value[3],1)));m.material=mat
    end
    renderer:SetViewport(0,Viewport:new(scene,camera))
end
local steps={
[20]=function() Shot('linear');zone.tonemapMode=TONEMAP_MODE_ACES end,
[40]=function() Shot('aces-off');Exposure.Apply(zone,1) end,
[60]=function() Shot('aces-one');Exposure.Apply(zone,.6) end,
[80]=function() Shot('aces-six');Exposure.Apply(zone,1.4) end,
[100]=function()
    Shot('aces-fourteen')
    print('[ColorProbe] LUT attribute type '..zone:GetAttribute('Tonemap LUT'):GetTypeName())
    V.assert(zone:SetAttribute('Tonemap LUT',Variant(VAR_RESOURCEREF,'Texture3D;ColorProbe.cube')),'assign constant color LUT')
    zone.tonemapMode=TONEMAP_MODE_LUT
end,
[120]=function()
    Shot('lut-binding')
    V.assert(zone:SetAttribute('Tonemap LUT',Variant(VAR_RESOURCEREF,'Texture3D;Crater/Tonemap.cube')),'assign crater LUT')
    Exposure.Apply(zone,1)
end,
[140]=function()
    Shot('crater-lut')
    for i=1,#values do for c=1,3 do V.assert(math.abs(results['crater-lut'][i][c]*255-reference.expected[3].pixels[i][c])<=3,'default H5 color patch '..i..' channel '..c) end end
    scene:SetVar('VoxColorGrade',Variant('crater'))
    settings=require('render.GraphicsSettings').New({ownsScene=true,isValidation=true,scene=scene,store={Write=function() return true end}})
    settings.data.bloom=0;settings.data.vignette=0;settings:Apply(scene)
    settings:Set('exposure',.7);settings:Update(.016)
    local cancelled=settings.tonemap.job;settings:Set('exposure',.6)
    V.assert(coroutine.status(cancelled)=='dead' and settings.tonemap.job~=cancelled,'superseded LUT job cancelled')
end}
local frame=0
local exposures={.6,1.4,1,1.4,1.1};local index,settle=1,0
local reloaded=false
for tick=45,1680 do V.atFrame(tick,function()
    if done then return end
    if not CRATER_PREVIEW then return end
    if frame==0 then Create() end
    frame=frame+1;if steps[frame] then steps[frame]() end
    if settings and frame>140 then
        settings:Update(.016)
        if settings.tonemap.job then settle=0;return end
        if index==3 and not reloaded then
            reloaded=true;V.assert(cache:ReloadResource(settings.tonemap.resource),'reload packaged source color LUT')
            settings:Update(.016);settle=0;return
        end
        settle=settle+1;if settle<3 then return end
        local exposure=exposures[index];local name='dynamic-'..index
        Shot(name);local expected
        for _,e in ipairs(reference.expected) do if e.exposure==exposure then expected=e.pixels end end
        for i=1,#values do for c=1,3 do V.assert(math.abs(results[name][i][c]*255-expected[i][c])<=3,'dynamic H5 exposure '..exposure..' patch '..i..' channel '..c) end end
        builds[#builds+1]={exposure=exposure,max_slice_ms=settings.tonemap.maxSliceMs,upload_ms=settings.tonemap.lastUploadMs,frames=settings.tonemap.buildFrames}
        index=index+1;settle=0
        if exposures[index] then settings:Set('exposure',exposures[index]);return end
        local tonemap=settings.tonemap;settings:Set('exposure',.7);settings:Dispose()
        V.assert(not tonemap.job and not tonemap.image and not tonemap.resource,'pending LUT work and references released on scene exit')
        for i=1,#values do for c=1,3 do V.assert(math.abs(results['aces-off'][i][c]-results['aces-one'][i][c])<1/255,'fixed exposure 1 is neutral') end end
        local file=File('docs/migration/evidence/color-pipeline.json',FILE_WRITE);file:WriteString(cjson.encode({inputs=values,pixels=results,builds=builds}));file:Dispose()
        renderer:SetViewport(0,nil);scene:Dispose();done=true;V.finish()
    end
end) end
V.atFrame(1690,function() V.assert(done,'color sequence finished');V.finish() end)
