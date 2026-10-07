-- Application lifecycle follows scaffold-3d-scene; scene content is authored data.
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
    self.view=""
    self.mode="hangar"
    self.trial=nil ---@type table|nil
    self.startTrial=false
    self.partsPage=0
    self.buildWanted=false
    self.build=nil ---@type table|nil
    self.isValidation=false
    self.loader=Loader.New()
    self.motionModule=nil ---@type table|nil
    self.hotReload=HotReload.New(function() self:Reload() end,function(module)
        self.motionModule=module
        if self.hangar then self.hangar.motion=module end
    end)
    for _,arg in ipairs(GetArguments()) do
        if arg=='-validate' or arg:match('^%-screenshot=') then self.isValidation=true end
        if arg=='-build' then self.buildWanted=true end
        if arg=="-dev" then self.development=true end
        if arg=="-trial" then self.startTrial=true end
        if arg=='-crater' then self.startTrial=true;self.startMap='crater';self.selectedMap='crater' end
        local blueprint=arg:match("^%-blueprint=(Blueprints/[%w_%-]+%.json)$")
        if blueprint then self.blueprint=Blueprint.New():Load(require("core.ResourceData").Read(blueprint));self.explicitBlueprint=true end
        local view=arg:match("^%-hangar%-view=(.+)$")
        if view and VIEWS[view] then self.view=view;_G.VOX_DEBUG={hideUI=true,time=10} end
        self.partsPage=tonumber(arg:match("^%-parts%-page=(%d+)$")) or self.partsPage
    end
    self.store=require('storage.BlueprintStore').New(self.isValidation and 'vox-validation' or nil)
    self.graphicsSettings=require('render.GraphicsSettings').New(self)
    self.previews=require('render.HangarPreview').New(self)
    self.store.captureContext=function()
        return {tier=self.tier,aspect=graphics:GetWidth()/math.max(1,graphics:GetHeight()),
            grid=self.hangar and self.hangar.gridOn or false,time=self.hangar and self.hangar.time or 10,
            graphics=self.graphicsSettings.data}
    end
    if not self.isValidation and not self.explicitBlueprint then
        local draft=self.store:Read('draft')
        if draft then
            local ok,bp=pcall(function() return Blueprint.New():Load(require('storage.BlueprintCode').Validate(draft)) end)
            if ok then self.blueprint=bp else print('[HangarApp] Invalid draft; keeping starter vehicle') end
        end
    end
    self.editor=require('construction.BuildEditor').New(self.blueprint,function(ops)
        if self.car then self.car:ApplyEdits(ops,self.blueprint) end
        if self.bays then self.bays:Changed() else self.store:Queue(self.blueprint) end
    end)
    self.bays=require('construction.Garage').New(self.blueprint,self.store,function(data) return self:LoadBlueprint(data) end,not self.isValidation and not self.explicitBlueprint)
end
function App:EnterBuild()
    if not self.ownsScene or self.mode=='trial' or self.loader.state=='loading' then return false end
    if self.build then return true end
    if self.vehicleSwitch then self.vehicleSwitch:Finish() end
    if self.build then return true end -- A pending empty preset already entered.
    if self.gallery then self:ToggleGallery() end
    Hud.Dispose()
    self.buildWanted=true
    local minY=math.huge
    for _,p in ipairs(self.blueprint:List()) do for _,c in ipairs(p._cells) do minY=math.min(minY,c[2]) end end
    if minY<4 then self.editor:Lift(4-minY) end
    self:View(VIEWS.car);self.camera.target=Vector3(0,3,0);self.camera.cur.target=self.camera.target;self.camera:Apply()
    self.hangar:SetGrid(true)
    self.build=require('app.BuildSession').New(self)
    return true
end
function App:ExitBuild()
    if self.build then self.build:Dispose();self.build=nil end
    self.buildCameraState=nil
    self.buildXray=false
    self.buildWanted=false
    if self.bays.active and self.bays.unsaved then local ok,err=self.bays:Save();if not ok then self.homeMessage=err end end
    self.homeTab='hangar'
    Hud.Create(self)
    Hud.Refresh(self.blueprint,Config.TIERS[self.tier]);self:GroundDisplay();self:HomeView('hangar')
end
function App:DisplayHeight()
    local minY=math.huge
    for _,p in ipairs(self.blueprint:List()) do
        for _,c in ipairs(p._cells) do minY=math.min(minY,c[2]) end
        local vis=self.car.visuals[p.id];local segments=vis and vis.data.segments
        if type(segments)=='table' and segments.leg then
            local toe=require('core.Rotations').ApplyRot(p.rot,segments.info.origins.toe)
            minY=math.min(minY,p.pos[2]+.5+toe[2])
        end
    end
    return minY<math.huge and -minY*Config.CELL or 0
