-- Original PC inventory composition; model/input, virtual rows and NVG art
-- have independent ownership. Source directory remains read-only.
local UI=require 'urhox-libs/UI'
local Theme=require 'ui.VoxTheme'
local D=require 'ui.SourceDraw'
local Defs=require 'parts.Defs'
local Model=require 'construction.Inventory'
local Art=require 'ui.InventoryChrome'
local M={};M.__index=M
function M.Open(session,restore)
    if session.inventoryPanel then return session.inventoryPanel end
    session.buildCamera:Release()
    local self=setmetatable({session=session,model=session.inventory,hoverType=false,shown=false,closed=false,trimTime=0,motionClock=0,listEpoch=0},M)
    session.inventoryPanel=self;session.controls:Cancel();session.editor.preview=nil;session.ghost:Refresh(session.editor,false)
    local current=Defs.PARTS[self.model:Current()];if not restore and current and current.mat then self.model.material=current.mat end
    local sw,sh=UI.GetViewportSize();self.narrow=sh<=600 and sw>sh
    local width,height=math.min(1580,sw*.94),math.min(960,sh*.92)
    if self.narrow then width=sw-24;height=sh-12 end
    local centerTop=self.narrow and 92 or 128
    local footerHeight=self.narrow and 104 or 135
    local centerHeight=height-centerTop-footerHeight
    self.width=width;self.height=height;self.gridWidth=width-(self.narrow and 232 or 338)
    self.centerHeight=centerHeight
    self.itemHeight=self.narrow and 106 or 146;self.itemGap=self.narrow and 7 or 12
    self.columns=math.max(1,math.floor((self.gridWidth-11+self.itemGap)/((self.narrow and 90 or 125)+self.itemGap)))
    self.rowWidth=self.gridWidth-11
    local modal=Art.Modal{title='',headerHeight=0,contentPadding=0,showCloseButton=false,closeOnEscape=false,
        onClose=function(w)
            self.closed=true;session.inventoryPanel=nil
            if self.pointerTargetListener then require('urhox-libs/UI/Core/Input').Off('PointerDown',self.pointerTargetListener);self.pointerTargetListener=nil end
            if self.pointerCancelListener then require('urhox-libs/UI/Core/Input').Off('PointerCancel',self.pointerCancelListener);self.pointerCancelListener=nil end
            if self.backdrop then self.backdrop:Dispose();self.backdrop=nil end
            w:Destroy();self:Trim(true);session:Refresh()
        end}
    self.modal=modal
    -- Cached Web adapters dispatch Gesture before UI, so event.target is still
    -- empty at gesture start. Pin the hit widget before the recognizer observes it.
    self.pointerTargetListener=require('urhox-libs/UI/Core/Input').On('PointerDown',function(event)
        if not self.closed and not event.target then event.target=UI.FindWidgetAt(event.x/UI.GetScale(),event.y/UI.GetScale()) end
    end,100)
    self.pointerCancelListener=require('urhox-libs/UI/Core/Input').On('PointerCancel',function(event)
        if event.pointerId~=self.dragPointer then return end
        if self.dragWidget then self.dragWidget.state.isDragging=false end
        self.dragType=nil;self.dragPoint=nil;self.dragWidget=nil;self.dragPointer=nil
    end,100)
    self.body=UI.Panel{width=width,height=height,pointerEvents='box-none'};modal:AddContent(self.body)
    self.body:AddChild(Art.Title(self))
    local search=require('ui.InventorySearch'){value=self.model.query,placeholder='搜索零件',sourceSize=13,position='absolute',right=self.narrow and 120 or 132.03125,top=self.narrow and 2 or 18,width=self.narrow and math.min(230,sw*.3) or math.min(350,math.max(190,sw*.23)),height=self.narrow and 44 or 40,
        onChange=function(_,value) self.model.query=value;self:Fill() end};self.search=search;self.body:AddChild(search)
    self.closeButton=Art.Button{position='absolute',right=0,top=self.narrow and 2 or 18,width=110.03125,height=self.narrow and 44 or 40,onClick=function() self:Close() end};self.body:AddChild(self.closeButton)
    self.categoryBar=UI.Panel{width=width,height=self.narrow and 44 or 52,flexDirection='row',alignItems='center',gap=4,flexShrink=0}
    function self.categoryBar:Render(vg) local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y+r.h-1,r.w,1,{54,86,117,255}) end
    self.body:AddChild(UI.ScrollView{position='absolute',left=0,top=self.narrow and 48 or 76,width=width,height=self.narrow and 44 or 52,scrollX=true,scrollY=false,showScrollbar=false,bounces=false,children={self.categoryBar}});self.categoryButtons={}
    local categories={{id='all',name='全部'}};for _,c in ipairs(Defs.CATEGORIES) do categories[#categories+1]=c end
    for i,c in ipairs(categories) do
        local count=0;for _,d in ipairs(Defs.LIST) do if not d.hidden and not d.panel and (not d.shape or d.mat=='light') and (c.id=='all' or c.id==d.cat) then count=count+1 end end
        local button=Art.Button{kind='category',text=c.name,icon=Art.icons[c.id],count=tostring(count),compact=self.narrow,width=95.8125,height=self.narrow and 44 or 42,flexShrink=0,
            onClick=function() self.model.category=c.id;self:Fill() end}
        self.categoryButtons[c.id]=button;self.categoryBar:AddChild(button)
    end
    self.center=UI.Panel{position='absolute',left=0,top=centerTop,width='100%',height=centerHeight,flexDirection='row',gap=self.narrow and 12 or 28};self.body:AddChild(self.center)
    self.list=require('ui.InventoryList'){width=self.gridWidth,height=self.centerHeight,viewportHeight=self.centerHeight,itemHeight=self.itemHeight,itemGap=self.itemGap,poolBuffer=1,bounces=false,data={},
        createItem=function() return self:CreateRow() end,bindItem=function(widget,row,index) self:BindRow(widget,row,index) end}
    self.center:AddChild(self.list)
    local materialContent=Art.MaterialHeader(self.narrow);materialContent:SetStyle({position='relative',left=0,top=0,width=math.max(320,self.rowWidth),height=self.narrow and 49 or 38,flexShrink=0})
    self.materialBar=UI.ScrollView{position='absolute',left=3,top=self.narrow and 8 or 18,width=self.rowWidth,height=self.narrow and 49 or 38,scrollX=true,scrollY=false,showScrollbar=false,bounces=false,children={materialContent}}
    self.list.contentContainer_:AddChild(self.materialBar);self.matButtons={}
    local mx=62
    for i,m in ipairs(Model.materials) do
        local mw=i<=2 and 51 or 64
        local button=Art.Button{kind='material',material=m.id,text=m.name,budget=m.budget,position='absolute',left=mx,top=0,width=mw,height=self.narrow and 44 or 32,
            onClick=function() self.model.material=m.id;self:Fill() end}
        self.matButtons[m.id]=button;materialContent:AddChild(button);mx=mx+mw+6
    end
    self.empty=UI.Panel{position='absolute',left=0,top=40,width=self.gridWidth,height=50,pointerEvents='none',visible=false}
    function self.empty:Render(vg) D.Begin(vg);local r=self:GetAbsoluteLayout();D.Text(vg,'没有找到零件',r.x+r.w/2,r.y,18,D.muted,nil,NVG_ALIGN_CENTER) end
    self.center:AddChild(self.empty)
    self.detail=require('ui.InventoryDetail'){width=self.narrow and 201 or 272,height=580,compact=self.narrow,viewportHeight=sh,viewportWidth=sw};self.detail.inventory=self.model
    self.detailScroll=UI.ScrollView{width=self.narrow and 220 or 310,height=self.centerHeight,scrollX=false,scrollY=true,bounces=false,flexShrink=0,
        paddingLeft=self.narrow and 12 or 24,paddingRight=self.narrow and 6 or 3,paddingTop=self.narrow and 8 or 18,borderLeftWidth=1,borderColor={54,86,117,255},children={self.detail}}
    self.center:AddChild(self.detailScroll)
    self.footer=Art.Footer();self.body:AddChild(self.footer)
    self.hotbar=require('ui.BuildHotbar').Create(session,false,function(id) self:Detail(id) end)
    self.footer:SetHeight(footerHeight)
    self.footer:AddChild(UI.ScrollView{position='absolute',left=math.max(0,(width-self.hotbar.root.props.width)/2),top=self.narrow and 5 or 17,width=math.min(width,self.hotbar.root.props.width),height=self.narrow and 64 or 79,scrollX=true,scrollY=false,showScrollbar=false,bounces=false,paddingTop=5,children={self.hotbar.root}})
    self:Fill();self:Detail(restore and restore.shown or self.model:Current());self.restoreScroll=restore;self.pendingAnchor=restore and restore.anchor
    modal:Open();session:Refresh()
    self.backdrop=require('render.SceneBackdrop').New()
    if self.backdrop then self.backdrop:Update() end
    self.initialFocus=not require('controls.TouchMode').Enabled()
    return self
end
function M:CreateRow()
    local cells={};local root=UI.Panel{width=self.rowWidth,height=self.itemHeight,flexDirection='row',gap=self.itemGap}
    for i=1,self.columns do
        local cell={type=false}
        cell.root=Art.Card{height=self.itemHeight,compact=self.narrow,flexGrow=1,flexBasis=0,
            onClick=function(_,event) if cell.type and (not event or not cell.suppressClick) and (not event or event:IsPrimaryButton()) then self.session:PickHotbar(cell.type);self:Detail(cell.type);self.hotbar.Refresh() end end,
            onPointerDown=function(event) cell.suppressClick=false;cell.dragSource=event.pointerType=='mouse' and event:IsPrimaryButton() and event.pointerId;self.keyboardFocus=nil end,
            onPointerCancel=function(event,w)
                if self.dragWidget~=w or self.dragPointer~=event.pointerId then return end
                w.state.isDragging=false;self.dragType=nil;self.dragPoint=nil;self.dragWidget=nil;self.dragPointer=nil
            end,
            onDoubleTap=function() if cell.type then self.session:PickHotbar(cell.type);self:Close() end end,
            onPointerEnter=function() self.hoverType=cell.type;if cell.type then self:Detail(cell.type) end end,
            onPointerLeave=function() if self.hoverType==cell.type then self.hoverType=false end end,
            onPanEnd=function(event,w)
                if self.dragWidget~=w or self.dragPointer~=event.pointerId then return end
                local slot=self.hotbar.Hit(event.x,event.y)
                if slot and self.dragType then self.session:AssignHotbar(slot,self.dragType);self.hotbar.Refresh() end
                w.state.isDragging=false;self.dragType=nil;self.dragPoint=nil;self.dragWidget=nil;self.dragPointer=nil
            end}
        cell.root.inventory=self.model;cell.root.inventoryOwner=self
        cell.root.OnPanStart=function(w,event)
            cell.suppressClick=true;if event.pointerType~='mouse' or cell.dragSource~=event.pointerId or not cell.type or self.dragWidget then return false end
            self.dragType=cell.type;self.dragPoint={x=event.x,y=event.y};self.dragWidget=w;self.dragPointer=event.pointerId;w.state.isDragging=true;return true
        end
        cell.root.OnPanMove=function(w,event) if self.dragWidget==w and self.dragPointer==event.pointerId then self.dragPoint={x=event.x,y=event.y} end end
        root:AddChild(cell.root);cells[i]=cell
    end
    root.cells=cells;return root
end
function M:BindRow(widget,row,index)
    for i,cell in ipairs(widget.cells) do
        local d=row[i];cell.type=d and d.id or false;cell.root.props.partType=cell.type
        if UI.GetFocus()==cell.root then UI.ClearFocus();self.keyboardFocus=nil end
        require('ui.InventoryCardMotion').Bind(cell.root,((index or 1)-1)*self.columns+i,self.motionClock-self.listEpoch)
        cell.root:SetStyle({visibility=d and 'visible' or 'hidden'})
    end
end
function M:Fill()
    self.hoverType=false;self.pendingAnchor=nil;self.listEpoch=self.motionClock
    local list=self.model:List();self.results=list;local query=self.model.query:match('%S')~=nil
    self.countText=query and ('搜到 '..#list..' 个') or (#list..' 个零件');self.empty:SetVisible(#list==0)
    local materialVisible=not query and (self.model.category=='all' or self.model.category=='structure')
    self.materialBar:SetVisible(materialVisible);self.list.props.topInset=materialVisible and (self.narrow and 64 or 68) or (self.narrow and 8 or 18)
    local rows={};for i=1,#list,self.columns do local row={};for j=i,math.min(#list,i+self.columns-1) do row[#row+1]=list[j] end;rows[#rows+1]=row end
    self.list:SetData(rows);self.list:ScrollToTop()
    for cat,b in pairs(self.categoryButtons) do
        b.props.selected=not query and cat==self.model.category
        local base=self.narrow and 79 or 95.8125;if cat=='shield' then base=base+(self.narrow and 14 or 18.390625) end
        b:SetWidth(base+(b.props.selected and (#b.props.count*6.125+9.1875) or 0))
    end
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
    local focus=UI.GetFocus();local id=focus and focus.inventoryOwner==self and focus.props.partType or self.hoverType
    if id then self.session:AssignHotbar(i,id) else self.session:SelectHotbar(i) end;self.hotbar.Refresh()
end
function M:Keys()
    local typing=UI.GetFocus()==self.search
    if input:GetKeyPress(KEY_ESCAPE) then
        if typing and self.model.query~='' then self.model.query='';self.search:SetValue('');self:Fill() else self:Close() end;return
    end
    local keys=require('ui.InventoryKeys')
    if input:GetKeyPress(KEY_TAB) then keys.Tab(self,input:GetKeyDown(KEY_SHIFT));return end
    if typing then return end
    for _,key in ipairs({KEY_RETURN,KEY_SPACE,KEY_DELETE,KEY_BACKSPACE}) do
        if input:GetKeyPress(key) and keys.Activate(self,key) then return end
    end
    if input:GetKeyPress(KEY_B) then self:Close();return end
    if input:GetKeyPress(KEY_G) then self.model:CycleMaterial();self:Fill() end
    for i,k in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}) do if input:GetKeyPress(k) then self:Digit(i) end end
end
function M:Trim(closing)
    local keep={};for _,id in ipairs(self.model.hotbar) do if id then keep[Theme.Thumbnail(id)]=true end end
    if not closing then
        local shadows=require 'ui.InventoryShadows'
        for _,kind in ipairs({'rest','hover','press'}) do keep['UI/Parts/Shadows/tile-'..kind..'.png']=true end
        keep[Theme.Thumbnail(self.shown)]=true
        keep[shadows.Path(self.shown,'detail')]=true
        for _,id in ipairs(self.model.hotbar) do if id then keep[shadows.Path(id,'slot')]=true end end
        local first,last=self.list:GetVisibleRange()
        for i=first,last do for _,d in ipairs(self.list.props.data[i] or {}) do keep[Theme.Thumbnail(d.id)]=true;keep[shadows.Path(d.id,'card')]=true end end
    end
    Theme.TrimThumbnails(keep)
end
function M:Update(dt)
    self.motionClock=self.motionClock+math.max(0,dt)
    if self.backdrop then self.backdrop:Update() end
    if self.initialFocus and self.modal.modalLayout_ then
        self.initialFocus=false
        local keys=require('ui.InventoryKeys');local current=self.model:Current();local focused=false
        for index,def in ipairs(self.results) do if def.id==current then focused=keys.Focus(self,{part=current,index=index});break end end
        if not focused then keys.Focus(self,{widget=self.closeButton}) end
    end
    if self.restoreScroll and self.modal.modalLayout_ then
        local state=self.restoreScroll;self.restoreScroll=nil
        self.detailScroll:SetScrollDirect(0,math.min(state.detailY or 0,math.max(0,self.detail.props.height+18-self.centerHeight)))
    end
    if self.pendingAnchor and self.modal.modalLayout_ then
        local anchor=self.pendingAnchor;self.pendingAnchor=nil
        for i,def in ipairs(self.results) do if def.id==anchor then self.list:ScrollToIndex(math.floor((i-1)/self.columns)+1);break end end
    end
    self.hotbar.Refresh()
    local target=self.dragType and self.dragPoint and self.hotbar.Hit(self.dragPoint.x,self.dragPoint.y)
    for i,slot in ipairs(self.hotbar.slots) do slot.widget.props.dropTarget=i==target end
    self.trimTime=self.trimTime+dt;if self.trimTime>.5 then self.trimTime=0;self:Trim(false) end
end
function M:Close() if not self.closed then self.modal:Close() end end
return M


