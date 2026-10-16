local MapShot=require 'render.MatchMapShot'
local scene,environment,shot,request,phase,start,sceneFile
local previousSettings={}
local function Read(path)local f=File(path,FILE_READ);local value=cjson.decode(f:ReadString());f:Dispose();return value end
local function Write(path,value)local f=File(path,FILE_WRITE);f:WriteString(cjson.encode(value));f:Dispose()end
local function Update()
    if not scene then return end
    if phase=='scene' then
        if scene.asyncLoading then return end
        sceneFile:Dispose();sceneFile=nil
        math.randomseed(1337)
        environment=require('scene.Crater').New(scene,require('drive.CraterLayout').Read())
        phase='environment';print('MATCH_MAP_BAKE environment');return
    end
    if phase=='environment' then
        if not require('app.SceneLoader').EnvironmentReady({},scene) then return end
        MapShot.Initialize();shot=MapShot.New(scene)
        environment:Update(1,shot.node)
        -- Static base excludes transient camera-facing particle/shield batches.
        -- Keep authored meshes and environment point lights in the same scene.
        for _,name in ipairs({'ShipSmoke','DustDevils','WindMotes','GroundWind'})do
            local node=environment.effects.root:GetChild(name,true);if node then node.enabled=false end
        end
        phase='capture';start=Time:GetSystemTime();print('MATCH_MAP_BAKE capture');return
    end
    if phase~='capture' then return end
    shot:Update();if not shot.ready then return end
    local texture,half=shot:Take();local image=assert(texture:GetImage())
    V.assert(half==320 and image.width==1024 and image.height==1024,'production map dimensions unchanged')
    local colors={};local count=0
    for y=0,1023,16 do for x=0,1023,16 do local p=image:GetPixelInt(x,y);if not colors[p]then colors[p]=true;count=count+1 end end end
    V.assert(count>32,'authored map has varied rendered pixels')
    V.assert(image:SavePNG(request.image),'save lossless production toned base')
    local checksums={}
    for _,path in ipairs({'Scenes/Crater.xml','render/MatchMapShot.lua','scene/Crater.lua'})do
        local file=assert(cache:GetFile(path));checksums[path]=file:GetChecksum();file:Dispose()
    end
    local elapsed=Time:GetSystemTime()-start
    V.assert(renderer.textureFilterMode==FILTER_TRILINEAR and renderer.textureAnisotropy==1,'capture uses production linear mip filtering without anisotropy')
    image:Dispose();texture:Dispose();shot:Dispose();shot=nil
    V.assert(scene:GetChild('MatchMapShotCamera')==nil,'bake camera released')
    environment:Dispose();environment=nil;scene:Dispose();scene=nil;MapShot.Shutdown()
    renderer.textureFilterMode=previousSettings.filter;renderer.textureAnisotropy=previousSettings.anisotropy
    V.assert(renderer.textureFilterMode==previousSettings.filter and renderer.textureAnisotropy==previousSettings.anisotropy,'capture restores previous renderer filtering')
    local result={result='PASSED',checksums=checksums,colorsSampled=count,captureAndToneMs=elapsed,half=half,size=1024,textureFilter='trilinear',textureAnisotropy=1}
    Write(request.result,result);print('MATCH_MAP_BAKE '..cjson.encode(result));V.finish()
end
V.atFrame(2,function()
    previousSettings={filter=renderer.textureFilterMode,anisotropy=renderer.textureAnisotropy}
    renderer.textureFilterMode=FILTER_TRILINEAR;renderer.textureAnisotropy=1
    request=Read('.tmp/match-map-bake-request.json');scene=Scene();scene.asyncLoadingMs=3
    sceneFile=assert(cache:GetFile(request.scene));assert(scene:LoadAsyncXML(sceneFile,LOAD_SCENE_AND_RESOURCES))
    phase='scene';SubscribeToEvent('Update',Update)
end)
