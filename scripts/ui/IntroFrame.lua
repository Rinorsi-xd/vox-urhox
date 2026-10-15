-- IntroStory's hudFrame.js terminal/dialog/comms/pad/tag geometry.
local D=require 'ui.SourceDraw'
local M={};local K=2-math.sqrt(2)
local ice={214,240,255,153};local secondary={214,240,255,77};local cyan={110,214,255,217}
local function Ring(w,h,c,o)
 local a,b,e,f=table.unpack(c);o=o or 0;a=a>0 and a+o*K or 0;b=b>0 and b+o*K or 0;e=e>0 and e+o*K or 0;f=f>0 and f+o*K or 0
 return {w+o-b,-o,w+o,b-o,w+o,h+o-e,w+o-e,h+o,f-o,h+o,-o,h+o-f,-o,a-o,a-o,-o,w+o-b,-o}
end
local function Corner(w,h,which,cut,o,l1,l2)
 local c=cut>0 and cut+o*K or 0;local x,y=-o,-o;local xx,yy=w+o,h+o
 if which=='tl' then return {x,y+c+l1,x,y+c,x+c,y,x+c+l2,y}
 elseif which=='tr' then return {xx-c-l1,y,xx-c,y,xx,y+c,xx,y+c+l2}
 elseif which=='br' then return {xx,yy-c-l1,xx,yy-c,xx-c,yy,xx-c-l2,yy}
 else return {x+c+l1,yy,x+c,yy,x,yy-c,x,yy-c-l2} end
end
local function Stroke(vg,p,color,width)
 nvgBeginPath(vg);nvgMoveTo(vg,math.floor(p[1]+.5)+.5,math.floor(p[2]+.5)+.5)
 for i=3,#p,2 do nvgLineTo(vg,math.floor(p[i]+.5)+.5,math.floor(p[i+1]+.5)+.5) end
 nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width or 1);nvgStroke(vg)
end
local function Ticks(vg,x,y,xx,yy,step,len,nx,ny)
 local count=math.floor(math.sqrt((xx-x)^2+(yy-y)^2)/step)
 for i=0,count do local t=i/math.max(1,count);local px=x+(xx-x)*t;local py=y+(yy-y)*t;local k=i%4==0 and 1.8 or 1
  D.Line(vg,px,py,px+nx*len*k,py+ny*len*k,secondary,1)
 end
end
local function Hatch(vg,x,y,n,gap,len,time)
 for i=0,n-1 do D.Line(vg,x+i*gap,y+len,x+i*gap+len,y,{110,214,255,(time-i*.12)%3.2<.26 and 38 or 153},1.5) end
end
local function Node(vg,x,y,s,time) s=s or 4;D.Rect(vg,math.floor(x-s/2+.5),math.floor(y-s/2+.5),s,s,{214,240,255,time%2.6<1.3 and 191 or 90}) end
local function Dots(vg,x,y,xx,yy)
 local count=math.floor(math.sqrt((xx-x)^2+(yy-y)^2)/5)
 for i=0,count do local t=i/math.max(1,count);nvgBeginPath(vg);nvgCircle(vg,x+(xx-x)*t,y+(yy-y)*t,.8);nvgFillColor(vg,nvgRGBA(214,240,255,128));nvgFill(vg) end
end
local function Flow(vg,p,time)
 local total=0;for i=3,#p,2 do total=total+math.sqrt((p[i]-p[i-2])^2+(p[i+1]-p[i-1])^2) end
 local start=(time%8)/8*total;local stop=start+.034*total;local at=0
 for i=3,#p,2 do local x,y,xx,yy=p[i-2],p[i-1],p[i],p[i+1];local length=math.sqrt((xx-x)^2+(yy-y)^2)
  for _,shift in ipairs({0,-total}) do
   local a,b=math.max(0,start+shift-at),math.min(length,stop+shift-at)
   if b>a and length>0 then D.Line(vg,x+(xx-x)*a/length,y+(yy-y)*a/length,x+(xx-x)*b/length,y+(yy-y)*b/length,{255,255,255,240},1.5) end
  end
  at=at+length
 end
end
function M.Shape(vg,w,h,u,kind)
 local cut=kind=='comms' and {0,2.4*u,0,2.4*u} or kind=='pad' and {0,2*u,0,2*u} or kind=='dialog' and {1.4*u,0,1.4*u,0} or kind=='tag' and {0,0,.9*u,0} or {2.2*u,0,2.2*u,0}
 D.Path(vg,Ring(w,h,cut));return cut
