-- Original srh bars/caption/skip/flash, drawn in the existing UI frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Ease=require('ui.SourceButtonMotion').Ease
local Page=UI.Widget:Extend('VoxSalvageCinematics')
function Page:HitTest() return self.session.salvage.cine.skipOn==true end
function Page:OnPointerDown() return true end
function Page:OnPointerUp() return true end
function Page:OnClick(event)
    local r=self.skipRect
    if r and event.x>=r.x and event.x<=r.x+r.w and event.y>=r.y and event.y<=r.y+r.h then self.session.salvage.cine:Skip() end
    return true
end
function Page:Render(vg)
    local cine=self.session.salvage.cine;D.Begin(vg);local b=self:GetAbsoluteLayout();local w,h=b.w,b.h
    nvgSave(vg);nvgTranslate(vg,b.x,b.y)
    local bars=h*.11*cine.bars.value
    D.Rect(vg,0,0,w,bars,{0,0,0,255});D.Rect(vg,0,h-bars,w,bars,{0,0,0,255})
    local k=math.min(1,w/1100,h/640);local cap=cine.caption.value
    if cine.namecard.value>.001 then
        nvgSave(vg);nvgGlobalAlpha(vg,cine.namecard.value);local x=-40*(1-cine.namecard.value)*k;local y=h*.36;local edge=w*.05
        local cw=math.max(D.Width(vg,cine.cardTitle,28*k,'vox-story'),D.Width(vg,cine.cardSub,13*k,'vox-story'))+edge+40*k
        nvgBeginPath(vg);nvgRect(vg,x,y,cw,85*k);D.Gradient(vg,x+cw*.6,y,cw*.4,85*k,{12,15,18,238},{12,15,18,0},true)
        D.Rect(vg,x,y,6*k,85*k,{255,52,32,255})
        D.Text(vg,cine.cardTitle,x+edge,y+12*k,28*k,{242,239,232,255},'vox-story')
        D.Text(vg,cine.cardSub,x+edge,y+54*k,13*k,{255,180,168,255},'vox-story');nvgRestore(vg)
    end
    if cap>.001 then
        nvgSave(vg);nvgGlobalAlpha(vg,cap)
        local x,y=w*.06,h*.86-67*k+10*(1-cap)*k
        D.Text(vg,cine.lastTitle,x,y,34*k,{242,239,232,255},'vox-story',nil,0,false,nil,{{x=0,y=2*k,blur=12*k,color={0,0,0,170}}})
        D.Text(vg,cine.lastSub,x,y+47*k,15*k,{240,162,28,255},'vox-story');nvgRestore(vg)
    end
    local sk=cine.skip.value
    if sk>.001 then
        nvgSave(vg);nvgGlobalAlpha(vg,sk);local x,y=w*.96-99*k,h*.87-22*k
        nvgBeginPath(vg);nvgRect(vg,x,y,38*k,24*k);nvgStrokeColor(vg,D.Color({201,193,178,255}));nvgStrokeWidth(vg,k);nvgStroke(vg)
        D.Text(vg,'空格',x+17*k,y+4*k,13*k,{201,193,178,255},'vox-title',NVG_ALIGN_CENTER)
        D.Text(vg,'跳过',x+45*k,y+4*k,13*k,{201,193,178,255},'vox-title');nvgRestore(vg)
        self.skipRect={x=b.x+x-12*k,y=b.y+y-12*k,w=123*k,h=48*k}
    else self.skipRect=nil end
    if cine.flashDuration and cine.flashTime<cine.flashDuration then
        local alpha=cine.flash*(1-Ease(cine.flashTime/cine.flashDuration,'ease'))
        D.Rect(vg,0,0,w,h,{255,255,255,math.floor(alpha*255)})
    end
    nvgRestore(vg)
end
return Page
