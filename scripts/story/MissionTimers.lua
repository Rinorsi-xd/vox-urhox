-- H5 choices and retries use setTimeout, independently of paused simulation.
---@class MissionTimers
---@field mission table|nil
---@field node Node|nil
---@field disposed boolean
local M={};M.__index=M
function M.New(mission)
    local self=setmetatable({},M);self:init(mission);return self
end
function M:init(mission)
    self.mission=mission;self.disposed=false
    self.node=Node()
    local receiver=self.node:CreateScriptObject('LuaScriptObject')
    assert(receiver,'Story timers require a native ScriptObject')
    receiver:SubscribeToEvent('Update',function() self:Update() end)
end
function M:Update()
    local mission=self.mission
    if self.disposed or not mission or mission.disposed or mission.reason then return end
    mission.rules:UpdateTimers()
    if #mission.rules.events>0 then mission:Events() end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.node then self.node:Dispose();self.node=nil end
    self.mission=nil
end
return M
