-- GC completion is shared: one consumer can finish a cycle for another.
-- Lua 5.4 generational steps do not reliably report cycle completion.
local M={}
local epoch=0
local previousMode=false
local stepping=false
local restoreRequested=false
-- 诊断日志（只在模式切换/完整回收时打一行，不影响回收逻辑）：谁触发、在什么模式下、堆多大、停了多久
local enteredAt=nil
local function Now() return Time:GetSystemTime() end
-- 第一个不在本模块里的 Lua 调用者（跳过 pcall 等 C 帧）
local function Caller()
    if not debug or not debug.getinfo then return '?' end
    local out={}
    for level=3,14 do
        local info=debug.getinfo(level,'Sl')
        if not info then break end
        local src=info.short_src or ''
        -- 跳过本模块、性能监控的计时包装和 C 帧
        if info.what~='C' and not src:find('CollectionCycle') and not src:find('PerformanceMonitor') then
            out[#out+1]=(src:gsub('^.*/',''))..':'..tostring(info.currentline or 0)
            if #out==2 then break end
        end
    end
    return #out>0 and table.concat(out,' < ') or '?'
end
local function Log(message)
    print(string.format('[GC] %s epoch=%d heap=%.1fMB',message,epoch,collectgarbage('count')/1024))
end
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
        Log(string.format('restore %s after %.1fs in incremental',tostring(mode),enteredAt and ((Now()-enteredAt)%4294967296)/1000 or -1))
        enteredAt=nil
    end
    restoreRequested=false
end
-- Keep mode entry and the actual collector step separately measurable.
function M.EnterIncremental()
    if not previousMode then
        previousMode=collectgarbage('incremental');enteredAt=Now()
        Log('enter incremental (was '..tostring(previousMode)..') by '..Caller())
    end
end
function M.Advance(size)
    return collectgarbage('step',size or 128)
end
function M.Step(size)
    if stepping then return false end
    stepping=true
    local ok,completed=pcall(function()
        M.EnterIncremental()
        return M.Advance(size)
    end)
    stepping=false
    if not ok then M.Restore();error(completed,0) end
    if completed then epoch=epoch+1;Log('cycle completed by step') end
    if completed or restoreRequested then M.Restore() end
    return completed
end
function M.Collect()
    if stepping then return false end
    M.Restore()
    stepping=true
    local before,started=collectgarbage('count'),Now()
    local ok,err=pcall(collectgarbage,'collect')
    stepping=false
    if not ok then error(err,0) end
    epoch=epoch+1
    Log(string.format('full collect by %s %dms freed=%.1fMB',Caller(),(Now()-started)%4294967296,(before-collectgarbage('count'))/1024))
    if restoreRequested then M.Restore() end
    return true
end
function M.State()
    return {epoch=epoch,active=previousMode~=false,previousMode=previousMode,stepping=stepping,restoreRequested=restoreRequested}
end
return M
