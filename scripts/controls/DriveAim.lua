local TouchPreferences=require("controls.TouchPreferences")
local AimAssist=require("combat.AimAssist")
local AimReach=require 'combat.AimReach'

local M={}
function M.Clear(s)
    s.aimReach=nil;s.aimReachVehicle=nil;s.aimReachSystem=nil
end
function M.Resolve(s,origin,direction,hit)
    local group=s.weapons:Group();local stats
    if not s.weapons.offline then for _,w in ipairs(group and group.weapons or {}) do if w.stats.assist then stats=w.stats;break end end end
    local player=s.combat and s.combat.player
    if not player then
        s.assistPlayer=s.assistPlayer or {team='player'};player=s.assistPlayer
        local p=s.vehicle.body.translation();player.pos={p.x,p.y,p.z};player.vehicle=s.vehicle
    end
    local prefs=TouchPreferences.Get(s.app)
    local wide=(s.scope and 1.8 or 1)*(s.touch and prefs.assist and 2.2 or 1)
    if not s.aimReach or s.aimReachVehicle~=s.vehicle or s.aimReachSystem~=s.weapons then
        s.aimReach=AimReach.New(s.weapons,s.vehicle)
        s.aimReachVehicle=s.vehicle;s.aimReachSystem=s.weapons
    end
    s.assist=AimAssist.Apply(origin,direction,hit,player,s.world.combatUnits or s.world.units,function(...) return s.world:CastRay(...) end,stats,wide,s.aimReach)
    s.aimRef=s.assist and s.assist.ref or hit and hit.owner and hit.owner.ref
    return s.assist and s.assist.point
end
function M.Look(s,dt)
    s.aimSlow=(s.aimSlow or 1)+((s.assist and s.assist.slow or 1)-(s.aimSlow or 1))*math.min(1,dt*10)
    local prefs=TouchPreferences.Get(s.app)
    if s.touch and prefs.assist and s.assist and s.assist.point and not s.scope then
        local p=s.camera:GetNode().worldPosition;local a=s.assist.point
        local dx,dy,dz=a[1]+p.x,a[2]-p.y,a[3]-p.z;local k=math.min(1,dt*3)
        local yaw=-math.atan(dx,dz)*180/math.pi
        local pitch=-math.atan(dy,math.sqrt(dx*dx+dz*dz))*180/math.pi
        s.yaw=s.yaw+((yaw-s.yaw+180)%360-180)*k;s.pitch=s.pitch+(pitch-s.pitch)*k
    end
    return s.aimSlow
end
function M.AutoFire(s)
    return s.touch and TouchPreferences.Get(s.app).autoFire and s.assist and s.assist.ref~=nil and not s.scope and s.pointer.captured and not s.dialog or false
end
return M
