-- Source Effects._light: one shared transient light for the whole battle.
-- Presentation only; no per-shot nodes, shadows, timers or simulation writes.
local Coord=require 'core.Coord'
local Config=require 'Config'
local M={};M.__index=M
function M.New(root)
    local self=setmetatable({},M);self:init(root);return self
end
function M:init(root)
    self.node=root:CreateChild('CombatFlashLight')
    self.light=self.node:CreateComponent('Light');self.light.lightType=LIGHT_POINT
    self.light.range=22;self.light.castShadows=false;self.light.useTemperature=false
    self.light.color=Config.HexLinear(0xffa050)
    self.intensity=0;self.decay=18;self.disposed=false;self:Clear()
end
function M:Emit(pos,intensity,color,decay,smooth)
    if self.disposed or intensity<self.intensity*.6 then return false end
    local target=Coord.Vec(pos[1],pos[2],pos[3])
    if smooth and smooth>0 and self.intensity>.5 then
        self.node.position=self.node.position:Lerp(target,1-smooth)
    else self.node.position=target end
    self.light.color=Config.HexLinear(color or 0xffa050)
    self.intensity=intensity;self.decay=decay or 18
    return true
end
function M:Update(dt)
    if self.disposed then return end
    self.intensity=self.intensity*math.exp(-dt*self.decay)
    local brightness=self.intensity>=.5 and self.intensity or 0
    self.light.brightness=brightness;self.light.enabled=brightness>0
end
function M:Clear()
    self.intensity=0;self.decay=18
    self.light.brightness=0;self.light.enabled=false
end
function M:Dispose()
    if self.disposed then return end
    self:Clear();self.disposed=true;self.node:Dispose()
end
return M
