-- RenderSurface keeps a raw parentTexture pointer in Runtime 20260923.
-- Its Lua wrapper can outlive Texture:Dispose(), then dereference freed memory
-- during __gc. Collect borrowed surfaces while their parent is still alive.
local M={}
local CollectionCycle=require 'core.CollectionCycle'
local pending={}
local fences={}
local cleared={}
local frames=0
local function ReleaseFinalized(collected)
    for texture,weakSurface in pairs(pending) do
        -- An external borrower may still hold the surface. Keep its parent
        -- until the borrower really releases it; never invalidate that pointer.
        if weakSurface[1]==nil then
            if collected and collected[texture]==weakSurface or cleared[texture] and CollectionCycle.Epoch()>fences[texture] then
                pending[texture]=nil;fences[texture]=nil;cleared[texture]=nil
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
    surface:SetNumViewports(0)
    pending[texture]=setmetatable({surface},{__mode='v'})
    fences[texture]=CollectionCycle.Fence()
end
function M.PendingCount()
    local count=0;for _ in pairs(pending) do count=count+1 end;return count
end
return M
