-- Measured from shared/css/style.css .inv-* at the PC viewport.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local BaseButton=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Key=require('ui.BuildButton').Key
local Theme=require 'ui.VoxTheme'
local Defs=require 'parts.Defs'
local M={icons={all='workshop',structure='cube',frame='truss',movement='wheel',weapon='crosshair',['function']='bolt',decor='decor'}}
M.Modal=require('ui.OwnedModal'):Extend('VoxInventoryModal')
function M.Modal:RenderModalContent(vg)
    if not self.isOpen_ then return end;D.Begin(vg)
    local sw,sh=UI.GetViewportSize();local w,h=math.min(1500,sw*.94),math.min(900,sh*.9)
    local x,y=(sw-w)/2,(sh-h)/2;local alpha=self.animProgress_;y=y+14*(1-alpha)^3
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    nvgSave(vg);nvgTranslate(vg,sw/2,sh*.45);nvgScale(vg,sw/sh,1)
    nvgBeginPath(vg);nvgRect(vg,-sh/2,-sh*.45,sh,sh)
    nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,sh*.6,nvgRGBA(14,15,18,209),nvgRGBA(6,7,9,245)));nvgFill(vg);nvgRestore(vg)
    self.modalLayout_={x=x,y=y,w=w,h=h};self.closeButtonLayout_=nil
    local content=self.contentContainer_;YGNodeCalculateLayout(content.node,w,h,YGDirectionLTR)
    content.renderOffsetX_=x;content.renderOffsetY_=y;content.renderWidth_=w;content.renderHeight_=h
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h);UI.RenderWidgetSubtree(content,vg);nvgRestore(vg);nvgRestore(vg)
end
M.Button=BaseButton:Extend('VoxInventoryButton')
function M.Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local on=p.selected;local color=(on or self.state.hovered) and D.white or D.muted
    if p.kind=='category' then
        D.Icon(vg,p.icon,x+20,y+17,20,on and D.orange or color)
        D.Text(vg,p.text,x+48,y+16,19,color,nil,nil,1);D.Text(vg,p.count,x+w-20,y+20,15,D.dim,nil,NVG_ALIGN_RIGHT,1)
        if on then D.Rect(vg,x+12,y+h-2,w-24,3,D.orange) end
    elseif p.kind=='material' then
        D.Panel(vg,x,y,w,h,0);if self.state.hovered then D.Rect(vg,x,y,w,h,{255,255,255,18}) end
        local c=p.material;local a,b={230,233,238,255},{167,173,182,255}
        if c=='heavy' then a,b={141,147,156,255},{85,91,100,255} elseif c=='glass' then a,b={159,220,255,217},{159,220,255,64} elseif c=='neon' then a,b=D.blue,D.blue end
        nvgBeginPath(vg);nvgRect(vg,x+8,y+8,18,18);nvgFillPaint(vg,nvgLinearGradient(vg,x+8,y+8,x+26,y+26,D.Color(a),D.Color(b)));nvgFill(vg)
        if c=='heavy' or c=='glass' then nvgBeginPath(vg);nvgRect(vg,x+9.5,y+9.5,15,15);nvgStrokeWidth(vg,c=='heavy' and 3 or 1);nvgStrokeColor(vg,D.Color(c=='heavy' and {34,37,42,255} or {255,255,255,128}));nvgStroke(vg) end
        D.Text(vg,p.text,x+34,y+7,17,color);D.Text(vg,'预算 '..p.budget,x+w-14,y+10,12,D.dim,'vox-body',NVG_ALIGN_RIGHT)
        if on then D.Rect(vg,x,y+h-3,w,3,D.orange) end
    else
        D.Panel(vg,x,y,w,h,0);D.Icon(vg,'close',x+12,y+12,18,D.muted);D.Text(vg,'关闭',x+38,y+10,18)
        Key(vg,'B',x+w-32,y+12,12)
    end
