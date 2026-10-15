local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Button=require('urhox-libs/UI/Widgets/Button'):Extend('VoxTouchEditorButton')
local Surface=UI.Panel:Extend('VoxTouchEditorSurface')
local M={Button=Button,Surface=Surface}
local function Cut(x,y,w,h,c) return {x,y,x+w-c,y,x+w,y+c,x+w,y+h,x,y+h} end
function Button:Render(vg)
    D.Begin(vg);D.HudFont(vg);local r=self:GetAbsoluteLayout();local p=self.props;local s=p.sourceScale or 1
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,s,s)
    local w,h=r.w/s,r.h/s;local selected=p.selected or self.state.pressed;local points=Cut(0,0,w,h,p.kind=='slot' and 7 or p.kind=='square' and 8 or 9)
    local color=selected and {155,215,250,255} or {237,246,255,255}
    if p.kind=='swatch' then
        local c=p.hex or 0;D.Path(vg,points);nvgFillColor(vg,nvgRGBA((c>>16)&255,(c>>8)&255,c&255,255));nvgFill(vg)
        if p.auto then nvgSave(vg);nvgIntersectScissor(vg,0,0,w,h);for x=-h,w,8 do D.Path(vg,{x,0,x+4,0,x+h+4,h,x+h,h});nvgFillColor(vg,nvgRGBA(213,221,229,255));nvgFill(vg) end;nvgRestore(vg) end
        if selected then nvgBeginPath(vg);nvgRect(vg,1,1,w-2,h-2);nvgStrokeColor(vg,nvgRGBA(255,255,255,255));nvgStrokeWidth(vg,2);nvgStroke(vg) end
    elseif p.kind=='chip' then
        D.Path(vg,points);nvgFillColor(vg,D.Color(selected and {42,85,131,255} or {22,44,67,255}));nvgFill(vg);D.Rect(vg,0,0,3,h,{155,215,250,255})
        D.Path(vg,{10,20,16.5,7,29.5,7,36,20,29.5,33,16.5,33});nvgFillColor(vg,nvgRGBA(155,215,250,255));nvgFill(vg)
        D.Text(vg,p.tier or '',23,13,11,{14,33,52,255},'vox-hud',NVG_ALIGN_CENTER)
        nvgSave(vg);nvgIntersectScissor(vg,44,0,p.nameWidth or 120,h);D.Text(vg,p.text or '',44,11,15,color,'vox-title',nil,1);nvgRestore(vg)
        local bx=44+(p.nameWidth or 120)+8
        if not p.narrow then D.Text(vg,'预算',bx,15,10,{159,186,210,255},'vox-title',nil,1);bx=bx+26 end
        D.Text(vg,p.budget or '0',bx,10,15,color,'vox-hud');D.Icon(vg,'chev',w-30,11,18,{155,215,250,204})
    else
        if p.kind=='slot' then
            D.Path(vg,points);nvgFillColor(vg,D.Color(selected and {42,85,131,255} or {27,53,80,255}));nvgFill(vg)
            D.Rect(vg,0,0,w-7,1,{142,198,249,77});D.Rect(vg,0,h-1,w,1,{11,36,75,255})
        else Relief.Draw(vg,0,0,w,h,p.primary,true,points,true) end
        if selected then D.Path(vg,points);nvgFillColor(vg,nvgRGBA(42,85,131,255));nvgFill(vg);D.Rect(vg,0,h-3,w,3,{155,215,250,255}) end
        if p.kind=='slot' then
            if p.partType then local z=math.min(w,h)*.84;self:RenderBackgroundImage(vg,require('ui.VoxTheme').Thumbnail(p.partType),{x=(w-z)/2,y=(h-z)/2,w=z,h=z},'contain',nil)
            else D.Icon(vg,'plus',(w-14)/2,(h-14)/2,14,{237,246,255,115}) end
        elseif p.kind=='row' then
            D.Rect(vg,4,4,32,32,{16,37,58,255});D.Icon(vg,p.icon,11.5,11.5,17,selected and color or {174,196,218,255})
            D.Text(vg,p.text or '',46,11,15,color,'vox-title',nil,1)
            if p.toggle~=nil then
                local tx=w-50;D.Panel(vg,tx,10,38,20,5,{16,37,58,255},{16,37,58,255});if p.toggle then D.Rect(vg,tx,10,38,20,{45,122,203,255}) end;D.Rect(vg,tx+(p.toggle and 21 or 3),13,14,14,p.toggle and {237,246,255,255} or {105,137,167,255})
            elseif p.detail then D.Text(vg,p.detail,w-12,15,11,{174,196,218,255},'vox-title',NVG_ALIGN_RIGHT) end
            if selected then D.Rect(vg,0,0,4,h,{155,215,250,255}) end
        elseif p.kind=='segment' then D.Text(vg,p.text or '',w/2,(h-12)/2,12,color,'vox-title',NVG_ALIGN_CENTER)
        elseif p.row then
            local label=p.narrow and '' or p.text or '';local iw=p.icon and 18 or 0;local tw=D.Width(vg,label,15,'vox-title',1);local x=(w-iw-(label~='' and 7+tw or 0))/2
            if p.icon then D.Icon(vg,p.icon,x,(h-18)/2,18,color) end;if label~='' then D.Text(vg,label,x+iw+7,(h-15)/2,15,color,'vox-title',nil,1) end
        else
            if p.hex then local c=p.hex;D.Path(vg,Cut((w-22)/2,4,22,20,5));nvgFillColor(vg,nvgRGBA((c>>16)&255,(c>>8)&255,c&255,255));nvgFill(vg)
                if p.auto then nvgSave(vg);nvgIntersectScissor(vg,(w-22)/2,4,22,20);for x=(w-22)/2-20,(w+22)/2,8 do D.Path(vg,{x,4,x+4,4,x+24,24,x+20,24});nvgFillColor(vg,nvgRGBA(213,221,229,255));nvgFill(vg) end;nvgRestore(vg) end
            else nvgSave(vg);if p.flip then nvgTranslate(vg,w,h-16);nvgRotate(vg,math.pi) end;D.Icon(vg,p.icon,(w-18)/2,p.kind=='square' and 5 or 8,18,color);nvgRestore(vg) end
            D.Text(vg,p.text or '',w/2,h-14,10,selected and color or {215,233,248,255},'vox-title',NVG_ALIGN_CENTER,1)
            if p.more then D.Path(vg,{w-11,h-3,w-3,h-3,w-3,h-11});nvgFillColor(vg,nvgRGBA(155,215,250,255));nvgFill(vg) end
        end
    end
    nvgRestore(vg)
