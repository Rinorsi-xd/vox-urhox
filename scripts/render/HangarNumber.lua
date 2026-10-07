-- Exact source font outlines for the 900/1080px bay numbers. No font atlas.
local Data=require 'render.HangarGlyphData'
local M={}
function M.Draw(vg,text,x,y,size,color)
    local width=0
    for ch in text:gmatch('.') do width=width+assert(Data.glyphs[ch]).advance end
    local scale=size/Data.units
    nvgSave(vg);nvgTranslate(vg,x-width*scale/2,y);nvgScale(vg,scale,scale)
    -- This runtime's NanoVG offscreen framebuffer does not attach linked stencil.
    -- Non-overlapping convex triangles preserve counters without stencil fills.
    nvgShapeAntiAlias(vg,0)
    nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],color[4] or 255))
    for ch in text:gmatch('.') do
        local g=Data.glyphs[ch]
        for _,p in ipairs(g.triangles) do
            nvgBeginPath(vg);nvgMoveTo(vg,p[1],p[2]);nvgLineTo(vg,p[3],p[4]);nvgLineTo(vg,p[5],p[6]);nvgClosePath(vg);nvgFill(vg)
        end
        nvgTranslate(vg,g.advance,0)
    end
    nvgRestore(vg)
end
return M
