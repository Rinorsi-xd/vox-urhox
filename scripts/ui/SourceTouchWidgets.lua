-- Source touch-controls.css relief; rendered inside the UI-owned VG frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Button=require('urhox-libs/UI/Widgets/Button'):Extend('VoxSourceTouchButton')
local Stick=UI.Panel:Extend('VoxSourceTouchStick')
local contexts=setmetatable({},{__mode='k'})
local function Font(vg)
    D.Begin(vg)
    if not contexts[vg] then
        local face=nvgCreateFont(vg,'vox-touch',require('ui.SourceFonts').Resolve().bold)
        assert(face>=0,'Source touch font failed to load')
        contexts[vg]=true
    end
    return 'vox-touch'
end
local function Rounded(vg,x,y,w,h,r)
    nvgBeginPath(vg);nvgRoundedRect(vg,x,y,w,h,r)
end
function Button:Render(vg)
    local font=Font(vg);local r=self:GetAbsoluteLayout();local k=self.props.touchScale or 1
    local selected=self.props.selected or self.touchHeld or self.state.pressed
    nvgSave(vg)
    if self.props.disclosure then
        local x,y=r.x+4*k,r.y+r.h/2
        nvgBeginPath(vg)
        if self.props.selected then nvgMoveTo(vg,x,y-3*k);nvgLineTo(vg,x+8*k,y-3*k);nvgLineTo(vg,x+4*k,y+4*k)
        else nvgMoveTo(vg,x,y-4*k);nvgLineTo(vg,x+7*k,y);nvgLineTo(vg,x,y+4*k) end
        nvgClosePath(vg);nvgFillColor(vg,nvgRGBA(232,247,255,255));nvgFill(vg)
        D.Text(vg,self.props.text,r.x+18*k,r.y+(r.h-15.6*k)/2,13*k,{232,247,255,255},font,nil,0,false,15.6*k)
        if self.state.focused then Rounded(vg,r.x-2*k,r.y-2*k,r.w+4*k,r.h+4*k,0);nvgStrokeWidth(vg,2*k);nvgStrokeColor(vg,nvgRGBA(255,255,255,255));nvgStroke(vg) end
        nvgRestore(vg);return
    end
    -- CSS 0 2px 6px #0008. Draw outside the button without covering its fill.
    Rounded(vg,r.x-8*k,r.y-6*k,r.w+16*k,r.h+20*k,18*k)
    Rounded(vg,r.x,r.y+2*k,r.w,r.h,10*k);nvgPathWinding(vg,NVG_HOLE)
    nvgFillPaint(vg,nvgBoxGradient(vg,r.x,r.y+2*k,r.w,r.h,10*k,6*k,nvgRGBA(0,0,0,136),nvgRGBA(0,0,0,0)));nvgFill(vg)
    Rounded(vg,r.x,r.y,r.w,r.h,10*k)
    if selected then nvgFillColor(vg,nvgRGBA(57,104,130,237))
    else
        local a=self.props.primary and nvgRGBA(54,105,129,232) or nvgRGBA(36,61,82,221)
        local b=self.props.primary and nvgRGBA(25,53,76,232) or nvgRGBA(13,26,43,232)
        nvgFillPaint(vg,nvgLinearGradient(vg,r.x,r.y,r.x,r.y+r.h,a,b))
    end
    nvgFill(vg);nvgStrokeWidth(vg,k);nvgStrokeColor(vg,selected and nvgRGBA(182,236,255,255) or nvgRGBA(122,216,255,136));nvgStroke(vg)
    nvgSave(vg);nvgIntersectScissor(vg,r.x+k,r.y+k,r.w-2*k,k)
    Rounded(vg,r.x+k,r.y+k,r.w-2*k,r.h-2*k,9*k);nvgFillColor(vg,nvgRGBA(196,238,255,64));nvgFill(vg);nvgRestore(vg)
    local text=self.props.text or '';local size=13*k;local maxWidth=r.w-8*k
    local natural=D.Width(vg,text,size,font);if natural>maxWidth then size=size*maxWidth/math.max(1,natural) end
    D.Text(vg,text,r.x+r.w/2,r.y+(r.h-size*1.2)/2,size,{232,247,255,255},font,NVG_ALIGN_CENTER,0,false,size*1.2)
    if self.state.focused then Rounded(vg,r.x-2*k,r.y-2*k,r.w+4*k,r.h+4*k,12*k);nvgStrokeWidth(vg,2*k);nvgStrokeColor(vg,nvgRGBA(255,255,255,255));nvgStroke(vg) end
    nvgRestore(vg)
end
function Stick:Render(vg)
    local font=Font(vg);local r=self:GetAbsoluteLayout();local k=self.props.touchScale or 1
    local cx,cy=r.x+r.w/2,r.y+r.h/2
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,r.w/2-k/2);nvgFillColor(vg,nvgRGBA(20,43,66,107));nvgFill(vg)
    nvgStrokeWidth(vg,k);nvgStrokeColor(vg,nvgRGBA(122,216,255,136));nvgStroke(vg)
    nvgBeginPath(vg);nvgCircle(vg,cx+(self.axisX or 0)*r.w*.36,cy+(self.axisY or 0)*r.w*.36,22*k-k/2)
    nvgFillColor(vg,nvgRGBA(122,216,255,112));nvgFill(vg);nvgStrokeColor(vg,nvgRGBA(182,236,255,153));nvgStroke(vg)
    D.Text(vg,'移动',cx,cy-6*k,12*k,{232,247,255,255},font,NVG_ALIGN_CENTER)
end
return {Button=Button,Stick=Stick,Font=Font}
