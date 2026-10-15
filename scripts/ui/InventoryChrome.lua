-- Frozen new-ui-inventory.css, including final new-ui-controls.css overrides.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local BaseButton=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Theme=require 'ui.VoxTheme'
local Defs=require 'parts.Defs'
local Feedback=require 'ui.InventoryFeedback'
local Shadows=require 'ui.InventoryShadows'
local M={icons={all='workshop',structure='cube',frame='truss',movement='wheel',weapon='crosshair',['function']='bolt',shield='shield',decor='decor'}}
M.Modal=require('ui.OwnedModal'):Extend('VoxInventoryModal')
function M.Modal:RenderModalContent(vg)
    if not self.isOpen_ then return end;D.Begin(vg)
    local sw,sh=UI.GetViewportSize();local compact=sh<=600 and sw>sh
    local w,h=math.min(1580,sw*.94),math.min(960,sh*.92)
    if compact then w=sw-24;h=sh-12 end
    local x,y=(sw-w)/2,(sh-h)/2;local alpha=self.animProgress_;y=y+14*(1-alpha)^3
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    -- CSS linear-gradient(110deg, start, middle 63%, end).
    local dx,dy=math.sin(math.rad(110)),-math.cos(math.rad(110))
    local length=sw*dx+sh*dy;local sx,sy=(sw-dx*length)/2,(sh-dy*length)/2
    local mx,my=sx+dx*length*.63,sy+dy*length*.63
    local reach=math.max(sw,sh)*2
    local function Band(a,b,x0,y0,x1,y1,c0,c1)
        local ax,ay=sx+dx*length*a,sy+dy*length*a
        local bx,by=sx+dx*length*b,sy+dy*length*b
        D.Path(vg,{ax-dy*reach,ay+dx*reach,bx-dy*reach,by+dx*reach,bx+dy*reach,by-dx*reach,ax+dy*reach,ay-dx*reach})
        nvgFillPaint(vg,nvgLinearGradient(vg,x0,y0,x1,y1,D.Color(c0),D.Color(c1)));nvgFill(vg)
    end
    nvgSave(vg);nvgIntersectScissor(vg,0,0,sw,sh)
    Band(-1,.63,sx,sy,mx,my,{6,17,32,219},{7,23,42,179})
    Band(.63,2,mx,my,sx+dx*length,sy+dy*length,{7,23,42,179},{7,22,38,214})
    nvgRestore(vg)
    self.modalLayout_={x=x,y=y,w=w,h=h};self.closeButtonLayout_=nil
    local content=self.contentContainer_;YGNodeCalculateLayout(content.node,w,h,YGDirectionLTR)
    content.renderOffsetX_=x;content.renderOffsetY_=y;content.renderWidth_=w;content.renderHeight_=h
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h);UI.RenderWidgetSubtree(content,vg);nvgRestore(vg);nvgRestore(vg)
end
M.Button=BaseButton:Extend('VoxInventoryButton')
function M.Button:Update(dt) Feedback.Button(self,dt) end
function M.Button:OnPointerDown(event)
    if self.inventoryKeyOwner then self.inventoryKeyOwner.keyboardFocus=nil end
    BaseButton.OnPointerDown(self,event)
end
function M.Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local on=p.selected;local focused=Feedback.Focused(self);local motion=self.inventoryFeedback
    local hover=motion and motion.hover.value or 0
    local color=Feedback.Color(on and D.white or Feedback.Mix(D.muted,p.kind=='material' and D.white or D.orange,hover),focused)
    local function Face(points)
        D.Path(vg,points);nvgFillColor(vg,D.Color(Feedback.Color(Feedback.Mix({25,62,110,255},{33,76,128,255},hover),focused)));nvgFill(vg)
        Feedback.Edges(vg,r,points,p.kind=='material' and on,focused)
    end
    if p.kind=='category' then
        local size=p.compact and 14 or 18;local pad=p.compact and 12 or 17
        D.Icon(vg,p.icon,x+pad,y+(h-18)/2,18,on and D.orange or color)
        D.Text(vg,p.text,x+pad+25,y+(h-size*1.2)/2,size,color,nil,nil,p.compact and 0 or .4)
        if on then
            D.Text(vg,p.count,x+w-pad,y+(h-13.2)/2,11,D.orange,'vox-body',NVG_ALIGN_RIGHT)
            D.Rect(vg,x+16,y+h-3,w-32,3,D.orange)
        end
        if focused then nvgBeginPath(vg);nvgRect(vg,x-4,y-4,w+8,h+8);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg) end
    elseif p.kind=='material' then
        Face({x,y,x+w-7,y,x+w,y+7,x+w,y+h,x,y+h})
        local a,b={230,233,238,255},{167,173,182,255};local c=p.material
        if c=='heavy' then a,b={141,147,156,255},{85,91,100,255} elseif c=='glass' then a,b={159,220,255,217},{159,220,255,64} elseif c=='neon' then a,b=D.orange,D.orange end
        nvgBeginPath(vg);nvgRect(vg,x+10,y+(h-11)/2,11,11);nvgFillPaint(vg,nvgLinearGradient(vg,x+10,y+(h-11)/2,x+21,y+(h+11)/2,D.Color(a),D.Color(b)));nvgFill(vg)
        if c=='heavy' then D.Rect(vg,x+12,y+(h-7)/2,7,7,{34,37,42,255}) end
        D.Text(vg,p.text,x+28,y+(h-15.6)/2,13,color,'vox-body')
    elseif p.kind=='more' or p.kind=='instructions' then
        if p.kind=='more' then D.Rect(vg,x,y,w,1,{65,100,134,255});D.Rect(vg,x,y+h-1,w,1,{65,100,134,255}) end
        local fs=p.kind=='more' and 12 or 10
        D.Text(vg,p.text,x,y+(h-fs*1.2)/2,fs,D.orange,'vox-body')
        if p.count then D.Text(vg,p.count..' 项',x+w-24,y+(h-12)/2,10,D.muted,'vox-body',NVG_ALIGN_RIGHT) end
        nvgSave(vg);nvgTranslate(vg,x+w-8,y+h/2);nvgRotate(vg,math.pi*(p.kind=='more' and motion and motion.arrow.value or on and 1 or 0));D.Icon(vg,'chev',-6,-6,12,D.orange);nvgRestore(vg)
        if focused then nvgBeginPath(vg);nvgRect(vg,x-4,y-4,w+8,h+8);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg) end
    else
        Face({x,y,x+w-14,y,x+w,y+14,x+w,y+h,x,y+h})
        D.Icon(vg,'close',x+12,y+(h-18)/2,18,Feedback.Color(D.orange,focused));D.Text(vg,'关闭',x+38,y+(h-19.2)/2,16,Feedback.Color(D.white,focused))
        D.Text(vg,'B',x+w-26,y+(h-14.4)/2,12,Feedback.Color({188,215,235,255},focused),'vox-body')
    end
