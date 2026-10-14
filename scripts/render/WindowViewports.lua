-- Keep requested viewports separate from screen rendering while minimized.
-- All screen viewport owners must use Set/Get, including disposal while hidden.
local M={}
---@type table<number, Viewport>
local requested={}
local suspended=false
function M.Drawable() return graphics:GetWidth()>0 and graphics:GetHeight()>0 end
function M.Set(index,viewport)
    requested[index]=viewport
    local drawable=M.Drawable()
    if not drawable then suspended=true end
    renderer:SetViewport(index,drawable and viewport or nil)
end
function M.Get(index)
    if suspended then return requested[index] or renderer:GetViewport(index) end
    return renderer:GetViewport(index)
end
function M.Refresh()
    local drawable=M.Drawable()
    for index,viewport in pairs(requested) do
        if index>=renderer.numViewports then requested[index]=nil
        else
            if not drawable or suspended then
                local effective=drawable and viewport or nil
                if renderer:GetViewport(index)~=effective then renderer:SetViewport(index,effective) end
            else
                -- Respect editor/test owners that replace a live viewport directly.
                requested[index]=renderer:GetViewport(index)
            end
        end
    end
    suspended=not drawable
end
function HandleVoxWindowViewports() M.Refresh() end
function M.Start() SubscribeToEvent('ScreenMode','HandleVoxWindowViewports');M.Refresh() end
function M.Stop()
    for index in pairs(requested) do renderer:SetViewport(index,nil) end
    requested={};suspended=false;UnsubscribeFromEvent('ScreenMode')
end
return M
