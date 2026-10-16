-- Source setTimeout uses wall time, including while the Boss simulation is paused.
---@class BossExposedDelay
---@field boss table|nil
---@field at number
---@field node Node|nil
---@field disposed boolean
local M={};M.__index=M
function M.New(boss)
    local self=setmetatable({},M);self:init(boss);return self
end
function M:init(boss)
    self.boss=boss;self.at=Time:GetSystemTime()+2600;self.disposed=false
    self.node=Node()
    local receiver=self.node:CreateScriptObject('LuaScriptObject')
    assert(receiver,'Boss exposed timer requires a native ScriptObject')
    receiver:SubscribeToEvent('Update',function() self:Update() end)
end
function M:Update()
    if self.disposed or Time:GetSystemTime()<self.at then return end
    local boss=self.boss;self:Dispose()
    if boss and not boss.disposed and boss.mission and not boss.mission.disposed and not boss.mission.reason and boss.rules.hp>0 then
        boss:Say('exposed',true)
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.node then self.node:Dispose();self.node=nil end
    self.boss=nil
end
return M
