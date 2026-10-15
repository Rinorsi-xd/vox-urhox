-- Frozen intro.css hudfx and the projection platform around the real portrait.
local D=require 'ui.SourceDraw'
local M={}
function M.Backdrop(vg,w,h,u,t)
 local horizon=h*.64;local step=7*u;local move=t%5/5*step
 for i=-25,25 do
  local a=i*step;D.Line(vg,w/2+a,horizon,w/2+a*5,h,{110,214,255,11},1)
 end
 for i=0,20 do local z=i*step+move;local y=horizon+z*.438/(1+z/(50*u));if y<=h then D.Line(vg,0,y,w,y,{110,214,255,11},1) end end
 D.Line(vg,w*.08,horizon,w*.92,horizon,{214,240,255,42},1)
 for x=w*.08,w*.92,5*u do local edge=math.min(1,(x-w*.08)/(w*.22),(w*.92-x)/(w*.22));D.Line(vg,x,horizon-.5*u,x,horizon+.5*u,{214,240,255,math.floor(76*math.max(0,edge))},1) end
 for _,side in ipairs({-1,1}) do
  local x=side==-1 and w*.014 or w*.986
  for i=0,58 do local y=h*.16+i*1.2*u+(t%8/8)*1.2*u;local mask=math.max(0,math.min(1,(y-h*.16)/(h*.136),(h*.84-y)/(h*.136)));D.Line(vg,x,y,x-side*(i%5==0 and 1.4 or .7)*u,y,{214,240,255,math.floor(mask*(i%5==0 and 69 or 34))},1) end
  for _,cy in ipairs({h*.09,h*.976}) do local dy=cy<h/2 and 1 or -1;D.Line(vg,x,cy,x-side*4*u,cy,{214,240,255,102},1);D.Line(vg,x,cy,x,cy+dy*4*u,{214,240,255,102},1) end
 end
 local ink={214,240,255,115};local sz=1.05*u
 D.Rect(vg,w*.014+1.2*u,h*.09+u,.7*u,.7*u,{110,214,255,179})
 D.Text(vg,'SS-07 · FIELD TERMINAL',w*.014+2.7*u,h*.09+u,sz,ink,'vox-display',nil,sz*.32)
 D.Text(vg,'SECURE LINK · AES-7',w*.986-1.2*u,h*.09+u,sz,ink,'vox-display',NVG_ALIGN_RIGHT,sz*.32)
 D.Text(vg,'HANGAR 07 · 坠舰陨坑',w*.014+1.2*u,h*.976-2.05*u,sz,ink,'vox-display',nil,sz*.32)
 local scan=-20*u+t%9/9*140*u;local half=8*u
 for _,part in ipairs({{scan,0,5},{scan+half,5,0}}) do D.Path(vg,{0,part[1],w,part[1],w,part[1]+half,0,part[1]+half});nvgFillPaint(vg,nvgLinearGradient(vg,0,part[1],0,part[1]+half,nvgRGBA(110,214,255,part[2]),nvgRGBA(110,214,255,part[3])));nvgFill(vg) end
end
function M.Projection(vg,x,y,w,h,u,t)
 local top=y+10*u;local bottom=y+h-4.2*u
 D.Path(vg,{x+w*.14,top,x+w*.86,top,x+w*.74,bottom,x+w*.26,bottom})
 nvgFillPaint(vg,nvgLinearGradient(vg,0,top,0,bottom,nvgRGBA(110,214,255,0),nvgRGBA(110,214,255,25)));nvgFill(vg)
 for yy=y+7*u,y+h-8*u,1.5*u do D.Line(vg,x+w-1.9*u,yy,x+w-u,yy,{214,240,255,49},1) end
 local cy=y+h-4.2*u;local cx=x+w/2;local rx=w*.38;local ry=1.2*u
 nvgSave(vg);nvgTranslate(vg,cx,cy);nvgScale(vg,1,ry/rx);nvgBeginPath(vg);nvgCircle(vg,0,0,rx)
 nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,rx,nvgRGBA(214,240,255,128),nvgRGBA(110,214,255,0)));nvgFill(vg)
 nvgBeginPath(vg);nvgCircle(vg,0,0,rx);nvgStrokeWidth(vg,rx/ry);nvgStrokeColor(vg,nvgRGBA(214,240,255,77));nvgStroke(vg);nvgRestore(vg)
 local progress=t%2.8/2.8;local scale=.85+.3*progress
 nvgBeginPath(vg);nvgEllipse(vg,cx,cy,rx*1.16*scale,(ry+.9*u)*scale);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(214,240,255,math.floor(56*(1-progress))));nvgStroke(vg)
end
return M
