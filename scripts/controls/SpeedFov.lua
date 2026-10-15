-- Frozen speedFov/combatSpeed: horizontal motion, not signed forward/fall speed.
local Math=require 'core.Math3'
local M={};M.__index=M
function M.New() local self=setmetatable({},M);self:Reset();return self end
function M:Reset() self.speed=0;self.peak=10;self.scopeT=nil end
function M:Step(vehicle,dt,base,current,options)
    local o=options or {};local body=vehicle.body;local v=body and body.linvel()
    local speed=v and math.sqrt(v.x*v.x+v.z*v.z) or math.abs(vehicle.speed or 0)
    self.peak=math.max(speed,self.peak*math.exp(-dt*.02),10)
    self.speed=self.speed+(speed-self.speed)*(1-math.exp(-dt*3))
    local motion=vehicle.spec and vehicle.spec.motion or {};local telemetry=vehicle.telemetry or {}
    local feet=vehicle.mechMode or vehicle.mechControl or vehicle.legMode
    local top=feet and (telemetry.legSpeedLimit or motion.topSpeed) or math.max(motion.topSpeed or 0,motion.thrusterSpeed or 0)
    if not top or top<=0 then top=self.peak end
    local rel=Math.Clamp((self.speed/top-.55)/.45,0,1)
    local want=o.scope or (base+12*rel*rel*(3-2*rel)+(o.rush or 0)*28-(o.charge or 0)*3+(o.punch or 0))
    local scoped=o.scope~=nil
    local smooth=(want-current)*(1-math.exp(-dt*((scoped or (self.scopeT or 0)>0) and 16 or 4)))
    self.scopeT=scoped and .5 or math.max(0,(self.scopeT or 0)-dt)
    local limit=self.scopeT>0 and 240*dt or 18*dt*((want<current and not scoped) and .5 or 1)
    return current+Math.Clamp(smooth,-limit,limit)
end
return M
