local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Overlay=Panel:Extend('VoxHomeBayOverlay')
function Overlay:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h;local a=self.data
    if a.draft then
        D.Path(vg,{x,y,x+w-16,y,x+w,y+16,x+w,y+h,x,y+h});D.Gradient(vg,x,y,w,h,{42,46,53,255},{27,29,34,255})
        D.Icon(vg,'wrench',x+w/2-15,y+20,30,D.dim);D.Text(vg,'草稿',x+w/2,y+58,18,D.dim,nil,NVG_ALIGN_CENTER)
    end
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h*.34);D.Gradient(vg,x,y,w,h*.34,{0,0,0,140},{0,0,0,0})
    nvgBeginPath(vg);nvgRect(vg,x,y+h*.42,w,h*.58);D.Gradient(vg,x,y+h*.42,w,h*.58,{10,11,13,0},{10,11,13,242})
    D.Text(vg,a.draft and '--' or string.format('%02d',a.slot),x+10,y+6,34,a.active and D.orange or D.white)
    nvgSave(vg);nvgIntersectScissor(vg,x+11,y+h-51,w-22,50)
    D.Text(vg,a.name,x+11,y+h-47,19);D.Icon(vg,a.draft and 'cube' or 'chip',x+11,y+h-25,14,D.muted)
    D.Text(vg,a.draft and (a.parts..' · 还没放进车位') or D.Number(a.budget),x+29,y+h-26,14,D.muted)
    if not a.draft then local sx=x+39+D.Width(vg,D.Number(a.budget),14);D.Icon(vg,'cube',sx,y+h-25,14,D.muted);D.Text(vg,a.parts,sx+18,y+h-26,14,D.muted) end
    nvgRestore(vg)
    -- Original inset shadow is beneath the full-size image; only ::after remains visible.
    if a.active then D.Rect(vg,x,y+h-4,w,4,D.orange) end
end
return Overlay
