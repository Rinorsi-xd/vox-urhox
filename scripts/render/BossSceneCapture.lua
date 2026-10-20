-- Capture the final 3D viewport, before NanoVG, without a backbuffer readback.
local Lifetime=require 'render.RenderTargetLifetime'
local OrientedCopy=require 'render.OrientedCopy'
local M={};M.__index=M
function M.New(viewport)
    assert(viewport,'Missing boss capture viewport')
    local self=setmetatable({frames=0},M)
    local ok,err=pcall(function()
        local w,h=math.max(1,graphics:GetWidth()),math.max(1,graphics:GetHeight())
        local width=math.min(1280,w);local height=math.max(1,math.floor(width*h/w+.5))
        self.texture=Texture2D:new();self.texture:SetNumLevels(1)
        assert(self.texture:SetSize(width,height,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate boss comic capture')
        self.texture:SetFilterMode(FILTER_BILINEAR)
        local surface=self.texture:GetRenderSurface();surface:SetViewport(0,viewport)
        surface:SetUpdateMode(SURFACE_MANUALUPDATE);surface:QueueUpdate()
    end)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Detach()
    if self.texture then self.texture:GetRenderSurface():SetNumViewports(0) end
end
function M:Presented()
    if self.disposed then return false end
    if self.ready then return true end
    self.frames=self.frames+1
    if self.frames<3 then self.texture:GetRenderSurface():QueueUpdate();return false end
    if not self.copy then self:Detach();self.copy=OrientedCopy.New(self.texture) end
    -- NanoVG shows render targets upside down on some devices; swap in the GPU-corrected copy.
    local shown=self.copy:Step();if not shown then return false end
    if shown~=self.texture then Lifetime.Retire(self.texture);self.texture=shown end
    self.copy=nil;self.ready=true;return true
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self:Detach()
    if self.copy then self.copy:Dispose();self.copy=nil end
    if self.texture then Lifetime.Retire(self.texture);self.texture=nil end
end
return M
