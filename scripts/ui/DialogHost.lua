-- Shared ownership for home/build overlays. A replaced build session must never
-- receive callbacks into its destroyed widgets.
local M={}
function M.Current(owner) return owner.editor and owner.app.build or owner end
function M.Notify(owner,text,kind)
    local current=M.Current(owner);if not current then return end
    if current.editor then current:Notify(text,kind);current.slot=current.app.bays.active or current.slot;current:Refresh()
    elseif current.message and current.message.Push then current.message:Push(text,kind)
    elseif current.app and current.app.toasts then current.app.toasts:Push(text,kind) end
end
function M.Close(owner) if owner.dialog then owner.dialog:Close() end end
function M.Update(owner,dt)
    if owner.closingDialog then owner.closingDialog:AdvanceClose(dt) end
end
function M.Dispose(owner)
    if owner.dialog then owner.dialog:Close(true) end
    if owner.closingDialog then owner.closingDialog:Destroy() end
end
function M.Open(owner,title,onClose,source,onDispose)
    local previous=owner.dialog
    local overlayTime=previous and previous.isOpen_ and
        not previous.props.source.help and not (source and source.help) and previous.sourceOverlayTime
    -- #help is a separate overlay: the old #modal may finish fading behind it.
    -- Replacing #modal's card clears its old DOM/resources immediately.
    if owner.closingDialog and not (source and source.help) then owner.closingDialog:Destroy() end
    if previous then previous:Close(not (source and source.help)) end
    if owner.buildCamera then owner.buildCamera:Release() end
    if owner.inventoryPanel then owner.inventoryPanel:Close() end
    if owner.controls then
        if owner.controls.Cancel then owner.controls:Cancel() else owner.controls:Clear() end
        if owner.hud and owner.hud.Clear then owner.hud.Clear() end
        if owner.editor then owner.editor.preview=nil;owner.ghost:Refresh(owner.editor,false) end
    end
    source=source or {width=780}
    local Modal=require 'ui.SourceModal'
    local modal=Modal{title=title,source=source,contentGap=source.gap or 0,size='lg',closeOnEscape=false,onClose=function(self)
            if owner.dialog==self then owner.dialog=nil;owner.dialogTick=nil end
            if not self.props.source.help then
                if owner.closingDialog and owner.closingDialog~=self then owner.closingDialog:Destroy() end
                owner.closingDialog=self
            end
            if onClose then onClose() end
        end,onDispose=function(self)
            if owner.closingDialog==self then owner.closingDialog=nil end
            if onDispose then onDispose() end
        end}
    -- Original openModal replaces only .card while #modal.show stays mounted.
    -- Help has its own source overlay and therefore starts a fresh fade.
    modal.sourceOverlayTime=overlayTime or 0
    owner.dialog=modal;modal:Open();return modal
end
function M.Confirm(owner,title,text,yes,no)
    local UI=require 'urhox-libs/UI';local Button=require 'ui.SourceButton';local m=M.Open(owner,title,nil,{width=780})
    m:AddContent(require('ui.SourceHint'){text=text,width='100%',height=29.25,marginTop=12.5,marginBottom=12.5,flexShrink=0})
    local buttons={cancel=Button{text='取消',sourceKind='dialog',width=72,height=40,onClick=function() M.Close(owner);if no then no() end end},
        confirm=Button{text='确定',sourceKind='primary',width=72,height=40,onClick=function() M.Close(owner);yes() end}}
    m:AddContent(UI.Panel{flexDirection='row',justifyContent='flex-end',gap=8,marginTop=20,children={buttons.confirm,buttons.cancel}})
    m.actions=buttons;return m
end
return M
