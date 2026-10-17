-- Application lifecycle follows scaffold-3d-scene; scene content is authored data.
local WebMapTransition=require("app.WebMapTransition")
local ResourceGate=require("app.ResourceGate")
local ResourceData=require("core.ResourceData")
local BlueprintStore=require("storage.BlueprintStore")
local AudioLevels=require("audio.AudioLevels")
local MusicPlayer=require("audio.MusicPlayer")
local GameAmbience=require("audio.GameAmbience")
local GraphicsSettings=require("render.GraphicsSettings")
local HangarPreview=require("render.HangarPreview")
local BlueprintCode=require("storage.BlueprintCode")
local BuildEditor=require("construction.BuildEditor")
local UiSound=require("audio.UiSound")
local Garage=require("construction.Garage")
local BuildSession=require("app.BuildSession")
local Rotations=require("core.Rotations")
local MechView=require("render.MechView")
local ImportedDependencies=require("parts.Dependencies")
local HomeStations=require("controls.HomeStations")
local SourceFonts=require("ui.SourceFonts")
local TouchMode=require("controls.TouchMode")
local LoadingFlow=require("app.LoadingFlow")
local SourceToasts=require("ui.SourceToasts")
local Tutorial=require("story.Tutorial")
local HangarResources=require("scene.HangarResources")
local ArenaData=require("combat.ArenaData")
local EndlessSelect=require("ui.EndlessSelect")
local IntroSession=require("intro.IntroSession")
local OpeningHost=require("app.OpeningHost")
local DriveMaps=require("app.DriveMaps")
local VehicleSpec=require("drive.VehicleSpec")
local PlatformUtils=require("urhox-libs.Platform.PlatformUtils")
local WeaponIconResources=require("ui.WeaponIconResources")
local MissileView=require("render.MissileView")
local WeaponAudio=require("audio.WeaponAudio")
local DrivingAudio=require("audio.DrivingAudio")
local CombatFeedbackAudio=require("audio.CombatFeedbackAudio")
local BattleController=require("combat.BattleController")
local Mission=require("story.Mission")
local EndlessSession=require("app.EndlessSession")
local TrialSession=require("app.TrialSession")
local MapPreview=require("app.MapPreview")
local HangarConfig=require("scene.HangarConfig")
local PreviewRoom=require("controls.PreviewRoom")
local LiveryPage=require("ui.LiveryPage")
local HomeVehicleSwitch=require("app.HomeVehicleSwitch")
local PartsGallery=require("render.PartsGallery")
local OpeningRetirement=require("app.OpeningRetirement")
local WindowViewports=require("render.WindowViewports")
local RenderTargetLifetime=require("render.RenderTargetLifetime")
local StoryComms=require("audio.StoryComms")
local IntroAudioTail=require("audio.IntroAudioTail")
local GameMusicState=require("audio.GameMusicState")
local Warehouse=require("scene.Warehouse")
local SalvageResultReturn=require("salvage.ResultReturn")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local UI=require "urhox-libs/UI"
local Config=require "Config"
local Blueprint=require "construction.Blueprint"
local Prefab=require "construction.Prefab"
local VehicleView=require "render.VehicleView"
local Hangar=require "scene.Hangar"
local OrbitCamera=require "controls.OrbitCamera"
local Hud=require "ui.GarageHud"
local Loader=require "app.SceneLoader"
local HotReload=require "app.HotReload"
local Quality=require "render.Quality"
local CollectionCycle=require "core.CollectionCycle"
local SCENE="Scenes/OrbitalHangar.xml"
local VIEWS={
    hall={target={0,5,-8},dist=32,yaw=180,pitch=12,fov=65},
    door={target={0,10,-70},dist=41,yaw=180,pitch=0,fov=65},
    rear={target={0,12,20},dist=38,yaw=0,pitch=0,fov=65},
    display={target={-29,4,0},dist=12,yaw=270,pitch=3,fov=60},
    car={target={0,1.1,0},dist=11,yaw=140,pitch=19,fov=48},
}
---@class HangarApp
local App={}
App.__index=App
function App.New()
    local self=setmetatable({},App)
    self:init()
    return self
