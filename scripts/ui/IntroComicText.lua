-- Frozen intro.css .sfx: original GameFont contours, centered transforms.
local G=require 'ui.IntroGlyphs'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local M={}
local black={11,11,13,255}
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do
  local v=(lo+hi)/2;local q=1-v;local x=3*q*q*v*x1+3*q*v*v*x2+v*v*v
  if x<t then lo=v else hi=v end
 end
 local v=(lo+hi)/2;local q=1-v;return 3*q*q*v*y1+3*q*v*v*y2+v*v*v
end
local function Impact(vg,text,x,y,size,rotation,scale,alpha,spacing,ink,stroke,thickness,shadows)
 local width=G.Width(text,size,spacing);local baseline=size*G.Ascent()
 nvgSave(vg);nvgTranslate(vg,x+width/2,y+size/2);nvgRotate(vg,rotation*math.pi/180);nvgScale(vg,scale,scale)
 nvgTranslate(vg,-width/2,-size/2);nvgGlobalAlpha(vg,math.max(0,math.min(1,alpha)))
 for _,shadow in ipairs(shadows) do
  local left=0
  for _,cp in utf8.codes(text) do
   local char=utf8.char(cp)
   G.Draw(vg,char,left+size*shadow[1],baseline+size*shadow[1],size,shadow[2],shadow[2],thickness)
   left=left+G.Glyph(char).advance*size+spacing
  end
 end
 local left=0
 for _,cp in utf8.codes(text) do
  local char=utf8.char(cp)
  G.Draw(vg,char,left,baseline,size,ink,stroke,thickness)
  left=left+G.Glyph(char).advance*size+spacing
 end
 nvgRestore(vg)
end
function M.No(vg,w,h,u,age)
 local size=34*u;local t=Ease(age/.24,.2,.8,.3,1.2)
 local scale=t<.7 and 2.8+(.94-2.8)*t/.7 or .94+.06*(t-.7)/.3
 local rotation=t<.7 and -10+6*t/.7 or -4
 local width=G.Width('NO!',size,size*.02)
 Impact(vg,'NO!',(w-width)/2,(h-size)/2,size,rotation,scale,t/.7,size*.02,
  {255,45,31,255},{255,255,255,255},size*.12,
  {{.2,{0,0,0,128}},{.16,black},{.12,black},{.08,black},{.04,black}})
end
function M.Bang(vg,x,y,u,age)
 local size=13*u;local t=Ease(age/.2,.2,.9,.3,1.3)
 Impact(vg,'砰——！',x,y,size,-20+12*t,2.6-1.6*t,t,0,{255,59,48,255},black,size*.1,
  {{.09,{255,255,255,255}},{.05,black}})
end
function M.Measure(text,size)
 return {width=G.Width(text,size,0),height=size,baseline=(size-size*(G.Ascent()+G.Descent()))/2+size*G.Ascent()}
end
function M.Draw(vg,text,x,y,size,rotation,state,variant)
 local box=M.Measure(text,size);local scale=2.4-1.4*state.fx
 local color=variant=='red' and {255,59,48,255} or variant=='white' and {255,255,255,255} or {255,211,106,255}
 local back=variant=='red' and {255,255,255,255} or variant=='white' and {40,121,235,255} or {216,23,12,255}
 nvgSave(vg);nvgTranslate(vg,x+box.width/2,y+box.height/2)
 nvgRotate(vg,(rotation-12*(1-state.fx))*math.pi/180);nvgScale(vg,scale,scale)
 nvgTranslate(vg,-box.width/2,-box.height/2);nvgGlobalAlpha(vg,state.alpha*state.fx)
 local left=0
 for _,cp in utf8.codes(text) do
  local char=utf8.char(cp)
  G.Draw(vg,char,left+size*.09,box.baseline+size*.09,size,back,back,size*.1)
  G.Draw(vg,char,left+size*.05,box.baseline+size*.05,size,black,black,size*.1)
  G.Draw(vg,char,left,box.baseline,size,color,black,size*.1)
  left=left+G.Glyph(char).advance*size
 end
 nvgRestore(vg)
 return box
end
return M
