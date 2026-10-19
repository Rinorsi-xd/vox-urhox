local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Overlay=Panel:Extend('VoxHomeBayOverlay')
function Overlay:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h;local a=self.data
    if a.draft then
        D.Panel(vg,x,y,w,h,12,{32,58,84,255},{18,38,56,255})
        -- 手机紧凑车位卡只有 74 高，水印会压在底部信息上，不画
        if h>=80 then D.Text(vg,'草稿',x+w/2,y+38,17,D.dim,nil,NVG_ALIGN_CENTER) end
    end
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h*.34);D.Gradient(vg,x,y,w,h*.34,{0,0,0,140},{0,0,0,0})
    -- 底部只剩一行小字，压暗区收窄，多露出预览图
    nvgBeginPath(vg);nvgRect(vg,x,y+h*.58,w,h*.42);D.Gradient(vg,x,y+h*.58,w,h*.42,{10,11,13,0},{10,11,13,217})
    D.Text(vg,a.draft and '—' or string.format('%02d',a.slot),x+10,y+7,25,a.active and D.orange or D.white)
    -- 车位卡不再显示车名：底部常驻预算 / 零件数，草稿显示零件数和入库提示
    nvgSave(vg);nvgIntersectScissor(vg,x+11,y+h-30,w-22,28)
    D.Icon(vg,a.draft and 'cube' or 'chip',x+11,y+h-22,12,D.muted)
    D.Text(vg,a.draft and (a.parts..' · 还没放进车位') or D.Number(a.budget),x+27,y+h-23,12,D.muted)
    if not a.draft then local sx=x+37+D.Width(vg,D.Number(a.budget),12);D.Icon(vg,'cube',sx,y+h-22,12,D.muted);D.Text(vg,a.parts,sx+16,y+h-23,12,D.muted) end
    nvgRestore(vg)
    -- Original inset shadow is beneath the full-size image; only ::after remains visible.
    if a.active or a.draft then D.Rect(vg,x,y+h-3,w,3,D.orange) end
end
return Overlay
