-- Frozen touch-controls.css/SVG geometry in the UI-owned NanoVG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Button=require('ui.ActionButton'):Extend('VoxSourceDriveTouchButton')
local Stick=UI.Panel:Extend('VoxSourceDriveTouchStick')
local Readiness=UI.Widget:Extend('VoxSourceDriveTouchReadiness')
local M={Button=Button,Stick=Stick,Readiness=Readiness}
local function Oct(vg,w,h,c,i)
    i=i or 0
    D.Path(vg,{c+i,i,w-c-i,i,w-i,c+i,w-i,h-c-i,w-c-i,h-i,c+i,h-i,i,h-c-i,i,c+i})
end
local function Stroke(vg,color,width)
    nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width);nvgStroke(vg)
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local k=self.props.touchScale or 1;local u=self.props.unit or 1
    local s=k*u;local w,h=r.w/s,r.h/s;local kind=self.props.kind or 'arc'
    local c=({fire=20,arc=12,context=11,small=10,menu=9})[kind] or 12
    local held=self.touchHeld or self.state.pressed;local selected=held or self.props.selected
    nvgSave(vg);nvgTranslate(vg,r.x+r.w/2,r.y+r.h/2);nvgScale(vg,s*(held and .95 or 1),s*(held and .95 or 1));nvgTranslate(vg,-w/2,-h/2)
    Oct(vg,w,h,c);nvgFillColor(vg,kind=='context' and selected and nvgRGBA(120,80,10,140) or nvgRGBA(10,15,20,selected and 140 or 82));nvgFill(vg)
    if kind=='fire' then Oct(vg,w,h,c-2,5);Stroke(vg,{255,255,255,56},k/s) end
    Oct(vg,w,h,c)
    local edge=selected and {255,255,255,255} or kind=='context' and {255,200,97,255} or {255,255,255,kind=='fire' and 204 or 140}
    Stroke(vg,edge,(selected and 2 or kind=='fire' and 1.8 or kind=='context' and 1.6 or 1.3)*k/s)
    local a=math.min(c*.9,9)*.7
    nvgBeginPath(vg)
    nvgMoveTo(vg,c-a,a+.5);nvgLineTo(vg,c,.5);nvgMoveTo(vg,.5,c);nvgLineTo(vg,a+.5,c-a)
    nvgMoveTo(vg,w-c,h-.5);nvgLineTo(vg,w-c+a,h-a-.5);nvgMoveTo(vg,w-.5,h-c);nvgLineTo(vg,w-a-.5,h-c+a)
    Stroke(vg,selected and {255,106,19,255} or kind=='context' and {255,215,138,217} or {255,255,255,217},2.4*k/s)
    local path=self.props.iconPath or ('UI/Touch/'..(self.props.icon or 'fire')..'.png')
    local image=Images.Get(path)
    if image and image>0 then
        local iw,ih=nvgImageSize(vg,image)
        local fraction=kind=='fire' and .44 or kind=='context' and .62 or self.props.weapon and .38 or .56
        local z=math.min(h*fraction/ih,w*(self.props.weapon and .78 or .7)/iw);local dw,dh=iw*z,ih*z
        local x=kind=='context' and 12 or (w-dw)/2;local y=(h-dh)/2
        nvgSave(vg)
        if self.props.flipX then nvgTranslate(vg,x+dw,y);nvgScale(vg,-1,1);x=0;y=0 end
        nvgBeginPath(vg);nvgRect(vg,x,y,dw,dh);nvgFillPaint(vg,nvgImagePattern(vg,x,y,dw,dh,0,image,selected and 1 or self.props.weapon and .88 or .92));nvgFill(vg);nvgRestore(vg)
        if kind=='context' then D.Text(vg,self.props.text or '',12+dw+6,(h-15.6)/2,13,{255,215,138,255},'vox-title',nil,0,false,15.6) end
    end
    nvgRestore(vg)
end
function Stick:Render(vg)
    local r=self:GetAbsoluteLayout();local s=r.w/108;local k=self.props.touchScale or 1
    nvgSave(vg);nvgGlobalAlpha(vg,self.live and 1 or .5);nvgTranslate(vg,r.x,r.y);nvgScale(vg,s,s)
    Oct(vg,108,108,32);nvgFillColor(vg,nvgRGBA(10,15,20,61));nvgFill(vg)
    Stroke(vg,self.dash and {255,106,19,255} or {255,255,255,128},(self.dash and 2 or 1.3)*k/s)
    for _,p in ipairs({{54,9,48,16,60,16},{54,99,48,92,60,92},{9,54,16,48,16,60},{99,54,92,48,92,60}}) do D.Path(vg,p);nvgFillColor(vg,nvgRGBA(255,255,255,128));nvgFill(vg) end
    nvgTranslate(vg,33+(self.axisX or 0)*108*.42,33+(self.axisY or 0)*108*.42)
    Oct(vg,42,42,12);nvgFillColor(vg,nvgRGBA(20,32,44,179));nvgFill(vg);Stroke(vg,{255,255,255,255},1.6*k/s)
    Oct(vg,42,42,9,6);Stroke(vg,{255,255,255,56},k/s);nvgRestore(vg)
end
function Readiness:Render(vg)
    local r=self:GetAbsoluteLayout();local cut=r.h
    nvgSave(vg);D.Path(vg,{r.x,r.y,r.x+r.w,r.y,r.x+r.w-cut,r.y+r.h,r.x+cut,r.y+r.h})
    nvgFillColor(vg,nvgRGBA(255,255,255,38));nvgFill(vg)
    nvgIntersectScissor(vg,r.x,r.y,r.w*(self.value or 1),r.h);nvgFillColor(vg,nvgRGBA(232,237,240,255));nvgFill(vg);nvgRestore(vg)
end
return M
