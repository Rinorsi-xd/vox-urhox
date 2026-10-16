-- Source actVirtues: panels persist, each entry/layer keeps its own clock.
local SourceParagraph=require("ui.SourceParagraph")

local D=require 'ui.SourceDraw'
local Opacity=require 'ui.IntroOpacity'
local nvgGlobalAlpha=Opacity.Set
local Images=require 'urhox-libs/UI/Core/ImageCache'
local M={}
local Motion=require 'ui.IntroComicMotion'
local function Dots(page,vg,path,points,x,y,size)
 page.comicPatterns=page.comicPatterns or {};local handle=page.comicPatterns[path]
 if not handle then handle=nvgCreateImage(vg,path,NVG_IMAGE_REPEATX|NVG_IMAGE_REPEATY);assert(handle>0,'Original comic CSS tile unavailable: '..path);page.comicPatterns[path]=handle;page.comicContext=vg end
 D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,x,y,size,size,0,handle,1));nvgFill(vg)
end
local definitions={
 prosper={name='city',rect={.025,.035,.95,.47},poly={0,0,1,0,1,.86,0,1},from={0,-.55},move={x=-.7,s1=1.12,s2=1.03}},
 order={name='order',rect={.025,.535,.47,.43},poly={0,.09,1,0,.96,1,0,1},from={-.55,0},move={y=.25,s1=1,s2=1.1}},
 leave={name='workshop',rect={.52,.55,.455,.415},poly={.05,0,1,0,1,1,0,1},from={.55,0},move={x=-.5,s1=1.04,s2=1}}
}
function M.State(I)
 local states={};local freeze
 for _,entry in ipairs(I.log or {}) do if entry.shot=='no' then freeze=entry.t end end
 local clock=freeze or I.time
 for _,entry in ipairs(I.log or {}) do if definitions[entry.shot] then
  states[entry.shot]={id=entry.shot,enteredAt=entry.t,age=math.max(0,clock-entry.t),definition=definitions[entry.shot]}
 end end
 if next(states)==nil and definitions[I.shot] then states[I.shot]={id=I.shot,enteredAt=I.time-I.age,age=I.age,definition=definitions[I.shot]} end
 return states
end
local function Points(poly,w,h,pad)
 local result={};pad=pad or 0
 for i=1,#poly,2 do result[i]=-pad+poly[i]*(w+2*pad);result[i+1]=-pad+poly[i+1]*(h+2*pad) end
 return result
end
local function Image(vg,path,rect,points,age,move,contain)
 local handle=Images.Get(path);if not handle or handle<=0 then return end
 local iw,ih=Images.GetSize(path);if iw<=0 or ih<=0 then return end
 local r=Motion.Layer(rect,age,move,iw,ih,contain)
 D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,r.x,r.y,r.w,r.h,r.angle,handle,1));nvgFill(vg)
end
local function Fine(page,vg,w,h,u)
 local size=1.35*u;local px,py=size*.8,size*.35
 local x,width=w*.06,w*.91
 page.comicFine=page.comicFine or SourceParagraph.New(size,size*1.3)
 local p=page.comicFine;p.font='vox-title';p.size=size;p.lineHeight=size*1.3;p.spacing=size*.04
 local text='*年假须在战区内休完 · 每年 0.5 天 · 不可累计 · 最终解释权归公司所有'
 local layout=p:Measure(vg,text,width-px*2,{255,255,255,255})
 local height=layout.height+py*2;local y=h*.97-height
 D.Rect(vg,x,y,width,height,{10,10,12,199})
 p:Draw(vg,text,x+px,y+py,width-px*2,{255,255,255,255})
end
function M.BeginPanels(page,vg,w,h,u)
 local x,y=Motion.Shake(page,page.owner,u)
 nvgSave(vg);nvgTranslate(vg,x,y)
