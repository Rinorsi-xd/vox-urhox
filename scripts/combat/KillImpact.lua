-- Frozen testDrive.update/_hud: only confirmed player kills start this clock.
local M={}
function M.Confirm(session,target)
    if not target or not target.spec then return end
    session.hitStop=math.max(session.hitStop or 0,.08)
    session.fovPunch=math.max(session.fovPunch or 0,4)
    session.trauma=math.min(1,math.max(session.trauma or 0,.35))
    local player=session.combat and session.combat.player
    if not player then return end
    local count,alive=0,false
    for _,unit in ipairs(session.world.units) do
        if unit~=player and unit.team~=player.team and unit.team~='neutral' then
            count=count+1;alive=alive or unit.alive
        end
    end
    if count>0 and not alive then session.slowMo=.7 end
end
function M.Step(session,dt)
    if (session.hitStop or 0)>0 then
        session.hitStop=math.max(0,session.hitStop-dt)
        return dt*.06
    elseif (session.slowMo or 0)>0 then
        session.slowMo=math.max(0,session.slowMo-dt)
        return dt*(.3+.7*(1-session.slowMo/.7)^2)
    end
    return dt
end
return M
