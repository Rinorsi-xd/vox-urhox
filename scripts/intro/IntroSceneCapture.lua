-- Freeze a scene into a GPU texture without reading the UI/backbuffer to CPU.
local Lifetime=require 'render.RenderTargetLifetime'
local M={};M.__index=M
function M.New(scene,camera)
 local self=setmetatable({frames=0},M)
 local ok,err=pcall(function()
  local screenW,screenH=math.max(1,graphics:GetWidth()),math.max(1,graphics:GetHeight())
  local width=math.min(1280,screenW);local height=math.max(1,math.floor(width*screenH/screenW+.5))
  self.node=scene:CreateChild('OpeningComicCamera')
  self.node.position=camera.node.worldPosition;self.node.rotation=camera.node.worldRotation
  local capture=self.node:CreateComponent('Camera');self.camera=capture
  capture.fov=camera.fov;capture.nearClip=camera.nearClip;capture.farClip=camera.farClip
  capture.autoAspectRatio=false;capture.aspectRatio=width/height
  local texture=Texture2D:new();self.texture=texture;texture:SetNumLevels(1)
  assert(texture:SetSize(width,height,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate opening comic capture')
  texture:SetFilterMode(FILTER_BILINEAR)
  local viewport=Viewport:new(scene,capture);self.viewport=viewport
  viewport:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
  local surface=texture:GetRenderSurface();surface:SetViewport(0,viewport)
  surface:SetUpdateMode(SURFACE_MANUALUPDATE);surface:QueueUpdate()
 end)
 if not ok then self:Dispose();error(err) end
 return self
end
function M:Detach()
 if self.texture then local surface=self.texture:GetRenderSurface();if surface then surface:SetNumViewports(0) end end
 self.viewport=nil;self.camera=nil
 if self.node then self.node:Dispose();self.node=nil end
end
function M:Presented()
 if self.disposed then return false end
 if self.ready then return true end
 self.frames=self.frames+1
 if self.frames<3 then self.texture:GetRenderSurface():QueueUpdate();return false end
 self.ready=true;self:Detach();return true
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true
 self:Detach()
 if self.texture then Lifetime.Retire(self.texture);self.texture=nil end
end
return M
