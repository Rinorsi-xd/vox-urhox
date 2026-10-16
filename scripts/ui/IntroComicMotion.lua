-- Frozen actVirtues transforms use the layer box, before object-fit containment.
local M={}
local function Cubic(t,a,b) local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
function M.Ease(p,x1,y1,x2,y2)
 if p<=0 then return 0 elseif p>=1 then return 1 end
 local low,high=0,1
 for _=1,22 do local t=(low+high)/2;if Cubic(t,x1,x2)<p then low=t else high=t end end
 return Cubic((low+high)/2,y1,y2)
end
function M.Layer(rect,age,move,iw,ih,contain)
 local k=1-(1-math.min(1,age/4))^2
 local scale=(move.s1 or 1)+((move.s2 or move.s1 or 1)-(move.s1 or 1))*k
 local bob=math.sin(age*(move.w or 1.6));local angle=bob*(move.r or 0)*math.pi/180
 local tx=(move.x or 0)*age*.01*rect.w
 local ty=((move.y or 0)*age+bob*(move.bob or 0))*.01*rect.h
 local fit=(contain and math.min or math.max)(rect.w/iw,rect.h/ih)
 local dw,dh=iw*fit,ih*fit
 local left=-dw/2;local top=contain and rect.h/2-dh or -dh/2
 local c,s=math.cos(angle),math.sin(angle)
 return {x=rect.x+rect.w/2+tx+(c*left-s*top)*scale,
  y=rect.y+rect.h/2+ty+(s*left+c*top)*scale,w=dw*scale,h=dh*scale,angle=angle,
  box={x=rect.x+tx+rect.w*(1-scale)/2,y=rect.y+ty+rect.h*(1-scale)/2,w=rect.w*scale,h=rect.h*scale}}
end
function M.Bounds(rect,age,move)
 local layer=M.Layer(rect,age,move,rect.w,rect.h)
 local box=layer.box;local c,s=math.abs(math.cos(layer.angle)),math.abs(math.sin(layer.angle))
 local width,height=c*box.w+s*box.h,s*box.w+c*box.h
 return {x=box.x+(box.w-width)/2,y=box.y+(box.h-height)/2,w=width,h=height}
end
function M.PaperOpacity(I)
 local age=I.age
 for _,entry in ipairs(I.log or {}) do if entry.shot=='prosper' then age=I.time-entry.t;break end end
 return M.Ease(age/.16,.16,1,.3,1)
end
local function Random(seed) local nextSeed=(seed*1664525+1013904223)&0xffffffff;return nextSeed,nextSeed/4294967296 end
function M.Shake(page,I,u)
 local at ---@type number|nil
 local amp,duration=0,0
 local key=''
 for _,entry in ipairs(I.log or {{shot=I.shot,t=I.time-I.age}}) do
  local start,strength,seconds=entry.t,.8,.26
  if entry.shot=='no' then start=start+.5;strength=2.2;seconds=.52
  elseif entry.shot~='prosper' and entry.shot~='order' and entry.shot~='leave' then start=nil end
  if start and start<=I.time and (not at or start>=at) then at,amp,duration,key=start,strength,seconds,entry.shot end
 end
 if not at or I.time>=at+duration then return 0,0 end
 page.comicShakes=page.comicShakes or {};local id=key..':'..tostring(at)
 local frames=page.comicShakes[id]
 if not frames then
  frames={};local seed=(math.floor(at*1000+.5)+7726)&0xffffffff
  for i=0,10 do local x,y;seed,x=Random(seed);seed,y=Random(seed);local a=amp*(1-i/10);frames[i+1]={(x*2-1)*a,(y*2-1)*a} end
  page.comicShakes[id]=frames
 end
 local progress=(I.time-at)/duration*10;local index=math.min(10,math.floor(progress)+1);local mix=progress-(index-1)
 local a,b=frames[index],frames[index+1]
 return (a[1]+(b[1]-a[1])*mix)*u,(a[2]+(b[2]-a[2])*mix)*u
end
return M
