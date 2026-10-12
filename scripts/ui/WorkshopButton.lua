local Base=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Button=Base:Extend('VoxWorkshopSourceButton')
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.sourceKind;local c=D.white
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.45) end
    if kind=='tab' or kind=='sort' then
        c=(p.selected or self.state.hovered) and D.white or {219,238,255,kind=='sort' and 115 or 128}
        if kind=='sort' and p.separator then D.Text(vg,'/',x,y+8,13,{255,255,255,77},nil,nil,1) end
        D.Text(vg,p.text,x+(kind=='tab' and 16 or 12),y+8,kind=='tab' and 19 or 13,c)
        if p.count then D.Text(vg,p.count,x+w-18,y+5,11,c) end
        if kind=='tab' and p.selected then D.Rect(vg,x+14,y+h-5,w-28,3,D.orange) end
    else
        if kind=='view' or kind=='all' or kind=='go' then Relief.Draw(vg,x,y,w,h,true,false,{x,y,x+w-14,y,x+w,y+14,x+w,y+h,x,y+h})
        elseif kind=='back' then Relief.Draw(vg,x,y,w,h,false,false,{x,y,x+w,y,x+w,y+h-14,x+w-14,y+h,x,y+h})
        elseif kind=='control' then
            c=p.selected and D.ink or {219,238,255,153}
            if p.selected then D.Rect(vg,x,y,w,h,D.orange) end
        elseif kind=='add' or kind=='ghost' or kind=='pager' then
            local cut=kind=='ghost' and 10 or kind=='pager' and 0 or 14
            D.Path(vg,{x,y,x+w,y,x+w,y+h-cut,x+w-cut,y+h,x,y+h});nvgFillColor(vg,nvgRGBA(8,15,28,kind=='ghost' and 140 or 153));nvgFill(vg)
            local edge=kind=='add' and {219,238,255,89} or {122,216,255,77}
            D.Rect(vg,x,y,w,1,edge);D.Rect(vg,x,y,1,h,edge)
            D.Rect(vg,x+w-1,y,1,h-cut,edge);D.Rect(vg,x,y+h-1,w-cut,1,edge)
        end
        if self.state.hovered and not p.disabled then D.Rect(vg,x,y,w,h,{255,255,255,24}) end
        if kind=='view' then
            D.Icon(vg,'eye',x+20,y+18,28);D.Text(vg,p.text,x+62,y+10,22,{255,255,255,255},nil,nil,3);D.Text(vg,'实景 3D 预览',x+62,y+39,12,{237,246,255,191},'vox-body')
        elseif kind=='go' then
            D.Rect(vg,x,y,70,h,{8,15,28,64});D.Icon(vg,'plus',x+20,y+20,30)
            D.Text(vg,p.text,x+88,y+11,26,nil,nil,nil,4);D.Text(vg,'现有的车不受影响',x+88,y+44,12,{237,246,255,179},'vox-body')
            local kw=D.Width(vg,'Enter',11)+18;local kx=x+w-20-kw;local ky=y+(h-22)/2
            D.Rect(vg,kx,ky,kw,22,{8,15,28,89})
            D.Line(vg,kx,ky,kx+kw,ky,{255,255,255,89});D.Line(vg,kx,ky+22,kx+kw,ky+22,{255,255,255,89})
            D.Line(vg,kx,ky,kx,ky+22,{255,255,255,89});D.Line(vg,kx+kw,ky,kx+kw,ky+22,{255,255,255,89})
            D.Text(vg,'Enter',kx+9,ky+4,11,{255,255,255,255})
        else
            local size=kind=='add' and 16 or kind=='all' and 16 or kind=='control' and 13 or 14
            local icon=(kind=='add' or kind=='back') and 18 or 17;local ix=x+(kind=='all' and 20 or kind=='add' and 22 or kind=='back' and 14 or 12)
            if kind=='pager' then
                nvgSave(vg);nvgTranslate(vg,x+w/2,y+h/2);nvgRotate(vg,math.rad(p.iconRotation));D.Icon(vg,'chev',-12,-12,24);nvgRestore(vg)
                nvgRestore(vg);return
            end
            if p.icon then D.Icon(vg,p.icon,ix,y+(h-icon)/2,icon,kind=='ghost' and D.orange or c) end
            local tx=ix+(p.icon and icon+8 or 0)
            D.Text(vg,p.text or '',tx,y+(h-size*1.2)/2,size,kind=='add' and {255,255,255,255} or kind=='ghost' and {237,246,255,217} or c,nil,nil,kind=='add' and 2 or kind=='all' and 3 or 1)
            if p.count then D.Rect(vg,x+w-70,y+13,28,18,{255,255,255,255});D.Text(vg,p.count,x+w-56,y+14,13,D.ink,'vox-tabular',NVG_ALIGN_CENTER) end
            if kind=='all' then nvgSave(vg);nvgTranslate(vg,x+w-18,y+h/2);nvgRotate(vg,-math.pi/2);D.Icon(vg,'chev',-9,-9,18);nvgRestore(vg) end
        end
    end
    nvgRestore(vg)
end
return Button