end
function Surface:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.props.sourceScale or 1
    if self.props.kind=='dock' then local points=Cut(r.x,r.y,r.w,r.h,12*s);D.Path(vg,points);nvgFillColor(vg,nvgRGBA(14,33,52,255));nvgFill(vg);Relief.Halftone(vg,r.x,r.y,r.w,r.h,false,nil,points)
    elseif self.props.kind=='sheet' then D.Panel(vg,r.x,r.y,r.w,r.h,16*s,{22,44,67,255},{22,44,67,255});local points=Cut(r.x,r.y,r.w,35*s,16*s);D.Path(vg,points);nvgFillColor(vg,nvgRGBA(29,56,82,255));nvgFill(vg);Relief.Halftone(vg,r.x,r.y,r.w,35*s,false,nil,points);D.Rect(vg,r.x,r.y,4*s,35*s,{155,215,250,255});D.Text(vg,self.props.text,r.x+18*s,r.y+9*s,18*s,D.white,'vox-title',nil,2*s);D.Text(vg,self.props.en,r.x+96*s,r.y+14*s,10*s,{155,215,250,255},'vox-hud',nil,3*s)
    elseif self.props.kind=='press' then
        local radius=r.w/2;local thickness=radius*.4
        nvgBeginPath(vg);nvgCircle(vg,r.x+radius,r.y+radius,radius-thickness/2);nvgStrokeWidth(vg,thickness);nvgStrokeColor(vg,nvgRGBA(255,255,255,31));nvgStroke(vg)
        local progress=math.max(0,math.min(1,self.props.progress or 0));if progress>0 then nvgBeginPath(vg);nvgArc(vg,r.x+radius,r.y+radius,radius-thickness/2,-math.pi/2,-math.pi/2+math.pi*2*progress,NVG_CW);nvgStrokeWidth(vg,thickness);nvgStrokeColor(vg,nvgRGBA(255,138,106,255));nvgStroke(vg) end
    elseif self.props.kind=='separator' then D.Rect(vg,r.x,r.y,r.w,r.h,{105,137,167,128})
    elseif self.props.kind=='label' then D.Text(vg,self.props.text or '',r.x,r.y,10*s,{159,186,210,255},'vox-title',nil,2*s)
    elseif self.props.kind=='hint' then D.Text(vg,self.props.text or '',r.x+r.w/2,r.y,12*s,{215,233,248,255},'vox-title',NVG_ALIGN_CENTER,1*s) end
end
return M
