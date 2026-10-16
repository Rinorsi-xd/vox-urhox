-- Source layer order: black > film > panels/slams/captions > cinema bars.
local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local M={}
local barChanges={idyll=true,prosper=false,['sortie-brief']=true,['sortie-play']=false,familiar=false,galaxy=true,['m-build']=true}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(p,x1,y1,x2,y2)
 if p<=0 then return 0 elseif p>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<p then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(I)
 local start;local from,target,at=0,0,0
 for _,entry in ipairs(I.log or {}) do
  if entry.shot=='idyll' then start=entry.t end
  local on=barChanges[entry.shot]
  if on~=nil then
   local value=on and 1 or 0
   if value~=target then
    from=from+(target-from)*Ease((entry.t-at)/.7,.16,1,.3,1);target=value;at=entry.t
   end
  end
 end
 local age=start and I.time-start or -1
 return {active=start~=nil,film=Ease(age/.4,.25,.1,.25,1),black=1-Ease(age/.7,.42,0,.58,1),
  bars=from+(target-from)*Ease((I.time-at)/.7,.16,1,.3,1),logo=age>=0 and age<.26,
  logoInset=.5*Ease(age/.26,.42,0,1,1)}
end
function M.Under(vg,I,w,h,u,k)
 local plan=M.Plan(I);if not plan.active then return end
 if I.shot=='idyll' and plan.black>0 then D.Rect(vg,0,0,w,h,{0,0,0,math.floor(plan.black*255)}) end
 nvgSave(vg);nvgGlobalAlpha(vg,plan.film)
 -- All scanlines share one NanoVG path/fill, rather than hundreds of draws.
 local pixel=1/(k or 1);nvgBeginPath(vg)
 for y=0,h,3*pixel do nvgRect(vg,0,y,w,pixel) end
 nvgFillColor(vg,nvgRGBA(0,0,0,41));nvgFill(vg)
 local rx,ry=w*.7*math.sqrt(2),h*.7*math.sqrt(2)
 nvgSave(vg);nvgTranslate(vg,w/2,h/2);nvgScale(vg,rx,ry);nvgBeginPath(vg);nvgRect(vg,-w/2/rx,-h/2/ry,w/rx,h/ry)
 nvgFillPaint(vg,nvgRadialGradient(vg,0,0,.45,1,nvgRGBA(40,22,0,0),nvgRGBA(40,22,0,140)));nvgFill(vg);nvgRestore(vg)
 local image=require('ui.IntroPage').Image
 local size=w*.0105;local small=w*.0062;local x,y=w*.032,h*.095;local emblem=w*.026
 image(vg,I,'company-emblem',x,y,emblem,emblem,1)
 local tx=x+emblem+size*.8;local titleY=y+(emblem-size*1.1-small*1.2)/2
 D.Text(vg,'星际前途 · 公益宣传',tx,titleY,size,{255,245,220,235},'vox-title',nil,size*.06,false,size*1.1)
 D.Text(vg,'INTERSTELLAR PROSPECTS PSA',tx,titleY+size*1.1,small,{255,245,220,176},'vox-display',nil,small*.2,false,small*1.2)
 local tagSize=w*.0085;local tagSpacing=tagSize*.1;local tagWidth=D.Width(vg,'广告',tagSize,'vox-title',tagSpacing)+tagSize*1.4;local tagHeight=tagSize*1.5
 local tagX=w*.968-tagWidth
 nvgBeginPath(vg);nvgRoundedRect(vg,tagX,y,tagWidth,tagHeight,3*pixel);nvgFillColor(vg,nvgRGBA(255,211,106,255));nvgFill(vg)
 D.Text(vg,'广告',tagX+tagSize*.7,y+tagSize*.25,tagSize,{58,36,0,255},'vox-title',nil,tagSpacing,false,tagSize)
 local legalSize=small;local lineHeight=legalSize*1.2;local legalY=h*.895-lineHeight*2
 D.Text(vg,'本片部分画面为实机演示* · 星际前途有限公司 出品',w*.968,legalY,legalSize,{255,240,210,166},'vox-title',NVG_ALIGN_RIGHT,legalSize*.04,false,lineHeight)
 D.Text(vg,'*另一部分为艺术加工，以实际战损为准',w*.968,legalY+lineHeight,legalSize,{255,240,210,166},'vox-title',NVG_ALIGN_RIGHT,legalSize*.04,false,lineHeight)
 nvgRestore(vg)
end
function M.Over(vg,I,w,h,u)
 local plan=M.Plan(I);if not plan.active then return end
 if plan.logo then
  nvgSave(vg);nvgIntersectScissor(vg,0,h*plan.logoInset,w,h*(1-2*plan.logoInset))
  require('ui.IntroBrand').Draw(vg,I,w,h,u,2.9+I.age);nvgRestore(vg)
 end
 local height=h*.085*plan.bars
 if height>0 then D.Rect(vg,0,0,w,height,{0,0,0,255});D.Rect(vg,0,h-height,w,height,{0,0,0,255}) end
end
return M
