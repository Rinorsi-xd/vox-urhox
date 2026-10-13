-- Source HTML button activation and Tab order, including offscreen virtual rows.
local UI=require 'urhox-libs/UI'
local M={}
function M.Stops(owner)
    local stops={{widget=owner.search},{widget=owner.closeButton}}
    for _,widget in ipairs(owner.categoryBar.children) do stops[#stops+1]={widget=widget} end
    if owner.materialBar:IsVisible() then
        for _,material in ipairs(require('construction.Inventory').materials) do stops[#stops+1]={widget=owner.matButtons[material.id]} end
    end
    for index,def in ipairs(owner.results) do stops[#stops+1]={part=def.id,index=index} end
    if owner.detail.more then stops[#stops+1]={widget=owner.detail.more} end
    for _,slot in ipairs(owner.hotbar.slots) do stops[#stops+1]={widget=slot.widget} end
    stops[#stops+1]={widget=owner.footer.children[1].children[1]}
    return stops
end
function M.Focus(owner,stop)
    if stop.part then
        local row=math.floor((stop.index-1)/owner.columns)+1
        local offset=owner.list.scrollOffset_;local inset=owner.list.props.topInset or 16
        local top=inset+(row-1)*owner.list.rowHeight_
        if top<offset or top+owner.itemHeight>offset+owner.centerHeight then owner.list:ScrollToIndex(row) end
        owner.list:UpdateVisibleItems()
        local widget=owner.list.pool_.inUse[row]
        local cell=widget and widget.cells[(stop.index-1)%owner.columns+1]
        if not cell or cell.type~=stop.part then return false end
        UI.SetFocus(cell.root);owner.keyboardFocus=cell.root
        owner.hoverType=stop.part;owner:Detail(stop.part);return true
    end
    if not stop.widget or not stop.widget.node then return false end
    if stop.widget.props.kind=='material' then owner.list:ScrollToTop() end
    UI.SetFocus(stop.widget);owner.keyboardFocus=stop.widget;owner.hoverType=false
    local p=stop.widget.props
    if p.inventoryStyle and p.partType then owner:Detail(p.partType) end
    return true
end
function M.Tab(owner,backward)
    local stops=M.Stops(owner);local focus=UI.GetFocus();local at=0
    for i,stop in ipairs(stops) do if stop.widget==focus or stop.part and focus and focus.props.partType==stop.part and focus.inventoryOwner==owner then at=i;break end end
    if at==0 and backward then at=1 end
    return M.Focus(owner,stops[(at-1+(backward and -1 or 1))%#stops+1])
end
function M.Activate(owner,key)
    local focus=UI.GetFocus();if not focus or focus==owner.search then return false end
    local p=focus.props
    if key==KEY_DELETE or key==KEY_BACKSPACE then
        if p.inventoryStyle then owner.session:ClearHotbar(p.index);owner.hotbar.Refresh();return true end
        return false
    end
    if key~=KEY_RETURN and key~=KEY_SPACE then return false end
    if p.onClick and not p.disabled then p.onClick(focus);return true end
    return false
end
return M
