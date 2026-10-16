-- Native pointer/focus ownership; original H5 appearance drawn in NanoVG.
local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Button=Base:Extend('VoxSourceButton')
local Motion=require 'ui.SourceButtonMotion'
local function Flat(kind) return kind=='dialog' or kind=='primary' or kind=='flat' end
function Button:Update(dt)
    local kind=self.props.sourceKind or 'action'
    if Flat(kind) then Motion.Update(self,dt)
    elseif kind:sub(1,4)=='cta-' then Motion.UpdateCTA(self,dt) end
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    local k=p.sourceScale or 1;nvgSave(vg);nvgScale(vg,k,k)
    local x,y,w,h=r.x/k,r.y/k,r.w/k,r.h/k
    local kind=p.sourceKind or 'action';local color=D.white
    nvgSave(vg)
    if Flat(kind) then nvgGlobalAlpha(vg,p.sourceOpacity or 1)
    elseif p.disabled then nvgGlobalAlpha(vg,kind=='pause' and .45 or .4) end
    local hover=self.state.hovered;local pressed=self.state.pressed
    if Flat(kind) then
        local scale=self.sourceMotion and self.sourceMotion.scale.value or 1
        nvgTranslate(vg,x+w*.5,y+h*.5);nvgScale(vg,scale,scale);nvgTranslate(vg,-x-w*.5,-y-h*.5)
    elseif kind:sub(1,4)=='cta-' then
        local motion=self.sourceMotion
        if motion then nvgTranslate(vg,motion.x.value,motion.y.value) end
    elseif pressed then nvgTranslate(vg,x+w*.5,y+h*.5+1);nvgScale(vg,.97,.97);nvgTranslate(vg,-x-w*.5,-y-h*.5) end
    if kind=='tab' then
        color=p.selected and D.white or D.muted
        if p.selected then D.Rect(vg,x,y,w,h,{24,50,77,96}) end
        local inset=p.headerHangar and 24 or 20;local size=p.headerHangar and 20 or 21
        D.Icon(vg,p.icon,x+inset,y+(h-22)/2,22,p.selected and D.orange or color)
        D.Text(vg,p.text,x+inset+31,y+(h-(p.headerHangar and 24 or 25))/2,size,hover and D.white or color,nil,nil,1)
        if p.selected then D.Rect(vg,x+14,y+h-4,w-28,4,D.orange) end
    elseif kind=='intro' then
        -- Exact source header entry: the unfinished intro replay button is part
        -- of the frozen H5 page, including its compact relief and badge.
        local points={x,y,x+w-14,y,x+w,y+14,x+w,y+h,x,y+h}
        nvgGlobalAlpha(vg,hover and 1 or .68)
        Relief.Draw(vg,x,y,w,h,false,true,points)
        D.Icon(vg,'play',x+12,y+11,18,D.orange)
        D.Text(vg,'开场动画',x+36,y+11,13,{183,210,232,255},'vox-body')
        D.Rect(vg,x+106,y+11,39,18,{230,187,112,255})
        D.Text(vg,'未完成',x+125.5,y+12.5,11,D.ink,'vox-body',NVG_ALIGN_CENTER)
    elseif kind=='mode' then
        if p.salvage then
            self:RenderBackgroundImage(vg,'UI/Salvage/map.jpg',r,'cover',nil)
            D.Rect(vg,x,y,w,h,{16,34,55,192})
        elseif p.selected then Relief.Draw(vg,x,y,w,h,false,true,{x,y,x+w,y,x+w,y+h,x,y+h},true)
        else D.Rect(vg,x,y,w,h,{16,34,55,255}) end
        D.Rect(vg,x+8,y+7.5,36,36,p.selected and {185,231,255,255} or {5,13,22,180})
        D.Icon(vg,p.icon,x+16,y+15.5,20,p.selected and {20,57,85,255} or D.muted)
        D.Text(vg,p.text,x+54,y+9,14)
        D.Text(vg,p.subtitle or '',x+54,y+28,10,{182,204,224,255},'vox-body')
        if p.selected then D.Rect(vg,x,y+h-3,w,3,D.orange) end
        if p.salvage then
            D.Rect(vg,x+114,y+10,20,15,{230,187,112,255});D.Text(vg,'新',x+118,y+11,9,D.ink,'vox-body')
            D.Rect(vg,x+w-34,y+13.5,24,24,{39,70,99,255});D.Icon(vg,'swap',x+w-30,y+17.5,16,{185,231,255,255})
        end
    elseif kind=='manage' then
        D.Icon(vg,'gear',x+10,y+8.5,15,{188,215,235,255})
        D.Text(vg,p.text,x+33,y+7,14,{188,215,235,255});D.Icon(vg,'plus',x+w-25,y+8.5,15,D.orange)
    elseif kind=='details' then
        D.Rect(vg,x,y,w,1,{145,172,200,51});D.Text(vg,p.text,x,y+6,17)
        D.Text(vg,p.subtitle or '',x,y+30,11,D.muted,'vox-body')
        D.Icon(vg,p.icon,x+w-19,y+15.5,19,D.orange)
    elseif kind=='cta-main' or kind=='cta-left' or kind=='cta-right' then
        local main=kind=='cta-main';color=D.white
        local points=main and {x+18,y,x+w-18,y,x+w,y+h,x,y+h} or kind=='cta-left' and {x+w*.17,y,x+w,y,x+w-18,y+h,x+w*.07,y+h,x,y+h*.79} or {x,y,x+w*.855,y,x+w,y+h*.79,x+w*.93,y+h,x+18,y+h}
        Relief.Draw(vg,x,y,w,h,main,false,points)
        local sweep=self.sourceMotion and self.sourceMotion.hover.value or 0
        -- The frozen primary removes ::before; side buttons retain its sweep.
        if not main and sweep>0 then
            nvgSave(vg);nvgIntersectScissor(vg,x,y,w*sweep,h);D.Path(vg,points)
            nvgFillColor(vg,nvgRGBA(255,255,255,26));nvgFill(vg);nvgRestore(vg)
        end
        local kw=D.Width(vg,p.key or '',12,nil,.5)+12
        local iconSize=main and 33 or 24;local titleSize=main and 36 or 25;local subSize=main and 11 or 10
        local tracking=main and 3 or 0
        local span=math.max(D.Width(vg,p.text,titleSize,nil,tracking),D.Width(vg,p.subtitle or '',subSize,'vox-body'))
        local start=main and x+(w-(iconSize+12+span+12+kw))*.5 or x+18
        D.Icon(vg,p.icon,start,y+(h-iconSize)/2,iconSize,main and {6,31,53,255} or {228,243,255,255})
        local tx=start+iconSize+(main and 12 or 9)
        D.Text(vg,p.text,tx,y+(main and 11 or 17),titleSize,color,nil,nil,tracking,false,titleSize)
        D.Text(vg,p.subtitle or '',tx,y+(main and 52 or 47),subSize,main and {228,244,255,255} or {195,222,244,255},'vox-body')
        local kx=main and tx+span+12 or x+w-18-kw
        local ky=y+(h-19)/2
        D.Rect(vg,kx,ky,kw,19,main and {22,61,103,102} or {19,36,58,255});nvgBeginPath(vg);nvgRect(vg,kx+.5,ky+.5,kw-1,18);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(0,0,0,0));nvgStroke(vg)
        D.Text(vg,p.key or '',kx+kw/2,ky+1,12,color,nil,NVG_ALIGN_CENTER,.5,false,17)
    elseif kind=='pause' then
        if hover and not p.disabled then x=x+4 end
        Relief.Draw(vg,x,y,w,h,false,true,{x,y,x+w,y,x+w,y+h,x,y+h},false)
        if hover and not p.disabled then D.Rect(vg,x,y,4,h,D.orange) end
        D.Rect(vg,x+10,y+10,46,46,{16,37,58,255});D.Icon(vg,p.icon,x+21,y+21,24,hover and D.orange or {174,196,218,255})
        D.Text(vg,p.text,x+72,y+12.5,22,{228,243,255,255},'vox-title',nil,1,false,22)
        D.Text(vg,p.subtitle or '',x+72,y+38.5,12.5,{174,196,218,255},'vox-body')
    elseif Flat(kind) then
        local primary=kind=='primary'
        local cut=kind=='flat' and 0 or 14
        local points={x,y,x+w-cut,y,x+w,y+cut,x+w,y+h,x,y+h}
        local selected=kind=='flat' and p.selected
        if selected then
            D.Path(vg,points);nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
            D.Rect(vg,x,y,w,1.5,{219,238,255,128});D.Rect(vg,x,y+h-1.5,w,1.5,{11,36,75,128})
        else Relief.Draw(vg,x,y,w,h,primary,true,points) end
        local sweep=self.sourceMotion and self.sourceMotion.hover.value or 0
        if sweep>0 then
            nvgSave(vg);nvgIntersectScissor(vg,x,y,w*sweep,h);D.Path(vg,points)
            nvgFillColor(vg,nvgRGBA(255,255,255,primary and 56 or 26));nvgFill(vg);nvgRestore(vg)
        end
        local size=kind=='flat' and 16 or 18;local icon=kind=='flat' and p.icon
        while size>12 and D.Width(vg,p.text,size)+(icon and 22 or 0)>w-16 do size=size-1 end
        local span=D.Width(vg,p.text,size,nil,.5)+(icon and 22 or 0);local tx=x+(w-span)/2
        if icon then D.Icon(vg,icon,tx,y+(h-16)/2,16,D.white);tx=tx+22 end
        D.Text(vg,p.text,tx,y+(h-size*1.2)/2,size,selected and D.ink or D.white,nil,nil,.5)
    elseif kind=='tier' then
        D.Path(vg,{x+9,y,x+w,y,x+w-9,y+h,x,y+h});nvgFillColor(vg,D.Color(p.selected and D.white or {42,46,53,255}));nvgFill(vg)
        D.Text(vg,p.text,x+w/2,y+7,18,p.selected and D.ink or D.muted,nil,NVG_ALIGN_CENTER)
    elseif kind=='arrow' then
        nvgSave(vg);if p.rightArrow then nvgTranslate(vg,x+w/2,y+h/2);nvgRotate(vg,math.pi);D.Icon(vg,'back',-10,-10,20,hover and D.white or D.muted) else D.Icon(vg,'back',x+(w-20)/2,y+(h-20)/2,20,hover and D.white or D.muted) end;nvgRestore(vg)
    elseif kind=='new' then
        Relief.Draw(vg,x,y,w,h,false,false,{x,y,x+w-16,y,x+w,y+16,x+w,y+h,x,y+h})
        D.Icon(vg,'plus',x+w/2-15,y+h/2-28,30,D.orange);D.Text(vg,'新战车',x+w/2,y+h/2+12,15,D.white,nil,NVG_ALIGN_CENTER)
    else
        if kind=='save' or kind=='icon' then
            Relief.Draw(vg,x,y,w,h,kind=='save',true,{x,y,x+w,y,x+w,y+h-7,x+w-7,y+h,x,y+h})
        else D.Panel(vg,x,y,w,h,0,{44,48,55,255},{29,32,37,255}) end
        local size=kind=='icon' and 22 or kind=='save' and 15 or 18;local ix=kind=='icon' and x+(w-size)/2 or x+(kind=='save' and 9 or 14)
        D.Icon(vg,p.icon,ix,y+(h-size)/2,size,hover and D.white or D.muted)
        if kind~='icon' then local fs=kind=='save' and 14 or 17;D.Text(vg,p.text,ix+size+(kind=='save' and 5 or 7),y+(h-fs*1.2)/2,fs,D.white,nil,nil,kind=='save' and .5 or 0,false,fs*1.2) end
    end
    if hover and not p.disabled and not Flat(kind) and kind~='tab' and kind~='arrow' and kind~='pause' and kind:sub(1,4)~='cta-' then D.Rect(vg,x+4,y+2,w-8,h-5,{255,255,255,14}) end
    nvgRestore(vg)
    nvgRestore(vg)
end
return Button
