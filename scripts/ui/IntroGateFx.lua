-- Frozen actGate layers; particles retain state between actual rendered frames.
local D=require 'ui.SourceDraw'
local Opacity=require 'ui.IntroOpacity'
local M={}
local cyan={110,214,255,255}
function M.Lock(vg,I,x,y,u,plan,image,half)
 Opacity.Push(vg,half and 1 or plan.lockAlpha)
 nvgTranslate(vg,x,y);local scale=half and 1 or plan.lockScale;nvgScale(vg,scale,scale)
 nvgRotate(vg,half and math.pi/3 or plan.rotation)
 local r=18*u
 nvgBeginPath(vg);nvgCircle(vg,0,0,r);nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,r,nvgRGBA(48,52,58,255),nvgRGBA(26,28,32,255)));nvgFill(vg)
 for _,radius in ipairs({r+.9*u,r+.5*u,r*.96}) do
  nvgBeginPath(vg);nvgCircle(vg,0,0,radius);nvgStrokeColor(vg,nvgRGBA(214,240,255,46));nvgStrokeWidth(vg,1.5);nvgStroke(vg)
 end
 for i=0,59 do local a=i*math.pi/30
  D.Line(vg,math.sin(a)*16.2*u,-math.cos(a)*16.2*u,math.sin(a)*(i%5==0 and 14.4*u or 15.48*u),-math.cos(a)*(i%5==0 and 14.4*u or 15.48*u),{255,255,255,102},1.4*r/100)
 end
 for i=0,18 do
  local a=i*28/84;local b=math.min(a+18/84,math.pi*2)
  nvgBeginPath(vg);nvgArc(vg,0,0,15.12*u,a,b,NVG_CW);nvgStrokeColor(vg,nvgRGBA(110,214,255,217));nvgStrokeWidth(vg,.54*u);nvgStroke(vg)
 end
 local color=plan.ok and cyan or {255,176,46,255}
 nvgBeginPath(vg);nvgCircle(vg,0,0,10.44*u);nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,.36*u);nvgStroke(vg)
 for i=0,5 do
  local retract=half and 1 or plan.bolts[i+1];local radial=(17.6-retract*5.2)*u;local bright=1-.45*retract
  nvgSave(vg);nvgRotate(vg,(i*60+30)*math.pi/180)
  D.Path(vg,{-1.3*u,-radial-3.7*u,1.3*u,-radial-3.7*u,1.3*u,-radial+3.7*u,-1.3*u,-radial+3.7*u})
  D.Gradient(vg,-1.3*u,-radial-3.7*u,2.6*u,7.4*u,{125*bright,131*bright,139*bright,255},{223*bright,227*bright,231*bright,255},true);nvgRestore(vg)
 end
 nvgBeginPath(vg);nvgCircle(vg,0,0,7.5*u);nvgFillPaint(vg,nvgRadialGradient(vg,0,0,0,7.5*u,nvgRGBA(35,39,44,255),nvgRGBA(18,20,23,255)));nvgFill(vg)
 nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,.3*u);nvgStroke(vg)
 image(vg,I,'division-insignia',-4.5*u,-4.5*u,9*u,9*u);Opacity.Pop(vg)
end
function M.Seam(vg,w,h,u,alpha)
 if alpha<=0 then return end
 Opacity.Push(vg,alpha)
 for i=6,1,-1 do D.Rect(vg,w/2-(.2+i*.6)*u,0,(.4+i*1.2)*u,h,{110,214,255,math.floor(8*(1-i/7))}) end
 D.Rect(vg,w/2-.2*u,0,.4*u,h,{238,250,255,255});Opacity.Pop(vg)
end
local function Vent(state,n)
 for _=1,n do for _,y in ipairs({.18,.84}) do
  local d=math.random()<.5 and -1 or 1
  state.puffs[#state.puffs+1]={x=.5,y=y+(math.random()-.5)*.04,vx=d*(.08+math.random()*.18),vy=(math.random()-.5)*.05,r=20+math.random()*30,t=0,life=1.2+math.random()*.8}
 end end
end
function M.Steam(page,vg,w,h,t)
 local state=page.gateSteam
 if not state or t<state.last then state={last=0,puffs={},vented={}};page.gateSteam=state end
 local dt=math.max(0,t-state.last);state.last=t
 for i=#state.puffs,1,-1 do local p=state.puffs[i]
  p.t=p.t+dt;p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vx=p.vx*.97;p.vy=p.vy*.97
  if p.t>p.life then table.remove(state.puffs,i) end
 end
 for i,cue in ipairs({{3.28,6},{3.58,8}}) do if t>=cue[1] and not state.vented[i] then Vent(state,cue[2]);state.vented[i]=true end end
 for _,p in ipairs(state.puffs) do
  local alpha=math.max(0,1-p.t/p.life);local r=p.r*(1+p.t*2.2)/(page.k or 1)
  nvgBeginPath(vg);nvgCircle(vg,p.x*w,p.y*h,r)
  nvgFillPaint(vg,nvgRadialGradient(vg,p.x*w,p.y*h,0,r,nvgRGBA(220,232,240,math.floor(255*.32*alpha+.5)),nvgRGBA(220,232,240,0)));nvgFill(vg)
 end
end
return M
