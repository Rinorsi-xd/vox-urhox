-- Owns one pending home operation. Garage remains synchronous and transactional.
-- Navigation completes an accepted switch before handing the blueprint onward;
-- disposal cancels it, so no delayed callback can touch a retired scene or HUD.
local Lift=require 'scene.CarLift'
local CELL=require('Config').CELL
---@class HomeVehicleSwitch
---@field app HangarApp|nil
---@field lift CarLift
---@field pending table|nil
---@field disposed boolean
local M={};M.__index=M
function M.New(app,root) return setmetatable({app=app,lift=Lift.New(root),disposed=false},M) end
function M:Depth()
    local stats=self.app.blueprint:Stats()
    return stats.count>0 and stats.dims.H*CELL+.6 or 1.5
end
function M:Rest() return self.app.buildWanted and 0 or self.app:DisplayHeight() end
function M:IsBusy() return self.pending~=nil end
function M:Begin(action,done)
    if self.disposed or self.pending or self.app.buildWanted or self.app.mode~='hangar' or self.app.loader.state=='loading' then return false end
    self.pending={action=action,done=done}
    self.lift:Sink(self:Depth())
    return true
end
function M:Replaced()
    if self.disposed then return end
    -- A direct replacement supersedes any uncommitted home request.
    self.pending=nil
    if self.app.buildWanted then self.lift:Settle(0)
    else self.lift:Rise(self:Depth(),self:Rest()) end
    self.app.hangar:Welcome(self.app.blueprint)
end
function M:Commit()
    local request=self.pending;if not request then return end
    self.pending=nil
    local ran,ok,err,reason=pcall(request.action)
    if not ran then
        print('[HomeVehicleSwitch] Operation failed: '..tostring(ok))
        ok,err,reason=false,'换车失败，保留当前战车',nil
    end
    if not ok or not self.lift.anim then self:Replaced() end -- Recover old car, or a successful no-op.
    if request.done and not self.disposed then request.done(ok,err,reason) end
end
function M:Update(dt)
    if self.disposed then return end
    self.lift:Update(dt)
    if self.pending and not self.lift.anim then self:Commit() end
end
function M:Finish()
    if self.disposed then return end
    self:Commit()
    if self.disposed then return end
    self.lift:Settle(self:Rest())
end
function M:Dispose()
    self.pending=nil;self.disposed=true;self.lift:Dispose();self.app=nil
end
return M
