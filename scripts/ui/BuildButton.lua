-- Original editbar/tool/toggle geometry; Button owns pointer and focus events.
local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Motion=require 'ui.SourceButtonMotion'
local Button=Base:Extend('VoxBuildButton')
local function SwatchLayout(self,parentRect)
    local p=self.props
    return {x=parentRect.x+p.left,y=parentRect.y+p.top,w=p.width,h=p.height}
end
function Button:GetAbsoluteLayout()
    if self.props.kind=='swatch' and self.parent then return SwatchLayout(self,self.parent:GetAbsoluteLayout()) end
    return Base.GetAbsoluteLayout(self)
end
function Button:GetAbsoluteLayoutForHitTest()
    -- Preserve the source fractional grid for both pixels and input; Yoga
    -- otherwise rounds parent and local offsets separately by up to 1px.
    if self.props.kind=='swatch' and self.parent then return SwatchLayout(self,self.parent:GetAbsoluteLayoutForHitTest()) end
    return Base.GetAbsoluteLayoutForHitTest(self)
end
function Button:Update(dt)
    if self.props.kind~='swatch' then return end
    self.hoverMotion=self.hoverMotion or {value=0,start=0,target=0,elapsed=0,duration=0}
    Motion.Step(self.hoverMotion,self.state.hovered and -2 or 0,.15,dt,false)
    if self.props.translateY~=self.hoverMotion.value then self:SetStyle({translateY=self.hoverMotion.value}) end
