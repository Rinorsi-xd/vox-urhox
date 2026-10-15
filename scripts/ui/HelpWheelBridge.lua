-- Detached help overlays need the root fallback when no widget is hovered.
local UI=require 'urhox-libs/UI'
local bindings=setmetatable({},{__mode='k'})
local M={}
local function Previous(handler)
    while bindings[handler] and not bindings[handler].active do handler=bindings[handler].previous end
    return handler
end
function M.Attach(owner,modal,scroll)
    local root=UI.GetRoot()
    if not root then return function()end end
    local entry={root=root,owner=owner,modal=modal,scroll=scroll,previous=root.OnWheel,active=true}
    local function Wheel(self,dx,dy)
        if entry.active and UI.GetRoot()==entry.root and UI.GetTopOverlay()==entry.modal
            and entry.owner.dialog==entry.modal and entry.modal.isOpen_ and not entry.modal.sourceDestroyed then
            entry.scroll:OnWheel(dx,dy);return
        end
        local previous=Previous(entry.previous)
        if previous then return previous(self,dx,dy) end
    end
    bindings[Wheel]=entry;root.OnWheel=Wheel
    return function()
        if not entry.active then return end
        entry.active=false
        if entry.root.OnWheel==Wheel then entry.root.OnWheel=Previous(entry.previous) end
        entry.root=nil;entry.owner=nil;entry.modal=nil;entry.scroll=nil
    end
end
return M