end
M.Card=Panel:Extend('VoxInventoryCard')
function M.Card:Update(dt) require('ui.InventoryCardMotion').Update(self,dt) end
function M.Card:OnMouseEnter() self:SetState({hovered=true}) end
function M.Card:OnMouseLeave() self:SetState({hovered=false,pressed=false}) end
function M.Card:OnMouseDown(_,_,button) if button==MOUSEB_LEFT then self:SetState({pressed=true}) end end
function M.Card:OnMouseUp() self:SetState({pressed=false}) end
function M.Card:Render(vg)
    local p=self.props;local def=Defs.PARTS[p.partType];if not def then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h
    local inv=self.inventory;local slot=false
    for i,t in ipairs(inv.hotbar) do if t==def.id then slot=i;break end end
    local focused=self.inventoryOwner and self.inventoryOwner.keyboardFocus==self and UI.GetFocus()==self
    local current=slot==inv.active;local motion=self.inventoryMotion
    local hover=motion and motion.hover.value or 0;local image=motion and motion.image.value or 0
    local points={x,y,x+w-15,y,x+w,y+15,x+w,y+h,x,y+h}
    Shadows.Tile(self,vg,r,motion)
    local face=current and 1 or hover
    D.Path(vg,points);nvgFillColor(vg,nvgRGBA(32+9*face,58+12*face,84+11*face,255));nvgFill(vg)
    Relief.Halftone(vg,x,y,w,h,false,165,points)
    if current then D.Rect(vg,x,y+h-3,w,3,D.orange) end
    local size=p.compact and 60 or 94;local imageY=y+(p.compact and 7 or 12)
    nvgSave(vg);local ix,iy=x+w/2,imageY+size/2
    nvgTranslate(vg,ix,iy-2*image);nvgRotate(vg,math.rad(-3)*image);nvgScale(vg,1+.06*image,1+.06*image);nvgTranslate(vg,-ix,-iy)
    Shadows.Image(self,vg,def.id,'card',{x=x+(w-size)/2,y=imageY,w=size,h=size})
    self:RenderBackgroundImage(vg,Theme.Thumbnail(def.id),{x=x+(w-size)/2,y=imageY,w=size,h=size},'contain',nil)
    nvgRestore(vg)
    if slot then
        local top=y+h-57
        D.Rect(vg,x+w-21,top,21,20,D.orange)
        D.Text(vg,slot%10,x+w-10.5,top,13,D.ink,'vox-body',NVG_ALIGN_CENTER,nil,false,20)
    end
    local fs=p.compact and 12 or 16;local name=def.name
    while D.Width(vg,name,fs)>w-20 and utf8.len(name)>1 do name=name:sub(1,utf8.offset(name,-1)-1) end
    if name~=def.name then
        while D.Width(vg,name..'…',fs)>w-20 and utf8.len(name)>1 do name=name:sub(1,utf8.offset(name,-1)-1) end
        name=name..'…'
    end
    local remaining=self.inventoryOwner and self.inventoryOwner.Remaining and self.inventoryOwner:Remaining(def.id)
    local out=remaining~=nil and remaining<=0
    D.Text(vg,name,x+w/2,y+h-(p.compact and 22 or 31),fs,out and {238,247,255,166} or nil,nil,NVG_ALIGN_CENTER)
    if focused then
        nvgBeginPath(vg);nvgRect(vg,x-3,y-3,w+6,h+6);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg)
    end
    local budget=motion and motion.budget.value or 0
    if budget>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,budget);nvgTranslate(vg,0,-5*(1-budget))
        local cost=def.budget>0 and ('预算 '..def.budget) or '免费';local cw=D.Width(vg,cost,10,'vox-body')+26
        D.Rect(vg,x+8,y+8,cw,19,{219,238,255,255});D.Icon(vg,'chip',x+14,y+11,12,{36,91,145,255})
        D.Text(vg,cost,x+29,y+11,10,{24,60,92,255},'vox-body');nvgRestore(vg)
    end
    if remaining~=nil then
        local text=out and '购买' or ('×'..remaining);local bw=D.Width(vg,text,10,'vox-body')+10+(out and 15 or 0)
        local bx=x+w-8-bw;D.Rect(vg,bx,y+7,bw,20,out and {214,185,126,255} or {17,38,61,255})
        if out then D.Icon(vg,'plus',bx+5,y+11,12,{25,37,52,255}) end
        D.Text(vg,text,bx+5+(out and 15 or 0),y+8,10,out and {25,37,52,255} or {219,238,255,255},'vox-body',nil,nil,false,18)
    end