end
function M.Draw(vg,w,h,u,kind,time)
 time=time or 0;local c=M.Shape(vg,w,h,u,kind);Stroke(vg,Ring(w,h,c),ice);Flow(vg,Ring(w,h,c),time)
 if kind=='terminal' then
  Stroke(vg,Corner(w,h,'tl',c[1],-5,.32*h,.4*w),secondary);Stroke(vg,Corner(w,h,'br',c[3],-5,.26*h,.28*w),secondary)
  Stroke(vg,{w+1,.08*h,w+7,.08*h+6,w+7,.34*h,w+1,.34*h+6},secondary);Ticks(vg,w+7,.11*h,w+7,.31*h,1.1*u,3,1,0)
  Node(vg,w+7,.34*h+12,nil,time);Dots(vg,-7,.5*h,-7,.86*h);Node(vg,-7,.86*h+6,nil,time)
  Stroke(vg,Corner(w,h,'tl',c[1],4,5*u,10*u),{238,250,255,255},3);Stroke(vg,Corner(w,h,'br',c[3],4,3*u,7*u),cyan,2)
  Stroke(vg,{w-18*u,-3,w-17*u,-1.1*u-3,w-5*u,-1.1*u-3,w-4*u,-3},secondary)
  D.Text(vg,'SEC·07',w-11*u,-2.65*u,1.05*u,{214,240,255,107},'vox-display',NVG_ALIGN_CENTER)
  Hatch(vg,3*u,h+4,6,6,5,time);D.Text(vg,'AUTH 0x07A3 · VALID',3*u+44,h+4,1.05*u,secondary,'vox-display')
 elseif kind=='comms' then
  Stroke(vg,{1.2*u,4.4*u,.6*w,4.4*u,.6*w+.8*u,3.6*u,w-1.2*u,3.6*u},secondary)
  Stroke(vg,{-1,.16*h,-7,.16*h+6,-7,.48*h,-1,.48*h+6},secondary);Ticks(vg,-7,.2*h,-7,.44*h,1.1*u,3,-1,0)
  Dots(vg,.32*w,h+6,.68*w,h+6);Node(vg,-7,.48*h+12,nil,time)
  Stroke(vg,Corner(w,h,'tr',c[2],4,8*u,6*u),{238,250,255,255},3);Stroke(vg,Corner(w,h,'bl',c[4],4,5*u,3*u),cyan,2)
  Node(vg,-4,-4,5,time);Hatch(vg,2*u,-10,5,6,5,time)
 elseif kind=='pad' then
  Stroke(vg,Corner(w,h,'tr',c[2],-5,.3*w,.3*h),secondary);Stroke(vg,{w+1,.5*h,w+7,.5*h+6,w+7,.86*h},secondary)
  Ticks(vg,w+7,.56*h,w+7,.84*h,1.1*u,3,1,0);Node(vg,w+7,.86*h+6,nil,time)
  Stroke(vg,Corner(w,h,'tr',c[2],4,6*u,5*u),{238,250,255,255},3);Stroke(vg,Corner(w,h,'bl',c[4],4,4*u,3*u),cyan,2)
  Hatch(vg,w-14*u,h+4,5,6,5,time)
 elseif kind=='dialog' then
  Stroke(vg,{.46*w,h+1,.46*w+5,h+6,w-14*u,h+6},secondary);Ticks(vg,.5*w,h+6,.62*w,h+6,1.2*u,3,0,1);Node(vg,w-14*u+5,h+6,nil,time)
  Stroke(vg,{w-30*u,5,w-5,5,w-5,.5*h},secondary)
  Stroke(vg,Corner(w,h,'tl',c[1],4,.42*h,3*u),{238,250,255,255},3);Stroke(vg,Corner(w,h,'br',c[3],4,1.6*u,9*u),cyan,2)
  Hatch(vg,w-21*u,-10,7,6,5,time);D.Text(vg,'CH-07 · 64 KBPS · ENC',2*u,h+4,1.05*u,secondary,'vox-display')
 else
  D.Line(vg,-4,1,-4,h-2,{238,250,255,255},3);Stroke(vg,{.4*w,h+5,w+8*u,h+5},secondary);Node(vg,w+8*u+3,h+5,nil,time);Hatch(vg,w+6,h-12,4,5,5,time)
 end
end
return M