end
M.Card=Panel:Extend('VoxInventoryCard')
function M.Card:Render(vg)
    local p=self.props;local def=Defs.PARTS[p.partType];if not def then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h
    local inv=self.inventory
    ---@type integer?
    local slot
    for i,t in ipairs(inv.hotbar) do if t==def.id then slot=i;break end end
    if self.state.hovered then y=y-4 end
    D.Path(vg,{x,y,x+w-14,y,x+w,y+14,x+w,y+h,x,y+h});nvgSave(vg)
    nvgIntersectScissor(vg,x,y,w,h*.7);D.Gradient(vg,x,y,w,h*.7,{44,48,55,255},{29,32,37,255});nvgRestore(vg)
    D.Path(vg,{x,y+h*.7,x+w,y+h*.7,x+w,y+h,x,y+h});D.Gradient(vg,x,y+h*.7,w,h*.3,{29,32,37,255},{24,26,30,255})
    D.Rect(vg,x,y,w-14,1,{255,255,255,23});D.Rect(vg,x,y+h-3,w,3,{0,0,0,102})
    if slot==inv.active then D.Path(vg,{x+1,y+1,x+w-14,y+1,x+w-1,y+14,x+w-1,y+h-1,x+1,y+h-1});nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg) end
    local size=self.state.hovered and 88.56 or 82
    self:RenderBackgroundImage(vg,Theme.Thumbnail(def.id),{x=x+(w-size)/2,y=y+6-(size-82)/2,w=size,h=size},'contain',nil)
    if slot then D.Rect(vg,x,y,24,22,D.orange);D.Text(vg,slot%10,x+12,y+2,16,D.ink,nil,NVG_ALIGN_CENTER) end
    nvgSave(vg);nvgIntersectScissor(vg,x+6,y+99,w-12,21);D.Text(vg,def.name,x+w/2,y+100,16,nil,nil,NVG_ALIGN_CENTER);nvgRestore(vg)
    local cost=def.budget>0 and tostring(def.budget) or '免费';local cw=D.Width(vg,cost,14)+16
    D.Icon(vg,'chip',x+(w-cw)/2,y+117,13,D.orange);D.Text(vg,cost,x+(w-cw)/2+16,y+115,14,D.muted)
end
function M.Title(owner)
    local p=Panel{position='absolute',left=0,top=0,width=450,height=64,pointerEvents='none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();D.Icon(vg,'workshop',r.x,r.y+16,32,D.orange)
        D.Text(vg,'零件库',r.x+44,r.y+10,40,nil,nil,nil,1);D.Text(vg,owner.countText or '',r.x+161,r.y+23,17,D.muted)
    end;return p
end
function M.MaterialHeader()
    local p=Panel{position='absolute',left=2,top=16,right=14,height=38,pointerEvents='box-none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();D.Text(vg,'方块材质',r.x+2,r.y+8,16,D.muted,nil,nil,1)
        local text='切换材质 · 每种材质 23 种形状';local tw=D.Width(vg,text,12,'vox-body');local x=r.x+r.w-tw-28
        -- Source itself drops no controls on PC. The hint is allowed to clip in a narrow PC window.
        if x>r.x+545 then Key(vg,'G',x,r.y+8,12);D.Text(vg,text,x+25,r.y+9,12,D.dim,'vox-body') end
    end;return p
end
function M.Footer()
    local p=Panel{position='absolute',left=0,bottom=0,width='100%',height=124,pointerEvents='box-none'}
    function p:Render(vg)
        D.Begin(vg);local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y,r.w,1,{255,255,255,26})
        if require('controls.TouchMode').Enabled() then
            D.Text(vg,'先选下方格子，再点零件装入 · 上下滑动浏览 · 点右上角关闭返回改装',r.x+r.w/2,r.y+101,13,D.muted,'vox-body',NVG_ALIGN_CENTER)
            return
        end
        local runs={{'左键',' 放进选中的格子'},{nil,'指着零件按 ', '1–0',' 放进对应格子'},{'拖动',' 到格子'},{'双击',' 放入并关闭'},{nil,'格子上 ','右键',' 清空'}}
        local widths={};local total=0
        for i,t in ipairs(runs) do local ww=D.Width(vg,t[2],12,'vox-body');if t[1] then ww=ww+D.Width(vg,t[1],12)+8 end;if t[3] then ww=ww+D.Width(vg,t[3],12)+8+D.Width(vg,t[4],12,'vox-body') end;widths[i]=ww;total=total+ww end
        local x=r.x+(r.w-total-80)/2;local y=r.y+101
        for i,t in ipairs(runs) do local tx=x;if t[1] then tx=tx+Key(vg,t[1],tx,y,12) end;D.Text(vg,t[2],tx,y+1,12,D.muted,'vox-body');tx=tx+D.Width(vg,t[2],12,'vox-body');if t[3] then tx=tx+Key(vg,t[3],tx,y,12);D.Text(vg,t[4],tx,y+1,12,D.muted,'vox-body') end;x=x+widths[i]+20 end
    end;return p
end
return M

