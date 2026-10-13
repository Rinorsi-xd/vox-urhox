-- Single runtime entry. Scene authoring lives in assets/Scenes/OrbitalHangar.xml.
-- Some Web bootstraps precede the translated UI library's engine initialization.
if not rawget(_G,'_tr') then require('urhox-libs/Engine/i18n') end
local App=require "app.HangarApp"
---@type HangarApp|nil
local app=nil
function Start()
    require('render.RectLightLookup').Ensure(function(ok,message)
        if not ok then print('[RectLightLookup] '..tostring(message)) end
        _G.VOX_APP_BOOTSTRAP=true
        app=App.New()
        app:Start()
        SubscribeToEvent("Update","HandleUpdate")
        SubscribeToEvent("PostUpdate","HandlePostUpdate")
        SubscribeToEvent("EndAllViewsRender","HandleViewsRendered")
        SubscribeToEvent("FileChanged","HandleFileChanged")
    end)
end
function Stop()
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("PostUpdate")
    UnsubscribeFromEvent("EndAllViewsRender")
    UnsubscribeFromEvent("FileChanged")
    if app then app:Stop();app=nil end
    _G.VOX_APP_BOOTSTRAP=nil
end
function HandleViewsRendered()
    if app and app.loadingFlow and renderer:GetViewport(0) then app.loadingFlow:Rendered() end
end
function HandlePostUpdate(eventType,eventData)
    if app then app:PostUpdate(eventData:GetFloat("TimeStep")) end
end
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType,eventData)
    if app then app:Update(eventData:GetFloat("TimeStep")) end
end
---@param eventType string
---@param eventData FileChangedEventData
function HandleFileChanged(eventType,eventData)
    if app and app.development then app.hotReload:Changed(eventData:GetString("ResourceName")) end
end
