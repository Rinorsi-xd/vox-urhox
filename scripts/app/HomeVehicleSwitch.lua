-- Owns one pending home transaction. Assembly checkpoints yield only inside
-- its action coroutine; saving/rollback finish before the lift rises.
local ResourceGate=require("app.ResourceGate")

local Lift=require 'scene.CarLift'
local CELL=require('Config').CELL
---@class HomeVehicleSwitch
---@field app HangarApp|nil
---@field lift CarLift
---@field pending table|nil
---@field disposed boolean
local M={};M.__index=M
function M.New(app,root) return setmetatable({app=app,lift=Lift.New(root),disposed=false,gate=ResourceGate.New()},M) end
function M:Depth()
    local stats=self.app.blueprint:Stats()
    return stats.count>0 and stats.dims.H*CELL+.6 or 1.5
end
function M:Rest() return self.app.buildWanted and 0 or self.app:DisplayHeight() end
function M:IsBusy() return self.pending~=nil end
function M:IsAssembling() return self.job~=nil end
function M:AssemblyCheckpoint()
    local job=self.job
    if not job or coroutine.running()~=job then return nil end
    self.assemblyDepth=math.max(self.assemblyDepth or 0,self:Depth())
    self.lift:Settle(-self.assemblyDepth)
    return function(progress)
        assert(not self.disposed and self.job==job,'Retired vehicle assembly')
        self.pending.progress=progress
        if Time:GetSystemTime()-self.sliceStart>=3 then coroutine.yield() end
    end
end
function M:Begin(action,done,resources)
    if self.disposed or self.pending or self.app.buildWanted or self.app.mode~='hangar' or self.app.loader.state=='loading' then return false end
    local request={action=action,done=done,ready=false};self.pending=request
    self.gate:Start(resources or {},function(ok,message)
        if self.disposed or self.pending~=request then return end
        if not ok then self.pending=nil;if done then done(false,message) end;return end
        request.ready=true;self.lift:Sink(self:Depth())
    end)
    return true
end
function M:CancelDownload()
    if self.pending and not self.pending.ready then self.gate:Cancel();self.pending=nil;return true end
    return false
end
function M:Replaced()
    if self.disposed then return end
    if self.job and coroutine.running()==self.job then return end
    -- A direct replacement supersedes any uncommitted home request.
    if self.job then local job=self.job;self.job=nil;coroutine.close(job) end
    self.gate:Cancel();self.pending=nil
    if self.app.buildWanted then self.lift:Settle(0)
    else self.lift:Rise(self:Depth(),self:Rest()) end
    self.app.hangar:Welcome(self.app.blueprint)
end
function M:Commit()
    local request=self.pending;if not request or not request.ready then return end
    if not self.job then
        self.job=coroutine.create(function() return pcall(request.action) end)
        self.assemblyDepth=nil;self.assemblyFrames=0;self.maxAssemblyMs=0
    end
    local job=self.job;self.sliceStart=Time:GetSystemTime()
    local resumed,ran,ok,err,reason=coroutine.resume(job)
    self.assemblyFrames=self.assemblyFrames+1
    self.maxAssemblyMs=math.max(self.maxAssemblyMs,Time:GetSystemTime()-self.sliceStart)
    if self.disposed or self.job~=job then return end
    if resumed and coroutine.status(job)~='dead' then return end
    self.job=nil;self.pending=nil;self.assemblyDepth=nil
    if not resumed then ran,ok=false,ran end
    if not ran then
        print('[HomeVehicleSwitch] Operation failed: '..tostring(ok))
        ok,err,reason=false,'换车失败，保留当前战车',nil
    end
    if not ok or not self.lift.anim then self:Replaced() end
    if request.done and not self.disposed then request.done(ok,err,reason) end
end
function M:Update(dt)
    if self.disposed then return end
    self.lift:Update(dt)
    if self.job or self.pending and self.pending.ready and not self.lift.anim then self:Commit() end
end
function M:Finish()
    if self.disposed then return end
    if self.pending and not self.pending.ready then return false end
    self:Commit()
    if self.pending or self.job then return false end
    if self.disposed then return end
    self.lift:Settle(self:Rest())
    return true
end
function M:Dispose()
    self.gate:Cancel();self.pending=nil;self.disposed=true
    local job=self.job;self.job=nil
    if job and coroutine.running()~=job then coroutine.close(job) end
    self.lift:Dispose();self.app=nil
end
return M
