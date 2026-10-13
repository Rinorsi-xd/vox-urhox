-- Frozen shared/ui/mechFrame.js geometry used by storyHud.css.
local D=require 'ui.SourceDraw'
local M={}
local function Ring(w,h,cut,out)
    local k=2-math.sqrt(2);local a=cut>0 and cut+out*k or 0
    return {a-out,-out,w+out,-out,w+out,h+out-a,w+out-a,h+out,-out,h+out,-out,a-out}
end
function M.Draw(vg,x,y,w,h,cut,color)
    cut=cut or 12;color=color or {70,200,255,255}
    nvgSave(vg);nvgTranslate(vg,x,y)
    D.Path(vg,Ring(w,h,cut,0));D.Gradient(vg,0,0,w,h,{30,32,36,242},{14,15,17,247})
    for _,out in ipairs({0,7}) do
        D.Path(vg,Ring(w,h,cut+(out>0 and 4 or 0),out));nvgStrokeWidth(vg,1)
        nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],out==0 and 64 or 153));nvgStroke(vg)
    end
    for _,points in ipairs({{w+7,-7,w+7,5,w-5,-7},{-7,h+7,-7,h-5,5,h+7}}) do
        D.Path(vg,points);nvgFillColor(vg,D.Color(color));nvgFill(vg)
    end
    local c=cut+4+7*(2-math.sqrt(2))
    nvgBeginPath(vg);nvgMoveTo(vg,-7,c-7+46);nvgLineTo(vg,-7,c-7);nvgLineTo(vg,c-7,-7);nvgLineTo(vg,c-7+60,-7)
    nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
    for i=0,2 do D.Line(vg,14+i*13,12,21+i*13,12,color);D.Line(vg,17.5+i*13,8.5,17.5+i*13,15.5,color) end
    for row=0,2 do for col=0,1 do D.Rect(vg,w-14+col*5,h-18+row*5,2,2,color) end end
    nvgRestore(vg)
end
return M
