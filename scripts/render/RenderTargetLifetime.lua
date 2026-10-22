-- RenderSurface keeps a raw parentTexture pointer in Runtime 20260923.
-- Its Lua wrapper can outlive Texture:Dispose(), then dereference freed memory
-- during __gc. Collect borrowed surfaces while their parent is still alive.
local M={}
local CollectionCycle=require 'core.CollectionCycle'
local pending={}
local fences={}
local cleared={}
local frames=0
-- 诊断日志：每张贴图废弃/释放各打一行（谁废弃的、尺寸、等了多久、当前回收状态），不影响释放逻辑
local origins=setmetatable({},{__mode='k'})
local function Now() return Time:GetSystemTime() end
local function Callers()
    if not debug or not debug.getinfo then return '?' end
    local out={}
    for level=3,10 do
        local info=debug.getinfo(level,'Sl')
        if not info then break end
        local src=info.short_src or ''
        -- 跳过本模块、性能监控的计时包装和 C 帧
        if info.what~='C' and not src:find('RenderTargetLifetime') and not src:find('PerformanceMonitor') then
            out[#out+1]=(src:gsub('^.*/',''))..':'..tostring(info.currentline or 0)
            if #out==2 then break end
        end
    end
    return #out>0 and table.concat(out,' < ') or '?'
end
local function Log(message)
    local count=0;for _ in pairs(pending) do count=count+1 end
    local state=CollectionCycle.State()
    print(string.format('[RTL] %s pending=%d gc=%s epoch=%d',message,count,state.active and 'incremental' or 'normal',state.epoch))
end
local function Released(texture,how)
    local o=origins[texture]
    Log(string.format('released %s waited %.1fs (%s) from %s',o and o.size or '?',o and ((Now()-o.at)%4294967296)/1000 or -1,how,o and o.by or '?'))
    origins[texture]=nil
end
local function ReleaseFinalized(collected)
    for texture,weakSurface in pairs(pending) do
        -- An external borrower may still hold the surface. Keep its parent
        -- until the borrower really releases it; never invalidate that pointer.
        if weakSurface[1]==nil then
            if collected and collected[texture]==weakSurface or cleared[texture] and CollectionCycle.Epoch()>fences[texture] then
                pending[texture]=nil;fences[texture]=nil;cleared[texture]=nil
                Released(texture,collected and 'flush' or 'cycle')
                texture:Dispose()
            elseif not cleared[texture] then
                -- A borrower can survive earlier cycles. Fence when its weak
                -- reference clears, not just when its parent was retired.
                cleared[texture]=true;fences[texture]=CollectionCycle.Fence()
            end
        end
    end
end
function M.Flush()
    if not next(pending) then return end
    local collected={};for texture,weakSurface in pairs(pending) do collected[texture]=weakSurface end
    if not CollectionCycle.Collect() then return end
    ReleaseFinalized(collected)
end
function M.Update()
    if not next(pending) then return end
    frames=frames+1
    if frames<3 then return end
    frames=0
    -- Weak values clear before __gc. Only the completed cycle guarantees that
    -- borrowed RenderSurface finalizers have finished using their parent.
    ReleaseFinalized()
    if not next(pending) then return end
    CollectionCycle.Step(128)
    ReleaseFinalized()
end
function M.Retire(texture)
    if not texture or pending[texture] then return end
    local surface=texture:GetRenderSurface()
    if not surface then texture:Dispose();return end
    origins[texture]={at=Now(),by=Callers(),size=texture:GetWidth()..'x'..texture:GetHeight()}
    surface:SetNumViewports(0)
    pending[texture]=setmetatable({surface},{__mode='v'})
    fences[texture]=CollectionCycle.Fence()
    local o=origins[texture];Log('retire '..o.size..' by '..o.by)
end
function M.PendingCount()
    local count=0;for _ in pairs(pending) do count=count+1 end;return count
end
return M
