local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local M=Base:Extend('VoxSalvageButton')
function M:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.kind or 'button';local color=p.selected and D.white or D.muted
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.45) end
    if kind=='quantity' then
        Relief.Draw(vg,x,y,w,h,false,true,{x,y,x+w,y,x+w,y+h,x,y+h})
        D.Text(vg,p.text,x+w/2,y+(h-24)/2,p.text=='最大' and 17 or 24,{195,222,244,255},p.text=='最大' and 'vox-body' or 'vox-tabular',NVG_ALIGN_CENTER)
    elseif kind=='segment' then
        Relief.Draw(vg,x,y,w,h,p.selected,true,{x,y,x+w,y,x+w,y+h,x,y+h},false)
        D.Text(vg,p.text,x+w/2,y+(h-24)/2,20,p.selected and D.white or {195,222,244,255},nil,NVG_ALIGN_CENTER)
    elseif kind=='subtab' then
        D.Text(vg,p.text,x+w/2,y+16,20,p.selected and D.white or {173,196,216,255},nil,NVG_ALIGN_CENTER)
        if p.selected then D.Rect(vg,x,y+h-3,w,3,D.orange) end
    elseif kind=='tab' or kind=='category' then
        D.Text(vg,p.text,x+w/2,y+(h-(kind=='tab' and 24 or 18)*1.2)/2,kind=='tab' and 24 or 18,self.state.hovered and D.white or color,nil,NVG_ALIGN_CENTER)
        if p.selected then D.Rect(vg,x+8,y+h-(kind=='tab' and 21 or 3),w-16,3,D.orange) end
    elseif kind=='operation' then
        D.Rect(vg,x,y,w,h,p.selected and {35,65,94,255} or {25,51,77,255});if p.selected then Relief.Halftone(vg,x,y,w,h) end;D.Rect(vg,x,y,3,h,p.selected and D.orange or p.stripe)
        D.Text(vg,p.text,x+18,y+14,22);D.Text(vg,p.subtitle,x+18+D.Width(vg,p.text,22)+12,y+22,12,D.muted,'vox-tabular')
        self.paragraph:Draw(vg,p.description,x+18,y+44,w-58,D.muted);D.Icon(vg,p.disabled and 'lock' or 'star',x+w-31,y+43,17,p.stripe)
    elseif kind=='handle' then
        D.Path(vg,{x+14,y,x+w,y,x+w,y+h,x+14,y+h,x,y+h-14,x,y+14});nvgFillColor(vg,nvgRGBA(20,43,67,255));nvgFill(vg)
        D.Rect(vg,x,y+14,3,h-28,D.orange);D.Icon(vg,'cube',x+19,y+24,25,D.white)
        D.Text(vg,'仓',x+w/2,y+74,26,nil,nil,NVG_ALIGN_CENTER);D.Text(vg,'库',x+w/2,y+111,26,nil,nil,NVG_ALIGN_CENTER)
        D.Text(vg,p.subtitle,x+w/2,y+169,16,D.orange,'vox-tabular',NVG_ALIGN_CENTER);D.Icon(vg,'back',x+23,y+206,16,D.muted)
        if not require('controls.TouchMode').Enabled() then D.Rect(vg,x+15,y+h-47,32,22,{19,36,58,255});D.Text(vg,'Tab',x+w/2,y+h-44,12,D.muted,'vox-code',NVG_ALIGN_CENTER) end
    elseif kind=='mode' then
        D.Rect(vg,x,y,w,h,{16,34,55,255});if p.selected then Relief.Draw(vg,x,y,w,h,false,true,{x,y,x+w,y,x+w,y+h,x,y+h}) end
        D.Rect(vg,x+7,y+7,36,36,p.selected and {185,231,255,255} or {20,43,67,255});D.Icon(vg,p.icon,x+15,y+15,20,p.selected and D.ink or D.muted)
        D.Text(vg,p.text,x+53,y+5,20);D.Text(vg,p.subtitle,x+53,y+31,12,D.muted,'vox-body')
        if p.selected then D.Rect(vg,x,y+h-3,w,3,D.orange) else D.Icon(vg,'swap',x+w-30,y+18,14,D.orange) end
    elseif kind=='trader' or kind=='gear' then
        D.Rect(vg,x,y,w,h,p.selected and {35,65,94,255} or {25,51,77,255});if p.selected then Relief.Halftone(vg,x,y,w,h) end;D.Rect(vg,x+12,y+12,40,40,p.selected and D.orange or {32,58,84,255})
        D.Icon(vg,p.icon,x+22,y+22,20,p.selected and D.ink or D.muted);D.Text(vg,p.text,x+64,y+10,19);D.Text(vg,p.subtitle,x+64,y+37,13,D.muted,'vox-body')
        if p.selected then D.Rect(vg,x,y+h-3,w,3,D.orange) end
    elseif kind=='slot' then
        D.Rect(vg,x,y,w,h,{32,58,84,35})
        for at=0,w-6,12 do D.Rect(vg,x+at,y,6,1,{145,172,200,70});D.Rect(vg,x+at,y+h-1,6,1,{145,172,200,70}) end
        for at=0,h-6,12 do D.Rect(vg,x,y+at,1,6,{145,172,200,70});D.Rect(vg,x+w-1,y+at,1,6,{145,172,200,70}) end
        D.Icon(vg,'plus',x+w/2-11,y+h/2-11,22,D.muted)
        if p.text~='' then D.Text(vg,p.text,x+w/2,y+h/2+20,19,nil,nil,NVG_ALIGN_CENTER) end
    elseif kind=='ghost' then D.Icon(vg,p.icon,x,y+12,18,D.muted);D.Text(vg,p.text,x+26,y+12,16,D.muted,'vox-body')
    else
        local primary=kind=='primary';local cut=primary and 26 or 14
        Relief.Draw(vg,x,y,w,h,primary or p.selected,not primary,primary and {x,y,x+w,y,x+w-cut,y+h,x,y+h} or {x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x,y+h})
        if primary then
            D.Text(vg,p.text,x+32,y+9,36);D.Text(vg,p.subtitle or '',x+32,y+55,14,{228,244,255,255},'vox-body')
        else
            local offset=p.icon and 50 or 22;if p.icon then D.Icon(vg,p.icon,x+22,y+(h-20)/2,20,D.muted) end
            D.Text(vg,p.text,x+offset,y+(h-22)/2,19)
        end
        if p.key then local kw=D.Width(vg,p.key,14,'vox-code')+16;D.Rect(vg,x+w-cut-kw-14,y+h/2-11,kw,22,{19,36,58,180});D.Text(vg,p.key,x+w-cut-kw-6,y+h/2-8,14,D.white,'vox-code') end
    end
    if self.state.hovered and not p.disabled and kind~='tab' and kind~='category' then D.Rect(vg,x+3,y+3,w-6,h-6,{255,255,255,10}) end
    nvgRestore(vg)
end
return M
