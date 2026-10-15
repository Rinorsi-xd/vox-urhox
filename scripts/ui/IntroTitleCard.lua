-- Frozen introFx.titleCard / intro.css: layered slabs and per-letter keyframes.
local D=require 'ui.SourceDraw'
local G=require 'ui.IntroGlyphs'
local M={}
local black={11,11,13,255};local white={255,255,255,255}
local function Cubic(t,a,b)local k=1-t;return 3*k*k*t*a+3*k*t*t*b+t*t*t end
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,15 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<t then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
local function Keys(t,offset,middle,first,last)
 if t<offset then return first+(middle-first)*t/offset end
 return middle+(last-middle)*(t-offset)/(1-offset)
end
local function Outline(w,h,u)return {3.5*u,0,w,0,w,h-3.5*u,w-3.5*u,h,0,h,0,3.5*u}end
local function Clip(subject,clip)
 local result=subject
 for i=1,#clip,2 do
  local j=i+2;if j>#clip then j=1 end
  local ax,ay,bx,by=clip[i],clip[i+1],clip[j],clip[j+1];local input=result;result={}
  if #input==0 then break end
  local px,py=input[#input-1],input[#input];local pd=(bx-ax)*(py-ay)-(by-ay)*(px-ax)
  for k=1,#input,2 do
   local x,y=input[k],input[k+1];local distance=(bx-ax)*(y-ay)-(by-ay)*(x-ax)
   if (distance>=0)~=(pd>=0) then local t=pd/(pd-distance);result[#result+1]=px+(x-px)*t;result[#result+1]=py+(y-py)*t end
   if distance>=0 then result[#result+1]=x;result[#result+1]=y end
   px,py,pd=x,y,distance
  end
 end
 return result
end
local plans={
 prosper={text='繁荣！',idx='01',tag='PROSPERITY',theme='gold',size=12,x=.17,y=.45},
 order={text='秩序！',idx='02',tag='ORDER',size=12,x=.17,y=.85},
 leave={text='带薪年假……*',idx='03',tag='PAID LEAVE',theme='blue',size=10,x=.73,y=.54},
 recruit={text='加入星际前途',idx='JOIN',tag='特别安保部 · SPECIAL SECURITY',size=15},
 peacekeeper={text='维和先锋',idx='01',tag='PEACEKEEPER',theme='blue',size=12},
 master={text='零件大师',idx='02',tag='PART MASTER',theme='gold',size=12},
 hero={text='英雄',idx='03',tag='HERO',theme='red',size=14},
 becoming={text='成为——',size=12},
 mechanic={text='战地机修师！',idx='YOU',tag='FIELD MECHANIC',theme='orange',size=18},
}
function M.Plan(id,text)
 if id=='master' and text=='英雄' then return plans.hero elseif id=='master' and text=='成为——' then return plans.becoming end
 return plans[id]
end
function M.Draw(vg,w,h,u,time,plan)
 local size=plan.size*u;local spacing=size*.02;local textWidth=G.Width(plan.text,size,spacing)
 local bw,bh=textWidth+10*u,size*1.05+5.6*u;local cx,cy=w*(plan.x or .5),h*(plan.y or .44)
 nvgSave(vg);nvgTranslate(vg,cx-bw/2,cy-bh/2)
 local polygon=Outline(bw,bh,u)
 if not plan.stripes then
  plan.stripes={};plan.chars={}
  local normalized=Outline(bw/u,bh/u,1)
  for sx=-bh/u,bw/u+bh/u,1.8 do
   local stripe=Clip({sx,0,sx+.7,0,sx+.7-bh/u,bh/u,sx-bh/u,bh/u},normalized)
   if #stripe>=6 then plan.stripes[#plan.stripes+1]=stripe end
  end
  for _,cp in utf8.codes(plan.text) do plan.chars[#plan.chars+1]=utf8.char(cp) end
 end
 for layer=1,2 do
  local age=(time-(layer==2 and .05 or 0))/.26;local t=Ease(age,.2,.9,.3,1);local scale=Keys(t,.7,1.06,0,1)
  nvgSave(vg);if layer==1 then nvgTranslate(vg,1.6*u,1.6*u) end
  nvgTranslate(vg,bw/2,bh/2);nvgScale(vg,math.max(.001,scale),1);nvgSkewX(vg,-12*math.pi/180);nvgTranslate(vg,-bw/2,-bh/2)
  nvgGlobalAlpha(vg,math.min(1,math.max(0,t)))
  D.Path(vg,polygon)
  if layer==1 then nvgFillColor(vg,D.Color(black));nvgFill(vg)
  else
   local a,b={45,122,203,255},{23,70,140,255}
   if plan.theme=='gold' then a,b={255,224,138,255},{255,191,58,255}
   elseif plan.theme=='blue' then a,b={71,184,255,255},{28,127,224,255}
   elseif plan.theme=='red' then a,b={255,59,42,255},{196,15,5,255}
   elseif plan.theme=='orange' then a,b={23,48,76,255},{8,15,28,255} end
   D.Gradient(vg,0,0,bw,bh,a,b,true)
   nvgBeginPath(vg)
   for _,stripe in ipairs(plan.stripes) do
    nvgMoveTo(vg,stripe[1]*u,stripe[2]*u);for j=3,#stripe,2 do nvgLineTo(vg,stripe[j]*u,stripe[j+1]*u) end;nvgClosePath(vg)
   end
   nvgFillColor(vg,nvgRGBA(0,0,0,plan.theme=='orange' and 18 or plan.theme=='red' and 46 or 33));nvgFill(vg)
   local border=(plan.theme=='orange' and .35 or .5)*u
   nvgSave(vg);nvgTranslate(vg,bw/2,bh/2);nvgScale(vg,(bw-border)/bw,(bh-border)/bh);nvgTranslate(vg,-bw/2,-bh/2)
   D.Path(vg,polygon);nvgStrokeColor(vg,D.Color(plan.theme=='orange' and {122,216,255,255} or {219,238,255,255}));nvgStrokeWidth(vg,border);nvgStroke(vg);nvgRestore(vg)
   -- Source's halftone mask is one batched path per opacity band.
   for band=4,9 do
    nvgBeginPath(vg)
    for dx=(band/10)*bw,(band/10+.1)*bw,1.1*u do for dy=1.1*u,bh,1.1*u do
     local inside=true
     for j=1,#polygon,2 do
      local k=j+2;if k>#polygon then k=1 end
      local ex,ey=polygon[k]-polygon[j],polygon[k+1]-polygon[j+1]
      if ex*(dy-polygon[j+1])-ey*(dx-polygon[j])<.28*u*math.sqrt(ex*ex+ey*ey) then inside=false;break end
     end
     if inside then nvgCircle(vg,dx,dy,.24*u) end
    end end
    nvgFillColor(vg,nvgRGBA(0,0,0,math.floor(36*math.min(1,math.max(0,(band/10-.4)/.45)))));nvgFill(vg)
   end
  end
  nvgRestore(vg)
 end
 local baseline=2.4*u+(size*1.05-size*(G.Ascent()+G.Descent()))/2+size*G.Ascent();local x=5*u
 for index,char in ipairs(plan.chars) do
  local advance=G.Glyph(char).advance*size
  local t=Ease((time-.09-(index-1)*.06)/.28,.2,.8,.3,1.1);local scale=Keys(t,.65,.88,3,1)
  local rotation=(((index*97)%35)-17)*Keys(t,.65,.1,1,0);local center=2.4*u+size*1.05/2
  nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,math.max(0,t)));nvgTranslate(vg,x+advance/2,center-(1-math.min(1,t/.65))*size*.315)
  nvgRotate(vg,rotation*math.pi/180);nvgScale(vg,scale,scale);nvgTranslate(vg,-advance/2,-center)
  local ink=plan.theme=='orange' and white or black
  for _,offset in ipairs({.12,.09,.06,.03}) do G.Draw(vg,char,size*offset,baseline+size*offset,size,ink,nil,0) end
  G.Draw(vg,char,0,baseline,size,plan.theme=='orange' and {122,216,255,255} or white,ink,size*.11)
  nvgRestore(vg);x=x+advance+spacing
 end
 if plan.idx or plan.tag then
  local count=utf8.len(plan.text);local t=Ease((time-.14-count*.06)/.26,.2,.9,.3,1)
  nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,math.max(0,t)));nvgTranslate(vg,4*u-(1-t)*6*u,bh+2.2*u)
  nvgSkewX(vg,-12*math.pi/180)
  local fs=2.2*u;local iw=plan.idx and D.Width(vg,plan.idx,fs,'vox-tabular',fs*.05)+fs*1.2 or 0
  local tw=plan.tag and D.Width(vg,plan.tag,fs,'vox-tabular',fs*.24)+fs*2 or 0;local th=fs*1.9
  nvgTranslate(vg,-th*.5*math.tan(12*math.pi/180),0)
  D.Rect(vg,.6*u,-th+.6*u,iw+tw,th,{0,0,0,128});D.Rect(vg,0,-th,iw,th,white);D.Rect(vg,iw,-th,tw,th,black)
  if plan.idx then D.Text(vg,plan.idx,fs*.6,-th+fs*.45,fs,black,'vox-tabular',nil,fs*.05) end
  if plan.tag then D.Text(vg,plan.tag,iw+fs,-th+fs*.45,fs,white,'vox-tabular',nil,fs*.24) end
  nvgRestore(vg)
 end
 nvgRestore(vg)
end
return M
