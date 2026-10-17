local Base=require 'urhox-libs/UI/Widgets/ScrollView'
local Scroll=Base:Extend('VoxInventoryDetailScroll')
function Scroll:UpdateContentSize()
    Base.UpdateContentSize(self)
    -- CSS scrollHeight includes the detail's trailing padding. The base
    -- ScrollView measures descendant bounds, which stop before that padding.
    self.contentHeight_=self.contentHeight_+(self.props.paddingBottom or 0)
    -- Browser detail replacement retains scrollTop, clamping only when the new
    -- content is shorter. Ignore transient Yoga heights during modal layout.
    local height=self:GetLayout().h
    if not self.props.bounces and height==height and height>0 then
        local limit=math.max(0,self.contentHeight_-height)
        local current=self.state.scrollY
        local clamped=math.max(0,math.min(limit,current))
        if clamped~=current then self:SetScrollDirect(self.state.scrollX,clamped) end
    end
end
return Scroll
