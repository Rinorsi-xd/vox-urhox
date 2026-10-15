-- Application adapter: allocate rows on demand and explicitly destroy detached
-- pooled widgets. Engine reference libraries remain untouched.
local Base=require 'urhox-libs/UI/Components/VirtualList'
local CatalogList=Base:Extend('VoxCatalogList')
function CatalogList:PrewarmPool() end
function CatalogList:CalculateVisibleRange()
    -- Modal's unconstrained measurement can temporarily expose NaN through
    -- GetLayout during Update. The owner supplies its bounded viewport height;
    -- never let an indeterminate Yoga height materialize the whole catalog.
    local height=self.props.viewportHeight or 0
    local count=#self.props.data
    if count==0 or height<=0 then return 0,0 end
    local offset=self.scrollOffset_
    if offset~=offset then offset=0 end
    return math.max(1,math.floor(offset/self.rowHeight_)+1),math.min(count,math.ceil((offset+height)/self.rowHeight_))
end
function CatalogList:SetViewportHeight(height)
    self.props.viewportHeight=math.max(0,height)
    self:SetStyle({height=height});self:UpdateVisibleItems()
end
function CatalogList:Update(dt)
    Base.Update(self,dt)
    while #self.pool_.available>2 do table.remove(self.pool_.available):Destroy() end
end
function CatalogList:Destroy()
    self:ReleaseAllItems()
    for _,widget in ipairs(self.pool_.available) do widget:Destroy() end
    self.pool_.available={}
    Base.Destroy(self)
end
return CatalogList
