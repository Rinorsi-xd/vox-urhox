-- Frozen drivingMix.js. Reuse five records across vehicles and frames.
local M={ids={'drive_idle','drive_load','track_loop','hover_loop','thruster_loop'}}
function M.New()
    local out={};for i,id in ipairs(M.ids) do out[i]={id=id,amount=0,pitch=1,pan=0} end;return out
end
function M.Fill(out,vehicle,command)
    local speed=math.abs(vehicle.speed or 0);local moving=math.min(1,speed/12)
    local wheel,track,hover=false,false,false
    for _,w in ipairs(vehicle.wheels) do if w.track then track=true else wheel=true end end
    for _,h in ipairs(vehicle.spec.hovers) do if h.works~=false then hover=true;break end end
    local thrust=0;for _,amount in pairs(vehicle.thrusterOutputs or {}) do thrust=math.max(thrust,amount) end
    out[1].amount=wheel and 1-moving*.55 or 0;out[1].pitch=.9+moving*.15
    out[2].amount=wheel and math.max(math.abs(command.throttle or 0)*.8,moving) or 0;out[2].pitch=.75+moving*.55
    out[3].amount=track and speed>.15 and math.min(1,.25+moving) or 0;out[3].pitch=.82+moving*.18
    out[4].amount=hover and not command.cutLift and (vehicle.telemetry.hoverForce or 0)>0 and .65+moving*.35 or 0;out[4].pitch=.95+moving*.12
    out[5].amount=math.sqrt(thrust);out[5].pitch=.92+thrust*.12
    return out
end
return M
