-- Frozen actPayslip / .slip2, separate from the approved caption renderer.
local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local G=require 'ui.IntroGlyphs'
local M={}
local ink={26,26,26,255};local red={194,36,15,255}
local rows={{'基本工资','3,200.00'},{'机油咖啡（强制订阅）','-480.00'},{'工位租金','-900.00'},{'安全帽折旧','-320.00'},{'呼吸空气使用费','-12.50'},{'绩效扣减（跳过广告）','-50.00'},{'战车维修费（实机演示）','-1,200.00'}}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local q=(lo+hi)/2;if Cubic(q,x1,x2)<t then lo=q else hi=q end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(age,duration,wrecked)
 local n=wrecked and 7 or 6;local entry=Ease(age/.52,.16,1,.3,1)
 local stamp=math.min(1,age/1.1);local scale=stamp<.6 and 2.6 or stamp<.85 and 2.6+(stamp-.6)/.25*(.94-2.6) or .94+(stamp-.85)/.15*.06
 local hit=math.max(1.8,(duration or 5.5)-1.3)
 return {rows=n,total=wrecked and '237.50' or '1,437.50',height=31.7+n*3.04,
  offset=70*(1-entry),rotation=-24+29*entry,stampAlpha=math.max(0,math.min(1,(stamp-.6)/.25)),stampScale=scale,
  hitAt=hit,shredAt=hit+.09,shredded=age>=hit+.09,laser=age>=hit and age<hit+.42,
  lock=age<hit+.09,lockProgress=math.min(1,age/(hit-.4))}
