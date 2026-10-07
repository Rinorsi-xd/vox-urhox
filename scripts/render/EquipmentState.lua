-- Source ThrusterRig display state, deliberately independent of native objects.
local V=require "core.Math3"
local M={}
function M.Power(current,target,dt)
    local result=current+(V.Clamp(target,0,1)-current)*(1-math.exp(-dt*(target>current and 18 or 24)))
    return result<.002 and 0 or result
end
function M.Jet(info,nozzle,power,time,seed)
    local bell=info.family=='pod' and info.tier==5 and 2 or 1.45
    local root=math.sqrt(power)
    return {radius=nozzle.radius*bell,
        length=nozzle.radius*(5.6+info.tier*.2)*(bell/1.45)*(.2+.8*root)*(1+.022*math.sin(time*23+seed*30)),
        power=root*(.975+.025*math.sin(time*19+seed*20))}
end
return M
