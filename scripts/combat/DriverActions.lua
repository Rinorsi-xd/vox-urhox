-- Source sessions apply recovery before stepping the vehicle and firing.
local M={}
function M.Apply(unit,info)
    if not info then return end
    local v=unit.vehicle
    if info.reset then v:Place(info.reset.pos,info.reset.yaw) end
    if info.flip then
        local p=v.body.translation()
        v:Place({p.x,p.y+v.spec.bounds.radius*.6,p.z},v:Yaw())
    end
end
return M