end
local function Paper(vg,I,u,plan,age,clip,alpha,owner)
 local w,h=50*u,plan.height*u
 local function Visible(y,height)return not clip or y+height>=clip.y and y<=clip.y+clip.h end
 local function Text(text,x,y,size,color,font,spacing,right,lineHeight)
  if Visible(y,lineHeight or size*1.6) then D.Text(vg,text,x,y,size,color,font or 'vox-title',right and NVG_ALIGN_RIGHT or nil,spacing or 0,false,lineHeight or size*1.6) end
 end
 local function Sheet(dx,dy)
  nvgBeginPath(vg);nvgRect(vg,dx,dy,w,h)
  local radius=.725*u;local left=clip and clip.x or 0;local right=clip and clip.x+clip.w or w
  local top=clip and clip.y or 0;local bottom=clip and clip.y+clip.h or h
  for x=1.1*u,w,2.2*u do
   local cx=x+dx
   if cx+radius>=left and cx-radius<=right then
    if dy+radius>=top and dy-radius<=bottom then nvgCircle(vg,cx,dy,radius);nvgPathWinding(vg,NVG_HOLE)end
    if h+dy+radius>=top and h+dy-radius<=bottom then nvgCircle(vg,cx,h+dy,radius);nvgPathWinding(vg,NVG_HOLE)end
   end
  end
 end
 nvgSave(vg);nvgIntersectScissor(vg,1.2*u,1.4*u,w,h);Sheet(1.2*u,1.4*u);nvgFillColor(vg,nvgRGBA(0,0,0,140));nvgFill(vg);nvgRestore(vg)
 nvgSave(vg);nvgIntersectScissor(vg,0,0,w,h);Sheet(0,0);nvgFillPaint(vg,nvgLinearGradient(vg,0,0,0,h,nvgRGBA(251,247,236,255),nvgRGBA(239,231,210,255)));nvgFill(vg);nvgRestore(vg)
 local context=owner or I;context.comicPatterns=context.comicPatterns or {};local path='UI/IntroComicPaperDots.png';local handle=context.comicPatterns[path]
 if not handle then handle=nvgCreateImage(vg,path,NVG_IMAGE_REPEATX|NVG_IMAGE_REPEATY);assert(handle>0,'Original paper texture unavailable');context.comicPatterns[path]=handle;context.comicContext=vg end
 nvgSave(vg);nvgIntersectScissor(vg,0,0,w,h);Sheet(0,0)
 nvgFillPaint(vg,nvgImagePatternTinted(vg,0,0,4,4,0,handle,nvgRGBA(0,0,0,72)));nvgFill(vg);nvgRestore(vg)
 if Visible(3.4*u,5.4*u) then require('ui.IntroPage').Image(vg,I,'company-emblem',3.4*u,3.4*u,5.4*u,5.4*u,1) end
 Text('星际前途有限公司',10.2*u,3.76*u,2.6*u,ink,'vox-title',.208*u,false,3.12*u)
 Text('PAYROLL · 薪资结算单',10.2*u,6.88*u,1.3*u,{102,102,102,255},'vox-code',.325*u,false,1.56*u)
 Text('No.2077-1021',46.6*u,3.4*u,1.4*u,{136,136,136,255},'vox-code',0,true,1.4*u)
 if Visible(10.2*u,.45*u)then D.Rect(vg,3.4*u,10.2*u,43.2*u,.45*u,ink)end
 Text('员工：初级装配员 #0721',3.4*u,11.85*u,1.5*u,{85,85,85,255},nil,0,false,2.4*u)
 Text('结算期：10 月',46.6*u,11.85*u,1.5*u,{85,85,85,255},nil,0,true,2.4*u)
 for index=1,plan.rows do
  local row=rows[index];local y=(15.25+(index-1)*3.04)*u
  Text(row[1],3.4*u,y,1.9*u,ink,nil,0,false,3.04*u)
  Text(row[2],46.6*u,y,1.9*u,index==1 and ink or red,'vox-code',0,true,3.04*u)
  if Visible(y,3.04*u) then
   local left=3.4*u+D.Width(vg,row[1],1.9*u,'vox-title')+.6*u
   local right=46.6*u-D.Width(vg,row[2],1.9*u,'vox-code')-.6*u
   for x=left,right,4 do D.Rect(vg,x,y+2*u,math.min(2,right-x),2,{170,170,170,255})end
  end
 end
 local totalY=(18.1+plan.rows*3.04)*u
 if Visible(totalY-1.65*u,.45*u) then
  D.Rect(vg,3.4*u,totalY-1.65*u,43.2*u,.15*u,ink);D.Rect(vg,3.4*u,totalY-1.35*u,43.2*u,.15*u,ink)
 end
 Text('实发',3.4*u,totalY+1.96*u,1.9*u,ink,nil,.57*u,false,3.04*u)
 Text(plan.total,46.6*u,totalY,5*u,red,'vox-display',.1*u,true,5*u)
 if Visible(h-7*u,4*u)then
  nvgBeginPath(vg)
  for x=3.4*u,46.6*u,12 do
   for _,bar in ipairs({{0,2},{4,3},{8,1}})do nvgRect(vg,x+bar[1],h-7*u,bar[2],4*u)end
  end
  nvgFillColor(vg,nvgRGBA(26,26,26,217));nvgFill(vg)
 end
 local size=4.4*u;local tw=G.Width('已扣款',size,.1*size);local sw=tw+1.4*size+u;local sh=size*1.6+u;local sy=h-7.6*u-sh
 if Visible(sy,sh) and plan.stampAlpha>0 then
  nvgSave(vg);nvgTranslate(vg,12*u+sw/2,sy+sh/2);nvgRotate(vg,-16*math.pi/180);nvgScale(vg,plan.stampScale,plan.stampScale);nvgTranslate(vg,-sw/2,-sh/2);nvgGlobalAlpha(vg,(alpha or 1)*plan.stampAlpha)
  local color={214,26,16,217};nvgBeginPath(vg);nvgRoundedRect(vg,.25*u,.25*u,sw-.5*u,sh-.5*u,.6*u);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,.5*u);nvgStroke(vg)
  local x=.7*size+.5*u;local baseline=.3*size+.5*u+G.Ascent()*size
  for _,cp in utf8.codes('已扣款')do local char=utf8.char(cp);G.Draw(vg,char,x,baseline,size,color,nil,0);x=x+G.Glyph(char).advance*size+.1*size end
  nvgRestore(vg)
 end
end
function M.Draw(vg,I,w,h,u,owner,deferForeground)
 local plan=M.Plan(I.age,I.voiceDuration,I.wrecked);local pw,ph=50*u,plan.height*u;local x,y=w/2-25*u,h*.14
 if not plan.shredded then
  nvgSave(vg);nvgTranslate(vg,x+pw/2,y+ph/2+plan.offset*u);nvgRotate(vg,plan.rotation*math.pi/180);nvgTranslate(vg,-pw/2,-ph/2);Paper(vg,I,u,plan,I.age,nil,nil,owner);nvgRestore(vg)
 else
  local age=I.age-plan.shredAt
  for row=0,8 do for col=0,6 do
   local seed=(row*7+col+1)*.61803398875;local rnd=seed%1;local duration=.8+rnd*.5;local t=Ease(age/duration,.3,.1,.6,1)
   if t<1 then
    local dx=(col-3.5+rnd-.5)*12*u*t;local dy=((row-4.5)*5+26+(seed*.73%1)*40)*u*t
    nvgSave(vg);nvgGlobalAlpha(vg,1-t);nvgTranslate(vg,x+pw/2+dx,y+ph/2+dy);nvgRotate(vg,(6+(((seed*.37)%1-.5)*500-6)*t)*math.pi/180);nvgTranslate(vg,-pw/2,-ph/2)
    local clip={x=col*pw/7,y=row*ph/9,w=pw/7,h=ph/9};nvgIntersectScissor(vg,clip.x,clip.y,clip.w,clip.h);Paper(vg,I,u,plan,plan.shredAt,clip,1-t,owner);nvgRestore(vg)
   end
  end end
 end
 if not deferForeground then M.DrawForeground(vg,I,w,h,u) end
 if I.age>=plan.shredAt and I.age<plan.shredAt+.26 then D.Rect(vg,0,0,w,h,{255,58,42,math.floor(153*(1-Ease((I.age-plan.shredAt)/.26,0,0,.58,1)))})end
