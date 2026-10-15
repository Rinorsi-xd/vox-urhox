-- Frozen storyBoss.js BAR_CSS transitions; one clock per rendered HUD update.
local Ease=require('ui.SourceButtonMotion').Ease
local M={}
local function Tween(value) return {value=value,target=value,start=value,elapsed=0} end
function M.New()
    return {main=Tween(1),trail=Tween(1),bar=Tween(0),letter=Tween(0),prompt=Tween(0),kneel=Tween(0),ult=Tween(0),kneelAge=0}
end
local function Step(tween,target,dt,duration,delay,curve)
    if tween.target~=target then tween.start=tween.value;tween.target=target;tween.elapsed=0 end
    tween.elapsed=tween.elapsed+math.max(0,dt)
    local progress=math.max(0,math.min(1,(tween.elapsed-(delay or 0))/duration))
    local easing='ease';if curve==false then easing=nil elseif curve then easing=curve end
    tween.value=tween.start+(target-tween.start)*Ease(progress,easing)
end
function M.Update(state,dt,snapshot)
    local hp=math.max(0,math.min(1,snapshot.hp or 0))
    Step(state.main,hp,dt,.15);Step(state.trail,hp,dt,.8,.25)
    Step(state.bar,snapshot.shown and 1 or 0,dt,.4)
    Step(state.letter,snapshot.cinematic and 1 or 0,dt,.5,0,false)
    Step(state.prompt,snapshot.cinematic and 1 or 0,dt,.4,.6)
    if snapshot.kneel then state.kneelAge=state.wasKneeling and state.kneelAge+dt or 0 else state.kneelAge=0 end
    state.wasKneeling=snapshot.kneel==true
    Step(state.kneel,snapshot.kneel and 1 or 0,dt,.2)
    Step(state.ult,snapshot.ult and 1 or 0,dt,.4)
    if snapshot.ult then state.lastUlt=snapshot.ult end
end
function M.Boom(age)
    local fade=1-Ease(math.max(0,math.min(1,age/.9)),'css-ease-out')
    -- fxBoom animates both element opacity and the white background alpha.
    return fade*fade
end
function M.Blink(age)
    local phase=(age%.5)/.5
    if phase<.5 then return 1-.65*math.floor(phase*4)/2 end
    return .35+.65*math.floor((phase-.5)*4)/2
end
return M
