-- Frozen actNo/_burst: clones lose their layer transform, retain bottom containment.
local IntroComic=require("ui.IntroComic")

local D=require 'ui.SourceDraw'
local Opacity=require 'ui.IntroOpacity'
local Motion=require 'ui.IntroComicMotion'
local Images=require 'urhox-libs/UI/Core/ImageCache'
local M={}
local function Random(seed) local nextSeed=(seed*1664525+1013904223)&0xffffffff;return nextSeed,nextSeed/4294967296 end
function M.Particles(box,seed)
 local particles={}
 for row=0,5 do for col=0,5 do
  local values={};for i=1,5 do local value;seed,value=Random(seed);values[i]=value end
  local force=2.2+values[1]*2.5
  particles[#particles+1]={col=col,row=row,dx=((col+.5)/6-.5)*box.w*force+(values[2]-.5)*120,
   dy=((row+.5)/6-.5)*box.h*force+(values[3]-.3)*120+220,rotation=(values[4]-.5)*720,duration=.7+values[5]*.5}
 end end
 return particles
end
function M.Draw(page,vg,w,h)
 local I=page.owner;local age=I.age-.5;if age<0 then return end
 local box=IntroComic.DoveBounds(I,w,h)
 local start=I.time-I.age
 for _,entry in ipairs(I.log or {}) do if entry.shot=='no' then start=entry.t end end
 local burst=page.comicBurst
 if not burst or burst.start~=start or burst.width~=w or burst.height~=h then
  burst={start=start,width=w,height=h,particles=M.Particles(box,(math.floor(start*1000+.5)+7726)&0xffffffff)};page.comicBurst=burst
 end
 local path=I.data.images.dove_red;local handle=Images.Get(path);if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local fit=math.min(box.w/iw,box.h/ih);local dw,dh=iw*fit,ih*fit
 for _,particle in ipairs(burst.particles) do
  if age<particle.duration then
   local progress=Motion.Ease(age/particle.duration,.2,.7,.5,1)
   Opacity.Push(vg,1-progress)
   nvgTranslate(vg,box.x+box.w/2+particle.dx*progress,box.y+box.h/2+particle.dy*progress)
   nvgRotate(vg,particle.rotation*progress*math.pi/180);nvgTranslate(vg,-box.w/2,-box.h/2)
   local x,y=particle.col*box.w/6,particle.row*box.h/6
   nvgIntersectScissor(vg,x,y,box.w/6,box.h/6)
   D.Path(vg,{x,y,x+box.w/6,y,x+box.w/6,y+box.h/6,x,y+box.h/6})
   nvgFillPaint(vg,nvgImagePattern(vg,(box.w-dw)/2,box.h-dh,dw,dh,0,handle,1));nvgFill(vg)
   Opacity.Pop(vg)
  end
 end
end
return M
