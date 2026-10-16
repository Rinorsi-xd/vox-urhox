-- The loading page must present before the old hall is released, and the
-- renderer must retire its references before new map resources are decoded.
local M={};M.__index=M
function M.New(release,sweep)
    return setmetatable({release=release,sweep=sweep,generation=0,stopped=false},M)
end
function M:Begin(enabled)
    assert(not self.stopped and not self.recovery,'Map transition is not available')
    self.generation=self.generation+1
    local token={generation=self.generation,state=enabled and 'cover' or 'ready',released=false}
    self.current=token
    return token
end
function M:IsCurrent(token) return not self.stopped and self.current==token end
function M:IsLatest(token) return not self.stopped and token.generation==self.generation end
function M:CanStart(covered,pageFrames,backgroundIdle)
    if self.stopped or not covered then return false end
    local token=self.current or self.recovery
    if not token then return true end
    if token.state=='ready' or token.state=='restore-ready' then return true end
    if token.state=='recovery' then return false end
    if token.state=='cover' then
        -- Mark ownership transferred before disposal, so a partial failure
        -- still restores the hall instead of trying to reuse disposed nodes.
        token.released=true;token.state='retiring';token.fenceAt=pageFrames
        local ok,message=pcall(self.release)
        if not ok then return false,tostring(message) end
        print('[WebMapTransition] Hall released; waiting for presented frames')
        return false
    end
    if token.state=='restore' and not token.fenceAt then token.fenceAt=pageFrames end
    if not token.fenceAt or pageFrames-token.fenceAt<3 or not backgroundIdle then return false end
    local ok,message=pcall(self.sweep)
    if not ok then return false,tostring(message) end
    if message==false then return false end
    token.state=token.state=='restore' and 'restore-ready' or 'ready'
    print('[WebMapTransition] Resource retirement settled; '..token.state)
    return true
end
function M:Cancel(token)
    if not self:IsCurrent(token) then return false end
    self.current=nil;token.state='cancelled'
    if token.released then token.state='recovery';self.recovery=token end
    return token.released
end
function M:Commit(token)
    if not self:IsCurrent(token) then return false end
    self.current=nil;token.state='committed'
    return true
end
function M:BeginRecovery()
    local token=self.recovery
    if self.stopped or not token or token.state~='recovery' then return false end
    token.state='restore';token.fenceAt=nil
    return true
end
function M:IsRestoring() return not self.stopped and self.recovery~=nil end
function M:PrepareRecovery()
    if self:IsRestoring() then self.recovery.state='restore';self.recovery.fenceAt=nil end
end
function M:Restored() self.recovery=nil end
function M:Stop() self.stopped=true;self.current=nil;self.recovery=nil end
function M:Snapshot()
    local token=self.current or self.recovery
    return token and {generation=token.generation,state=token.state,released=token.released,fenceAt=token.fenceAt} or {state='idle'}
end
return M
