-- Frozen intro.js motto and salvage Web Animation clocks.
local M={}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local mid=(lo+hi)/2;if Cubic(mid,x1,x2)<t then lo=mid else hi=mid end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Motto(I)
 local duration=I.audio and I.audio:Duration('vo_n16') or I.data.durations and I.data.durations.vo_n16 or 8
 if duration<=0 then duration=8 end
 local age=I.shot=='disclaimer' and duration+.1+I.age or I.age
 for i=#(I.log or {}),1,-1 do
  local entry=I.log[i]
  if entry.shot=='motto' then age=I.time-entry.t;break end
 end
 return Ease(age/.4,.16,1,.3,1),Ease(age/.9,.6,0,.3,1),Ease((age-duration*.48)/.9,.6,0,.3,1)
end
function M.Salvage(I,w,h)
 if I.shot=='m-salvage' then
  local remaining=1-Ease(I.age/.28,.16,1,.3,1)
  return true,remaining*w*.45,-remaining*h*.2,I.age
 end
 if I.shot~='recruit' then return false end
 local exitAt
 for i=#(I.log or {}),1,-1 do
  local entry=I.log[i]
  if entry.shot=='recruit' then exitAt=entry.t
  elseif entry.shot=='m-salvage' then
   if not exitAt then return false end
   local elapsed=I.time-exitAt
   if elapsed<0 or elapsed>=.2 then return false end
   local progress=Ease(elapsed/.2,.42,0,1,1)
   return true,progress*w*.45,progress*h*.2,I.time-entry.t
  end
 end
 return false
end
return M
