local D=require 'ui.SourceDraw'
local M={};local contexts=setmetatable({},{__mode='k'})
function M.Begin(vg)
    D.Begin(vg);if contexts[vg] then return end
    local font='Fonts/MiSans-Regular.ttf'
    if GetPlatform()=='Windows' and os.getenv then
        local windows=os.getenv and os.getenv('SystemRoot') or 'C:/Windows'
        local candidate=windows:gsub('\\','/')..'/Fonts/segoeui.ttf'
        if fileSystem:FileExists(candidate) then font=candidate end
    end
    local face=nvgCreateFont(vg,'vox-music-latin',font)
    if face<0 and font~='Fonts/MiSans-Regular.ttf' then
        face=nvgCreateFont(vg,'vox-music-latin','Fonts/MiSans-Regular.ttf')
    end
    assert(face>=0,'Music Latin font unavailable');contexts[vg]={}
end
function M.Texture(vg,name,x,y,w,h,points)
    local ctx=contexts[vg];local handle=ctx[name]
    if not handle then handle=nvgCreateImage(vg,'UI/Music/'..name..'.png',NVG_IMAGE_REPEATX);assert(handle>0,'Music texture missing: '..name);ctx[name]=handle end
    local period=h*5/100;D.Path(vg,points or {x,y,x+w,y,x+w,y+h,x,y+h});nvgFillPaint(vg,nvgImagePattern(vg,x+(w-period)/2,y,period,h,0,handle,1));nvgFill(vg)
end
function M.Image(vg,name,x,y,w,h,points)
    local ctx=contexts[vg];local handle=ctx[name]
    if not handle then handle=nvgCreateImage(vg,'UI/Music/'..name..'.png',NVG_IMAGE_GENERATE_MIPMAPS);assert(handle>0,'Music artwork missing: '..name);ctx[name]=handle end
    D.Path(vg,points or {x,y,x+w,y,x+w,y+h,x,y+h});nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,handle,1));nvgFill(vg)
end
function M.CutEdges(vg,x,y,w,h,color,cut,topRight)
    local c=cut or 14
    D.Rect(vg,x,y,w-(topRight and c or 0),1,color)
    D.Rect(vg,x+w-1,y+(topRight and c or 0),1,h-c,color)
    D.Rect(vg,x,y,1,h,color);D.Rect(vg,x,y+h-1,w-(topRight and 0 or c),1,color)
end
function M.Stroke(vg,x,y,w,h,color)
    nvgBeginPath(vg);nvgRect(vg,x+.5,y+.5,w-1,h-1);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
end
function M.Text(vg,text,x,y,size,color,font,align,lineHeight)
    D.Text(vg,text,x,y,size,color or {228,237,240,255},font or 'vox-body',align,0,false,lineHeight or size*1.5)
end
function M.Icon(vg,name,x,y,size,color,fill)
    -- Original icons.js paths; music-box.css requests rounded 1.8px strokes.
    local paths=require('core.ResourceData').Read('UI/SourceIcons.json');local path=paths[name];if not path then return end
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size/24,size/24);nvgBeginPath(vg)
    for _,p in ipairs(path) do if p[1]=='moveTo' then nvgMoveTo(vg,p[2],p[3]) elseif p[1]=='lineTo' then nvgLineTo(vg,p[2],p[3]) elseif p[1]=='curveTo' then nvgBezierTo(vg,p[2],p[3],p[4],p[5],p[6],p[7]) elseif p[1]=='closePath' then nvgClosePath(vg) end end
    if fill then nvgFillColor(vg,D.Color(fill));nvgFill(vg) end
    nvgLineCap(vg,NVG_ROUND);nvgLineJoin(vg,NVG_ROUND);nvgStrokeWidth(vg,1.8);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg);nvgRestore(vg)
end
function M.Time(t) t=math.max(0,math.floor(t or 0));return math.floor(t/60)..':'..string.format('%02d',t%60) end
function M.Color(hex) return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255} end
function M.Local(vg,widget)
    M.Begin(vg);local r=widget:GetAbsoluteLayout();local s=widget.owner;local k=s.layout.k
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k);nvgGlobalAlpha(vg,s.alpha or 1)
    return r.w/k,r.h/k,s
end
function M.Focus(vg,w,h,widget)
    if widget.state.focused and widget.owner.keyboardFocus then M.Stroke(vg,1,1,w-2,h-2,{255,188,101,255}) end
end
return M
