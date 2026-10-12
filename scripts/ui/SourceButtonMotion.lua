-- Source CSS timings: hover .2s ease-out, press .05s ease-back,
-- release .24s ease-back. Kept local to each widget; no global subscriptions.
local M={}
local function Coordinate(t,a,b) local u=1-t;return 3*u*u*t*a+3*u*t*t*b+t*t*t end
local function Ease(x,back)
    if x<=0 then return 0 elseif x>=1 then return 1 end
    local x1,x2,y1= .16,.3,1
    if back=='ease' then x1,x2,y1=.25,.25,.1
    elseif back=='css-ease-out' then x1,x2,y1=0,.58,0
    elseif back then x1,x2,y1=.34,.64,1.56 end
    local lo,hi=0,1
    for _=1,16 do
        local mid=(lo+hi)/2
        if Coordinate(mid,x1,x2)<x then lo=mid else hi=mid end
    end
    return Coordinate((lo+hi)/2,y1,1)
end
local function Step(tween,target,duration,dt,back)
    if tween.target~=target then
        tween.start=tween.value;tween.target=target;tween.elapsed=0;tween.duration=duration
    end
    if tween.elapsed<tween.duration then
        tween.elapsed=math.min(tween.duration,tween.elapsed+math.max(0,dt))
        tween.value=tween.start+(target-tween.start)*Ease(tween.elapsed/tween.duration,back)
    end
end
-- Shared with library cards: exact source CSS Bezier curves, not the UI
-- library's differently shaped presets. Rendering/hit transforms stay in UI.
M.Step=Step
M.Ease=Ease
function M.Update(button,dt)
    if not button.sourceMotion then
        button.sourceMotion={hover={value=0,start=0,target=0,elapsed=0,duration=0},
            scale={value=1,start=1,target=1,elapsed=0,duration=0}}
    end
    local motion=button.sourceMotion
    local enabled=not button.props.disabled
    local pressed=enabled and button.state.pressed
    Step(motion.hover,enabled and button.state.hovered and 1 or 0,.2,dt,false)
    Step(motion.scale,pressed and .95 or 1,pressed and .05 or .24,dt,true)
end
return M
