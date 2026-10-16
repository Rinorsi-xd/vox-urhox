-- Frozen .motto-card flex composition; reveal clocks remain IntroPromoMotion's.
local D=require 'ui.SourceDraw'
local Opacity=require 'ui.IntroOpacity'
local M={}
local first='以发展之眼光，促螺旋之上升。'
local second='为星系予和平，许员工以价值。'
function M.Plan(vg,w,h,u,pixel)
 pixel=pixel or 1
 local size=4.4*u;local spacing=.2*size;local lineHeight=1.5*size
 local width=math.max(D.Width(vg,first,size,'vox-title',spacing),D.Width(vg,second,size,'vox-title',spacing))
 local a,d=D.FontMetrics(vg,1.3*u,'vox-title');local fineHeight=a+d
 local textHeight=2*lineHeight+4*u+2*pixel
 local height=16*u+4.8*u+textHeight+fineHeight
 local top=(h-height)/2;local textY=top+18.4*u
 return {x=(w-width)/2,w=width,top=top,size=size,spacing=spacing,lineHeight=lineHeight,
  textY=textY,textHeight=textHeight,firstY=textY+pixel+2*u,secondY=textY+pixel+2*u+lineHeight,
  fineY=textY+textHeight+2.4*u,fineHeight=fineHeight,pixel=pixel}
end
local function Line(vg,text,w,h,plan,y,reveal)
 if reveal<=0 then return end
 local width=D.Width(vg,text,plan.size,'vox-title',plan.spacing)
 nvgSave(vg);nvgIntersectScissor(vg,(w-width)/2,0,width*reveal,h)
 D.Text(vg,text,w/2,y,plan.size,{244,245,247,255},'vox-title',NVG_ALIGN_CENTER,plan.spacing,false,plan.lineHeight);nvgRestore(vg)
end
function M.Draw(page,vg,w,h,u,alpha,one,two)
 local plan=M.Plan(vg,w,h,u,page.cssPixel or 1);page.mottoLayout=plan
 Opacity.Push(vg,alpha)
 require('ui.IntroPage').Image(vg,page.owner,'company-emblem',w/2-8*u,plan.top,16*u,16*u)
 D.Rect(vg,plan.x,plan.textY,plan.w,plan.pixel,{255,255,255,64})
 D.Rect(vg,plan.x,plan.textY+plan.textHeight-plan.pixel,plan.w,plan.pixel,{255,255,255,64})
 Line(vg,first,w,h,plan,plan.firstY,one);Line(vg,second,w,h,plan,plan.secondY,two)
 D.Text(vg,'*最终解释权归公司所有',w/2,plan.fineY,1.3*u,{255,240,210,153},'vox-title',NVG_ALIGN_CENTER,.104*u,false,plan.fineHeight)
 Opacity.Pop(vg)
end
return M
