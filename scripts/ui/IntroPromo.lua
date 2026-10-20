-- The comic artwork is original 2D art; live shots remain the host's 3D viewport.
local ImageCache=require("urhox-libs/UI/Core/ImageCache")
local IntroTitleCard=require("ui.IntroTitleCard")
local IntroRecruitTitles=require("ui.IntroRecruitTitles")
local IntroBrand=require("ui.IntroBrand")
local IntroComic=require("ui.IntroComic")
local IntroComicBurst=require("ui.IntroComicBurst")
local IntroComicText=require("ui.IntroComicText")
local IntroFamiliar=require("ui.IntroFamiliar")
local IntroGalaxyText=require("ui.IntroGalaxyText")
local IntroSortieUi=require("ui.IntroSortieUi")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local D=require 'ui.SourceDraw'
local Typography=require 'ui.IntroTypography'
local Motion=require 'ui.IntroPromoMotion'
local Fx=require 'ui.IntroPromoFx'
local Decision=require 'ui.IntroDecisionFx'
local Opacity=require 'ui.IntroOpacity'
local nvgGlobalAlpha=Opacity.Set
local M={};local white={255,255,255,255};local red={255,59,48,255};local gold={255,211,106,255}
local function Image(page,vg,name,x,y,w,h,cover) DeferredModules['ui.IntroPage'].Image(vg,page.owner,name,x,y,w,h,1,cover) end
local function Panel(page,vg,points,name,x,y,w,h,age)
 D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,247,227,255));nvgFill(vg)
 local dx=(1-math.min(1,age/.28))*w
 local path=page.owner.data.images[name];local images=ImageCache;local handle=images.Get(path)
 if handle and handle>0 then
  local iw,ih=images.GetSize(path);local s=math.max(w/iw,h/ih)
  D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,x+(w-iw*s)/2+dx,y+(h-ih*s)/2,iw*s,ih*s,0,handle,1));nvgFill(vg)
 end
 D.Path(vg,points);nvgStrokeColor(vg,nvgRGBA(8,12,20,255));nvgStrokeWidth(vg,7);nvgStroke(vg)
end
local function Title(vg,I,w,h,u,id,text,age,exitAge)
 local module=IntroTitleCard;local plan=module.Plan(id,text)
 if plan then module.Draw(vg,w,h,u,age or I.age,plan,exitAge) end
end
local function Salvage(page,vg,w,h,t,offsetX,offsetY)
 local I=page.owner;local x=w*.52;local y=h*.1;local width=w*.5;local height=h*.74
 nvgSave(vg);nvgTranslate(vg,offsetX,offsetY)
 local points={x+width*.18,y,x+width,y,x+width,y+height,x,y+height}
 -- Source .cl.hero-cut：35%/35% 处的蓝色椭圆渐变 + 浅蓝网点 + 旋转白色速度线 + .3vh 品牌色内描边，无黑框
 D.Path(vg,points);nvgFillColor(vg,nvgRGBA(8,15,28,255));nvgFill(vg)
 nvgSave(vg);nvgTranslate(vg,x+width*.35,y+height*.35);nvgScale(vg,width,height)
 D.Path(vg,{-.35,-.35,.65,-.35,.65,.65,-.35,.65})
 nvgFillPaint(vg,nvgRadialGradient(vg,0,0,.505,.919,nvgRGBA(27,79,150,255),nvgRGBA(8,15,28,255)));nvgFill(vg)
 D.Path(vg,{-.35,-.35,.65,-.35,.65,.65,-.35,.65})
 nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,.505,nvgRGBA(58,143,224,255),nvgRGBA(27,79,150,0)));nvgFill(vg)
 nvgRestore(vg)
 nvgSave(vg);nvgIntersectScissor(vg,x,y,width,height)
 local cell=1.1*h/100;nvgBeginPath(vg)
 for dx=x+cell/2,x+width,cell do for dy=y+cell/2,y+height,cell do
  if (dx-x)>=width*.18*(1-(dy-y)/height) then nvgCircle(vg,dx,dy,cell*.2) end
 end end
 nvgFillColor(vg,nvgRGBA(131,199,251,89));nvgFill(vg)
 -- 剪裁只能是矩形：速度线避开左上斜角外侧
 nvgIntersectScissor(vg,x+width*.18,y,width*.82,height)
 local radius=.8*math.sqrt(width*width+height*height)*1.6
 nvgTranslate(vg,x+width/2,y+height/2);nvgRotate(vg,t*math.pi*2/7)
 for index=0,39 do for _,slice in ipairs({{4,4.4,.14},{4.4,5,.385},{5,5.4,.14}}) do
  local a,b=math.rad(index*9+slice[1]),math.rad(index*9+slice[2]);local mid=(a+b)/2
  D.Path(vg,{0,0,math.sin(a)*radius,-math.cos(a)*radius,math.sin(b)*radius,-math.cos(b)*radius})
  nvgFillPaint(vg,nvgLinearGradient(vg,math.sin(mid)*radius*.22,-math.cos(mid)*radius*.22,
   math.sin(mid)*radius*.6,-math.cos(mid)*radius*.6,nvgRGBA(255,255,255,0),nvgRGBA(255,255,255,math.floor(slice[3]*255+.5))))
  nvgFill(vg)
 end end
 nvgRestore(vg)
 local images=ImageCache;local path=I.data.images.machinist_hero;local handle=images.Get(path)
 if handle and handle>0 then
  local iw,ih=images.GetSize(path);local scale=math.min(width*.925/iw,height*1.16/ih)
  local dw,dh=iw*scale,ih*scale
  D.Path(vg,points);nvgFillPaint(vg,nvgImagePattern(vg,x+width*.04+(width*.925-dw)/2,y-height*.04+height*1.16-dh,dw,dh,0,handle,1));nvgFill(vg)
 end
 local inset=.3*h/100
 nvgSave(vg);nvgTranslate(vg,x+width/2,y+height/2);nvgScale(vg,(width-inset)/width,(height-inset)/height);nvgTranslate(vg,-x-width/2,-y-height/2)
 D.Path(vg,points);nvgStrokeColor(vg,nvgRGBA(122,216,255,255));nvgStrokeWidth(vg,inset);nvgStroke(vg);nvgRestore(vg)
 nvgRestore(vg)