end
function Button.Key(vg,text,x,y,size,dark)
    size=size or 12;local w=D.Width(vg,text,size)+8
    D.Rect(vg,x,y,w,size+5,{0,0,0,56});nvgBeginPath(vg);nvgRect(vg,x+.5,y+.5,w-1,size+4)
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(0,0,0,0));nvgStroke(vg)
    D.Text(vg,text,x+4,y+1,size,dark and D.ink or D.white);return w
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.kind;local on=p.selected;local color=on and D.orange or D.muted
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.4) end
    if self.state.pressed and kind~='swatch' then nvgTranslate(vg,x+w/2,y+h/2+1);nvgScale(vg,.95,.95);nvgTranslate(vg,-x-w/2,-y-h/2) end
    if kind=='tier' then
        Relief.Draw(vg,x,y,w,h,on,true,{x+7,y,x+w,y,x+w-7,y+h,x,y+h},false)
        if self.state.hovered then D.Rect(vg,x+7,y,w-14,h,{255,255,255,25}) end
        D.Text(vg,p.text,x+w/2,y+4,16,p.unfit and {127,154,180,255} or D.white,nil,NVG_ALIGN_CENTER)
    elseif kind=='more' then
        local tw=D.Width(vg,p.text,15)+20
        Relief.Draw(vg,x,y,tw,h,false,true,{x,y,x+tw,y,x+tw,y+h,x,y+h})
        local color=self.state.hovered and D.white or {228,243,255,255}
        D.Text(vg,p.text,x,y+3,15,color);local tx=x+D.Width(vg,p.text,15)+4
        nvgSave(vg);nvgTranslate(vg,tx+8,y+12);if on then nvgRotate(vg,math.pi) end;D.Icon(vg,'chev',-8,-8,16,color);nvgRestore(vg)
    elseif kind=='swatch' or kind=='dock-swatch' then
        local c=p.hex or 0xc9ced6;D.Rect(vg,x,y,w,h,{(c>>16)&255,(c>>8)&255,c&255,255});D.Rect(vg,x,y+h-1,w,1,{0,0,0,64});D.Rect(vg,x,y,w,1,{255,255,255,51})
        if p.auto then nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h);for k=-h,w,6 do D.Path(vg,{x+k,y,x+k+3,y,x+k+h+3,y+h,x+k+h,y+h});nvgFillColor(vg,nvgRGBA(125,131,140,255));nvgFill(vg) end;nvgRestore(vg) end
        if p.key then D.Text(vg,p.key,x+2,y+1,9,D.white,'vox-body') end
        if on then D.Rect(vg,x,y+h-3,w,3,D.white);D.Rect(vg,x,y+h-4,w,1,D.ink) end
    else
        local rectangle=kind=='tool' or kind=='toggle' or kind=='dock-color' or kind=='channel'
        local points=rectangle and {x,y,x+w,y,x+w,y+h,x,y+h} or {x,y,x+w-12,y,x+w,y+12,x+w,y+h,x,y+h}
        Relief.Draw(vg,x,y,w,h,kind=='save',true,points)
        if self.state.hovered and not p.disabled then D.Rect(vg,x,y,w,h,{255,255,255,25}) end
        if kind=='tool' then
            local mc=p.icon=='erase' and {255,59,48,255} or {155,215,250,255}
            if on then D.Rect(vg,x,y,w,h,{44,73,98,255});D.Rect(vg,x,y, w,1,{142,198,249,80});D.Rect(vg,x,y+h-2,w,2,mc) end
            D.Icon(vg,p.icon,x+(w-22)/2,y+(h-22)/2,22,on and mc or {174,196,218,255})
            D.Text(vg,p.key,x+w-4,y+h-13,10.5,on and {174,196,218,255} or {127,154,180,255},'vox-body',NVG_ALIGN_RIGHT)
        elseif kind=='toggle' then
            if on then D.Rect(vg,x,y,w,h,{32,56,78,255}) end
            D.Rect(vg,x+8,y,w-16,2,on and {155,215,250,255} or {47,52,60,255})
            D.Icon(vg,p.icon,x+(w-18)/2,y+11,18,color);D.Text(vg,p.text,x+w/2,y+32,12,on and D.white or D.muted,'vox-body',NVG_ALIGN_CENTER)
            D.Text(vg,p.key,x+w-3,y+5,10.5,D.dim,'vox-body',NVG_ALIGN_RIGHT)
        elseif kind=='dock-color' then
            D.Rect(vg,x,y,w,h,{32,56,78,255});D.Rect(vg,x,y,w,1,{142,198,249,128});D.Rect(vg,x,y+h-1.5,w,1.5,{11,36,75,128})
            local c=p.hex or 0xc9ced6
            D.Rect(vg,x+8,y+11,30,30,{(c>>16)&255,(c>>8)&255,c&255,255})
            if p.auto then nvgSave(vg);nvgIntersectScissor(vg,x+8,y+11,30,30);for k=-30,30,6 do D.Path(vg,{x+8+k,y+11,x+11+k,y+11,x+41+k,y+41,x+38+k,y+41});nvgFillColor(vg,nvgRGBA(125,131,140,255));nvgFill(vg) end;nvgRestore(vg) end
            D.Text(vg,p.text,x+46,y+10,15);D.Text(vg,'C 吸色',x+46,y+30,10.5,D.dim,'vox-body')
        elseif kind=='channel' then
            if on then D.Rect(vg,x,y+h-3,w,3,D.orange) end
            D.Text(vg,p.text,x+w/2,y+(h-16)/2,13,on and D.white or D.muted,'vox-body',NVG_ALIGN_CENTER)
        elseif kind=='icon' then D.Icon(vg,p.icon,x+(w-22)/2,y+(h-22)/2,22,D.white)
        else
            local back=kind=='back';local save=kind=='save';local ix=x+(back and 12 or save and 18 or 16);local size=back and 20 or 22
            local fs=back and 18 or 21;local spacing=back and 0 or 1
            local keyWidth=p.key and D.Width(vg,p.key,12)+24 or 0
            local tx=p.icon and ix+size+(back and 8 or 10) or x+12
            while fs>12 and D.Width(vg,p.text,fs,nil,spacing)>x+w-12-keyWidth-tx do fs=fs-1 end
            if p.icon then D.Icon(vg,p.icon,ix,y+(h-size)/2,size,back and D.orange or D.white)
            else tx=x+(w-keyWidth-D.Width(vg,p.text,fs,nil,spacing))/2 end
            D.Text(vg,p.text,tx,y+(h-fs*1.2)/2,fs,D.white,nil,nil,spacing)
            if p.key then Button.Key(vg,p.key,x+w-(save and 22 or 16)-D.Width(vg,p.key,12)-8,y+(h-17)/2,12,false) end
        end
    end
    nvgRestore(vg)
end
return Button
