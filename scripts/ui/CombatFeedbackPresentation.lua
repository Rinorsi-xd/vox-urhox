-- Frozen combatFeedback.css keyframes interpolate each interval separately.
local M={}
local function Cubic(t,a,b) local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(p,x1,y1,x2,y2)
    if p<=0 then return 0 elseif p>=1 then return 1 end
    local lo,hi=0,1
    for _=1,22 do local t=(lo+hi)/2;if Cubic(t,x1,x2)<p then lo=t else hi=t end end
    return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(age)
    if age<0 or age>=2 then return {visible=false} end
    local incoming=Ease(age/.12,0,0,.58,1)
    local outgoing=Ease((age-1.64)/.36,0,0,.58,1)
    local first=age<.192
    local slam=Ease(first and age/.192 or (age-.192)/.128,.2,1.7,.4,1)
    return {visible=true,alpha=incoming*(1-outgoing),pointsAlpha=first and math.max(0,math.min(1,slam)) or 1,
        scale=age>=.32 and 1 or first and 2.2+(.92-2.2)*slam or .92+.08*slam,lift=-12*outgoing}
end
function M.Style(streak,pixel)
    pixel=pixel or 1
    return {color=streak>1 and {255,226,122,255} or {255,210,74,255},points={
        {x=0,y=2*pixel,blur=0,color={58,36,0,255}},
        {x=0,y=0,blur=(streak>1 and 26 or 18)*pixel,color={255,176,46,streak>1 and 204 or 136}},
        {x=0,y=0,blur=3*pixel,color={0,0,0,255}}},
        who={{x=0,y=pixel,blur=3*pixel,color={0,0,0,255}},{x=0,y=0,blur=8*pixel,color={0,0,0,170}}}}
end
return M