end
function App:GroundDisplay()
    self.car.root.position=Vector3(0,self:DisplayHeight(),0)
end
function App:LoadBlueprint(data)
    -- Parse into a candidate first; a malformed save cannot clear the active car.
    local ok,candidate=pcall(function() return Blueprint.New():Load(require('storage.BlueprintCode').Validate(data)) end)
    if not ok then return false,'无效的蓝图' end
    if self.build then self.build:Dispose();self.build=nil end
    self.blueprint:Load(candidate:ToTable());self.editor.history.undoStack={};self.editor.history.redoStack={}
    self.blueprint.dropped=candidate.dropped;self.blueprint.migrationWarnings=candidate.migrationWarnings
    self.editor.selection={};self.editor.preview=nil;self.editor.pasting=false
    self.car:Rebuild(self.blueprint);self.store:Queue(self.blueprint)
    if self.bays then self.bays:Changed() end
    if self.buildWanted then self.build=require('app.BuildSession').New(self) end
    if not self.buildWanted then
        self:GroundDisplay()
        local pose=require('controls.HomeStations').Get(self.blueprint:Stats(),'hangar',self.camera.maxDist)
        self.camera:Focus(Vector3(table.unpack(pose.target)),pose.dist)
    end
    if self.vehicleSwitch then self.vehicleSwitch:Replaced() end
    return true
end
function App:Start(existingScene)
    self.previousState={autoReload=cache.autoReloadResources,hdr=renderer.hdrRendering,
        shadowSize=renderer.shadowMapSize,shadows=renderer.drawShadows,mouseMode=input.mouseMode,
        maxFps=engine.maxFps,inactiveFps=engine.maxInactiveFps}
    if not existingScene then graphics.windowTitle="方块战车 · 轨道改装机库" end
    input.mouseMode=MM_ABSOLUTE
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme="default-dark",scale=require('controls.TouchMode').Scale('home'),
        fonts={{family="sans",weights={normal=fonts.body,bold=fonts.bold}}}})
    self.toasts=require('ui.SourceToasts').New()
    self.toasts:Attach()
    if not existingScene then cache.autoReloadResources=self.development end
    renderer.hdrRendering=true
    renderer.shadowMapSize=Quality.current.shadowMapSize
    if not existingScene then engine.maxFps=Quality.current.maxFps;engine.maxInactiveFps=10 end
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
    if self.vehicleSwitch then self.vehicleSwitch:Finish() end
    print("[HangarApp] Loading authored scene "..SCENE)
    self.loader:Load(SCENE,function(scene) self:Install(scene) end,function(message)
        print("[HangarApp] Load failed; keeping previous scene: "..message)
        if self.scene then Hud.SetMode("场景更新失败，保留当前画面 · F5 重试")
        else self.loadingLabel:SetText("机库加载失败 · 按 F5 重试") end
    end)
end
function App:EnterTrial(mapId)
    if not self.ownsScene then
        Hud.SetMode("试车请用项目独立运行入口；当前为编辑器机库预览")
        return false
    end
    if self.mode=="trial" or self.loader.state=="loading" then return false end
    if self.vehicleSwitch then self.vehicleSwitch:Finish() end
    if self.build then self.build.buildCamera:Release() end
    local map=assert(require('app.DriveMaps')[mapId or 'trial'],'Unknown drive map')
    local loadingToast=self.toasts:Push('正在加载'..map.name..'…','info',90000)
    self.pendingMap=map;self.mapLoadingToast=loadingToast
    local preparedWorld=nil ---@type table|nil
    local function ClearLoading()
        if loadingToast then loadingToast.age=loadingToast.hold+.4 end
        self.pendingMap=nil;self.mapLoadingToast=nil
    end
    local options={resources=map.resources and require('core.ResourceData').Read(map.resources) or {map.scene},cancel=ClearLoading,
        cleanup=function() if preparedWorld then preparedWorld:Dispose();preparedWorld=nil end end}
    if map.prepareWorld then options.prepare=function(scene,checkpoint)
        preparedWorld=require(map.world).New(scene,true)
        require(map.prepareWorld).Build(preparedWorld,checkpoint)
    end end
    self.loader:Load(map.scene,function(scene)
        local Trial=require "app.TrialSession"
        -- Ownership transfers even if initialization throws: Trial disposes its world.
        local world=preparedWorld;preparedWorld=nil
        local candidate=Trial.New(scene,self.blueprint,self,map,world)
        self.graphicsSettings:Apply(scene)
        local activated,activationError=pcall(candidate.Activate,candidate,function() self:Reload() end)
        if not activated then candidate:Dispose();error(activationError) end
        local previous=self.scene
        Hud.Dispose()
        if self.build then self.build:Dispose();self.build=nil end
        self.previews:Dispose()
        if self.gallery then self.gallery:Dispose();self.gallery=nil end
        if self.vehicleSwitch then self.vehicleSwitch:Dispose();self.vehicleSwitch=nil end
        if self.car then self.car:Dispose();self.car=nil end
        if self.hangar then self.hangar:Dispose();self.hangar=nil end
        self.camera=nil;self.galleryOn=false;self.scene=scene;self.trial=candidate;self.mode="trial"
        _G.VOX_HANGAR=nil;_G.VOX_TRIAL={session=candidate,app=self}
        if previous then previous:Dispose() end
        self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
        ClearLoading()
        print("[HangarApp] Trial ready; hangar scene released, unused resource cleanup queued")
    end,function(message)
        ClearLoading()
        self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
        Hud.SetMode(map.name..'加载失败，保留机库');print('[HangarApp] '..message)
    end,options)
    return true
