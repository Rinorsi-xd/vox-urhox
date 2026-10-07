-- PC source geometry + actual mouse routing, preserving list state on resize.
local UI=require 'urhox-libs/UI'
local Event=require 'urhox-libs/UI/Core/PointerEvent'
local app,s,p,old,oldContent,oldRow,anchor,detailY
local w,h=1920,1080
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Bounds(widget) return widget:GetAbsoluteLayoutForHitTest() end
local function At(x,y,kind,button)
    UI.HandlePointerEvent(Event.new(kind,{x=x,y=y,pointerId=0,pointerType='mouse',button=button or MOUSEB_LEFT}))
end
local function Click(widget)
    local r=Bounds(widget);At(r.x+r.w/2,r.y+r.h/2,'PointerDown');At(r.x+r.w/2,r.y+r.h/2,'PointerUp')
end
local function Shot(name)
    local img=Image:new();local ok=graphics:TakeScreenShot(img);local crop=img:GetSubimage(IntRect(0,0,w,h))
    V.assert(ok and crop:SavePNG('docs/migration/evidence/pc-inventory-'..name..'.png'),'rendered '..name);crop:Dispose();img:Dispose()
end
local function Bound() s.hud.root:SetStyle({width=w,height=h});renderer:GetViewport(0):SetRect(IntRect(0,0,w,h)) end
local function Near(value,expected,label) V.assert(math.abs(value-expected)<=1,label..': '..value..' expected '..expected) end
local function Layout()
    local cw,ch=math.min(1500,w*.94),math.min(900,h*.9);local x,y=(w-cw)/2,(h-ch)/2
    local r=Bounds(p.body);Near(r.x,x,'source card left');Near(r.y,y,'source card top');Near(r.w,cw,'source card width');Near(r.h,ch,'source card height')
    local grid=Bounds(p.list);Near(grid.x,x,'source grid left');Near(grid.y,y+120,'source grid top');Near(grid.w,cw-368,'source grid width');Near(grid.h,ch-244,'source grid height')
    local detail=Bounds(p.detailScroll);Near(detail.w,340,'source detail width');Near(detail.x,x+cw-340,'source detail left')
    local hot=Bounds(p.hotbar.root);Near(hot.x,(w-694)/2,'source hotbar centered');Near(hot.y,y+ch-109,'source hotbar top');Near(hot.w,694,'source hotbar width')
    V.assert(not p.compact and not p.detailButton and not p.filterButton,'removed mobile detail/filter drawers')
    local pool=p.list:GetPoolStats();V.assert(pool.total<=math.ceil(grid.h/150)+3,'virtual pool bounded after layout')
