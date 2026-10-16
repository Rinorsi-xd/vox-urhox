-- Frozen introLogo.sting / intro.css .ip2: independent CSS animation clocks.
local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local Images=require 'urhox-libs/UI/Core/ImageCache'
local M={}
local chars={'星','际','前','途'}
local english='INTERSTELLAR PROSPECTS LTD.'
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(p,x1,y1,x2,y2)
 if p<=0 then return 0 elseif p>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<p then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(age)
 local track=Ease((age-.85)/.9,.2,.8,.2,1)
 local plan={line=Ease(age/.5,.7,0,.2,1),lineAlpha=1-Ease((age-1.1)/.4,.42,0,1,1),
  mask=.75*Ease((age-.35)/.6,.7,0,.2,1),wordAlpha=Ease((age-.5)/.4,.25,.1,.25,1),
  englishAlpha=track,englishSpacing=1.2+(.42-1.2)*track,metaAlpha=Ease((age-1)/.5,.25,.1,.25,1),letters={}}
 for i=1,4 do plan.letters[i]=1-Ease((age-.6-(i-1)*.06)/.5,.2,.8,.2,1) end
 return plan
end
local function Image(vg,I,name,x,y,size,radius)
 if not I.downloaded then return end
 local path=I.data.images[name];local handle=path and Images.Get(path)
 if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local scale=math.min(size/iw,size/ih);local dw,dh=iw*scale,ih*scale
 nvgSave(vg);nvgIntersectScissor(vg,x,y,size,size);nvgBeginPath(vg)
 if radius then nvgCircle(vg,x+size/2,y+size/2,radius*size) else nvgRect(vg,x,y,size,size) end
 nvgFillPaint(vg,nvgImagePattern(vg,x+(size-dw)/2,y+(size-dh)/2,dw,dh,0,handle,1));nvgFill(vg);nvgRestore(vg)
end
function M.Draw(vg,I,w,h,u,age)
 local plan=M.Plan(age)
 D.Rect(vg,0,0,w,h,{12,13,16,255})
 for x=0,w,8*u do D.Line(vg,x,0,x,h,{255,255,255,11},1) end
 for y=0,h,8*u do D.Line(vg,0,y,w,y,{255,255,255,11},1) end
 if plan.lineAlpha>0 then
  local right=w*plan.line;local alpha=plan.lineAlpha
  for _,pass in ipairs({{1.6,10},{.8,22},{.4,45}}) do
   D.Rect(vg,0,h/2-pass[1]*u/2,right,pass[1]*u,{40,121,235,math.floor(pass[2]*alpha)})
  end
  D.Rect(vg,0,h/2,right,1,{122,216,255,math.floor(255*alpha)})
 end
 local nameWidth=0;local advances={}
 for i,char in ipairs(chars) do local width=D.Width(vg,char,10*u,'vox-title',1.4*u);advances[i]=width;nameWidth=nameWidth+width end
 local englishSize=1.9*u;local englishSpacing=englishSize*plan.englishSpacing
 local wordWidth=math.max(nameWidth,D.Width(vg,english,englishSize,'vox-code',englishSpacing))
 local rowWidth=20*u+4.5*u+1+4.5*u+wordWidth
 local x=(w-rowWidth)/2;local top=(h-20*u)/2;local wordX=x+24.5*u+1+4.5*u;local wordY=(h-13.5*u)/2
 Image(vg,I,'company-emblem',x,top,20*u,plan.mask)
 nvgSave(vg);nvgGlobalAlpha(vg,plan.wordAlpha)
 D.Rect(vg,wordX-4.5*u-1,wordY,1,13.5*u,{255,255,255,64})
 local at=wordX
 for i,char in ipairs(chars) do
  nvgSave(vg);nvgIntersectScissor(vg,at,wordY,advances[i],10*u)
  D.Text(vg,char,at,wordY+10.5*u*plan.letters[i],10*u,{244,245,247,255},'vox-title',nil,1.4*u,false,10*u)
  nvgRestore(vg);at=at+advances[i]
 end
 nvgSave(vg);nvgGlobalAlpha(vg,plan.wordAlpha*plan.englishAlpha)
 D.Text(vg,english,wordX,wordY+11.6*u,englishSize,{154,160,170,255},'vox-code',nil,englishSpacing,false,englishSize)
 nvgRestore(vg);nvgRestore(vg)
 nvgSave(vg);nvgGlobalAlpha(vg,plan.metaAlpha)
 local metaSize=1.3*u;local metaSpacing=metaSize*.2;local gray={100,106,116,255}
 D.Text(vg,'PUBLIC SERVICE FILM — NO.077',w*.04,h*.12,metaSize,gray,'vox-code',nil,metaSpacing,false,metaSize)
 D.Text(vg,'SPECIAL SECURITY DIV. / SEC-07',w*.96,h*.12,metaSize,gray,'vox-code',NVG_ALIGN_RIGHT,metaSpacing,false,metaSize)
 local by=h*.88-6.4*u
 Image(vg,I,'division-insignia',w*.04,by,6.4*u)
 D.Text(vg,'特别安保部 · 荣誉出品',w*.04+8*u,by+(6.4*u-metaSize)/2,metaSize,{122,216,255,255},'vox-title',nil,metaSize*.3,false,metaSize)
 D.Text(vg,'EST. 2187',w*.96,h*.88-metaSize,metaSize,gray,'vox-code',NVG_ALIGN_RIGHT,metaSpacing,false,metaSize)
 nvgRestore(vg)
end
return M
