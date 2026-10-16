-- Keep the original 16:9 terminal/pad/portrait composition on shorter tablets.
local M={}
function M.Unit(w,h)
 return math.min(h/100,w*9/1600)
end
function M.Plan(w,h)
 local u=M.Unit(w,h)
 local x,y=w*.04,h*.1
 local cw=math.min(70*u,w*.92-92.4*u)
 local ch=h*.86
 return {unit=u,terminal={x=x,y=y,w=cw,h=ch},
  pad={x=x+cw-2.6*u,y=y+38*u,w=44*u,h=ch-41*u}}
end
return M
