-- Native pointer/focus ownership; original H5 appearance drawn in NanoVG.
local Base=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Button=Base:Extend('VoxSourceButton')
local Motion=require 'ui.SourceButtonMotion'
local function Flat(kind) return kind=='dialog' or kind=='primary' or kind=='flat' end
function Button:Update(dt)
    if Flat(self.props.sourceKind) then Motion.Update(self,dt) end
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.sourceKind or 'action';local color=D.white
    nvgSave(vg)
    if Flat(kind) then nvgGlobalAlpha(vg,p.sourceOpacity or 1)
    elseif p.disabled then nvgGlobalAlpha(vg,.4) end
    local hover=self.state.hovered;local pressed=self.state.pressed
    if Flat(kind) then
        local scale=self.sourceMotion and self.sourceMotion.scale.value or 1
        nvgTranslate(vg,x+w*.5,y+h*.5);nvgScale(vg,scale,scale);nvgTranslate(vg,-x-w*.5,-y-h*.5)
    elseif pressed then nvgTranslate(vg,x+w*.5,y+h*.5+1);nvgScale(vg,.97,.97);nvgTranslate(vg,-x-w*.5,-y-h*.5) end
    if kind=='tab' then
        color=p.selected and D.white or D.muted
        D.Icon(vg,p.icon,x+20,y+19,22,p.selected and D.orange or color)
        D.Text(vg,p.text,x+51,y+17,21,hover and D.white or color,nil,nil,1)
        if p.selected then D.Rect(vg,x+14,y+h-9,w-28,3,D.orange) end
    elseif kind=='cta-main' or kind=='cta-left' or kind=='cta-right' then
        local main=kind=='cta-main';color=main and D.ink or D.white
        local points=main and {x+22,y,x+w-22,y,x+w,y+h,x,y+h} or kind=='cta-left' and {x,y,x+w,y,x+w-22,y+h,x,y+h} or {x,y,x+w,y,x+w,y+h,x+22,y+h}
        local stop=math.floor(h*(main and .52 or .55)+.5)/h
        local middle=main and D.orange or {34,37,43,255}
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h*stop)
        D.Path(vg,points);D.Gradient(vg,x,y,w,h*stop,main and {255,149,80,255} or {49,53,61,255},middle);nvgRestore(vg)
        nvgSave(vg);nvgIntersectScissor(vg,x,y+h*stop,w,h*(1-stop))
        D.Path(vg,points);D.Gradient(vg,x,y+h*stop,w,h*(1-stop),middle,main and {226,84,10,255} or {26,28,33,255});nvgRestore(vg)
        if hover then D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,255,255,main and 51 or 26));nvgFill(vg) end
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,main and 2 or 1)
        D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,255,255,main and 89 or 26));nvgFill(vg);nvgRestore(vg)
        nvgSave(vg);nvgIntersectScissor(vg,x,y+h-(main and 5 or 4),w,main and 5 or 4)
        D.Path(vg,points);nvgFillColor(vg,main and nvgRGBA(120,36,0,115) or nvgRGBA(0,0,0,115));nvgFill(vg);nvgRestore(vg)
        local kw=math.max(18,D.Width(vg,p.key or '',12)+10)
        local span=math.max(D.Width(vg,p.text,34,nil,1),D.Width(vg,p.subtitle or '',13,'vox-body'))
        local start=main and x+(w-(38+12+span+12+kw))*.5 or x+(kind=='cta-right' and 40 or 24)
        D.Icon(vg,p.icon,start,y+(main and 15 or 20),main and 38 or 28,main and D.ink or D.muted,main and 2.4 or 2)
        local tx=start+(main and 50 or 40)
        D.Text(vg,p.text,tx,y+(main and 5 or 8),main and 34 or 26,color,nil,nil,1)
        D.Text(vg,p.subtitle or '',tx,y+(main and 43 or 39.5),main and 13 or 12,main and {26,13,5,185} or D.muted,'vox-body')
        local kx=main and tx+span+12 or x+w-(kind=='cta-right' and 24 or 40)-kw
        D.Rect(vg,kx,y+25,kw,19,{0,0,0,56});nvgBeginPath(vg);nvgRect(vg,kx+.5,y+25.5,kw-1,18);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(0,0,0,main and 77 or 0));nvgStroke(vg)
        D.Text(vg,p.key or '',kx+kw/2,y+27,12,color,nil,NVG_ALIGN_CENTER)
    elseif kind=='pause' then
        if hover and not p.disabled then x=x+4 end
        D.Panel(vg,x,y,w,h,0,{44,48,55,255},{29,32,37,255})
        if hover and not p.disabled then D.Rect(vg,x,y,4,h,D.orange) end
        D.Rect(vg,x+10,y+10,46,46,{0,0,0,77});D.Icon(vg,p.icon,x+21,y+21,24,hover and D.orange or D.muted)
        D.Text(vg,p.text,x+72,y+9,22,nil,nil,nil,1)
        D.Text(vg,p.subtitle or '',x+72,y+38,12.5,D.muted,'vox-body')
    elseif Flat(kind) then
        local primary=kind=='primary'
        local cut=primary and 12 or 0
        local points={x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x,y+h}
        D.Path(vg,points)
        local selected=kind=='flat' and p.selected
        nvgFillColor(vg,D.Color(selected and D.white or primary and D.orange or {42,46,53,255}));nvgFill(vg)
        -- CSS clips the rectangular border; it does not stroke the cut edge.
        local edge=selected and D.white or hover and not p.disabled and {86,93,104,255} or primary and {255,140,69,255} or {53,58,66,255}
        D.Rect(vg,x,y,w-cut,1,edge);D.Rect(vg,x,y,1,h,edge)
        D.Rect(vg,x+w-1,y+cut,1,h-cut,edge);D.Rect(vg,x,y+h-1,w,1,edge)
        local sweep=self.sourceMotion and self.sourceMotion.hover.value or 0
        if sweep>0 then
            nvgSave(vg);nvgIntersectScissor(vg,x,y,w*sweep,h);D.Path(vg,points)
            nvgFillColor(vg,nvgRGBA(255,255,255,primary and 56 or 26));nvgFill(vg);nvgRestore(vg)
        end
        local size=kind=='flat' and 16 or 18;local icon=kind=='flat' and p.icon
        local span=D.Width(vg,p.text,size,nil,.5)+(icon and 22 or 0);local tx=x+(w-span)/2
        if icon then D.Icon(vg,icon,tx,y+(h-16)/2,16,D.white);tx=tx+22 end
        D.Text(vg,p.text,tx,y+(h-size*1.2)/2,size,(primary or selected) and D.ink or D.white,nil,nil,.5)
    elseif kind=='tier' then
        D.Path(vg,{x+9,y,x+w,y,x+w-9,y+h,x,y+h});nvgFillColor(vg,D.Color(p.selected and D.white or {42,46,53,255}));nvgFill(vg)
        D.Text(vg,p.text,x+w/2,y+7,18,p.selected and D.ink or D.muted,nil,NVG_ALIGN_CENTER)
    elseif kind=='arrow' then
        nvgSave(vg);if p.rightArrow then nvgTranslate(vg,x+w/2,y+h/2);nvgRotate(vg,math.pi);D.Icon(vg,'back',-10,-10,20,hover and D.white or D.muted) else D.Icon(vg,'back',x+(w-20)/2,y+(h-20)/2,20,hover and D.white or D.muted) end;nvgRestore(vg)
    elseif kind=='new' then
        D.Path(vg,{x,y,x+w-16,y,x+w,y+16,x+w,y+h,x,y+h});nvgFillColor(vg,D.Color({255,255,255,10}));nvgFill(vg)
        -- CSS clips an inset rectangular border: no invented diagonal stroke.
        D.Rect(vg,x,y,w-16,1,{255,255,255,41});D.Rect(vg,x,y,1,h,{255,255,255,41})
        D.Rect(vg,x+w-1,y+16,1,h-16,{255,255,255,41});D.Rect(vg,x,y+h-1,w,1,{255,255,255,41})
        D.Icon(vg,'plus',x+w/2-20,y+h/2-34,40,D.orange,2.5);D.Text(vg,'新战车',x+w/2,y+h/2+14,18,D.white,nil,NVG_ALIGN_CENTER)
    else
        D.Panel(vg,x,y,w,h,0,{44,48,55,255},{29,32,37,255})
        local size=kind=='icon' and 22 or kind=='save' and 15 or 18;local ix=kind=='icon' and x+(w-size)/2 or x+(kind=='save' and 9 or 14)
        D.Icon(vg,p.icon,ix,y+(h-size)/2,size,hover and D.white or D.muted)
        if kind~='icon' then local fs=kind=='save' and 14 or 17;D.Text(vg,p.text,ix+size+(kind=='save' and 5 or 7),y+(h-fs*1.2)/2,fs,D.white) end
    end
    if hover and not p.disabled and not Flat(kind) and kind~='tab' and kind~='arrow' and kind~='pause' and kind:sub(1,4)~='cta-' then D.Rect(vg,x+4,y+2,w-8,h-5,{255,255,255,14}) end
    nvgRestore(vg)
end
return Button
