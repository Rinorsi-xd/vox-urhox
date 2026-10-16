local Base=require 'ui.ActionButton'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Button=Base:Extend('VoxSourceModeAction')
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local car=p.sourceKind=='loadout'
    local points={x+22,y,x+w,y,x+w-22,y+h,x,y+h}
    if car then D.Path(vg,points);D.Gradient(vg,x,y,w,h,{42,46,53,255},{23,25,29,255})
    else Relief.Draw(vg,x,y,w,h,true,false,points) end
    if self.state.hovered then D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,255,255,20));nvgFill(vg) end
    if car then
        D.Path(vg,{x+22,y,x+26,y,x+4,y+h,x,y+h});nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
        local cx,cy=x+62,y+h/2
        D.Path(vg,{cx,cy-30.5,cx+27,cy-15.25,cx+27,cy+15.25,cx,cy+30.5,cx-27,cy+15.25,cx-27,cy-15.25})
        nvgStrokeWidth(vg,3);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg)
        D.Text(vg,'T'..p.tier,cx,cy-13,26,D.white,'vox-tabular',NVG_ALIGN_CENTER)
        D.Text(vg,'出战战车 · LOADOUT',x+104,y+14,11,{127,154,180,255},nil,nil,2)
        D.Text(vg,p.text,x+104,y+30,24,nil,nil,nil,1,false,26.4)
        D.Icon(vg,p.valid and 'check' or 'warn',x+104,y+61,13,p.valid and D.green or {255,109,114,255})
        D.Text(vg,p.valid and '按 '..require('Config').TIERS[p.tier].name..' 匹配' or '不符合出战限制',x+122,y+61,12,D.muted,'vox-body')
        D.Text(vg,'换车 ›',x+w-44,y+36,13,{219,238,255,255},nil,NVG_ALIGN_RIGHT,2)
    else
        D.Text(vg,p.text,x+40,y+14.5,40,{243,249,255,255},nil,nil,4,false,40);D.Text(vg,p.subtitle,x+40,y+58.5,12,{228,244,255,255},'vox-body',nil,2)
        local kw=D.Width(vg,'Enter',13)+16;D.Rect(vg,x+w-34-kw,y+31,kw,26,{19,36,58,255})
        D.Text(vg,'Enter',x+w-26-kw,y+36,13,{219,238,255,255})
    end
end
return Button
