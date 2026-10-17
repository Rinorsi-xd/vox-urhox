-- Probe the real weapon mechanics without moving the live turret or spending energy.
local V=require 'core.Math3'
local M={}
local fields={'pivot','quat','stats','range','off','offs','muzzle','dir','barrel','mphase'}
function M.New(system,vehicle)
    local probes=setmetatable({},{__mode='k'})
    local state={pos={0,0,0},quat={x=0,y=0,z=0,w=1}}
    return function(point)
        local group=system:Group()
        if system.offline or not group then return false end
        local body=vehicle.body;local p=body.translation()
        state.pos[1]=p.x;state.pos[2]=p.y;state.pos[3]=p.z
        state.quat=body.rotation();state.aim=point
        for _,w in ipairs(group.weapons) do
            if w.pivot and not w.stats.homing and not w.stats.drill then
                local probe=probes[w]
                if not probe then probe={};probes[w]=probe end
                for _,key in ipairs(fields) do probe[key]=w[key] end
                probe.yaw=w.yaw;probe.pitch=w.pitch
                system:Aim(probe,1000000,state)
                if system:Aligned(probe) then
                    local muzzle=system:Muzzle(probe,state)
                    if V.Dot(V.Sub(point,muzzle.pos),muzzle.dir)>1e-4 then return true end
                end
            end
        end
        return false
    end
end
return M