end
local function Cleanup()
    app.store.pending=nil
    for _,key in ipairs({'draft','garage-state','build-settings'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local path=app.store.prefix..key..suffix;if fileSystem:FileExists(path) then fileSystem:Delete(path) end end end
end
V.atFrame(55,function()
    app=VOX_HANGAR.app;app.store=require('storage.BlueprintStore').New('vox-pc-inventory-test');app.bays.store=app.store;app.bays.active=false;Cleanup()
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    app:EnterBuild();s=app.build;Bound();s.inventory=require('build.Inventory').New();app.inventory=s.inventory;s:SelectHotbar(1);p=s:OpenInventory()
end)
V.atFrame(80,function()
    Layout();Shot('1920');V.assert(p.columns==8 and #p.results==105,'original 8 columns and catalog count')
    local cell=p.list.pool_.inUse[1].cells[1];local r=Bounds(cell.root);Near(r.x,212,'source first tile left');Near(r.y,274,'source material header scrolls above tiles');Near(r.w,130.75,'source first tile width');Near(r.h,140,'source first tile height')
    local before=s.editor.history.revision;Click(p.matButtons.neon)
    V.assert(s.inventory.material=='neon' and p.matButtons.neon.props.selected,'native material click selects real material')
    Click(p.categoryButtons.weapon);V.assert(s.inventory.category=='weapon' and #p.results==12 and not p.materialBar.props.visible,'native weapon tab routes to data and hides materials')
    V.assert(before==s.editor.history.revision,'inventory does not edit world history');p:Detail('mg5')
end)
V.atFrame(97,function()
    Shot('weapons');Click(p.search);p.search:OnTextInput('玻璃')
    V.assert(p.model.query=='玻璃' and #p.results==26 and not p.categoryButtons.weapon.props.selected,'native search finds other materials with no active category')
end)
V.atFrame(112,function()
    Shot('search');local cell=p.list.pool_.inUse[1].cells[1];Click(cell.root)
    V.assert(s.inventory:Current()==cell.type and p.shown==cell.type,'native search card selects and shows actual part')
    Click(p.search);p.search:SelectAll();p.search:OnTextInput('不存在的零件xyz')
end)
V.atFrame(125,function()
    V.assert(#p.results==0 and p.empty.props.visible,'no result state renders without material row or pooled cards')
    p.search:SelectAll();p.search:OnTextInput('');UI.ClearFocus();Click(p.categoryButtons.all)
end)
V.atFrame(138,function()
    local cell=p.list.pool_.inUse[1].cells[1];local r=Bounds(cell.root);At(r.x+20,r.y+20,'PointerMove');UI.HandleWheel(0,-9)
end)
V.atFrame(150,function()
    V.assert(p.list.scrollOffset_>0,'mouse wheel over a tile reaches inventory scroll view')
    V.assert(Bounds(p.materialBar).y<Bounds(p.list).y,'material selector scrolls with original grid')
    p.list:ScrollToIndex(5);p:Detail('leg5')
end)
V.atFrame(160,function()
    p.detailScroll:ScrollToBottom();local _,sy=p.detailScroll:GetScroll();detailY=sy;anchor=p:ListAnchor();print('[PCInventory] before resize '..tostring(anchor)..' scroll='..p.list.scrollOffset_..' height='..p.list.scrollView_:GetLayout().h);old=p;oldContent=p.modal.contentContainer_;for _,row in pairs(p.list.pool_.inUse) do oldRow=row;break end
    w,h=1440,900
end)
V.atFrame(175,function()
    p=assert(s.inventoryPanel);Bound();V.assert(p~=old and old.closed and not oldContent.node and not oldRow.node,'PC resize destroys old modal and virtual rows')
    V.assert(p.model.material=='neon' and p.shown=='leg5','PC resize preserves material and detail')
end)
V.atFrame(190,function()
    print('[PCInventory] after resize '..tostring(p:ListAnchor())..' pending='..tostring(p.pendingAnchor)..' scroll='..p.list.scrollOffset_..' height='..p.list.scrollView_:GetLayout().h);local _,dy=p.detailScroll:GetScroll();V.assert(detailY>0 and math.abs(dy-detailY)<1,'PC resize preserves detail scroll position');Layout();Shot('1440');V.assert(p.columns==7,'16:10 PC matches source seven columns')
    local first,last=p.list:GetVisibleRange();local found=false;for i=first,last do for _,d in ipairs(p.list.props.data[i] or {}) do if d.id==anchor then found=true end end end
    V.assert(found,'previous top part remains visible after column count changes');Click(p.search);p.search:OnTextInput('玻璃')
end)
V.atFrame(203,function()
    V.assert(p.list.scrollOffset_==0 and not p.pendingAnchor,'new search resets old scroll anchor')
    p:Trim(false);local cached=0;for _,path in ipairs(require('urhox-libs/UI/Core/ImageCache').GetCachedPaths()) do if path:sub(1,9)=='UI/Parts/' then cached=cached+1 end end
    V.assert(cached<=60,'thumbnail cache bounded to visible rows plus current hotbar/detail')
    Click(p.closeButton);V.assert(not s.inventoryPanel and p.closed and not p.body.node,'close disposes inventory and returns same editor')
    V.assert(UI.GetFocus()==nil and s.hud.toolbar.props.visible~=false,'search focus released and build chrome restored')
    app:ExitBuild();Cleanup();UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale);V.finish()
end)


