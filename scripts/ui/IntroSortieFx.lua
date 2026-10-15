-- Original intro.css sortieNudge and the ally dashed fire-control glow.
local M={}
local gaussian=type(nvgBoxGradientGaussian)=='function' and nvgBoxGradientGaussian or nvgBoxGradient
function M.Nudge(s)
 local start=s.step==1 and 4 or s.step==2 and 6 or nil
 if s.pending or not start or s.elapsed<start then return 0 end
 return .5-.5*math.cos((s.elapsed-start)*math.pi*2/.9)
end
function M.TipGlow(vg,w,h,u,pulse)
 if pulse<=0 then return end
 local blur=2.4*u*pulse
 nvgSave(vg);nvgTransform(vg,1,0,-math.tan(math.pi/18),1,0,0)
 nvgBeginPath(vg);nvgRect(vg,-blur*2,-blur*2,w+blur*4,h+blur*4)
 nvgFillPaint(vg,gaussian(vg,0,0,w,h,0,blur,nvgRGBA(122,216,255,math.floor(140*pulse)),nvgRGBA(122,216,255,0)))
 nvgFill(vg);nvgRestore(vg)
end
function M.LockRing(vg,x,y,radius,angle,u)
 local blur=1.2*u;local length=radius*.55*math.pi/12;local thickness=.45*u
 for i=0,23 do
  local mid=angle+(i+.275)*math.pi/12
  nvgSave(vg);nvgTranslate(vg,x+math.cos(mid)*radius,y+math.sin(mid)*radius);nvgRotate(vg,mid+math.pi/2)
  nvgBeginPath(vg);nvgRect(vg,-length/2-blur*2,-thickness/2-blur*2,length+blur*4,thickness+blur*4)
  nvgFillPaint(vg,gaussian(vg,-length/2,-thickness/2,length,thickness,0,blur,nvgRGBA(255,59,48,153),nvgRGBA(255,59,48,0)))
  nvgFill(vg);nvgRestore(vg)
 end
 -- All crisp source dashes share one path; the halo adds no render targets.
 nvgBeginPath(vg)
 for i=0,23 do
  local a=angle+i*math.pi/12
  nvgMoveTo(vg,x+math.cos(a)*radius,y+math.sin(a)*radius)
  nvgArc(vg,x,y,radius,a,angle+(i+.55)*math.pi/12,NVG_CW)
 end
 nvgStrokeWidth(vg,thickness);nvgStrokeColor(vg,nvgRGBA(255,59,48,255));nvgStroke(vg)
end
return M
