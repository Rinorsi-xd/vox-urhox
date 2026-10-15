-- Virtual rows below a scrolling material selector. All offsets are CSS pixels.
local Base=require 'ui.CatalogList'
local List=Base:Extend('VoxInventoryList')
function List:BuildStructure()
    Base.BuildStructure(self)
    self.scrollView_.UpdateContentSize=function(sv)
        local r=sv:GetLayout();sv.contentWidth_=math.max(0,r.w)
        sv.contentHeight_=(self.props.topInset or 16)+#self.props.data*self.rowHeight_+6
    end
end
function List:CalculateVisibleRange()
    local count=#self.props.data;local height=self.props.viewportHeight or 0
    if count==0 or height<=0 then return 0,0 end
    local offset=(self.scrollOffset_ or 0)-(self.props.topInset or 16)
    return math.max(1,math.floor(offset/self.rowHeight_)+1),math.min(count,math.ceil((offset+height)/self.rowHeight_))
end
function List:UpdateVisibleItems()
    Base.UpdateVisibleItems(self)
    if not self.contentContainer_ then return end
    local inset=self.props.topInset or 16
    self.contentContainer_:SetStyle({height=inset+#self.props.data*self.rowHeight_+6})
    for i,row in pairs(self.pool_.inUse) do row:SetStyle({left=2,top=inset+(i-1)*self.rowHeight_}) end
end
function List:ScrollToIndex(index)
    -- Modal measurement can return NaN before its constrained render pass.
    -- Use the known list extent for restoration instead of ScrollView:SetScroll,
    -- whose clamp uses that transient Yoga height.
    local inset=self.props.topInset or 16
    local maxOffset=math.max(0,inset+#self.props.data*self.rowHeight_+6-self.props.viewportHeight)
    self.scrollView_:SetScrollDirect(0,math.min(maxOffset,inset+(index-1)*self.rowHeight_))
end
return List
