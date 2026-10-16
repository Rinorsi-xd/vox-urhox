-- GC completion is shared: one consumer can finish a cycle for another.
-- Lua 5.4 generational steps do not reliably report cycle completion.
local M={}
local epoch=0
local previousMode=false
local stepping=false
local restoreRequested=false
function M.Epoch() return epoch end
function M.Fence()
    -- Owners dropped mid-cycle may already be marked; wait one more cycle.
    return epoch+((previousMode or stepping) and 1 or 0)
end
function M.Restore()
    if stepping then restoreRequested=true;return end
    local mode=previousMode
    if mode then
        -- Switching collector mode can itself run finalizers.
        stepping=true
        local ok,err=pcall(collectgarbage,mode)
        stepping=false
        if not ok then error(err,0) end
        previousMode=false
    end
    restoreRequested=false
end
function M.Step(size)
    if stepping then return false end
    stepping=true
    local ok,completed=pcall(function()
        if not previousMode then previousMode=collectgarbage('incremental') end
        return collectgarbage('step',size or 128)
    end)
    stepping=false
    if not ok then M.Restore();error(completed,0) end
    if completed then epoch=epoch+1 end
    if completed or restoreRequested then M.Restore() end
    return completed
end
function M.Collect()
    if stepping then return false end
    M.Restore()
    stepping=true
    local ok,err=pcall(collectgarbage,'collect')
    stepping=false
    if not ok then error(err,0) end
    epoch=epoch+1
    if restoreRequested then M.Restore() end
    return true
end
function M.State()
    return {epoch=epoch,active=previousMode~=false,previousMode=previousMode,stepping=stepping,restoreRequested=restoreRequested}
end
return M
