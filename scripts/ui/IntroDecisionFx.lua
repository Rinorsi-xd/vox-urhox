-- actDecide CSS layers, in IntroPage's existing design-space coordinates.
local D=require 'ui.SourceDraw'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local Opacity=require 'ui.IntroOpacity'
local M={}
local beam={}
for i=0,47 do
 local angle=i*.5;local midpoint=angle+.25
 local alpha=midpoint<10 and midpoint/10*.22 or midpoint<12 and .22+(midpoint-10)/2*.1 or midpoint<14 and .32-(midpoint-12)/2*.1 or .22*(24-midpoint)/10
 local a,b=math.rad(168+angle),math.rad(168+angle+.5)
 beam[#beam+1]={math.sin(a),-math.cos(a),math.sin(b),-math.cos(b),alpha}
end
local speed={{4,4.4,.275},{4.4,5,.55},{5,5.4,.275}}
function M.Plan(I)
 local decided=I.shot=='decided';local progress=decided and 1 or math.max(0,math.min(1,I.holdProgress or 0))
 local age=I.age
 for index=#(I.log or {}),1,-1 do
  local entry=I.log[index]
  if entry.shot=='decide' then age=I.time-entry.t;break end
 end
 return {cone=progress*.9,brightness=decided and 1 or .18+progress*.8,speed=decided and .75 or 0,
  spot=decided and .7 or .06+progress*.34,rotation=age*math.pi*2/7,progress=progress}
end
function M.Below(vg,I,w,h)
 local plan=M.Plan(I);local u=h/100
 if plan.cone>0 then
  Opacity.Push(vg,plan.cone)
  local cx,cy=w/2,-10*u;local radius=120*u/math.cos(math.rad(12))
  nvgIntersectScissor(vg,cx-40*u,cy,80*u,120*u)
  for _,slice in ipairs(beam) do
   D.Path(vg,{cx,cy,cx+slice[1]*radius,cy+slice[2]*radius,cx+slice[3]*radius,cy+slice[4]*radius})
   nvgFillColor(vg,nvgRGBA(214,238,255,math.floor(slice[5]*255+.5)));nvgFill(vg)
  end
  Opacity.Pop(vg)
 end
 if plan.speed>0 then
  Opacity.Push(vg,plan.speed)
  nvgIntersectScissor(vg,0,0,w,h);nvgTranslate(vg,w/2,h/2);nvgRotate(vg,plan.rotation)
  local radius=.8*math.sqrt(w*w+h*h)
  for index=0,39 do for _,slice in ipairs(speed) do
   local a,b=math.rad(index*9+slice[1]),math.rad(index*9+slice[2]);local mid=(a+b)/2
   D.Path(vg,{0,0,math.sin(a)*radius,-math.cos(a)*radius,math.sin(b)*radius,-math.cos(b)*radius})
   nvgFillPaint(vg,nvgLinearGradient(vg,math.sin(mid)*radius*.22,-math.cos(mid)*radius*.22,
    math.sin(mid)*radius*.6,-math.cos(mid)*radius*.6,nvgRGBA(255,255,255,0),nvgRGBA(255,255,255,math.floor(slice[3]*255+.5))))
   nvgFill(vg)
  end end
  Opacity.Pop(vg)
 end
 return plan
end
function M.Hero(page,vg,name,x,y,w,h,brightness)
 local I=page.owner;if not I.downloaded then return end
 local path=I.data.images[name];if not path then return end
 local handle=Images.Get(path);if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local scale=math.min(w/iw,h/ih);local dw,dh=iw*scale,ih*scale
 local px,py=x+(w-dw)/2,y+h-dh;local value=math.floor(brightness*255+.5)
 nvgBeginPath(vg);nvgRect(vg,px,py,dw,dh)
 nvgFillPaint(vg,nvgImagePatternTinted(vg,px,py,dw,dh,0,handle,nvgRGBA(value,value,value,255)));nvgFill(vg)
end
return M
