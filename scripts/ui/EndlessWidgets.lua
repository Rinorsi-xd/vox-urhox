local UI=require('urhox-libs/UI')
local D=require('ui.SourceDraw')
local Button=UI.Button:Extend('VoxEndlessButton')
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    local bg=self.state.hovered and {41,72,93,255} or {23,44,58,255};if p.disabled then nvgSave(vg);nvgGlobalAlpha(vg,.45) end
    D.Rect(vg,r.x,r.y,r.w,r.h,bg);nvgBeginPath(vg);nvgRect(vg,r.x+.5,r.y+.5,r.w-1,r.h-1);nvgStrokeColor(vg,nvgRGBA(105,131,150,102));nvgStrokeWidth(vg,1);nvgStroke(vg)
    local preview=p.thumb or p.repair;local thumb=p.shop and 56 or 80
    if p.thumb then self:RenderBackgroundImage(vg,p.thumb,{x=r.x+(p.shop and 8 or 20),y=r.y+(p.shop and 8 or 12),w=thumb,h=thumb},'contain',nil)
    elseif p.repair then D.Text(vg,'✚',r.x+20,r.y+12,44,{238,247,255,255},'vox-title') end
    local x=r.x+(p.shop and 74 or 20);local y=r.y+(p.shop and 14 or preview and 100 or p.subtitle and 16 or (r.h-18)/2)
    D.Text(vg,p.text or '',x,y,p.subtitle and 18 or 14,{238,247,255,255},'vox-title')
    if p.subtitle then D.Text(vg,p.subtitle,x,y+(p.shop and 26 or 31),p.shop and 12 or 14,{190,208,219,255},'vox-title');if p.reason then D.Text(vg,p.reason,x,y+55,14,{190,208,219,255},'vox-title') end end
    if p.disabled then nvgRestore(vg) end
end
local Frame=UI.Panel:Extend('VoxEndlessPanel')
function Frame:Render(vg)
    local r=self:GetAbsoluteLayout();D.Rect(vg,r.x,r.y,r.w,r.h,{12,24,37,245});nvgBeginPath(vg);nvgRect(vg,r.x+.5,r.y+.5,r.w-1,r.h-1);nvgStrokeColor(vg,nvgRGBA(83,113,132,255));nvgStrokeWidth(vg,1);nvgStroke(vg)
end
return {Button=Button,Frame=Frame}