end
function M.EndPanels(vg) nvgRestore(vg) end
function M.Panel(vg,page,state,w,h,u)
 local d=state.definition;local box=d.rect;local x,y,pw,ph=box[1]*w,box[2]*h,box[3]*w,box[4]*h
 local entry=Motion.Ease(state.age/.3,.2,.9,.3,1.05)
 nvgSave(vg);nvgTranslate(vg,x+pw/2+d.from[1]*w*(1-entry),y+ph/2+d.from[2]*h*(1-entry));nvgRotate(vg,-4*math.pi/180*(1-entry));nvgTranslate(vg,-pw/2,-ph/2);nvgGlobalAlpha(vg,math.min(1,entry))
 for _,layer in ipairs({{pad=.8*u,x=1.5*u,y=1.5*u,color={0,0,0,184}},{pad=.8*u,x=0,y=0,color={11,11,13,255}},{pad=.5*u,x=0,y=0,color={255,255,255,255}}}) do
  nvgSave(vg);nvgTranslate(vg,layer.x,layer.y);D.Path(vg,Points(d.poly,pw,ph,layer.pad));nvgFillColor(vg,D.Color(layer.color));nvgFill(vg);nvgRestore(vg)
 end
 local points=Points(d.poly,pw,ph);D.Path(vg,points);nvgFillColor(vg,nvgRGBA(17,17,17,255));nvgFill(vg)
 local rect={x=-pw*.06,y=-ph*.06,w=pw*1.12,h=ph*1.12}
 local captured=false;local host=page.owner.host
 if state.id=='leave' and host and host.DrawCapture then
  local r=Motion.Layer(rect,state.age,d.move,rect.w,rect.h).box;r.points=points
  captured=host.DrawCapture(vg,'leave',r)
 end
 if not captured then Image(vg,page.owner.data.images[d.name],rect,points,state.age,d.move) end
 if state.id=='prosper' and not (page.owner.shot=='no' and page.owner.age>=.5) then
  local images=page.owner.data.images
  local path=page.owner.shot=='no' and page.owner.age>=.4 and images.dove_red or images.dove
  Image(vg,path,{x=pw*.74,y=ph*.12,w=pw*.17,h=ph*.62},points,state.age,{x=1.4,y=-.6,bob=5,r=3,w=1.9},true)
 elseif state.id=='leave' then
  Image(vg,page.owner.data.images.family,{x=pw*.12,y=ph*.26,w=pw*.82,h=ph*.79},points,state.age,{x=.6,s1=1.08,s2=1,bob=.8,w=2.4},true)
 end
 if state.id=='prosper' or state.id=='order' then Dots(page,vg,'UI/IntroComicInkDots.png',points,0,0,6) end
 if state.id=='leave' then Fine(page,vg,pw,ph,u) end
 nvgRestore(vg)
end
function M.DoveBounds(I,w,h)
 local state=M.State(I).prosper
 if not state then return {x=w*.75,y=h*.1,w=200,h=260} end
 local rect=state.definition.rect;local pw,ph=rect[3]*w,rect[4]*h
 local box=Motion.Bounds({x=pw*.74,y=ph*.12,w=pw*.17,h=ph*.62},state.age,{x=1.4,y=-.6,bob=5,r=3,w=1.9})
 box.x=box.x+rect[1]*w;box.y=box.y+rect[2]*h
 return box
end
function M.Draw(page,vg,w,h,u)
 local I=page.owner;local states=M.State(I);page.comicStates=states
 Opacity.Push(vg,Motion.PaperOpacity(I))
 D.Path(vg,{0,0,w,0,w,h,0,h});D.Gradient(vg,0,0,w,h,{246,236,210,255},{234,216,174,255})
 Dots(page,vg,'UI/IntroComicPaperDots.png',{0,0,w,0,w,h,0,h},0,0,1.2*u)
 Opacity.Pop(vg)
 for _,id in ipairs({'prosper','order','leave'}) do if states[id] then M.Panel(vg,page,states[id],w,h,u) end end
end
local function Random(seed) local nextSeed=(seed*1664525+1013904223)&0xffffffff;return nextSeed,nextSeed/4294967296 end
function M.Confetti(page,vg,w,h,u)
 local state=M.State(page.owner).prosper;if not state or state.age>4.2 then return end
 if not page.confetti then
  page.confetti={};local seed=7726
  for i=1,60 do
   local values={};for j=1,6 do local value;seed,value=Random(seed);values[j]=value end
   page.confetti[i]={size=.8+values[1]*1.4,x=values[2],dx=(values[3]-.5)*.3,rot=(values[4]-.5)*900,dur=1.8+values[5]*1.6,delay=values[6]*.5}
  end
 end
 local colors={{40,121,235,255},{255,255,255,255},{255,211,106,255},{122,216,255,255},{219,238,255,255}}
 for i,p in ipairs(page.confetti) do
  local progress=math.max(0,math.min(1,(state.age-p.delay)/p.dur));local lo,hi=0,1
  for _=1,12 do local t=(lo+hi)/2;local q=1-t;local x=3*q*q*t*.3+3*q*t*t*.6+t*t*t;if x<progress then lo=t else hi=t end end
  local t=(lo+hi)/2;local q=1-t;local eased=3*q*q*t*.2+3*q*t*t+t*t*t
  nvgSave(vg);nvgTranslate(vg,w*(p.x+p.dx*eased),(-12+124*eased)*u);nvgRotate(vg,p.rot*eased*math.pi/180)
  D.Rect(vg,0,0,p.size*u,p.size*u,colors[(i-1)%5+1]);D.Path(vg,{0,0,p.size*u,0,p.size*u,p.size*u,0,p.size*u});nvgStrokeColor(vg,nvgRGBA(0,0,0,38));nvgStrokeWidth(vg,1);nvgStroke(vg);nvgRestore(vg)
 end
end
function M.Dispose(page)
 if page.comicPatterns and page.comicContext then for _,handle in pairs(page.comicPatterns) do nvgDeleteImage(page.comicContext,handle) end end
 page.comicPatterns=nil;page.comicContext=nil;page.comicShakes=nil;page.comicBurst=nil;page.comicFine=nil
end
return M