end
function App:init()
    self.scene=nil ---@type Scene|nil
    self.hangar=nil ---@type Hangar|nil
    self.camera=nil ---@type OrbitCamera|nil
    self.vehicleSwitch=nil ---@type HomeVehicleSwitch|nil
    self.gallery=nil ---@type PartsGallery|nil
    self.blueprint=Prefab.BuildRaceCar(Blueprint.New())
    self.tier=3
    self.generation=0
    self.reloadQueued=false
    self.galleryOn=false
    self.ownsScene=true
    self.stopped=false
    self.development=false
    self.debugEnabled=false
    self.view=""
    self.mode="hangar"
    self.trial=nil ---@type table|nil
    self.startTrial=false
    self.partsPage=0
    self.buildWanted=false
    self.build=nil ---@type table|nil
    self.isValidation=false
    self.loader=Loader.New()
    self.mapTransition=WebMapTransition.New(function() self:ReleaseMapHangar() end,function() return self:ReleaseSettledAssets() end)
    self.vehicleGate=ResourceGate.New()
    self.motionModule=nil ---@type table|nil
    self.hotReload=HotReload.New(function() self:Reload() end,function(module)
        self.motionModule=module
        if self.hangar then self.hangar.motion=module end
    end)
    for _,arg in ipairs(GetArguments()) do
        if arg=='-validate' or arg:match('^%-screenshot=') then self.isValidation=true end
        if arg=='-build' then self.buildWanted=true end
        if arg=="-dev" then self.development=true;self.debugEnabled=true end
        if arg=='-debug' or arg=='-debug=1' or arg=='-vox-debug' or arg=='-vox-debug=1' then self.debugEnabled=true end
        if arg=="-trial" then self.startTrial=true end
        if arg=='-crater' then self.startTrial=true;self.startMap='crater';self.selectedMap='crater' end
        local blueprint=arg:match("^%-blueprint=(Blueprints/[%w_%-]+%.json)$")
        if blueprint then self.blueprint=Blueprint.New():Load(ResourceData.Read(blueprint));self.explicitBlueprint=true end
        local view=arg:match("^%-hangar%-view=(.+)$")
        if view and VIEWS[view] then self.view=view;_G.VOX_DEBUG={hideUI=true,time=10} end
        self.partsPage=tonumber(arg:match("^%-parts%-page=(%d+)$")) or self.partsPage
    end
    self.store=BlueprintStore.New(self.isValidation and 'vox-validation' or nil)
    AudioLevels.Init(self.store)
    self.music=MusicPlayer.New(self.store)
    self.ambience=GameAmbience.New()
    self.graphicsSettings=GraphicsSettings.New(self)
    self.previews=HangarPreview.New(self)
    self.store.captureContext=function()
        return {tier=self.tier,aspect=math.max(1,graphics:GetWidth())/math.max(1,graphics:GetHeight()),
            grid=self.hangar and self.hangar.gridOn or false,time=self.hangar and self.hangar.time or 10,
            graphics=self.graphicsSettings.data}
    end
    if not self.isValidation and not self.explicitBlueprint then
        local draft=self.store:Read('draft')
        if draft then
            local ok,bp=pcall(function() return Blueprint.New():Load(BlueprintCode.Validate(draft)) end)
            if ok then self.blueprint=bp else print('[HangarApp] Invalid draft; keeping starter vehicle') end
        end
    end
    self.editor=BuildEditor.New(self.blueprint,function(ops)
        if self.car then self.car:ApplyEdits(ops,self.blueprint) end
        if self.bays then self.bays:Changed() else self.store:Queue(self.blueprint) end
    end,UiSound.Play)
    self.bays=Garage.New(self.blueprint,self.store,function(data) return self:LoadBlueprint(data) end,not self.isValidation and not self.explicitBlueprint)
end
function App:EnterBuild()
    if not self.ownsScene or self.mode=='trial' or self.loader.state=='loading' then return false end
    if self.build then return true end
    if self.vehicleSwitch and self.vehicleSwitch:Finish()==false then return false end
    self.vehicleGate:Cancel()
    if self.build then return true end -- A pending empty preset already entered.
    if self.gallery then self:ToggleGallery() end
    self.graphicsSettings:SetSceneVisible(true)
    Hud.Dispose()
    self.buildWanted=true
    self:View(VIEWS.car);self.camera.target=Vector3(0,3,0);self.camera.cur.target=self.camera.target;self.camera:Apply()
    self.hangar:SetGrid(true)
    self.build=BuildSession.New(self)
    return true
end
function App:ExitBuild()
    self.vehicleGate:Cancel()
    if self.build then self.build:Dispose();self.build=nil end
    self.buildCameraState=nil
    self.buildXray=false
    self.buildWanted=false
    self.hangar:SetGrid(false)
    if self.bays.active and self.bays.unsaved then local ok,err=self.bays:Save();if not ok then self.homeMessage=err end end
    self.homeTab=self.lobby=='salvage' and 'salvage' or 'hangar'
    Hud.Create(self)
    Hud.Refresh(self.blueprint,Config.TIERS[self.tier]);self:GroundDisplay();self:HomeView('hangar')
end
function App:DisplayHeight()
    local minY=math.huge
    for _,p in ipairs(self.blueprint:List()) do
        for _,c in ipairs(p._cells) do minY=math.min(minY,c[2]) end
        local vis=self.car.visuals[p.id];local segments=vis and vis.data.segments
        if type(segments)=='table' and segments.leg then
            local toe=Rotations.ApplyRot(p.rot,segments.info.origins.toe)
            minY=math.min(minY,p.pos[2]+.5+toe[2])
        end
    end
    return minY<math.huge and -minY*Config.CELL or 0
end
function App:GroundDisplay()
    self.car.root.position=Vector3(0,self:DisplayHeight(),0)
    for _,vis in pairs(self.car.visuals) do
        if vis.rig and vis.rig.mech then MechView.StandOn(vis,0) end
    end
end
function App:LoadBlueprint(data)
    -- Parse into a candidate first; a malformed save cannot clear the active car.
    local checkpoint=self.vehicleSwitch and self.vehicleSwitch:AssemblyCheckpoint()
    local ok,candidate=pcall(function() return Blueprint.New():Load(BlueprintCode.Validate(data),checkpoint) end)
    if not ok then return false,'无效的蓝图' end
    if not ImportedDependencies.Ready(candidate:List()) then return false,'战车零件尚未下载完成' end
    if self.build then self.build:Dispose();self.build=nil end
    self.blueprint:Load(candidate:ToTable(),checkpoint);self.editor.history.undoStack={};self.editor.history.redoStack={}
    self.blueprint.dropped=candidate.dropped;self.blueprint.migrationWarnings=candidate.migrationWarnings
    self.editor.selection={};self.editor.preview=nil;self.editor.pasting=false
    self.car:Rebuild(self.blueprint,self.vehicleSwitch and self.vehicleSwitch:AssemblyCheckpoint());self.store:Queue(self.blueprint)
    if self.bays then self.bays:Changed() end
    if self.buildWanted then self.build=BuildSession.New(self) end
    if not self.buildWanted then
        self:GroundDisplay()
        local pose=HomeStations.Get(self.blueprint:Stats(),'hangar',self.camera.maxDist)
        self.camera:Focus(Vector3(table.unpack(pose.target)),pose.dist)
    end
    if self.vehicleSwitch then self.vehicleSwitch:Replaced() end
    return true
