-- Frozen introFx.wipe: one CSS effect easing, then keyframe interpolation.
local D=require 'ui.SourceDraw'
local M={}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
function M.Plan(age)
 if age<0 or age>=.76 then return {active=false}end
 local lo,hi=0,1;local t=age/.76
 for _=1,22 do local p=(lo+hi)/2;if Cubic(p,.55,.45)<t then lo=p else hi=p end end
 local p=Cubic((lo+hi)/2,.05,.95);local x
 if p<.42 then x=115-150*p/.42 elseif p<.58 then x=-35-20*(p-.42)/.16 else x=-55-160*(p-.58)/.42 end
 return {active=true,x=x/100,progress=p}
end
local function Color(hex)
 return {tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
end
function M.Draw(vg,I,w,h,u)
 if not I.wipeAt then return end
 local p=M.Plan(I.time-I.wipeAt);if not p.active then return end
 local width,height=w*1.9,h*1.2;local cy=-h*.1+height/2;local skew=math.tan(-20*math.pi/180)
 local function Slab(offset,color)
  local x=p.x*w+offset;local top=x+skew*(-height/2);local bottom=x+skew*(height/2)
  D.Path(vg,{top,cy-height/2,top+width,cy-height/2,bottom+width,cy+height/2,bottom,cy+height/2})
  nvgFillColor(vg,D.Color(color));nvgFill(vg)
 end
 nvgSave(vg);nvgIntersectScissor(vg,0,0,w,h)
 Slab(w*.022,{122,216,255,255});Slab(-w*.022,{122,216,255,255})
 Slab(w*.014,{40,121,235,255});Slab(-w*.014,{40,121,235,255})
 Slab(0,Color(I.wipeColor or '#0b0b0d'));nvgRestore(vg)
end
return M
