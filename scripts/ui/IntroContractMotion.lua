-- Frozen IntroStory _unfold / choose clocks; the narrative still resumes at 260ms.
local SourceDraw=require("ui.SourceDraw")
local IntroOpacity=require("ui.IntroOpacity")

local Ease=require('ui.IntroGateMotion').Ease
local M={}
local function Clamp(t)return math.max(0,math.min(1,t))end
function M.Unfold(age,duration,delay,x,y,w,h,pixel)
 local p=Clamp((age-(delay or 0))/duration);pixel=pixel or 1
 local half=h/2-pixel;local left,top
 if p<.22 then left=w/2+(-60*pixel-w/2)*Ease(p/.22,.3,0,.2,1);top=half
 else left=-60*pixel;top=half+(-60*pixel-half)*Ease((p-.22)/.78,.1,.9,.2,1) end
 local alpha=p<.1 and Ease(p/.1,.3,0,.2,1) or p<.7 and 1 or p<.8 and 1-(p-.7)*5 or p<.9 and .5+(p-.8)*5 or 1
 return {x=x+left,y=y+top,w=math.max(0,w-2*left),h=math.max(0,h-2*top),alpha=alpha,progress=p,clipped=p<1}
end
function M.Contract(I,layout,pixel)
 local age=I.shot=='contract' and I.age or 1
 local t,p=layout.terminal,layout.pad
 return M.Unfold(age,.24,0,t.x,t.y,t.w,t.h,pixel),M.Unfold(age,.2,.25,p.x,p.y,p.w,p.h,pixel)
end
function M.Intersection(a,b)
 local x,y=math.max(a.x,b.x),math.max(a.y,b.y)
 return {x=x,y=y,w=math.max(0,math.min(a.x+a.w,b.x+b.w)-x),h=math.max(0,math.min(a.y+a.h,b.y+b.h)-y)}
end
function M.Choice(index,selected,elapsed,w)
 local p=Clamp(elapsed/(.24+(index-1)*.04));local eased=Ease(p,.42,0,1,1)
 return {alpha=1-eased,x=(index==selected and .02 or -.1)*w*eased,visible=p<1}
end
function M.Scan(vg,rect,u,pixel)
 if not rect.clipped or rect.progress<=0 then return end
 local p=Ease(rect.progress,.1,.9,.2,1)
 local wide=math.min(1,p/.22);local travel=Clamp((p-.22)/.48)
 local alpha=p<.7 and 1-p/.7*.1 or .9*(1-(p-.7)/.3)
 local D=SourceDraw
 for _,edge in ipairs({-1,1})do
  local y=rect.centerY+edge*rect.fullHeight*.5*travel
  local x=rect.centerX-(rect.fullWidth+2*u)*wide/2;local width=(rect.fullWidth+2*u)*wide
  nvgSave(vg);nvgIntersectScissor(vg,x,y-2*pixel,width,4*pixel)
  nvgBeginPath(vg);nvgRect(vg,x,y-pixel,width,2*pixel)
  nvgFillPaint(vg,nvgLinearGradient(vg,x,y,x+width,y,nvgRGBA(214,240,255,0),nvgRGBA(214,240,255,math.floor(242*alpha))));nvgFill(vg)
  D.Line(vg,x+width*.12,y,x+width*.88,y,{214,240,255,math.floor(242*alpha)},2*pixel);nvgRestore(vg)
 end
end
function M.Begin(vg,plan,box)
 IntroOpacity.Push(vg,plan.alpha)
 if plan.clipped then nvgIntersectScissor(vg,plan.x,plan.y,plan.w,plan.h)end
 plan.centerX=box.x+box.w/2;plan.centerY=box.y+box.h/2;plan.fullWidth=box.w;plan.fullHeight=box.h
end
return M