end
-- CSS lock-on (z8) and laser (z9) escape the unstacked panels above cinema bars.
function M.DrawForeground(vg,I,w,h,u)
 local plan=M.Plan(I.age,I.voiceDuration,I.wrecked);local pw,ph=50*u,plan.height*u;local x,y=w/2-25*u,h*.14
 if plan.lock then
  local q=plan.lockProgress;local e=1-(1-q)^3;local angle=plan.rotation*math.pi/180
  local bw=math.abs(math.cos(angle))*pw+math.abs(math.sin(angle))*ph;local bh=math.abs(math.sin(angle))*pw+math.abs(math.cos(angle))*ph
  local bx=x+pw/2-bw/2;local by=y+ph/2+plan.offset*u-bh/2
  local x0=bx*e-8;local y0=by*e-8;local x1=w-(w-bx-bw)*e+8;local y1=h-(h-by-bh)*e+8
  local color=q>=1 and {255,59,48,255} or {46,168,255,255};local length=6*u;local width=.8*u
  for _,c in ipairs({{x0,y0,1,1},{x1,y0,-1,1},{x0,y1,1,-1},{x1,y1,-1,-1}})do
   D.Line(vg,c[1],c[2],c[1]+length*c[3],c[2],color,width);D.Line(vg,c[1],c[2],c[1],c[2]+length*c[4],color,width)
  end
  local radius=(x1-x0)*.35;local phase=I.age*math.pi*2/(q>=1 and .6 or 3)
  nvgBeginPath(vg)
  local segments=q>=1 and 1 or math.max(12,math.floor(math.pi*radius/(.9*u)))
  for segment=0,segments-1 do
   local first=phase+segment/segments*math.pi*2;local last=first+math.pi*2/segments*(q>=1 and 1 or .5)
   local steps=q>=1 and 96 or 8
   for step=0,steps do local a=first+(last-first)*step/steps;local px=(x0+x1)/2+math.cos(a)*radius;local py=(y0+y1)/2+math.sin(a)*radius;if step==0 then nvgMoveTo(vg,px,py)else nvgLineTo(vg,px,py)end end
  end
  nvgStrokeColor(vg,nvgRGBA(color[1],color[2],color[3],q>=1 and 255 or 179));nvgStrokeWidth(vg,.3*u);nvgStroke(vg)
  local text=q>=1 and '已锁定 · 目标：你的工资条' or '锁定中 '..math.floor(q*100)..'%';local size=2.8*u;local tw=D.Width(vg,text,size,'vox-title',size*.1)+size*1.4
  D.Rect(vg,x0,y0-5.4*u,tw,size*1.6,color);D.Text(vg,text,x0+.7*size,y0-5.4*u+.3*size,size,q>=1 and {255,255,255,255} or ink,'vox-title',nil,size*.1,false,size)
 end
 if plan.laser then
  local age=(I.age-plan.hitAt)/.42;local sx,sy=w+40,-40;local tx,ty=x+pw/2,y+ph/2;local length=math.sqrt((tx-sx)^2+(ty-sy)^2)
  nvgSave(vg);nvgTranslate(vg,sx,sy+.7*u);nvgRotate(vg,math.atan(ty-sy,tx-sx));nvgScale(vg,math.min(1,age/.25),age<.25 and 1 or 1-.8*(age-.25)/.75);nvgGlobalAlpha(vg,age<.25 and 1 or 1-(age-.25)/.75)
  for index=0,19 do
   local t=(index+.5)/20;local white=math.max(0,1-math.abs(t-.5)/.2);local alpha=t<.3 and t/.3 or t>.7 and (1-t)/.3 or 1
   D.Rect(vg,0,(-.7+index*.07)*u,length,.071*u,{math.floor(255),math.floor(59+196*white),math.floor(48+207*white),math.floor(255*alpha)})
  end
  nvgRestore(vg)
 end
end
return M
