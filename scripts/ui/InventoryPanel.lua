-- Original PC inventory composition; model/input, virtual rows and NVG art
-- have independent ownership. Source directory remains read-only.
local UI=require 'urhox-libs/UI'
local Theme=require 'ui.VoxTheme'
local D=require 'ui.SourceDraw'
local Defs=require 'parts.Defs'
local Model=require 'build.Inventory'
local Art=require 'ui.InventoryChrome'
local M={};M.__index=M
function M.Open(session,restore)
    if session.inventoryPanel then return session.inventoryPanel end
    session.buildCamera:Release()
    local self=setmetatable({session=session,model=session.inventory,hoverType=false,shown=false,closed=false,trimTime=0},M)
    session.inventoryPanel=self;session.controls:Cancel();session.editor.preview=nil;session.ghost:Refresh(session.editor,false)
    local current=Defs.PARTS[self.model:Current()];if not restore and current and current.mat then self.model.material=current.mat end
    local sw,sh=UI.GetViewportSize();local width,height=math.min(1500,sw*.94),math.min(900,sh*.9)
    self.width=width;self.height=height;self.gridWidth=width-368;self.centerHeight=height-244
    self.itemHeight=140;self.columns=math.max(1,math.floor((self.gridWidth-16+10)/134))
    self.rowWidth=self.gridWidth-16
    local modal=Art.Modal{title='',headerHeight=0,contentPadding=0,showCloseButton=false,closeOnEscape=false,
        onClose=function(w) self.closed=true;session.inventoryPanel=nil;w:Destroy();self:Trim(true);session:Refresh() end}
    self.modal=modal
    self.body=UI.Panel{width=width,height=height,pointerEvents='box-none'};modal:AddContent(self.body)
    self.body:AddChild(Art.Title(self))
    local search=require('ui.InventorySearch'){value=self.model.query,position='absolute',right=124.8125,top=11,width=360,height=42,
        onChange=function(_,value) self.model.query=value;self:Fill() end};self.search=search;self.body:AddChild(search)
    self.closeButton=Art.Button{position='absolute',right=0,top=11,width=106.8125,height=42,onClick=function() self:Close() end};self.body:AddChild(self.closeButton)
    self.categoryBar=UI.Panel{position='absolute',left=0,top=64,width='100%',height=56,flexDirection='row',gap=2}
    function self.categoryBar:Render(vg) local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y+r.h-1,r.w,1,{255,255,255,26}) end
    self.body:AddChild(self.categoryBar);self.categoryButtons={}
    local categories={{id='all',name='全部'}};for _,c in ipairs(Defs.CATEGORIES) do categories[#categories+1]=c end
    local widths={128.53125,123.171875,120.90625,123.140625,120.984375,115.78125,120.71875}
    for i,c in ipairs(categories) do
        local count=0;for _,d in ipairs(Defs.LIST) do if not d.hidden and not d.panel and (not d.shape or d.mat=='light') and (c.id=='all' or c.id==d.cat) then count=count+1 end end
        local button=Art.Button{kind='category',text=c.name,icon=Art.icons[c.id],count=tostring(count),width=widths[i],height=55,flexShrink=0,
            onClick=function() self.model.category=c.id;self:Fill() end}
        self.categoryButtons[c.id]=button;self.categoryBar:AddChild(button)
    end
    self.center=UI.Panel{position='absolute',left=0,top=120,width='100%',height=self.centerHeight,flexDirection='row',gap=28};self.body:AddChild(self.center)
    self.list=require('ui.InventoryList'){width=self.gridWidth,height=self.centerHeight,viewportHeight=self.centerHeight,itemHeight=140,itemGap=10,poolBuffer=1,bounces=false,data={},
        createItem=function() return self:CreateRow() end,bindItem=function(widget,row) self:BindRow(widget,row) end}
    self.center:AddChild(self.list)
    self.materialBar=Art.MaterialHeader();self.list.contentContainer_:AddChild(self.materialBar);self.matButtons={}
    local mx=69.203125
    for i,m in ipairs(Model.materials) do
        local mw=i<=2 and 104.203125 or 117.796875
        local button=Art.Button{kind='material',material=m.id,text=m.name,budget=m.budget,position='absolute',left=mx,top=0,width=mw,height=34,
            onClick=function() self.model.material=m.id;self:Fill() end}
        self.matButtons[m.id]=button;self.materialBar:AddChild(button);mx=mx+mw+6
    end
    self.empty=UI.Panel{position='absolute',left=0,top=40,width=self.gridWidth,height=50,pointerEvents='none',visible=false}
    function self.empty:Render(vg) D.Begin(vg);local r=self:GetAbsoluteLayout();D.Text(vg,'没有找到零件',r.x+r.w/2,r.y,18,D.muted,nil,NVG_ALIGN_CENTER) end
    self.center:AddChild(self.empty)
    self.detail=require('ui.InventoryDetail'){width=292,height=580};self.detail.inventory=self.model
    self.detailScroll=UI.ScrollView{width=340,height=self.centerHeight,scrollX=false,scrollY=true,bounces=false,
        paddingLeft=27,paddingRight=21,paddingTop=18,borderLeftWidth=1,borderColor={255,255,255,26},children={self.detail}}
    self.center:AddChild(self.detailScroll)
    self.footer=Art.Footer();self.body:AddChild(self.footer)
    self.hotbar=require('ui.BuildHotbar').Create(session,false,function(id) self:Detail(id) end)
    self.hotbar.root:SetStyle({position='absolute',left=(width-694)/2,top=15});self.footer:AddChild(self.hotbar.root)
    self:Fill();self:Detail(restore and restore.shown or self.model:Current());self.restoreScroll=restore;self.pendingAnchor=restore and restore.anchor
    modal:Open();session:Refresh();return self
end
function M:CreateRow()
    local cells={};local root=UI.Panel{width=self.rowWidth,height=140,flexDirection='row',gap=10}
    for i=1,self.columns do
        local cell={type=false}
        cell.root=Art.Card{height=140,flexGrow=1,flexBasis=0,
            onClick=function(_,event) if cell.type and not cell.suppressClick and (not event or event:IsPrimaryButton()) then self.session:PickHotbar(cell.type);self:Detail(cell.type);self.hotbar.Refresh() end end,
            onPointerDown=function() cell.suppressClick=false end,
            onPointerCancel=function(_,w) w.state.isDragging=false;self.dragType=nil end,
            onDoubleTap=function() if cell.type then self.session:PickHotbar(cell.type);self:Close() end end,
            onPointerEnter=function() self.hoverType=cell.type;if cell.type then self:Detail(cell.type) end end,
            onPointerLeave=function() if self.hoverType==cell.type then self.hoverType=false end end,
            onPanEnd=function(event,w)
                local slot=self.hotbar.Hit(event.x,event.y)
                if slot and self.dragType then self.session:AssignHotbar(slot,self.dragType);self.hotbar.Refresh() end
                w.state.isDragging=false;self.dragType=nil
            end}
        cell.root.inventory=self.model
        cell.root.OnPanStart=function(w,event)
            cell.suppressClick=true;if event.pointerType~='mouse' or not cell.type then return false end
            self.dragType=cell.type;w.state.isDragging=true;return true
        end
        root:AddChild(cell.root);cells[i]=cell
    end
    root.cells=cells;return root
end
function M:BindRow(widget,row)
    for i,cell in ipairs(widget.cells) do
        local d=row[i];cell.type=d and d.id or false;cell.root.props.partType=cell.type
        cell.root:SetStyle({visibility=d and 'visible' or 'hidden'})
    end
end
function M:Fill()
    self.hoverType=false;self.pendingAnchor=nil
    local list=self.model:List();self.results=list;local query=self.model.query:match('%S')~=nil
    self.countText=query and ('搜到 '..#list..' 个') or (#list..' 个零件');self.empty:SetVisible(#list==0)
    local materialVisible=not query and (self.model.category=='all' or self.model.category=='structure')
    self.materialBar:SetVisible(materialVisible);self.list.props.topInset=materialVisible and 64 or 16
    local rows={};for i=1,#list,self.columns do local row={};for j=i,math.min(#list,i+self.columns-1) do row[#row+1]=list[j] end;rows[#rows+1]=row end
    self.list:SetData(rows);self.list:ScrollToTop()
    for cat,b in pairs(self.categoryButtons) do b.props.selected=not query and cat==self.model.category end
    for mat,b in pairs(self.matButtons) do b.props.selected=mat==self.model.material end
end
function M:ViewState()
    local _,dy=self.detailScroll:GetScroll()
    return {shown=self.shown,anchor=self:ListAnchor(),detailY=dy}
end
function M:ListAnchor()
    if self.pendingAnchor then return self.pendingAnchor end
    local row=math.max(1,math.floor((self.list.scrollOffset_-(self.list.props.topInset or 16))/self.list.rowHeight_)+1)
    local def=self.list.props.data[row] and self.list.props.data[row][1];return def and def.id
end
function M:Detail(id)
    if not Defs.PARTS[id] or self.shown==id then return end;self.shown=id;self.detail:SetPart(id);self.detailScroll:ScrollToTop()
end
function M:Digit(i)
    if self.hoverType then self.session:AssignHotbar(i,self.hoverType) else self.session:SelectHotbar(i) end;self.hotbar.Refresh()
end
function M:Keys()
    local typing=UI.GetFocus()==self.search
    if input:GetKeyPress(KEY_ESCAPE) then
        if typing and self.model.query~='' then self.model.query='';self.search:SetValue('');self:Fill() else self:Close() end;return
    end
    if typing then return end
    if input:GetKeyPress(KEY_B) then self:Close();return end
    if input:GetKeyPress(KEY_G) then self.model:CycleMaterial();self:Fill() end
    for i,k in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}) do if input:GetKeyPress(k) then self:Digit(i) end end
