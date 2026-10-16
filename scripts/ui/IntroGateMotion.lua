local M={}
local function Clamp(t) return math.max(0,math.min(1,t)) end
function M.Ease(t,x1,y1,x2,y2)
 t=Clamp(t);if t==0 or t==1 then return t end;local lo,hi=0,1
 for _=1,24 do local v=(lo+hi)/2;local q=1-v;local x=3*q*q*v*x1+3*q*v*v*x2+v*v*v;if x<t then lo=v else hi=v end end
 local v=(lo+hi)/2;local q=1-v
 return 3*q*q*v*y1+3*q*v*v*y2+v*v*v
end
function M.Out(t,duration) return 1-M.Ease(t/duration,.42,0,1,1) end
function M.Plan(t)
 local split=0
 if t<.46 then split=1-M.Ease(t/.46,.6,0,.9,.6)
 elseif t<3.58 then split=0
 elseif t<3.94 then split=.06*M.Ease((t-3.58)/.36,.3,0,.3,1)
 elseif t<4.24 then split=.06
 else split=.06+.98*M.Ease((t-4.24)/1.5,.45,0,.2,1) end
 local bolts={}
 for i=1,6 do bolts[i]=M.Ease((t-2.44-(i-1)*.08)/.13,.42,0,1,1) end
 local lockEase=M.Ease((t-.46)/.22,.2,1.4,.4,1)
 local lockAlpha=Clamp(lockEase)
 local lockScale=1.3-.3*lockEase
 return {split=split,bolts=bolts,rotation=M.Ease((t-2.92)/.42,.5,0,.2,1.3)*math.pi/3,
  half=t>=3.58,lockAlpha=lockAlpha,lockScale=lockScale,ok=t>=1.89,
  seam=t<4.24 and M.Ease((t-3.28)/.3,.25,.1,.25,1) or Clamp(1-(t-4.24)/1.2),
  idAlpha=t<3.94 and 1 or M.Out(t-3.94,.3),visible=t<5.94}
end
function M.Stamp(t)
 local p=M.Ease(t/.26,.5,0,.7,1)
 return {alpha=math.min(1,p/.75),scale=p<.75 and 3.2+(0.92-3.2)*p/.75 or .92+.08*(p-.75)/.25}
end
return M
