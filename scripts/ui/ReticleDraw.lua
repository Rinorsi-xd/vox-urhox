local D=require 'ui.SourceDraw'
local M={white={242,246,248,255},muted={242,246,248,166},hp={111,230,207,255},en={46,168,255,255},warn={255,176,46,255},red={255,74,58,255},busy={120,200,255,255}}
function M.Arc(vg,x,y,r,a,b,color,width,glow)
    if math.abs(b-a)<.001 then return end
    local function Stroke(w,c)
        nvgBeginPath(vg);nvgArc(vg,x,y,r,a*math.pi/180,b*math.pi/180,b>a and NVG_CW or NVG_CCW)
        nvgStrokeWidth(vg,w);nvgLineCap(vg,NVG_BUTT);nvgStrokeColor(vg,D.Color(c));nvgStroke(vg)
    end
    if glow then nvgSave(vg);nvgGlobalAlpha(vg,.12);Stroke(width+glow*2,color);nvgRestore(vg) end
    Stroke(width,color)
end
function M.Spoke(vg,x,y,r0,r1,a,c,w)
    local ca,sa=math.cos(a*math.pi/180),math.sin(a*math.pi/180)
    D.Line(vg,x+ca*r0,y+sa*r0,x+ca*r1,y+sa*r1,c,w)
end
local textScale=1
local outline={{-1,0},{1,0},{0,-1},{0,1},{-.707107,-.707107},{.707107,-.707107},{-.707107,.707107},{.707107,.707107}}
local outlineColor={0,0,0,170}
function M.SetTextScale(scale) textScale=scale end
function M.Width(vg,text,size,medium,spacing)
    return D.Width(vg,text,size,medium and 'vox-hud-medium' or 'vox-hud',(spacing or 1)*textScale)
end
function M.Text(vg,text,x,y,size,color,align,story,medium,spacing)
    -- Final source reticle CSS uses Chakra + Industrial in story and free drive.
    -- NanoVG has no text stroke; use the UI library's eight-offset outline method.
    local font=medium and 'vox-hud-medium' or 'vox-hud'
    local tracking=(spacing or 1)*textScale;local radius=1.5*textScale
    for _,offset in ipairs(outline) do
        D.Text(vg,text,x+offset[1]*radius,y+offset[2]*radius,size,outlineColor,font,align,tracking,true)
    end
    D.Text(vg,text,x,y,size,color or M.white,font,align,tracking,true)
end
function M.Poly(vg,points,fill,stroke,width)
    D.Path(vg,points)
    if fill then nvgFillColor(vg,D.Color(fill));nvgFill(vg) end
    if stroke then nvgStrokeColor(vg,D.Color(stroke));nvgStrokeWidth(vg,width or 1);nvgStroke(vg) end
end
return M
