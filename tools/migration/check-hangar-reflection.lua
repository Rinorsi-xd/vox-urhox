local app,h,lod0
local constantTexture
local UI=require 'urhox-libs/UI'
local function Near(a,b) return math.abs(a-b)<.0001 end
local function Snapshot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'capture '..name)
    V.assert(image:SavePNG('docs/migration/evidence/'..name..'.png'),'save '..name);image:Dispose()
end
V.atFrame(60,function()
    app=VOX_HANGAR.app;h=app.hangar;app.camera:Step(.65);app.camera.autoSpin=false;_G.VOX_DEBUG={time=10}
    UI.SetRoot(UI.Panel{width='100%',height='100%',pointerEvents='none'})
    renderer:GetViewport(0):SetRect(IntRect(0,0,1920,1080))
end)
V.atFrame(75,function()
    V.assert(h.reflW==960 and h.reflH==540 and Near(h.reflCam.aspectRatio,16/9),'reflection uses actual 1920x1080 game viewport')
    V.assert(#h.reflFilter.textures==3 and h.reflFilter.textures[1].width==480 and h.reflFilter.textures[3].width==120,'reflection allocates only the three source LOD levels')
    V.assert(h.reflTex.levels==1,'unused black native mip allocation removed')
    local matrix=h.padMat:GetShaderParameter('refl_matrix'):GetMatrix4()
    local maxError=0
    for _,p in ipairs({Vector3(0,0,0),Vector3(5,0,-5),Vector3(-5,0,5)}) do
        local reflected=matrix*Vector4(p.x,p.y,p.z,1)
        local main=(app.camera.camera:GetProjection()*app.camera.camera:GetView())*Vector4(p.x,p.y,p.z,1)
        maxError=math.max(maxError,math.abs(reflected.x/reflected.w-main.x/main.w),math.abs(reflected.y/reflected.w-main.y/main.w))
    end
    V.assert(maxError<.0001,'reflected floor projection matches main camera at three world positions')
    print('[ReflectionQA] '..h.reflW..'x'..h.reflH..' levels='..h.reflTex.levels..' projectionError='..maxError)
end)
V.atFrame(90,function()
    lod0=h.reflTex:GetImage();V.assert(lod0~=nil,'read actual GPU reflection mip zero');lod0:SavePNG('docs/migration/evidence/reflection-mip0.png')
end)
V.atFrame(105,function()
    local image=h.reflFilter.textures[3]:GetImage();local difference,energy=0,0
    image:SavePNG('docs/migration/evidence/reflection-mip3.png');assert(image:Resize(lod0.width,lod0.height))
    local channels=lod0.width*lod0.height*3
    for y=0,lod0.height-1 do for x=0,lod0.width-1 do local a,b=lod0:GetPixel(x,y),image:GetPixel(x,y);difference=difference+math.abs(a.r-b.r)+math.abs(a.g-b.g)+math.abs(a.b-b.b);energy=energy+b.r+b.g+b.b end end
    V.assert(difference/channels>.001,'actual rendered filtered mip differs from sharp reflection')
    V.assert(energy/channels>.002,'generated reflection mip contains scene pixels rather than black')
    print('[ReflectionQA] mip3 mean='..(energy/channels)..' delta='..(difference/channels))
    image:Dispose();lod0:Dispose()
    Snapshot('pc-reflection-1920')
    renderer:GetViewport(0):SetRect(IntRect(160,70,1600,970))
end)
V.atFrame(125,function()
    V.assert(h.reflW==720 and h.reflH==450 and Near(h.reflCam.aspectRatio,1.6),'offset 1440x900 viewport resizes reflection without using window aspect')
    Snapshot('pc-reflection-1440-offset')
    local source=Image:new();source:SetSize(128,128,3);source:Clear(Color(.25,.5,.75))
    constantTexture=Texture2D:new();constantTexture:SetNumLevels(1);assert(constantTexture:SetData(source));source:Dispose()
    for _,material in ipairs(h.reflFilter.materials) do material:SetSurfaceTexture('source_map',constantTexture) end
    h.reflFilter:Queue()
    print('[ReflectionQA] default path commands')
    local path=h.reflFilter.textures[1].renderSurface:GetViewport(0).renderPath
    for i=0,path:GetNumCommands()-1 do local c=path:GetCommand(i);print('[ReflectionQA] '..i..' type='..c.type..' pass='..c.pass..' pixel='..c.pixelShaderName..' tag='..c.tag) end
end)
V.atFrame(145,function()
    for i,texture in ipairs(h.reflFilter.textures) do
        local image=texture:GetImage();local p=image:GetPixel(math.floor(image.width/2),math.floor(image.height/2))
        print('[ReflectionQA] constant level '..i..' '..p.r..','..p.g..','..p.b)
        V.assert(math.abs(p.r-.25)<.015 and math.abs(p.g-.5)<.015 and math.abs(p.b-.75)<.015,'filter preserves linear HDR colors level '..i);image:Dispose()
    end
    for _,material in ipairs(h.reflFilter.materials) do material:SetSurfaceTexture('source_map',h.reflTex) end
    constantTexture:Dispose();app:Reload()
end)
V.atFrame(170,function()
    V.assert(app.hangar~=h and h.reflTex==nil and h.reflNode==nil and h.reflFilter==nil,'reload releases owned reflection target, filters and camera')
    V.assert(app.hangar.reflTex~=nil,'reload recreates reflection for current scene')
    _G.VOX_DEBUG=nil;V.finish()
end)