end
function M.Title(owner)
    local p=Panel{position='absolute',left=0,top=0,width=450,height=owner.narrow and 48 or 76,pointerEvents='none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();local compact=owner.narrow;local tx=r.x+(compact and 34 or 42)
        D.Icon(vg,'workshop',r.x,r.y+(compact and 13 or 23),compact and 22 or 30,D.orange)
        D.Text(vg,'机库 · 装配终端',tx,r.y+(compact and 3 or 12.5),compact and 9 or 10,D.muted,'vox-body',nil,2)
        local fs=compact and 24 or 36;D.Text(vg,'零件库',tx,r.y+(compact and 16 or 27.5),fs,nil,nil,nil,2)
        if not compact then D.Text(vg,owner.countText or '',tx+D.Width(vg,'零件库',fs,nil,2)+20,r.y+37,12,D.muted,'vox-body') end
    end;return p
end
function M.MaterialHeader(compact)
    local p=Panel{pointerEvents='box-none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();D.Text(vg,'方块材质',r.x,r.y+(compact and 15 or 9),12,D.muted,'vox-body')
        if r.w>470 then D.Text(vg,'G  换材质',r.x+r.w,r.y+9,10,D.muted,'vox-body',NVG_ALIGN_RIGHT) end
    end;return p
end
function M.Footer()
    local p=Panel{position='absolute',left=0,bottom=0,width='100%',height=135,pointerEvents='box-none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y,r.w,1,{54,86,117,255})
    end
    local line=Panel{position='absolute',left='50%',marginLeft=-121.15625,bottom=3,width=242.3125,height=28,zIndex=3,pointerEvents='box-none'}
    function line:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout()
        D.Text(vg,'选择零件放入快捷栏 · 拖动分配位置',r.x+r.w-84,r.y+8,10,D.muted,'vox-body',NVG_ALIGN_RIGHT)
    end
    line:AddChild(M.Button{kind='instructions',text='操作说明',width=58,height=28,position='absolute',right=0,top=0,onClick=function(b)
        b.props.selected=not b.props.selected;p.tip:SetVisible(b.props.selected)
    end})
    local tips={
        {{'左键 / Enter',true},{' 放进选中的格子'}},
        {{'指着或聚焦零件按 '},{'1–0',true},{' 放进对应格子'}},
        {{'拖动',true},{' 到格子'}},
        {{'双击',true},{' 放入并关闭'}},
        {{'格子上 '},{'右键 / Delete',true},{' 清空'}},
        {{'G',true},{' 换材质 · '},{'Q',true},{' 选块后 '},{'F',true},{' 连块 / 拆开'}},
    }
    -- Frozen Chromium measurement: six 16.390625px rows, 12px gaps, 20px padding.
    p.tip=Panel{position='absolute',right=0,bottom=35,width=430,height=198.34375,visible=false,pointerEvents='none'}
    function p.tip:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout()
        self.sourceShadow=self.sourceShadow or require('ui.SourceBoxShadow').New()
        self.sourceShadow:Draw(vg,r.x,r.y+3,r.w,r.h,10,nvgRGBA(4,12,22,64))
        D.Rect(vg,r.x,r.y,r.w,r.h,{17,43,69,255})
        for i,row in ipairs(tips) do
            local x,y=r.x+20,r.y+20+(i-1)*28.390625
            for _,span in ipairs(row) do
                local key=span[2];local fs=key and 11 or 12
                D.Text(vg,span[1],x+(key and 5 or 0),y+(key and 1 or 0),fs,key and D.orange or D.white,'vox-body')
                x=x+D.Width(vg,span[1],fs,'vox-body')+(key and 10 or 0)
            end
        end
    end
    function p.tip:Destroy()
        if self.sourceShadow then self.sourceShadow:Dispose();self.sourceShadow=nil end
        Panel.Destroy(self)
    end
    line:AddChild(p.tip);p:AddChild(line);return p
end
return M
