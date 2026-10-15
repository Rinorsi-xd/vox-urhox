-- RenderSurface keeps a raw parentTexture pointer in Runtime 20260923.
-- Its Lua wrapper can outlive Texture:Dispose(), then dereference freed memory
-- during __gc. Collect borrowed surfaces while their parent is still alive.
local M={}
local pending={}
local frames=0
function M.Flush()
    if not next(pending) then return end
    collectgarbage('collect')
    for texture,weakSurface in pairs(pending) do
        -- An external borrower may still hold the surface. Keep its parent
        -- until the borrower really releases it; never invalidate that pointer.
        if weakSurface[1]==nil then
            pending[texture]=nil
            texture:Dispose()
        end
    end
end
function M.Update()
    if not next(pending) then return end
    frames=frames+1
    if frames>=3 then frames=0;M.Flush() end
end
function M.Retire(texture)
    if not texture or pending[texture] then return end
    local surface=texture:GetRenderSurface()
    if not surface then texture:Dispose();return end
    surface:SetNumViewports(0)
    pending[texture]=setmetatable({surface},{__mode='v'})
end
function M.PendingCount()
    local count=0;for _ in pairs(pending) do count=count+1 end;return count
end
return M
