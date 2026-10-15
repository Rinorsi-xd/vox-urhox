-- Frozen reticle.js ordinary unit marks: render-clock ghost and CSS states.
local M={}
function M.New() return setmetatable({},{__mode='k'}) end
function M.Ghost(states,ref,hp,now)
    if not ref then return hp end
    local g=states[ref]
    if not g then g={v=hp,last=hp,t=0,at=now};states[ref]=g end
    if hp<g.last-1e-4 then g.t=now end
    if hp>=g.v then g.v=hp
    elseif now-g.t>400 then g.v=math.max(hp,g.v-(now-g.at)*.0012) end
    g.last=hp;g.at=now
    return g.v
end
function M.Read(states,mark,now)
    local hp=math.max(0,math.min(1,mark.health==nil and 1 or mark.health))
    local low=mark.enemy and hp<.3
    return hp,M.Ghost(states,mark.unit or mark.ref,hp,now),low,low and math.floor(now/220)%2~=0
end
function M.Segment(i,hp,ghost)
    local c=(i+.5)/10
    return c<=hp and 'live' or c<=ghost and 'lost' or 'bg'
end
function M.Point(unit)
    local p=unit:Position();if not p then return end
    return {p[1],p[2]+unit.spec.bounds.max[2]-unit.vehicle.com[2]+1.2,p[3]}
end
return M
