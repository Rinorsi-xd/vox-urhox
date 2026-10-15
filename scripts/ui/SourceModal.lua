-- Source CSS modal ownership and input. SourceModalVisual handles layout and
-- nested opacity groups; steady-state drawing stays in the UI-owned NVG frame.
local Base=require 'ui.OwnedModal'
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Modal=Base:Extend('VoxSourceModal')
function Modal:Open()
    if self.sourceDestroyed then return self end
    if not self.isOpen_ then
        self.sourceEntryTime=0;self.sourceOverlayTime=self.sourceOverlayTime or 0
    end
    if not self.visual then self.visual=require('ui.SourceModalVisual').New(self) end
    return Base.Open(self)
end
function Modal:Update(dt)
    -- Host advances retirement outside UI's ipairs traversal, so removing a
    -- closing modal cannot skip the next overlay's update (notably Help).
    if not self.isOpen_ then return end
    -- Retain the library's content update/ownership; only replace its generic
    -- linear 125ms entry with the two independent animations in source CSS.
    Base.Update(self,dt)
    if self.isOpen_ then
        self.sourceEntryTime=math.min(.26,(self.sourceEntryTime or .26)+math.max(0,dt))
        self.sourceOverlayTime=math.min(.18,(self.sourceOverlayTime or .18)+math.max(0,dt))
        self.animProgress_=Motion.Ease(self.sourceOverlayTime/.18,'ease')
    end
end
local function Contains(self,widget)
    while widget do if widget==self then return true end;widget=widget.parent end
    return false
end
function Modal:ReleaseInput()
    if Contains(self,UI.GetFocus()) then UI.ClearFocus() end
    for id,kind in pairs(self.sourcePointers or {}) do
        if Contains(self,UI.GetPressedWidgetForPointer(id)) then UI.CancelPointer(id,kind) end
    end
    self.sourcePointers={}
end
function Modal:Close(immediate)
    if self.sourceDestroyed then return self end
    if self.isOpen_ then
        self.isOpen_=false;self.targetAnimProgress_=0;self.props.pointerEvents='none'
        self.sourceClosing=true;self.sourceCloseTime=0;self.animProgress_=1
        UI.PopOverlay(self);self:ReleaseInput()
        self:DispatchEvent('close',self)
        if self.onClose_ then self.onClose_(self) end
    end
    if immediate or self.props.source.help then self:Destroy() end
    return self
end
function Modal:AdvanceClose(dt)
    if not self.sourceClosing or self.sourceDestroyed then return end
    self.sourceCloseTime=math.min(.16,self.sourceCloseTime+math.max(0,dt))
    self.animProgress_=1-Motion.Ease(self.sourceCloseTime/.16,'ease')
    if self.sourceCloseTime>=.16 then self:Destroy() end
end
function Modal:IsVisible()
    return not self.sourceDestroyed and (self.isOpen_ or self.sourceClosing) and self.animProgress_>0
end
function Modal:Destroy()
    if self.sourceDestroyed or self.sourceDestroying then return end
    self.sourceDestroying=true
    if self.isOpen_ then self:Close() end
    self:ReleaseInput();UI.PopOverlay(self)
    self.sourceClosing=false;self.sourceDestroyed=true;self.animProgress_=0
    if self.props.onDispose then self.props.onDispose(self) end
    Base.Destroy(self)
    if self.visual then self.visual:Dispose();self.visual=nil end
end
function Modal:EntryState()
    if self.sourceClosing then
        local progress=Motion.Ease(self.sourceCloseTime/.16,'ease')
        return 1-progress,1-progress,10*progress*(self.props.source.sourceScale or 1)
    end
    local time=self.sourceEntryTime or .26
    local card=Motion.Ease(time/.26,false)
    return Motion.Ease((self.sourceOverlayTime or .18)/.18,'ease'),card,18*(1-card)*(self.props.source.sourceScale or 1)
end
function Modal:OnPointerDown(event)
    if not self.isOpen_ then return false end
    self.sourcePointers=self.sourcePointers or {}
    if event.pointerId then self.sourcePointers[event.pointerId]=event.pointerType or 'mouse' end
    local r=self.modalLayout_
    if self.props.source.help and r and (event.y<r.y+94 or event.y>r.y+r.h-24 or event.x<r.x+28 or event.x>r.x+r.w-28) then
        self:Close();return true
    end
    return Base.OnPointerDown(self,event)
end
function Modal:OnPointerUp(event)
    if self.sourcePointers then self.sourcePointers[event.pointerId]=nil end
    return Base.OnPointerUp(self,event)
end
function Modal:RenderModalContent(vg)
    if self:IsVisible() and self.visual then self.visual:Draw(vg) end
end
function Modal.DrawHeading(vg,x,y,w,title,subtitle,compact)
    local h,padx,pady,size=compact and 54 or 74,compact and 18 or 28,compact and 12 or 20,compact and 24 or 30
    local shape={x,y,x+w-20,y,x+w,y+20,x+w,y+h,x,y+h}
    D.Path(vg,shape);nvgFillColor(vg,nvgRGBA(29,56,82,255));nvgFill(vg)
    require('ui.SourceRelief').Halftone(vg,x,y,w,h,false,h*2,shape)
    D.Rect(vg,x,y,4,h,{155,215,250,255});D.Rect(vg,x,y+h-1,w,1,{255,255,255,20})
    D.Text(vg,title,x+padx,y+pady,size,nil,'vox-title',nil,1)
    if subtitle then D.Text(vg,subtitle,x+padx+12+D.Width(vg,title,size,'vox-title',1),y+pady+(compact and 9 or 13),13,{174,196,218,255},'vox-body') end
end
return Modal