end
function App:Install(scene)
    -- Construct and validate the candidate before releasing the active scene.
    local h=Hangar.Bind(scene)
    if self.motionModule then h.motion=self.motionModule end
    local authoredCamera=scene:GetChild("Camera")
    local camera=OrbitCamera.New(scene,authoredCamera)
    camera.roomLimit=require('scene.HangarConfig').layout.cameraLimit
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
    h:SetInfoSource(function()
        local diag=self.build and self.build.inspection:Get() or nil
        return self.blueprint,Config.TIERS[self.tier],self.bays.active,self.bays.revision,diag
    end)
    h:Welcome(self.blueprint)
    h:SetGrid(self.hangar and self.hangar.gridOn or false)
    local oldScene,oldHangar,oldCar=self.scene,self.hangar,self.car
    local oldSwitch=self.vehicleSwitch
    local oldTrial=self.trial
    if self.build then self.build:Dispose();self.build=nil end
    if self.gallery then self.gallery:Dispose() end
    self.scene,self.hangar,self.camera,self.car=scene,h,camera,car
    self.vehicleSwitch=require('app.HomeVehicleSwitch').New(self,car.root)
    if self.ownsScene then renderer:SetViewport(0,Viewport:new(scene,camera.camera)) end
    self.graphicsSettings:Apply(scene)
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
    if oldTrial then oldTrial:Dispose() end
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
        if not oldScene then
            local minY=math.huge
            for _,p in ipairs(self.blueprint:List()) do for _,c in ipairs(p._cells) do minY=math.min(minY,c[2]) end end
            if minY<4 then self.editor:Lift(4-minY) end
            self:View(VIEWS.car);self.camera.target=Vector3(0,3,0);self.camera.cur.target=self.camera.target;self.camera:Apply()
        end
        self.build=require('app.BuildSession').New(self)
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
    local pose=require('controls.HomeStations').Get(self.blueprint:Stats(),tab,self.camera.maxDist)
    if pose then self.camera:FlyTo(pose,.65) end
end
function App:ToggleGallery(page)
    print("[HangarApp] Catalog "..(self.gallery and "close" or ("open page="..(page or 1))))
    if self.gallery then
        self.gallery:Dispose();self.gallery=nil;self.galleryOn=false;self:View(VIEWS.car)
        self.car:SetVisible(true)
        Hud.SetMode("")
    else
        self.gallery=require("render.PartsGallery").New(self.scene,page or 1)
        self.galleryOn=true
        self.car:SetVisible(false)
        self:View({target={0,1,-10.5},dist=24,yaw=180,pitch=48,fov=48})
        Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭")
    end
end
function App:DeferAssetRelease(release)
    self.pendingAssetRelease=release;self.assetReleaseFrames=3
