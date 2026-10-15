-- Exact asymmetric rings and accents from shared/ui/mechFrame.js.
local D=require 'ui.SourceDraw'
local M={}
local K=2-math.sqrt(2)
local function Ring(w,h,c,o)
    local a,b,e,f=table.unpack(c);a=a>0 and a+o*K or 0;b=b>0 and b+o*K or 0
    e=e>0 and e+o*K or 0;f=f>0 and f+o*K or 0
    return {a-o,-o,w+o-b,-o,w+o,b-o,w+o,h+o-e,w+o-e,h+o,f-o,h+o,-o,h+o-f,-o,a-o}
end
function M.Shape(vg,w,h,portrait) D.Path(vg,Ring(w,h,portrait and {0,14,0,14} or {12,0,12,0},0)) end
function M.Draw(vg,w,h,portrait,accent,line)
    local cut=portrait and {0,14,0,14} or {12,0,12,0}
    M.Shape(vg,w,h,portrait);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(255,255,255,26));nvgStroke(vg)
    local outer={};for i,v in ipairs(cut) do outer[i]=v>0 and v+4 or 0 end
    D.Path(vg,Ring(w,h,outer,7));nvgStrokeColor(vg,D.Color(line));nvgStroke(vg)
    local tris=portrait and {{-7,-7,3,-7,-7,3},{w+7,h+7,w-3,h+7,w+7,h-3}}
        or {{w+7,-7,w+7,5,w-5,-7},{-7,h+7,-7,h-5,5,h+7}}
    for _,tri in ipairs(tris) do D.Path(vg,tri);nvgFillColor(vg,D.Color(accent));nvgFill(vg) end
    local c=outer[portrait and 2 or 1]+7*K
    local pts=portrait and {w+7-c-60,-7,w+7-c,-7,w+7,c-7,w+7,c-7+46}
        or {-7,c-7+46,-7,c-7,c-7,-7,c-7+60,-7}
    for _,style in ipairs({{9,20},{6,38},{3,255}}) do
        nvgBeginPath(vg);nvgMoveTo(vg,pts[1],pts[2]);for i=3,#pts,2 do nvgLineTo(vg,pts[i],pts[i+1]) end
        nvgStrokeWidth(vg,style[1]);nvgStrokeColor(vg,nvgRGBA(accent[1],accent[2],accent[3],style[2]));nvgStroke(vg)
    end
    if not portrait then
        for i=0,2 do D.Line(vg,14+i*13,12,21+i*13,12,{255,255,255,66},1.2);D.Line(vg,17.5+i*13,8.5,17.5+i*13,15.5,{255,255,255,66},1.2) end
        for row=0,2 do for col=0,1 do D.Rect(vg,w-14+col*5,h-18+row*5,2,2,{255,255,255,77}) end end
    end
end
return M
