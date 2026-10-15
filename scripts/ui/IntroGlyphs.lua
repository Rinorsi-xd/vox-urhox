-- Original font contours support true centered CSS text stroke, including holes.
local D=require 'ui.SourceDraw'
local data=require('core.ResourceData').Read('Intro/Fonts/TitleGlyphs.json')
local M={}
function M.Glyph(char)return assert(data.glyphs[char],'Missing original title glyph '..char)end
function M.Width(text,size,spacing)
 local width=0
 for _,cp in utf8.codes(text) do width=width+M.Glyph(utf8.char(cp)).advance*size+(spacing or 0) end
 return width
end
function M.Draw(vg,char,x,y,size,fill,stroke,thickness)
 local glyph=M.Glyph(char);nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size,size);nvgBeginPath(vg)
 for _,contour in ipairs(glyph.contours) do
  for _,c in ipairs(contour.commands) do
   if c[1]=='m' then nvgMoveTo(vg,c[2],c[3]) elseif c[1]=='l' then nvgLineTo(vg,c[2],c[3])
   elseif c[1]=='c' then nvgBezierTo(vg,c[2],c[3],c[4],c[5],c[6],c[7]) else nvgClosePath(vg) end
  end
  nvgPathWinding(vg,contour.hole and NVG_HOLE or NVG_SOLID)
 end
 if stroke and thickness>0 then nvgStrokeWidth(vg,thickness/size);nvgStrokeColor(vg,D.Color(stroke));nvgStroke(vg) end
 nvgFillColor(vg,D.Color(fill));nvgFill(vg);nvgRestore(vg)
end
function M.Ascent()return data.ascent end
function M.Descent()return data.descent end
return M
