-- Single runtime entry. Scene authoring lives in assets/Scenes/OrbitalHangar.xml.
-- Some Web bootstraps precede the translated UI library's engine initialization.
if not rawget(_G,'_tr') then require('urhox-libs/Engine/i18n') end
local App=require "app.HangarApp"
local Storage=require 'storage.CloudStorage'
local MapShot=require 'render.MatchMapShot'
---@type HangarApp|nil
local app=nil
local running=false
local RectLightLookup=require("render.RectLightLookup")
local DebugPanel=require("ui.DebugPanel")
local PerformanceMonitor=require 'diagnostics.PerformanceMonitor'
local PerformanceBindings=require 'diagnostics.PerformanceBindings'
local PerformancePanel=require 'ui.PerformancePanel'
local PlatformUtils=require 'urhox-libs.Platform.PlatformUtils'
local performance=nil ---@type table|nil
local performancePanel=nil ---@type table|nil
local showPerformance=true

function Start()
    running=true
    local enabled=true
    for _,arg in ipairs(GetArguments()) do if arg=='-vox-perf=0' then enabled=false end end
    performance=PerformanceMonitor.New({enabled=enabled,noFile=PlatformUtils.IsWebPlatform()})
    if enabled then SubscribeToEvent('LogMessage','HandlePerformanceLog') end
    SubscribeToEvent('EndFrame','HandleFramePresented')
    MapShot.Initialize()
    SubscribeToEvent("Update","HandleUpdate")
    Storage.Boot(function()
        if not running then return end
        RectLightLookup.Ensure(function(ok,message)
            if not running then return end
            local bootScope=performance and performance:Begin('bootstrap.app')
            if not ok then print('[RectLightLookup] '..tostring(message)) end
            _G.VOX_APP_BOOTSTRAP=true
            app=App.New()
            app:Start()
            if performance.enabled then performancePanel=PerformancePanel.New(app) end
            if app.debugEnabled then app.debugPanel=DebugPanel.New(app) end
            SubscribeToEvent("PostUpdate","HandlePostUpdate")
            SubscribeToEvent("EndAllViewsRender","HandleViewsRendered")
            SubscribeToEvent("FileChanged","HandleFileChanged")
            if performance then performance:End(bootScope) end
        end)
    end)
end
function Stop()
    running=false
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("PostUpdate")
    UnsubscribeFromEvent("EndAllViewsRender")
    UnsubscribeFromEvent("EndFrame")
    UnsubscribeFromEvent("FileChanged")
    UnsubscribeFromEvent('LogMessage')
    if performancePanel then performancePanel:Dispose();performancePanel=nil end
    if performance then performance:Dispose();performance=nil end
    if app then
        if app.debugPanel then app.debugPanel:Dispose();app.debugPanel=nil end
        app:Stop();app=nil
    end
    MapShot.Shutdown()
    Storage.Stop()
    _G.VOX_APP_BOOTSTRAP=nil
end
function HandleViewsRendered()
    if app and app.loadingFlow and renderer:GetViewport(0) then app.loadingFlow:Rendered() end
end
function HandleFramePresented()
    if app and app.trial and app.trial.story then app.trial.story:FramePresented() end
    if app and app.loadingFlow then
        app.loadingFlow:FramePresented()
        app.loader:FramePresented()
        if app.opening and app.opening.active and app.opening.host.FramePresented then app.opening.host.FramePresented(app.opening) end
    end
    if performance and performance.enabled then performance:EndFrame(PerformanceBindings.Context(app)) end
end
function HandlePostUpdate(eventType,eventData)
    local scope=performance and performance:Begin('main.PostUpdate')
    if app then app:PostUpdate(eventData:GetFloat("TimeStep")) end
    if performance then performance:End(scope) end
end
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType,eventData)
    local dt=eventData:GetFloat("TimeStep")
    if performance and performance.enabled then
        performance:BeginFrame(dt)
        local started=performance.clock()
        PerformanceBindings.Attach(performance,app)
        performance.monitorMs=performance.monitorMs+(performance.clock()-started)%4294967296
        if input:GetKeyPress(KEY_F6) then showPerformance=not showPerformance end
        if input:GetKeyPress(KEY_F10) then performance:Marker('user-mark',PerformanceBindings.Context(app)) end
        if performancePanel then
            performancePanel:SetVisible(showPerformance)
            if showPerformance then performancePanel:Update(performance:Snapshot(),dt) end
        end
    end
    local scope=performance and performance:Begin('main.Update')
    Storage.Update(dt,app)
    if app then
        if app.debugPanel then app.debugPanel:Update(dt) end
        app:Update(dt)
    end
    if performance then performance:End(scope) end
end
function HandlePerformanceLog(eventType,eventData)
    if not performance or not performance.enabled then return end
    local level=eventData:GetInt('Level')
    if level>=LOG_ERROR then
        performance.errors=performance.errors or {}
        if #performance.errors<16 then performance.errors[#performance.errors+1]=eventData:GetString('Message'):sub(1,1500) end
    end
end
---@param eventType string
---@param eventData FileChangedEventData
function HandleFileChanged(eventType,eventData)
    if app and app.development then app.hotReload:Changed(eventData:GetString("ResourceName")) end
end