end
function M:Trim(closing)
    local keep={};for _,id in ipairs(self.model.hotbar) do if id then keep[Theme.Thumbnail(id)]=true end end
    if not closing then
        keep[Theme.Thumbnail(self.shown)]=true
        local first,last=self.list:GetVisibleRange()
        for i=first,last do for _,d in ipairs(self.list.props.data[i] or {}) do keep[Theme.Thumbnail(d.id)]=true end end
    end
    Theme.TrimThumbnails(keep)
end
function M:Update(dt)
    if self.restoreScroll and self.modal.modalLayout_ then
        local state=self.restoreScroll;self.restoreScroll=nil
        self.detailScroll:SetScrollDirect(0,math.min(state.detailY or 0,math.max(0,self.detail.props.height+18-self.centerHeight)))
    end
    if self.pendingAnchor and self.modal.modalLayout_ then
        local anchor=self.pendingAnchor;self.pendingAnchor=nil
        for i,def in ipairs(self.results) do if def.id==anchor then self.list:ScrollToIndex(math.floor((i-1)/self.columns)+1);break end end
    end
    self.hotbar.Refresh();self.trimTime=self.trimTime+dt;if self.trimTime>.5 then self.trimTime=0;self:Trim(false) end
end
function M:Close() if not self.closed then self.modal:Close() end end
return M


