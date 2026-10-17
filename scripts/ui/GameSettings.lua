-- One settings entry for live modes and the editor, using the source pause card.
local SourceButton=require("ui.SourceButton")
local EndlessWidgets=require("ui.EndlessWidgets")
local DriveChrome=require("ui.DriveChrome")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local M={}
function M.Open(owner)
    if owner.app.debugPanel and owner.app.debugPanel.open then owner.app.debugPanel:SetOpen(false) end
    if owner.dialog and owner.dialog.unifiedSettings then return owner.dialog end
    if owner.Pause then owner:Pause() end
    return DeferredModules['ui.PauseMenu'].Open(owner,{inGame=owner.combat~=nil,unified=true})
end
function M.Attach(session,root,top)
    local Button=SourceButton
    local props={position='absolute',text='设置',icon='gear',top=12,width=62,height=36,
        onClick=function() M.Open(session) end}
    local button=nil ---@type Widget|nil
    if session.battle then
        props.right=134;props.sourceKind='flat';props.height=34;button=Button(props)
    elseif session.endless then
        props.right=156;props.height=44;button=EndlessWidgets.Button(props)
    else
        props.right=12;props.top=top+103;props.kind='exit';props.course=true
        button=DriveChrome(props);button.session=session
    end
    root:AddChild(button);return button
end
return M
