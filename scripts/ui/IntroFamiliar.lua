-- Source actFamiliar: staggered panels, screenshot Ken Burns, character breath.
local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Type=require 'ui.IntroTypography'
local ComicText=require 'ui.IntroComicText'
local M={}
local definitions={
 {at=0,rect={.025,.05,.42,.9},poly={0,0,1,0,.78,1,0,1},from={-.5,0},capture='charge',s1=1.14,s2=1},
 {at=.34,rect={.37,.05,.605,.43},poly={.09,0,1,0,1,1,0,1},from={0,-.6},capture='wreck',s1=1,s2=1.12},
 {at=.68,rect={.31,.51,.665,.44},poly={.06,0,1,0,1,1,0,1},from={.7,0}}
}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(p,x1,y1,x2,y2)
 if p<=0 then return 0 elseif p>=1 then return 1 end
 local lo,hi=0,1;for _=1,22 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<p then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(age)
 local result={}
 for index,d in ipairs(definitions) do
  local t=age-d.at
  if t>=0 then
   local entry=Ease(t/.3,.2,.9,.3,1.05);local kb=math.min(1,t/3)
   local fx=Ease((t-.12)/.22,.2,.9,.3,1.3)
   result[#result+1]={index=index,age=t,entry=entry,alpha=entry,scale=(d.s1 or 1)+((d.s2 or 1)-(d.s1 or 1))*kb,
    imageX=index==2 and .02-.04*kb or 0,fx=fx,breath=1+math.sin(math.max(0,age-.68)*2.2)*.008}
  end
 end
 return result
end
local function Points(d,w,h,pad)
 local p={};pad=pad or 0;for i=1,#d.poly,2 do p[i]=-pad+d.poly[i]*(w+2*pad);p[i+1]=-pad+d.poly[i+1]*(h+2*pad)end;return p
end
local function Tile(page,vg,path,points,size)
 page.comicPatterns=page.comicPatterns or {};local handle=page.comicPatterns[path]
 if not handle then handle=nvgCreateImage(vg,path,NVG_IMAGE_REPEATX|NVG_IMAGE_REPEATY);assert(handle>0,'Opening comic tile unavailable');page.comicPatterns[path]=handle;page.comicContext=vg end
 D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,0,0,size,size,0,handle,1));nvgFill(vg)
end
local function Picture(vg,page,rect,points,contain)
 local path=page.owner.data.images[contain and 'machinist_idle' or 'workshop'];local handle=Images.Get(path);if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local fit=(contain and math.min or math.max)(rect.w/iw,rect.h/ih);local dw,dh=iw*fit,ih*fit
 D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,rect.x+(rect.w-dw)/2,contain and rect.y+rect.h-dh or rect.y+(rect.h-dh)/2,dw,dh,0,handle,1));nvgFill(vg)
end
local function Label(vg,text,x,y,u,dark,right)
 local size=2.6*u;local width=D.Width(vg,text,size,'vox-title')+1.6*size+.7*u;local height=size*1.75+.7*u
 local left=right and x-width or x
 nvgSave(vg);nvgTranslate(vg,left+width/2,y+height/2);nvgRotate(vg,-2*math.pi/180);nvgTranslate(vg,-width/2,-height/2)
 D.Rect(vg,0,0,width,height,dark and {17,17,17,255}or{255,255,255,255})
 nvgBeginPath(vg);nvgRect(vg,0,0,width,height);nvgStrokeWidth(vg,.35*u);nvgStrokeColor(vg,dark and nvgRGBA(255,255,255,255)or nvgRGBA(17,17,17,255));nvgStroke(vg)
 D.Text(vg,text,size*.8+.35*u,size*.3+.35*u,size,dark and {255,255,255,255}or{17,17,17,255},'vox-title',nil,0,false,size*1.15);nvgRestore(vg)
end
function M.Draw(page,vg,w,h,u)
 Type.Begin(vg);D.Path(vg,{0,0,w,0,w,h,0,h});D.Gradient(vg,0,0,w,h,{26,27,31,255},{12,12,14,255})
 local I=page.owner
 for _,state in ipairs(M.Plan(I.age))do
  local d=definitions[state.index];local x,y,pw,ph=d.rect[1]*w,d.rect[2]*h,d.rect[3]*w,d.rect[4]*h
  nvgSave(vg);nvgTranslate(vg,x+pw/2+d.from[1]*w*(1-state.entry),y+ph/2+d.from[2]*h*(1-state.entry));nvgRotate(vg,-4*math.pi/180*(1-state.entry));nvgTranslate(vg,-pw/2,-ph/2);nvgGlobalAlpha(vg,state.alpha)
  for _,layer in ipairs({{.8,1.5,1.5,{0,0,0,184}},{.8,0,0,{11,11,13,255}},{.5,0,0,{255,255,255,255}}})do
   nvgSave(vg);nvgTranslate(vg,layer[2]*u,layer[3]*u);D.Path(vg,Points(d,pw,ph,layer[1]*u));nvgFillColor(vg,D.Color(layer[4]));nvgFill(vg);nvgRestore(vg)
  end
  local points=Points(d,pw,ph);D.Path(vg,points);nvgFillColor(vg,nvgRGBA(17,17,17,255));nvgFill(vg)
  local rect={x=-pw*.06,y=-ph*.06,w=pw*1.12,h=ph*1.12}
  rect.x=rect.x+rect.w*(1-state.scale)/2+state.imageX*rect.w;rect.y=rect.y+rect.h*(1-state.scale)/2;rect.w=rect.w*state.scale;rect.h=rect.h*state.scale
  rect.points=points
  if not(d.capture and I.host.DrawCapture and I.host.DrawCapture(vg,d.capture,rect))then Picture(vg,page,rect,points)end
  if state.index==3 then
   local chr={x=pw*.092,y=ph*.06,w=pw*.633,h=ph*1.7};local bottom=chr.y+chr.h
   chr.y=bottom-chr.h*state.breath;chr.h=chr.h*state.breath;Picture(vg,page,chr,points,true)
  end
  Tile(page,vg,'UI/IntroComicInkDots.png',points,6)
  if state.index==1 then
   Label(vg,'第 7 边境星区 · 坠舰陨坑',pw*.06,ph*.05,u,true)
   ComicText.Draw(vg,'轰——！',pw*.08,ph*.9-11*u,11*u,-8,state,'red')
  elseif state.index==2 then
   Label(vg,I.wrecked and '公司资产 · 你开的那辆（已损毁）' or '公司财产 · 贵重矿车',pw*.96,ph*.08,u,false,true)
   ComicText.Draw(vg,'滋滋——',pw*.14,ph*.92-8*u,8*u,6,state)
  else
   Label(vg,'你（初级装配员）',pw*.96,ph*.9-5.25*u,u,false,true)
   ComicText.Draw(vg,'……？',pw*.09,ph*.12,7*u,-4,state,'white')
  end
  nvgRestore(vg)
 end
end
return M
