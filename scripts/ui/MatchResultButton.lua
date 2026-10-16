local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Button=Base:Extend('VoxMatchResultButton')
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local k=r.h/50
    nvgSave(vg);nvgGlobalAlpha(vg,self.revealAlpha or 1)
    local points={r.x+10*k,r.y,r.x+r.w,r.y,r.x+r.w-10*k,r.y+r.h,r.x,r.y+r.h}
    require('ui.SourceRelief').Draw(vg,r.x,r.y,r.w,r.h,self.props.primary==true,true,points)
    if self.state.hovered then D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,255,255,32));nvgFill(vg) end
    D.Text(vg,self.props.text,r.x+r.w/2,r.y+14*k,18*k,{243,249,255,255},'vox-title',NVG_ALIGN_CENTER,4*k)
    nvgRestore(vg)
end
return Button
