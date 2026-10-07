-- Modal content/footer live outside its regular Widget children. Release these
-- explicitly, including detached virtual-list rows, before destroying the shell.
local Base=require 'urhox-libs/UI/Widgets/Modal'
local Modal=Base:Extend('VoxOwnedModal')
function Modal:Destroy()
    local UI=require 'urhox-libs/UI'
    local focused=UI.GetFocus()
    while focused do
        if focused==self then UI.ClearFocus();break end
        focused=focused.parent
    end
    for _,key in ipairs({'contentContainer_','footerWidget_','headerWidget_'}) do
        local widget=self[key]
        if widget and widget.node then widget:Destroy() end
        self[key]=nil
    end
    self.contentChildren_={}
    Base.Destroy(self)
end
return Modal