end
function App:WithVehicle(data,action,done)
    if self.stopped or self.vehicleGate.state=='loading' then return false end
    local scene,build,home=self.scene,self.build,Hud.GetState()
    self.vehicleGate:Start(ImportedDependencies.FromBlueprint(data),function(ok,message)
        if self.stopped or self.scene~=scene or self.build~=build or Hud.GetState()~=home then return end
        local result,err,reason=false,message,nil
        if ok then
            local ran,a,b,c=pcall(action)
            result=ran and a;reason=c
            if ran then err=b else err=tostring(a) end
        end
        if done then done(result,err,reason) elseif not result then self.toasts:Push(err,'bad') end
    end)
    return true
end
function App:Start(existingScene)
    self.previousState={autoReload=cache.autoReloadResources,hdr=renderer.hdrRendering,
        shadowSize=renderer.shadowMapSize,shadows=renderer.drawShadows,mouseMode=input.mouseMode,
        maxFps=engine.maxFps,inactiveFps=engine.maxInactiveFps,
        textureFilterMode=renderer.textureFilterMode,textureAnisotropy=renderer.textureAnisotropy}
    if not existingScene then graphics.windowTitle="构装纪元 CONSTRUCT ERA" end
    input.mouseMode=MM_ABSOLUTE
    local fonts=SourceFonts.Resolve()
    UI.Init({theme="default-dark",scale=TouchMode.Scale('home'),
        fonts={{family="sans",weights={normal=fonts.body,bold=fonts.bold}}}})
    UiSound.Start()
    self.loadingFlow=LoadingFlow.New(self)
    self.loader.canStart=function()
        local ready,message=self.mapTransition:CanStart(self.loadingFlow:CanStartLoad(),self.loadingFlow.pageFrames,
            cache:GetNumBackgroundLoadResources()==0)
        if message then self.loader:Fail(message) end
        return ready
    end
    self.toasts=SourceToasts.New()
    self.toasts:Attach()
    self.tutorial=Tutorial.New(self)
    if not existingScene then cache.autoReloadResources=self.development end
    renderer.hdrRendering=true
    renderer.textureFilterMode=FILTER_TRILINEAR;renderer.textureAnisotropy=1
    renderer.shadowMapSize=Quality.current.shadowMapSize
    if not existingScene then engine.maxFps=Quality.FrameLimit();engine.maxInactiveFps=10 end
    if not existingScene then self.graphicsSettings:Apply() end
    self.loadingLabel=UI.Label{text="正在进入机库…",fontSize=22}
    UI.SetRoot(UI.Panel{width="100%",height="100%",backgroundColor={12,15,20,255},
        alignItems="center",justifyContent="center",children={self.loadingLabel}})
    if existingScene then
        self.ownsScene=false
        self:Install(existingScene)
        self.loader.state="ready"
    else self:Reload() end
end
function App:Reload()
    if not self.ownsScene then
        Hud.SetMode("编辑器预览：停止播放后修改并保存场景")
        return
    end
    if self.loader.state=="loading" then self.reloadQueued=true;return end
    self.mapTransition:PrepareRecovery()
    if self.vehicleSwitch and self.vehicleSwitch:Finish()==false then return end
    self.vehicleGate:Cancel()
    if self.trial or not self.scene then
        if self.trial then self.trial:Pause() end
        self.loadingFlow:Open({id='hangar',name='轨道改装机库',boot=not self.scene,loadingArt='UI/Salvage/depot.jpg',loadingBrand='返回机库',
            loadingSub='战车、车库与改装'},function()
                if self.trial and self.loadingFlow.failed then self:Reload()
                else self.loader:Cancel() end
            end)
    end
    print("[HangarApp] Loading authored scene "..SCENE)
    self.loader:Load(SCENE,function(scene)
        self:Install(scene)
        if self.loadingFlow.active then self.loadingFlow:Finish() end
        self.mapTransition:Restored()
    end,function(message)
        if self.loadingFlow.active then self.loadingFlow:Fail(message) end
        print("[HangarApp] Load failed; keeping previous scene: "..message)
        if self.scene then Hud.SetMode("场景更新失败，保留当前画面 · F5 重试")
        elseif not self.loadingFlow.active then self.loadingLabel:SetText("机库加载失败 · 按 F5 重试") end
    end,{resources=HangarResources.For(self.blueprint:List())})
end
function App:EnterBattle(mode)
    if not ArenaData.modes[mode] then return false end
    if self.loadingFlow.active or self.mode=='trial' or self.loader.state=='loading' then return false end
    return self.loadingFlow:QueueBattle(mode,self.blueprint)
end
function App:SelectEndless()
    if self.mode=='trial' or self.loader.state=='loading' or self.loadingFlow.active or self.opening and self.opening.active then return false end
    if self.endlessSelect then return false end
    self.endlessSelect=EndlessSelect.Open(self,function(source,saved)
        self.endlessSelect=nil;self.pendingEndless={source=source,saved=saved};self:EnterTrial('endless')
    end,function() self.endlessSelect=nil end)
    return true
end
function App:StartOpening(part)
    if self.mode=='trial' or self.loader.state=='loading' or self.loadingFlow.active or self.opening and self.opening.active then return false end
    if self.build then self:ExitBuild() end
    self.opening=IntroSession.New(self,OpeningHost.New(self))
    return self.opening:Start(part)
