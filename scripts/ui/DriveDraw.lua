-- Resolved source drive.css variables: legacy cyan is now white; cut is none.
local D=require 'ui.SourceDraw'
local M={}
function M.Width(vg,text,size,spacing,font)
    return D.Width(vg,text,size,font,spacing)
end
function M.Text(vg,text,x,y,size,color,spacing,font,align)
    local w=M.Width(vg,text,size,spacing,font)
    D.Text(vg,text,x,y,size,color,font,align,spacing);return w
end
function M.Panel(vg,x,y,w,h,border)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);D.Gradient(vg,x,y,w,h,{14,27,40,214},{8,16,25,184})
    nvgBeginPath(vg);nvgRect(vg,x+.5,y+.5,w-1,h-1);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color(border or {53,58,66,255}));nvgStroke(vg)
end
function M.Key(vg,text,x,y)
    local w=math.max(18,M.Width(vg,text,12,.5)+12)
    D.Rect(vg,x,y,w,19,{0,0,0,89});nvgBeginPath(vg);nvgRoundedRect(vg,x+.5,y+.5,w-1,18,2)
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(86,93,104,255));nvgStroke(vg)
    M.Text(vg,text,x+w/2,y+2,12,D.white,.5,nil,NVG_ALIGN_CENTER);return w
end
return M
