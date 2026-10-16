-- Frozen intro.js cut/decided/recruit flashes and hero Web Animation clocks.
local D=require 'ui.SourceDraw'
local M={}
local cuts={['m-build']=true,['m-drive']=true,['m-missile']=true,['m-salvage']=true}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<t then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(I)
 local age=I.age;local duration,peak,color=0,0,{255,255,255}
 if cuts[I.shot] then duration,peak,color=.16,.85,{255,255,255}
 elseif I.shot=='decided' then duration,peak,color=.5,1,{255,255,255}
 elseif I.shot=='mechanic' then duration,peak,color=.42,.7,{255,211,106} end
 local flash=duration>0 and peak*(1-Ease(age/duration,0,0,.58,1)) or 0
 local heroScale=I.shot=='decided' and 1.25-.23*Ease(age/.42,.2,.9,.3,1) or 1
 return {flash=flash,color=color,heroScale=heroScale}
end
function M.MottoBlack(I)
 local age=I.age;local found=false
 for index=#(I.log or {}),1,-1 do
  local entry=I.log[index]
  if entry.shot=='motto' then age=I.time-entry.t;found=true;break end
 end
 if I.shot=='disclaimer' and not found then return .7 end
 return .7*Ease(age/.5,.42,0,.58,1)
end
function M.Draw(vg,I,w,h)
 local plan=M.Plan(I)
 if plan.flash>0 then D.Rect(vg,0,0,w,h,{plan.color[1],plan.color[2],plan.color[3],math.floor(255*plan.flash)}) end
end
return M
