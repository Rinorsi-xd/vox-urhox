local Base=require 'urhox-libs/UI/Widgets/ScrollView'
local Scroll=Base:Extend('VoxInventoryDetailScroll')
function Scroll:UpdateContentSize()
    Base.UpdateContentSize(self)
    -- CSS scrollHeight includes the detail's trailing padding. The base
    -- ScrollView measures descendant bounds, which stop before that padding.
    self.contentHeight_=self.contentHeight_+(self.props.paddingBottom or 0)
end
return Scroll
