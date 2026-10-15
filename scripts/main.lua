-- Single runtime entry. Scene authoring lives in assets/Scenes/OrbitalHangar.xml.
-- Some Web bootstraps precede the translated UI library's engine initialization.
if not rawget(_G,'_tr') then require('urhox-libs/Engine/i18n') end
local App=require "app.HangarApp"
local Storage=require 'storage.CloudStorage'
local MapShot=require 'render.MatchMapShot'
---@type HangarApp|nil
local app=nil
local running=false
function Start()
    running=true
    MapShot.Initialize()
    SubscribeToEvent("Update","HandleUpdate")
    Storage.Boot(function()
        if not running then return end
        require('render.RectLightLookup').Ensure(function(ok,message)
            if not running then return end
            if not ok then print('[RectLightLookup] '..tostring(message)) end
            _G.VOX_APP_BOOTSTRAP=true
            app=App.New()
            app:Start()
            SubscribeToEvent("PostUpdate","HandlePostUpdate")
            SubscribeToEvent("EndAllViewsRender","HandleViewsRendered")
            SubscribeToEvent("EndFrame","HandleFramePresented")
            SubscribeToEvent("FileChanged","HandleFileChanged")
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
    if app then app:Stop();app=nil end
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
end
function HandlePostUpdate(eventType,eventData)
    if app then app:PostUpdate(eventData:GetFloat("TimeStep")) end
end
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType,eventData)
    local dt=eventData:GetFloat("TimeStep")
    Storage.Update(dt,app)
    if app then app:Update(dt) end
end
---@param eventType string
---@param eventData FileChangedEventData
function HandleFileChanged(eventType,eventData)
    if app and app.development then app.hotReload:Changed(eventData:GetString("ResourceName")) end
end