end
function M.Draw(page,vg,w,h,u)
 local I=page.owner;local id=I.shot;local t=I.age
 local film=DeferredModules['ui.IntroFilm'];film.Under(vg,I,w,h,u,page.k)
 local showSalvage,offsetX,offsetY,salvageAge=Motion.Salvage(I,w,h)
 if showSalvage then Salvage(page,vg,w,h,salvageAge,offsetX,offsetY) end
 local recruit=IntroRecruitTitles;recruit.Draw(vg,I,w,h,u)
 if id=='crt' then
  local tall=t<.23 and .004 or math.min(1,(t-.23)/.26);D.Rect(vg,0,h*(1-tall)/2,w,h*tall,{255,255,255,math.floor(255*(1-math.max(0,(t-.49)/.16)))})
 elseif id=='tvcut' then
  local frame=math.floor(t*24);local cell=math.max(8,h/44)
  for row=0,43 do for col=0,math.ceil(w/cell) do
   local seed=(row*374761393+col*668265263+frame*1274126177)&0xffffffff
   seed=((seed~(seed>>13))*1274126177)&0xffffffff;local value=(seed~(seed>>16))&255
   D.Rect(vg,col*cell,row*cell,cell,cell,{value,value,value,217})
  end end
  local y=-h*.2+t/.45*h*.8;D.Rect(vg,0,y,w,h*.055,{255,255,255,130});D.Rect(vg,0,y+h*.065,w,h*.025,{0,0,0,190})
 elseif id=='logo' then
  IntroBrand.Draw(vg,I,w,h,u,t)
 elseif id=='prosper' or id=='order' or id=='leave' or id=='no' then
  local comic=IntroComic;comic.BeginPanels(page,vg,w,h,u)
  comic.Draw(page,vg,w,h,u)
  if id=='no' and t>=.5 then IntroComicBurst.Draw(page,vg,w,h) end
  if id~='no' then
   comic.EndPanels(vg)
   -- Original comic titles accumulate until the laser wipes the whole page.
   for _,entry in ipairs(I.log or {{shot=id,t=I.time-t}}) do
    if entry.shot=='prosper' or entry.shot=='order' or entry.shot=='leave' then Title(vg,I,w,h,u,entry.shot,nil,I.time-entry.t) end
   end
   comic.Confetti(page,vg,w,h,u)
  elseif id=='no' then
   local dove=comic.DoveBounds(I,w,h);local tx,ty=dove.x+dove.w*.55,dove.y+dove.h*.42
   if t<.4 and math.floor(t/.06)%2==0 then
    nvgBeginPath(vg);nvgCircle(vg,tx,ty,4.2*u);nvgFillPaint(vg,nvgRadialGradient(vg,tx,ty,0,4.2*u,nvgRGBA(255,42,26,204),nvgRGBA(255,42,26,0)));nvgFill(vg)
    nvgBeginPath(vg);nvgCircle(vg,tx,ty,1.2*u);nvgFillColor(vg,nvgRGBA(255,42,26,255));nvgFill(vg)
   end
   if t>=.32 and t<.96 then
    local age=(t-.32)/.64;local length=math.sqrt((tx-w*.3)^2+(ty+80)^2)+30
    local grow=math.min(1,age/.18);local thick=age<.5 and .6+age*2.2 or 1.7*(1-(age-.5)*2)
    nvgSave(vg);nvgTranslate(vg,w*.3,-80);nvgRotate(vg,math.atan(ty+80,tx-w*.3));nvgGlobalAlpha(vg,1-age*.45)
    for _,pass in ipairs({{12,24},{8,48},{5,180},{2.2,255}}) do
     local width=pass[1]*u*math.max(0,thick);D.Rect(vg,0,-width/2,length*grow,width,pass[1]==2.2 and {255,240,235,pass[2]} or {255,42,26,pass[2]})
    end
    nvgRestore(vg)
   end
   if t>=.4 and t<.6 then D.Rect(vg,0,0,w,h,{255,90,58,math.floor((.6-t)/.2*178)}) end
   if t>=.5 then
    local flash=math.max(0,1-(t-.5)/.36);D.Rect(vg,0,0,w,h,{255,255,255,math.floor(flash*255)})
    D.Rect(vg,0,0,w,h,{255,30,15,48});IntroComicText.Bang(vg,tx-h*.2,ty+h*.08,u,t-.5)
   end
   comic.EndPanels(vg)
   if t<.15 then
    for _,entry in ipairs(I.log or {}) do
     if entry.shot=='prosper' or entry.shot=='order' or entry.shot=='leave' then Title(vg,I,w,h,u,entry.shot,nil,I.time-entry.t,t) end
    end
   end
   if t>=.5 then IntroComicText.No(vg,w,h,u,t-.5) end
  end
 elseif id=='familiar' then
  IntroFamiliar.Draw(page,vg,w,h,u)
 elseif id=='galaxy' then
  D.Rect(vg,0,0,w,h,{5,7,13,255});local k=math.min(1,t/((I.voiceDuration or 4.84)*.95));local cx=w*.56;local cy=h*.54;local R=math.min(w,h)*(.62+k*.12)
  nvgBeginPath(vg);nvgRect(vg,0,0,w,h);nvgFillPaint(vg,nvgRadialGradient(vg,cx,cy,0,R*.5,nvgRGBA(255,220,180,89),nvgRGBA(0,0,0,0)));nvgFill(vg)
  for _,s in ipairs(I.data.galaxy.stars) do
   local a=s.a+t*.05;local alpha=math.floor((.45+.4*math.sin(t*2+s.tw))*255);local color=s.c=='#9fd4ff' and {159,212,255,alpha} or s.c=='#ffe4c4' and {255,228,196,alpha} or {255,255,255,alpha}
   D.Rect(vg,cx+math.cos(a)*s.r*R,cy+math.sin(a)*s.r*R*.58,s.s,s.s,color)
  end
  local count=0;local last
  for _,hit in ipairs(I.data.galaxy.hits) do if hit.at<=k then
   count=count+1;last=hit;local s=hit.star;local a=s.a+t*.05;local x=cx+math.cos(a)*s.r*R;local y=cy+math.sin(a)*s.r*R*.58;local age=math.min(1,(k-hit.at)*6)
   nvgBeginPath(vg);nvgCircle(vg,x,y,4+age*26);nvgStrokeColor(vg,nvgRGBA(255,59,48,math.floor((1-age)*255)));nvgStrokeWidth(vg,2);nvgStroke(vg)
   nvgBeginPath(vg);nvgCircle(vg,x,y,2.6+(math.sin(t*9+hit.id)>0 and 1.2 or 0));nvgFillColor(vg,D.Color(red));nvgFill(vg)
  end end
  IntroGalaxyText.Draw(page,vg,I,w,h,u,count,last)
 elseif id=='payslip' then
  DeferredModules['ui.IntroPayslip'].Draw(vg,I,w,h,u,page,true)
 elseif id=='decide' or id=='decided' then
  D.Rect(vg,0,0,w,h,{0,0,0,255});local q=id=='decided' and 1 or I.holdProgress or 0
  local decision=Decision.Below(vg,I,w,h)
  nvgSave(vg)
  local scale=Fx.Plan(I).heroScale
  nvgTranslate(vg,w/2-10.15*u,h*.68);nvgScale(vg,scale,scale);nvgTranslate(vg,-(w/2-10.15*u),-h*.68)
  Decision.Hero(page,vg,id=='decided' and 'machinist_hero' or 'machinist_idle',w/2-62.3*u,h*.16,104.3*u,104*u,decision.brightness);nvgRestore(vg)
  if id=='decide' and I.deciding then
   -- Source .hold anchors the entire SVG + gap + instruction above bottom:16vh.
   local svg,gap,size=11*u,1.6*u,2.6*u;local top=h-16*u-svg-gap-size;local cy=top+svg*.5
   nvgSave(vg);nvgLineCap(vg,NVG_ROUND)
   nvgBeginPath(vg);nvgCircle(vg,w/2,cy,svg*.44);nvgStrokeColor(vg,nvgRGBA(255,255,255,51));nvgStrokeWidth(vg,svg*.06);nvgStroke(vg)
   nvgBeginPath(vg);nvgArc(vg,w/2,cy,svg*.44,-math.pi/2,-math.pi/2+q*math.pi*2,NVG_CW);nvgStrokeColor(vg,nvgRGBA(122,216,255,255));nvgStrokeWidth(vg,svg*.06);nvgStroke(vg)
   D.Text(vg,'按住',w/2,top+svg*.58,svg*.22,white,'vox-title',NVG_ALIGN_CENTER,0,true)
   local visual=I.host.state and I.host.state.sortieUi;local touch=visual and visual.session.touch
   if touch==nil then touch=require('controls.TouchMode').Enabled() end
   -- Source .hold .k：inBlink 1.1s 呼吸闪
   nvgGlobalAlpha(vg,IntroSortieUi.Blink(I.time,1.1))
   D.Text(vg,touch and '按住屏幕 · 做出决定' or '按住 鼠标左键 / 空格 · 做出决定',w/2,top+svg+gap,size,white,'vox-title',NVG_ALIGN_CENTER,size*.14,false,size)
   nvgRestore(vg)
  end
 elseif id=='sortie-countdown' then
  IntroSortieUi.Chrome(vg,w,h,u,I.time,0);IntroSortieUi.Countdown(page,vg,I,w,h,u)
 elseif id=='sortie-brief' or I.playing then
  IntroSortieUi.Chrome(vg,w,h,u,I.time,I.sortie and I.sortie.step or 0)
  if id=='sortie-brief' then
   IntroSortieUi.Warn(vg,w,h,u,t)
   if t>=2.2 and not I.playing then
    local visual=I.host.state and I.host.state.sortieUi
    IntroSortieUi.Brief(vg,w,h,u,t,visual and visual.session.touch)
   end
  elseif I.sortie then
   local s=I.sortie
   local visual=I.host.state and I.host.state.sortieUi;if visual then visual:Draw(vg,I,w,h,u) end
   IntroSortieUi.Countdown(page,vg,I,w,h,u)
   if s.step==5 then
    IntroSortieUi.Stamp(vg,w,h,u,s)
   end
  end
 elseif id=='motto' or id=='disclaimer' then
  local alpha,first,second=Motion.Motto(I)
   D.Rect(vg,0,0,w,h,{0,0,0,math.floor(255*Fx.MottoBlack(I))})
   DeferredModules['ui.IntroMotto'].Draw(page,vg,w,h,u,alpha,first,second)
 elseif I.big and I.big~='' and not recruit.Handles(id) then Title(vg,I,w,h,u,id,I.big,t-(I.wordAt or 0))
 end
 DeferredModules['ui.IntroCaption'].Draw(page,vg,I,w,h,u)
 film.Over(vg,I,w,h,u)
 if id=='payslip' then DeferredModules['ui.IntroPayslip'].DrawForeground(vg,I,w,h,u) end
 Fx.Draw(vg,I,w,h)
end
return M
