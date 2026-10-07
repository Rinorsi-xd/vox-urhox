-- Original editbar/tool/toggle geometry; Button owns pointer and focus events.
local Base=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
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
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color(dark and {0,0,0,77} or {154,160,170,130}));nvgStroke(vg)
    D.Text(vg,text,x+4,y+1,size,dark and D.ink or D.white);return w
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.kind;local on=p.selected;local color=on and D.orange or D.muted
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.4) end
    if self.state.pressed and kind~='swatch' then nvgTranslate(vg,x+w/2,y+h/2+1);nvgScale(vg,.95,.95);nvgTranslate(vg,-x-w/2,-y-h/2) end
    if kind=='tier' then
        D.Path(vg,{x+7,y,x+w,y,x+w-7,y+h,x,y+h});nvgFillColor(vg,D.Color(on and D.white or {255,255,255,self.state.hovered and 36 or 18}));nvgFill(vg)
        D.Text(vg,p.text,x+w/2,y+4,16,on and D.ink or p.unfit and D.dim or D.muted,nil,NVG_ALIGN_CENTER)
    elseif kind=='more' then
        local color=self.state.hovered and D.white or D.muted
        D.Text(vg,p.text,x,y+3,15,color);local tx=x+D.Width(vg,p.text,15)+4
        nvgSave(vg);nvgTranslate(vg,tx+8,y+12);if on then nvgRotate(vg,math.pi) end;D.Icon(vg,'chev',-8,-8,16,color);nvgRestore(vg)
    elseif kind=='swatch' then
        local c=p.hex;D.Rect(vg,x,y,w,h,{(c>>16)&255,(c>>8)&255,c&255,255});D.Rect(vg,x,y+h-3,w,3,{0,0,0,64})
        nvgBeginPath(vg);nvgRect(vg,x+.5,y+.5,w-1,h-1);nvgStrokeColor(vg,D.Color({255,255,255,51}));nvgStrokeWidth(vg,1);nvgStroke(vg)
        if on then nvgBeginPath(vg);nvgRect(vg,x-3,y-3,w+6,h+6);nvgStrokeColor(vg,D.Color(D.orange));nvgStrokeWidth(vg,2);nvgStroke(vg) end
    else
        if kind=='save' then
            D.Panel(vg,x,y,w,h,12,{255,149,80,255},{226,84,10,255});D.Rect(vg,x,y,w-12,2,{255,255,255,90})
        else D.Panel(vg,x,y,w,h,0,{44,48,55,255},{29,32,37,255}) end
        if self.state.hovered and not p.disabled then D.Rect(vg,x,y,w,h,{255,255,255,25}) end
        if kind=='tool' then
            if on then D.Rect(vg,x,y+h-3,w,3,p.icon=='erase' and {255,59,48,255} or D.orange) end
            if p.hex then local c=p.hex;D.Rect(vg,x+w/2-12,y+6,24,24,{(c>>16)&255,(c>>8)&255,c&255,255})
            else D.Icon(vg,p.icon,x+w/2-12,y+6,24,on and p.icon=='erase' and {255,59,48,255} or color) end
            D.Text(vg,p.text,x+w/2,y+35,15,D.white,nil,NVG_ALIGN_CENTER)
            local kw=D.Width(vg,p.key,11.5)+8;Button.Key(vg,p.key,x+(w-kw)/2,y+56,11.5)
        elseif kind=='toggle' then
            D.Icon(vg,p.icon,x+6,y+4,14,color);D.Text(vg,p.text,x+26,y+2,14,on and D.white or D.muted)
            Button.Key(vg,p.key,x+32+D.Width(vg,p.text,14),y+3,11)
            D.Path(vg,{x+w-12,y+7,x+w-8,y+11,x+w-12,y+15,x+w-16,y+11});nvgFillColor(vg,D.Color(on and D.orange or {43,47,54,255}));nvgFill(vg)
        elseif kind=='channel' then
            if on then D.Rect(vg,x,y+h-3,w,3,D.orange) end
            D.Text(vg,p.text,x+w/2,y+(h-22)/2,17,D.white,nil,NVG_ALIGN_CENTER)
        elseif kind=='icon' then D.Icon(vg,p.icon,x+(w-22)/2,y+(h-22)/2,22,self.state.hovered and D.white or D.muted)
        else
            local back=kind=='back';local save=kind=='save';local ix=x+(back and 12 or save and 18 or 16);local size=back and 20 or 22
            D.Icon(vg,p.icon,ix,y+(h-size)/2,size,back and D.orange or save and D.ink or D.muted)
            D.Text(vg,p.text,ix+size+(back and 8 or 10),y+(h-(back and 22 or 26))/2,back and 18 or 21,save and D.ink or D.white,nil,nil,back and 0 or 1)
            if p.key then Button.Key(vg,p.key,x+w-(save and 22 or 16)-D.Width(vg,p.key,12)-8,y+(h-17)/2,12,save) end
        end
    end
    nvgRestore(vg)
end
return Button