end
function App:Update(dt)
    if self.stopped then return end
    require('render.RenderTargetLifetime').Update()
    if self.pendingAssetRelease and self.loader.state~='loading' and cache:GetNumBackgroundLoadResources()==0 then
        self.assetReleaseFrames=self.assetReleaseFrames-1
        if self.assetReleaseFrames<=0 then
            local release=self.pendingAssetRelease;self.pendingAssetRelease=nil
            collectgarbage('collect');require('render.RenderTargetLifetime').Flush()
            -- This Runtime's environment baker keeps source HDRs alive even
            -- after their Scene/Zone is gone. Active Zones retain their applied
            -- SH/IBL; clear only the reusable bake cache at this settled scene
            -- boundary, then let the ordinary non-forced cache sweep release
            -- the old map. The next visit may bake again in the background.
            environmentBakeCache:ClearCache()
            release()
        end
    end
    if self.pendingMap and input.focus and input:GetKeyPress(KEY_ESCAPE) then
        self:CancelMapLoad();return
    end
    self.loader:Update(dt)
    if self.pendingMap and self.mapLoadingToast then
        local phase=({download='准备资源',scene='载入场景',prepare='准备碰撞',environment='准备光照'})[self.loader.phase] or '加载'
        local text=self.pendingMap.name..' · '..phase..' '..math.floor(self.loader.progress*100)..'% · Esc 取消'
        local toast=self.mapLoadingToast
        if toast.text~=text then toast.text=text;toast.layoutWidth=nil end
    end
    self.store:Update(dt)
    self.previews:Update(dt)
    self.graphicsSettings:Update(dt)
    if self.reloadQueued and self.loader.state~="loading" then
        self.reloadQueued=false
        self:Reload()
    end
    if self.development then self.hotReload:Update(dt) end
    if input:GetKeyPress(KEY_F5) then self:Reload() end
    if not self.scene then return end
    if self.trial then self.trial:Update(dt);return end
    if self.vehicleSwitch then self.vehicleSwitch:Update(dt) end
    local focus=UI.GetFocus();local typing=focus and focus.OnTextInput~=nil
    local homeBlocked=Hud.IsBlocked()
    if self.startTrial or not typing and not homeBlocked and not (self.build and (self.build.dialog or self.build.inventoryPanel)) and input:GetKeyPress(KEY_T) then
        self.startTrial=false;self:EnterTrial(self.startMap);self.startMap=nil
    end
    if not self.build and not homeBlocked and not typing and input:GetKeyPress(KEY_E) then self:EnterBuild() end
    if self.build then
        self.build:Update(dt)
        self.hangar:Update(self.camera.node,self.camera.camera,dt)
        self.car:UpdateIdle(math.min(dt,.1),self.hangar.time)
        self.car:UpdateWeaponEffects(dt,{camera=self.camera.node,time=self.hangar.time,fov=self.camera.camera.fov})
        return
    end
    Hud.Update(dt)
    if self.build then return end
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
    if input:GetKeyPress(KEY_G) then self:ToggleGallery() end
    if self.gallery then
        if input:GetKeyPress(KEY_PAGEUP) then self.gallery:Page(self.gallery.page-1);Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭") end
        if input:GetKeyPress(KEY_PAGEDOWN) then self.gallery:Page(self.gallery.page+1);Hud.SetMode("零件目录 "..self.gallery.page.."/"..self.gallery.pages.." · PageUp / PageDown 翻页 · G 关闭") end
        self.gallery:Update()
    end
    for i,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5}) do
        if input:GetKeyPress(key) then self.tier=i;self.hangar:SetTier(i);Hud.Refresh(self.blueprint,Config.TIERS[i]) end
    end
    self.camera:Update(dt,UI.IsPointerOverUI(),true)
    self.camera.node.position=Hangar.ClampCamera(self.camera.node.position)
    self.hangar:Update(self.camera.node,self.camera.camera,dt)
    local display=self.gallery and self.gallery.view or self.car
    if display then
        display:UpdateIdle(math.min(dt,.1),self.hangar.time)
        display:UpdateWeaponEffects(dt,{camera=self.camera.node,time=self.hangar.time,fov=self.camera.camera.fov})
    end
end
function App:PostUpdate(dt)
    if self.trial and not self.stopped then self.trial:PostUpdate(dt) end
    if not self.stopped then self.graphicsSettings:PostUpdate() end
end
function App:CancelMapLoad()
    if not self.pendingMap then return false end
    self.loader:Cancel()
    self:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
    self.toasts:Push('已取消加载');return true
end
function App:Stop()
    if self.stopped then return end
    self.stopped=true
    self.pendingAssetRelease=nil
    print("[HangarApp] Stop ownsScene="..tostring(self.ownsScene))
    self.loader:Cancel()
    if self.vehicleSwitch then self.vehicleSwitch:Dispose();self.vehicleSwitch=nil end
    self.toasts:Dispose()
    Hud.Dispose()
    if self.build then self.build:Dispose();self.build=nil end
    self.previews:Dispose()
    self.store:Flush()
    self.graphicsSettings:Dispose()
    if self.trial then self.trial:Dispose();self.trial=nil end
    if self.gallery then self.gallery:Dispose();self.gallery=nil end
    if self.car then self.car:Dispose();self.car=nil end
    if self.hangar then self.hangar:Dispose() end
    if self.ownsScene then renderer:SetViewport(0,nil) end
    if self.scene and self.ownsScene then self.scene:Dispose() end
    local previous=self.previousState
    cache.autoReloadResources=previous.autoReload
    renderer.hdrRendering=previous.hdr;renderer.shadowMapSize=previous.shadowSize
    renderer.drawShadows=previous.shadows
    input.mouseMode=previous.mouseMode
    if self.ownsScene then engine.maxFps=previous.maxFps;engine.maxInactiveFps=previous.inactiveFps end
    self.scene=nil
    _G.VOX_HANGAR=nil
    _G.VOX_TRIAL=nil
    UI.Shutdown()
    require('render.RenderTargetLifetime').Flush()
end
return App
