-- Frozen CSS background: center / auto 100% repeat-x, including source edges.
local D=require 'ui.SourceDraw'
local M={}
local contexts=setmetatable({},{__mode='k'})
function M.Halftone(vg,x,y,w,h,light,textureWidth,points)
    local handles=contexts[vg]
    if not handles then handles={};contexts[vg]=handles end
    local key=light and 'halftoneLight' or 'halftone'
    if not handles[key] then
        handles[key]=nvgCreateImage(vg,light and 'UI/HalftoneSoftLight.png' or 'UI/HalftoneSoftDark.png',0)
        assert(handles[key]>0,'Source halftone image unavailable')
    end
    local sh=textureWidth and textureWidth/2 or h*1.7;local sw=sh*2
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h)
    D.Path(vg,points or {x,y,x+w,y,x+w,y+h,x,y+h})
    nvgFillPaint(vg,nvgImagePattern(vg,x+w-sw,textureWidth and y or y+(h-sh)/2,sw,sh,0,handles[key],1));nvgFill(vg);nvgRestore(vg)
end
function M.Draw(vg,x,y,w,h,primary,compact,points,printed)
    local handles=contexts[vg]
    if not handles then handles={};contexts[vg]=handles end
    D.Path(vg,points)
    if printed==nil then printed=not compact or primary end
    if printed then
        local name=(primary and 'primary' or 'side')..(compact and '-compact' or '')
        local handle=handles[name]
        if not handle then
            handle=nvgCreateImage(vg,'UI/Relief-'..name..'.png',NVG_IMAGE_REPEATX)
            assert(handle>0,'Source relief image unavailable: '..name);handles[name]=handle
        end
        local period=5*h/(compact and 44 or 100)
        nvgFillPaint(vg,nvgImagePattern(vg,x+(w-period)/2,y,period,h,0,handle,1))
    else nvgFillColor(vg,D.Color(primary and {45,122,203,255} or {25,62,110,255})) end
    nvgFill(vg)
    -- CSS inset shadows are clipped by the same polygon as the material.
    for _,edge in ipairs({{y,primary and {182,224,255,153} or {142,198,249,128}},
        {y+h-1.5,primary and {18,62,114,115} or {11,36,75,128}}}) do
        nvgSave(vg);nvgIntersectScissor(vg,x,edge[1],w,1.5)
        D.Path(vg,points);nvgFillColor(vg,D.Color(edge[2]));nvgFill(vg);nvgRestore(vg)
    end
end
return M