end
function App:EnterTrial(mapId,battleMode,roster,reuseLoading)
    if not self.ownsScene then
        Hud.SetMode("试车请用项目独立运行入口；当前为编辑器机库预览")
        return false
    end
    if self.mode=="trial" or self.loader.state=="loading" then return false end
    if self.vehicleSwitch and self.vehicleSwitch:Finish()==false then return false end
    self.vehicleGate:Cancel()
    if self.build then self.build.buildCamera:Release() end
    local map=assert(DriveMaps[mapId or 'trial'],'Unknown drive map')
    local entryBlueprint=self.blueprint
    if map.endless and self.pendingEndless then
        local copy={};for key,value in pairs(map) do copy[key]=value end;map=copy
        entryBlueprint=Blueprint.New():Load(self.pendingEndless.source);map.endlessSaved=self.pendingEndless.saved;self.pendingEndless=nil
    end
    if map.salvage then
        if self.lobby~='salvage' then return false end
        local spec=VehicleSpec.Build(self.blueprint)
        if not spec.ok then self.toasts:Push(spec.reason or '战车无法出发，请先整备','bad');return false end
        local items=ResourceData.Read('UI/Outgame.json')
        local value=0
        for _,p in ipairs(self.blueprint:List()) do local it=items.items['part:'..p.type];if it then value=value+it.price end end
        local op=items.ops[self.salvageLobby.data.op or 1]
        if value<op.minValue then self.toasts:Push('带入价值不足 '..tostring(op.minValue),'bad');return false end
        for id in pairs(self.salvageLobby:DeploymentShortfall()) do
            self.toasts:Push('仓库缺少 '..(items.items[id] and items.items[id].name or id),'bad');return false
        end
    end
    if battleMode then
        local copy={};for key,value in pairs(map) do copy[key]=value end;map=copy
        local cfg=ArenaData.modes[battleMode]
        map.battleMode=battleMode;map.battleRoster=roster;map.loadingBrand=cfg.name;map.loadingSub=cfg.size..'V'..cfg.size
        map.loadingTips=cfg.rules
    end
    if not reuseLoading then self.loadingFlow:Open(map,function() self:CancelMapLoad(true) end) end
    self.pendingMap=map
    local transition=self.mapTransition:Begin(PlatformUtils.IsWebPlatform()
        and map.prepareWorld~=nil and self.scene~=nil and self.hangar~=nil)
    local preparedWorld=nil ---@type table|nil
    local preparedSession=nil ---@type table|nil
    local function ClearLoading()
        if self.mapTransition:IsCurrent(transition) then self.pendingMap=nil end
    end
    local options={webWarmup=map.webWarmup,cancel=function() ClearLoading();self.mapTransition:Cancel(transition) end,
        cleanup=function()
            if transition.released and self.mapTransition:IsLatest(transition) then self:DetachSceneRender() end
            if preparedSession then
                if transition.released and self.trial==preparedSession then
                    self.trial=nil;self.scene=nil;self.mode='hangar';_G.VOX_TRIAL=nil
                end
                preparedSession:Dispose();preparedSession=nil
            end
            if preparedWorld then preparedWorld:Dispose();preparedWorld=nil end
        end}
    options.resources=function()
    local resources=map.resources and ResourceData.Read(map.resources) or {map.scene}
    resources[#resources+1]='Shaders/BLGL/Boundary.shader'
    resources[#resources+1]='Shaders/BLGL/AimLine.shader'
    resources[#resources+1]='Shaders/BLGL/RestoreFlash.shader'
    if map.salvage then
        options.webWarmup={{type='Texture2D',name='Salvage/GroundBaked.png'}}
        for _,path in ipairs(resources) do
            if path:match('^Salvage/run%-model%-.*%.bin$') then options.webWarmup[#options.webWarmup+1]={type='Model',name=path} end
        end
    end
    local parts=entryBlueprint:List()
    for _,path in ipairs(WeaponIconResources.For(parts)) do resources[#resources+1]=path end
    for _,part in ipairs(Prefab.BuildRaceCar(Blueprint.New()):List()) do parts[#parts+1]=part end
    for _,path in ipairs(ImportedDependencies.For(parts)) do resources[#resources+1]=path end
    for _,path in ipairs(MissileView.Dependencies()) do resources[#resources+1]=path end
    for _,path in ipairs(WeaponAudio.Dependencies()) do resources[#resources+1]=path end
    for _,path in ipairs(DrivingAudio.Dependencies()) do resources[#resources+1]=path end
    for _,path in ipairs(CombatFeedbackAudio.Dependencies()) do resources[#resources+1]=path end
    if map.salvage then
        for _,module in ipairs({'salvage.Run','audio.SalvageAudio','render.SalvageCinematics'}) do
            for _,path in ipairs(DeferredModules[module].Dependencies()) do resources[#resources+1]=path end
        end
    end
    if battleMode then for _,path in ipairs(BattleController.Dependencies(self.blueprint,roster,battleMode)) do resources[#resources+1]=path end end
    if map.storyLevel then for _,path in ipairs(Mission.Dependencies(self.blueprint,map.storyLevel)) do resources[#resources+1]=path end end
    if map.endless then for _,path in ipairs(EndlessSession.Dependencies(entryBlueprint)) do resources[#resources+1]=path end end
    return resources
    end
    options.prepare=function(scene,checkpoint)
        if map.prepareWorld then
            preparedWorld=DeferredModules[map.world].New(scene,true)
            DeferredModules[map.prepareWorld].Build(preparedWorld,function(progress,stage) checkpoint(progress*.6,stage) end)
        end
        checkpoint(.6,'session')
        -- Retain the partially built session so cancellation can release it
        -- even when coroutine.close bypasses the constructor's pcall cleanup.
        local world=preparedWorld;preparedWorld=nil
        preparedSession=TrialSession.New(scene,entryBlueprint,self,map,world,
            function(progress,stage) checkpoint(.6+.4*progress,stage) end,
            function(candidate) preparedSession=candidate end)
    end
    self.loader:Load(map.scene,function(scene)
        assert(self.mapTransition:IsCurrent(transition),'Obsolete map transition')
        local candidate=assert(preparedSession,'Trial preparation did not complete')
        self.graphicsSettings:Apply(scene)
        local activated,activationError=pcall(candidate.Activate,candidate,function() self:Reload() end)
        if not activated then candidate:Dispose();error(activationError) end
        candidate:Pause()
        local previous=self.scene
        Hud.Dispose()
        if self.build then self.build:Dispose();self.build=nil end
        self.previews:Dispose()
        if self.gallery then self.gallery:Dispose();self.gallery=nil end
        if self.vehicleSwitch then self.vehicleSwitch:Dispose();self.vehicleSwitch=nil end
        if self.car then self.car:Dispose();self.car=nil end
        if self.warehouse then self.warehouse:Dispose();self.warehouse=nil end
        if self.hangar then self.hangar:Dispose();self.hangar=nil end
        self.camera=nil;self.galleryOn=false;self.scene=scene;self.trial=candidate;self.mode="trial"
        _G.VOX_HANGAR=nil;_G.VOX_TRIAL={session=candidate,app=self}
        if previous then previous:Dispose() end
        self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
        ClearLoading()
        self.loadingFlow:Finish()
        assert(self.mapTransition:Commit(transition),'Map transition lost ownership')
        preparedSession=nil
        print("[HangarApp] Trial ready; hangar scene released, unused resource cleanup queued")
    end,function(message)
        if not self.mapTransition:IsLatest(transition) or transition.state=='committed' then return end
        ClearLoading()
        self.loadingFlow:Fail(message)
        self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
        if transition.released then self.toasts:Push(map.name..'加载失败，正在返回机库','bad')
        else Hud.SetMode(map.name..'加载失败，保留机库') end
        print('[HangarApp] '..message)
    end,options)
    return true
end
function App:PreviewMap(id)
    if not self.ownsScene or self.loader.state=='loading' or self.mapPreview then return false end
    local map=assert(DriveMaps[id],'Unknown map preview')
    self.loadingFlow:Open(map,function() self:CancelMapLoad(true) end)
    self.pendingMap=map
    local function Clear() self.pendingMap=nil end
    self.loader:Load(map.scene,function(scene)
        local home=Hud.GetState();home.CancelInput();home.root:SetVisible(false)
        self.mapPreview=MapPreview.New(self,scene,map);Clear();self.loadingFlow:Finish()
    end,function(message) Clear();self.loadingFlow:Fail(message);self.toasts:Push(map.name..'加载失败','bad');print('[MapPreview] '..message) end,
        {resources=ResourceData.Read(map.resources),webWarmup=map.webWarmup,cancel=Clear})
    return true
end
function App:Install(scene)
    if self.warehouse then self.warehouse:Dispose();self.warehouse=nil end
    -- Construct and validate the candidate before releasing the active scene.
    local h=Hangar.Bind(scene)
    if self.motionModule then h.motion=self.motionModule end
    local authoredCamera=scene:GetChild("Camera")
    local camera=OrbitCamera.New(scene,authoredCamera)
    camera.roomLimit=HangarConfig.layout.cameraLimit
    camera.safety=PreviewRoom.New(scene)
    local car=VehicleView.New(scene,"Car")
    car:Rebuild(self.blueprint) -- only the vehicle's actual part types are loaded
    if self.camera then
        camera.target=self.camera.target;camera.dist=self.camera.dist
        camera.yaw=self.camera.yaw;camera.pitch=self.camera.pitch
        camera.camera.fov=self.camera.camera.fov;camera.autoSpin=self.camera.autoSpin
        camera.cur={target=camera.target,dist=camera.dist,yaw=camera.yaw,pitch=camera.pitch}
        camera:Apply()
    end
    h:SetTier(self.tier)
    h:SetEnvelope(self.editor.bounds)
    h:SetInfoSource(function()
        local diag=self.build and self.build.inspection:Get() or nil
        return self.blueprint,Config.TIERS[self.tier],self.bays.active,self.bays.revision,diag
    end)
    h:Welcome(self.blueprint)
    h:SetGrid(self.hangar and self.hangar.gridOn or false)
    local oldScene,oldHangar,oldCar=self.scene,self.hangar,self.car
    if self.tutorial then self.tutorial:DetachVoice() end
    local oldSwitch=self.vehicleSwitch
    local oldTrial=self.trial
    -- Restore the live battle camera/root before the new hall takes over.
    if oldTrial and oldTrial.endless and oldTrial.endless.edit then
        oldTrial.endless.edit:Leave();oldTrial.endless.edit=nil
    end
    local oldHome=Hud.GetState()
    if oldHome and oldHome.livery then LiveryPage.Leave(oldHome) end
    if self.build then self.build:Dispose();self.build=nil end
    if self.gallery then self.gallery:Dispose() end
    self.scene,self.hangar,self.camera,self.car=scene,h,camera,car
    self.vehicleSwitch=HomeVehicleSwitch.New(self,car.root)
    self.graphicsSettings:Apply(scene)
    if self.ownsScene then self.graphicsSettings:Show(scene,camera.camera) end
    self.gallery=nil;self.galleryOn=false
    -- Editor owns the Game render target and viewport rectangle in PIE.
    -- Standalone owns viewport 0; embedded playback only moves the scene camera.
    Hud.Create(self);Hud.Refresh(self.blueprint,Config.TIERS[self.tier])
    if self.view~="" then
        self:View(VIEWS[self.view])
        UI.SetRoot(UI.Panel{width="100%",height="100%",pointerEvents="none"})
    elseif not oldScene then self:HomeView(self.homeTab or 'hangar') end
    if self.partsPage>0 and not oldScene then self:ToggleGallery(self.partsPage) end
    self.generation=self.generation+1
    _G.VOX_HANGAR={scene=scene,garage=h,camera=camera,blueprint=self.blueprint,app=self}
    if oldSwitch then oldSwitch:Dispose() end
    if oldCar then oldCar:Dispose() end
    if oldHangar then oldHangar:Dispose() end
    if oldTrial then oldTrial:Dispose();SalvageResultReturn.RecordRelease(self,oldTrial) end
    if oldScene then oldScene:Dispose() end
    self.trial=nil;self.mode="hangar";_G.VOX_TRIAL=nil
    if oldTrial then
        self:HomeView(self.homeTab or 'hangar')
        -- Finish the scene commit and let the renderer retire its previous
        -- frame before Lua finalizers release native render resources.
        self:DeferAssetRelease(oldTrial.ReleaseAssets)
    end
    if self.buildWanted and self.ownsScene then
        -- Install runs while the loader still reports loading, so bind directly.
        if not oldScene and not self.mapTransition:IsRestoring() then
            local minY=math.huge
            for _,p in ipairs(self.blueprint:List()) do for _,c in ipairs(p._cells) do minY=math.min(minY,c[2]) end end
            if minY<4 then self.editor:Lift(4-minY) end
            self:View(VIEWS.car);self.camera.target=Vector3(0,3,0);self.camera.cur.target=self.camera.target;self.camera:Apply()
        end
        self.build=BuildSession.New(self)
        self.hangar:SetGrid(true)
    else self:GroundDisplay() end
    print("[HangarApp] Ready generation="..self.generation..", parts="..self.blueprint:Size())
end
function App:View(v)
    print("[HangarApp] View yaw="..v.yaw..", distance="..v.dist)
    local c=self.camera
    c.flight=false
    c.target=Vector3(table.unpack(v.target));c.dist=v.dist;c.yaw=v.yaw;c.pitch=v.pitch
    c.camera.fov=v.fov;c.autoSpin=false
    c.cur={target=c.target,dist=v.dist,yaw=v.yaw,pitch=v.pitch};c:Apply()
end
function App:HomeView(tab)
    if self.lobby=='salvage' then
        local home=Hud.GetState();local sv=home and home.salvage
        tab=sv and ({loadout=sv.stash and 'svLoadout' or 'svLoadoutC',ops='svOps',market='svMarket',garage='svGarage',workshop='svGarage'})[sv.tab] or 'svLoadoutC'
    end
    local pose=HomeStations.Get(self.blueprint:Stats(),tab,self.camera.maxDist)
    if pose then self.camera:FlyTo(pose,.65) end
end
function App:ToggleGallery(page)
    print("[HangarApp] Catalog "..(self.gallery and "close" or ("open page="..(page or 1))))
    if self.gallery then
        self.gallery:Dispose();self.gallery=nil;self.galleryOn=false;self:View(VIEWS.car)
        self.car:SetVisible(true)
        Hud.SetMode("")
    else
        self.gallery=PartsGallery.New(self.scene,page or 1)
        self.galleryOn=true
        self.car:SetVisible(false)
        self:View({target={0,1,-10.5},dist=24,yaw=180,pitch=48,fov=48})
        Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭")
    end
end
function App:RetireOpening(work,done)
    self.openingRetirements=self.openingRetirements or {}
    self.openingRetirements[#self.openingRetirements+1]=OpeningRetirement.New(work,done)
end
function App:AdvanceOpeningRetirements(flush)
    local jobs=self.openingRetirements
    if not jobs then return end
    while jobs[1] do
        if not OpeningRetirement.Step(jobs[1],flush) then return end
        table.remove(jobs,1)
        if not flush then break end
    end
    if #jobs==0 then self.openingRetirements=nil end
end
function App:DeferAssetRelease(release,incremental)
    local pending=self.pendingAssetRelease
    if pending then
        self.pendingAssetRelease=function() pending();release() end
    else self.pendingAssetRelease=release end
    self.assetReleaseIncremental=incremental==true and (not pending or self.assetReleaseIncremental==true)
    self.assetReleaseEpoch=CollectionCycle.Fence()
    if not self.assetReleaseIncremental then CollectionCycle.Restore() end
    self.assetReleaseFrames=3
end
function App:DetachSceneRender()
    local settings=self.graphicsSettings
    settings:SetSceneVisible(false);settings.suspendedViewport=nil
    WindowViewports.Set(0,nil)
    settings:ParkPost()
    if settings.retainedPost then settings:ReleasePost(settings.retainedPost.scene) end
    if settings.tonemap then settings.tonemap:Dispose();settings.tonemap=nil end
end
function App:ReleaseMapHangar()
    local previous=self.scene
    assert(previous and self.hangar and not self.trial,'No live hangar to retire')
    self:DetachSceneRender()
    if self.tutorial then self.tutorial:DetachVoice() end
    local home=Hud.GetState()
    if home and home.livery then LiveryPage.Leave(home) end
    Hud.Dispose()
    -- UI.Render requires a root even for independent global loading overlays.
    UI.SetRoot(UI.Panel{width='100%',height='100%',pointerEvents='none'})
    if self.build then self.build:Dispose();self.build=nil end
    self.previews:Dispose()
    for _,key in ipairs({'gallery','vehicleSwitch','car','warehouse','hangar'}) do
        if self[key] then self[key]:Dispose();self[key]=nil end
    end
    self.camera=nil;self.galleryOn=false;self.scene=nil;_G.VOX_HANGAR=nil
    previous:Dispose()
    self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
end
function App:ReleaseSettledAssets()
    local incremental=self.assetReleaseIncremental
    local pending=self.pendingAssetRelease
    if incremental then
        if CollectionCycle.Epoch()<=self.assetReleaseEpoch then CollectionCycle.Step(128) end
        if CollectionCycle.Epoch()<=self.assetReleaseEpoch then return false end
    elseif not CollectionCycle.Collect() then return false end
    -- A finalizer may queue newer owners in either collection mode.
    if self.pendingAssetRelease~=pending then return false end
    local release=self.pendingAssetRelease;self.pendingAssetRelease=nil
    self.assetReleaseIncremental=nil;self.assetReleaseEpoch=nil
    if not incremental then RenderTargetLifetime.Flush() end
    -- Active Zones retain their applied SH/IBL. Drop reusable source HDRs only
    -- after scene disposal and the renderer retirement fence.
    environmentBakeCache:ClearCache()
    if release then release() end
    return true
end
function App:Update(dt)
    StoryComms.Tick(dt)
    if self.loadingFlow and not self.stopped then self.loadingFlow:Advance(dt) end
    if self.stopped then return end
    IntroAudioTail.Update(dt,input.focus and not input.minimized)
    self:AdvanceOpeningRetirements(false)
    BlueprintStore.UpdateAll(dt)
    ResourceGate.UpdatePending(dt)
    UiSound.Update()
    if input:GetMouseButtonPress(MOUSEB_LEFT) or input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then self.music:Unlock() end
    local musicState=GameMusicState.FromApp(self,Hud.GetState())
    AudioLevels.MixContext(dt,musicState.introActive or musicState.briefing)
    self.music:Update(dt,musicState.scene,not input.focus or input.minimized,musicState)
    self.ambience:Update(dt,GameAmbience.FromApp(self,Hud.GetState()),input.focus and not input.minimized)
    RenderTargetLifetime.Update()
    if self.pendingAssetRelease and not self.openingRetirements and self.loader.state~='loading' and cache:GetNumBackgroundLoadResources()==0 then
        self.assetReleaseFrames=self.assetReleaseFrames-1
        if self.assetReleaseFrames<=0 then
            self:ReleaseSettledAssets()
        end
    end
    if self.loader.state~='loading' and self.mapTransition:BeginRecovery() then self:Reload() end
    if self.loadingFlow and self.loadingFlow.active and input.focus and input:GetKeyPress(KEY_ESCAPE) then
        self.loadingFlow:Back();return
    end
    if self.pendingMap and input.focus and input:GetKeyPress(KEY_ESCAPE) then
        self:CancelMapLoad();return
    end
    if self.vehicleSwitch and input.focus and input:GetKeyPress(KEY_ESCAPE) and self.vehicleSwitch:CancelDownload() then
        self.toasts:Push('已取消换车');return
    end
    self.loader:Update(dt)
    if self.lobbyLoading then self.lobbyLoading:Update(dt) end
    if self.loadingFlow then self.loadingFlow:Observe(self.loader,dt) end
    self.previews:Update(dt)
    if self.opening and self.opening.active then
        for _,key in ipairs({KEY_SPACE,KEY_RETURN,KEY_ESCAPE,KEY_1,KEY_2,KEY_3,KEY_T,KEY_BACKSPACE}) do if input:GetKeyPress(key) then self.opening:KeyDown(key,false) end end
        if not input:GetKeyDown(KEY_SPACE) then self.opening:KeyUp(KEY_SPACE) end
        self.opening:Update(dt,input.focus and not input.minimized)
        self.graphicsSettings:Update(dt);return
    end
    self.graphicsSettings:Update(dt)
    if self.debugPanel and self.debugPanel.open then return end
    if self.tutorial and self.tutorial:Keys() then return end
    if self.loadingFlow and self.loadingFlow.active then
        -- Keep downloads, saves and renderer retirement alive under the overlay.
        -- The old scene is fully covered; candidate rendering warms only after commit.
        if self.loadingFlow.pageVisible and not self.loadingFlow.finished and not self.loadingFlow.keepSceneVisible then self.graphicsSettings:SetSceneVisible(false) end
        return
    end
    if self.pendingSalvageResult then
        SalvageResultReturn.Update(self,Hud.GetState(),dt,DeferredModules['ui.SalvageRunHud'].Result)
    end
    if self.mode~='trial' and self.scene and self.hangar then
        if self.lobby=='salvage' then
            self.warehouse=self.warehouse or Warehouse.New(self);self.warehouse:Update()
        elseif self.warehouse then self.warehouse:Dispose();self.warehouse=nil end
    end
    if self.reloadQueued and self.loader.state~="loading" then
        self.reloadQueued=false
        self:Reload()
    end
    if self.development then self.hotReload:Update(dt) end
    if input:GetKeyPress(KEY_F5) then self:Reload() end
    if not self.scene then return end
    if self.endlessAgain and self.mode=='hangar' then self.endlessAgain=false;self:SelectEndless();return end
    if self.restartBattle and self.mode=='hangar' then
        if self:EnterBattle(self.restartBattle) then self.restartBattle=nil end
        return
    end
    if self.endlessSelect then return end
    if self.mode=='hangar' and self.restartStory then local id=self.restartStory;self.restartStory=false;self:EnterTrial(type(id)=='string' and id or 'story1');return end
    if self.trial then self.trial:Update(dt);return end
    if self.mapPreview then self.mapPreview:Update(dt);return end
    if self.vehicleSwitch then self.vehicleSwitch:Update(dt) end
    if self.vehicleSwitch and self.vehicleSwitch:IsAssembling() then
        self.hangar:Update(self.camera.node,self.camera.camera,dt);return
    end
    local focus=UI.GetFocus();local typing=focus and focus.OnTextInput~=nil
    local homeBlocked=Hud.IsBlocked()
    local homePage=Hud.GetState();local storyOpen=homePage and homePage.tab=='story';local liveryOpen=homePage and homePage.tab=='livery'
    if self.startTrial or not storyOpen and not liveryOpen and not typing and not homeBlocked and not (self.build and (self.build.dialog or self.build.inventoryPanel)) and input:GetKeyPress(KEY_T) then
        self.startTrial=false;self:EnterTrial(self.startMap);self.startMap=nil
    end
    if not storyOpen and not liveryOpen and not self.build and not homeBlocked and not typing and input:GetKeyPress(KEY_E) then self:EnterBuild() end
    if self.build then
        self.build:Update(dt)
        self.hangar:Update(self.camera.node,self.camera.camera,dt)
        self.car:UpdateIdle(math.min(dt,.1),self.hangar.time)
        self.car:UpdateWeaponEffects(dt,{camera=self.camera.node,time=self.hangar.time,fov=self.camera.camera.fov})
        return
    end
    Hud.Update(dt)
    if self.build then return end
    local page=Hud.GetState()
    local opaque=page and (page.tab=='story' or page.tab=='salvage' and page.salvage and page.salvage.tab=='ops'
        or page.tab=='workshop' and page.page and page.page.view=='feature')
    self.graphicsSettings:SetSceneVisible(not opaque)
    if opaque then return end
    if page and page.tab=='livery' and page.livery then
        page.livery.controls:Update(dt,homeBlocked or Hud.IsBlocked() or typing)
        self.hangar:Update(self.camera.node,self.camera.camera,dt)
        self.car:UpdateIdle(math.min(dt,.1),self.hangar.time)
        self.car:UpdateWeaponEffects(dt,{camera=self.camera.node,time=self.hangar.time,fov=self.camera.camera.fov})
        return
    end
    if homeBlocked or Hud.IsBlocked() or typing then
        self.hangar:Update(self.camera.node,self.camera.camera,dt)
        self.car:UpdateIdle(math.min(dt,.1),self.hangar.time)
        return
    end
    for key,view in pairs({[KEY_F1]="car",[KEY_F2]="hall",[KEY_F3]="door",[KEY_F4]="rear"}) do
        if input:GetKeyPress(key) then self:View(VIEWS[view]) end
    end
    if input:GetKeyPress(KEY_B) then self.hangar:SetGrid(not self.hangar.gridOn) end
    if input:GetKeyPress(KEY_R) then self.hangar:Welcome(self.blueprint) end
    if input:GetKeyPress(KEY_G) and page and page.tab=='hangar' then page.SetLobby('salvage');return end
    if self.gallery then
        if input:GetKeyPress(KEY_PAGEUP) then self.gallery:Page(self.gallery.page-1);Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭") end
        if input:GetKeyPress(KEY_PAGEDOWN) then self.gallery:Page(self.gallery.page+1);Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭") end
        self.gallery:Update()
    end
    for i,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5}) do
        if self.lobby~='salvage' and input:GetKeyPress(key) then self.tier=i;self.hangar:SetTier(i);Hud.Refresh(self.blueprint,Config.TIERS[i]) end
    end
    self.camera:Update(dt,UI.IsPointerOverUI(),true)
    if not (self.warehouse and self.warehouse.ready) then self.camera.node.position=Hangar.ClampCamera(self.camera.node.position) end
    self.hangar:Update(self.camera.node,self.camera.camera,dt)
    local home=Hud.GetState()
    local display=home and home.workshopPreview and home.workshopPreview.view or self.gallery and self.gallery.view or self.car
    if display then
        display:UpdateIdle(math.min(dt,.1),self.hangar.time)
        display:UpdateWeaponEffects(dt,{camera=self.camera.node,time=self.hangar.time,fov=self.camera.camera.fov})
    end
end
function App:PostUpdate(dt)
    if self.opening and self.opening.active and not self.stopped then self.opening:Camera() end
    -- CombatWarmup owns camera-facing geometry until its next rendered frame.
    local flow=self.loadingFlow
    if self.trial and not self.stopped and not (flow and flow.active and (not flow.finished or flow.combatWarmup)) then self.trial:PostUpdate(dt) end
    if not self.stopped then self.graphicsSettings:PostUpdate() end
end
function App:CancelMapLoad(fromFlow)
    if not self.pendingMap then
        -- Installation transfers loader ownership before render warmup finishes.
        if fromFlow and self.loadingFlow and self.loadingFlow.failed then
            if self.mapPreview then self.mapPreview:Return();return true end
            if self.trial then self:Reload();return true end
        end
        return false
    end
    if not fromFlow and self.loadingFlow and self.loadingFlow.active then self.loadingFlow:Back();return true end
    self.loader:Cancel()
    self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
    self.toasts:Push('已取消加载');return true
end
function App:Stop()
    if self.stopped then return end
    self.stopped=true
    IntroAudioTail.CancelAll()
    UiSound.Dispose()
    self.mapTransition:Stop()
    if self.opening then self.opening:Dispose();self.opening=nil end
    self:AdvanceOpeningRetirements(true)
    if self.endlessSelect then self.endlessSelect.Close();self.endlessSelect=nil end
    self.vehicleGate:Cancel()
    if self.lobbyLoading then self.lobbyLoading:Dispose();self.lobbyLoading=nil end
    if self.loadingFlow then self.loadingFlow:Dispose();self.loadingFlow=nil end
    if self.tutorial then self.tutorial:Dispose();self.tutorial=nil end
    if self.warehouse then self.warehouse:Dispose();self.warehouse=nil end
    self.pendingAssetRelease=nil
    self.assetReleaseIncremental=nil;self.assetReleaseEpoch=nil
    CollectionCycle.Restore()
    print("[HangarApp] Stop ownsScene="..tostring(self.ownsScene))
    self.loader:Cancel()
    if self.vehicleSwitch then self.vehicleSwitch:Dispose();self.vehicleSwitch=nil end
    if self.trial then self.trial:Dispose();self.trial=nil end
    self.toasts:Dispose()
    Hud.Dispose()
    self.music:Dispose()
    self.ambience:Dispose()
    if self.build then self.build:Dispose();self.build=nil end
    self.previews:Dispose()
    self.store:Flush()
    self.graphicsSettings:Dispose()
    if self.mapPreview then self.mapPreview:Dispose();self.mapPreview=nil end
    if self.gallery then self.gallery:Dispose();self.gallery=nil end
    if self.car then self.car:Dispose();self.car=nil end
    if self.hangar then self.hangar:Dispose() end
    if self.ownsScene then WindowViewports.Stop() end
    if self.scene and self.ownsScene then self.scene:Dispose() end
    local previous=self.previousState
    cache.autoReloadResources=previous.autoReload
    renderer.hdrRendering=previous.hdr;renderer.shadowMapSize=previous.shadowSize
    renderer.drawShadows=previous.shadows
    renderer.textureFilterMode=previous.textureFilterMode;renderer.textureAnisotropy=previous.textureAnisotropy
    input.mouseMode=previous.mouseMode
    if self.ownsScene then engine.maxFps=previous.maxFps;engine.maxInactiveFps=previous.inactiveFps end
    self.scene=nil
    _G.VOX_HANGAR=nil
    _G.VOX_TRIAL=nil
    StoryComms.Shutdown()
    UI.Shutdown()
    RenderTargetLifetime.Flush()
end
return App
