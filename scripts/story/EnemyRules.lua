-- Frozen storyMission._doomed. Hull damage threshold applies only without shared hull HP.
local M={}
function M.Doom(spec,hullEnabled,health,flee,boss)
    local disarmed=not spec or not spec.weapons or #spec.weapons==0
    local stuck=spec and spec.motion and(spec.motion.load==0 or spec.motion.topSpeed==0) or false
    if flee then return(disarmed or stuck) and 'flee' or nil end
    local low=not hullEnabled and health<(boss and .35 or .55)
    return(disarmed or stuck or low) and 'destroy' or nil
end
return M
