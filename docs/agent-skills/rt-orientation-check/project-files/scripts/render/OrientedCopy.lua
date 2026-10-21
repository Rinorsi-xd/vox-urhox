-- One-shot GPU copy of a camera-rendered snapshot into a target that NanoVG
-- shows upright on this device (see OrientedCopy.shader). Nothing is read back
-- on the CPU, so it also works on WebGPU. The copy waits until render.OrientationMap
-- has repainted its map after the request, then renders once and stays static.
local OrientationMap=require 'render.OrientationMap'
---@class OrientedCopy
---@field source Texture2D
---@field texture Texture2D|nil
---@field scene Scene|nil
---@field material Material|nil
---@field start integer
---@field queued integer|nil
---@field done Texture2D|nil
---@field disposed boolean|nil
local M={};M.__index=M
local TIMEOUT=60 -- frames to wait for the orientation map before keeping the source as is
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
local function Frame() return time.frameNumber end
--- How a discarded copy target is released. Replace with the project's deferred
--- release if its runtime lets RenderSurface wrappers outlive their texture.
---@param texture Texture2D
function M.Retire(texture)
    local surface=texture:GetRenderSurface();if surface then surface:SetNumViewports(0) end
    texture:Dispose()
end
---@param source Texture2D
---@return OrientedCopy
function M.New(source)
    local self=setmetatable({source=source,start=Frame()},M)
    local ok,err=pcall(function()
        local scene=Scene();self.scene=scene;scene:CreateComponent('Octree')
        local camera=scene:CreateChild('CopyCamera'):CreateComponent('Camera');camera.node.position=Vector3(0,0,-2)
        camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
        local geometry=scene:CreateChild('CopyQuad'):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
        for _,v in ipairs(vertices) do geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4])) end
        geometry:Commit()
        local material=Material:new();self.material=material
        assert(material:SetSurfaceShader(OrientationMap.SHADER_DIR..'OrientedCopy.shader'),'Cannot load oriented copy shader')
        assert(material:SetSurfaceTexture('source_map',source))
        assert(OrientationMap.Bind(material,true),'Orientation map or sentinel unavailable')
        geometry:SetMaterial(material)
        local xml=XMLFile:new();assert(xml:FromString('<renderpath><command type="clear" color="0 0 0 1" depth="1"/><command type="scenepass" pass="base" vertexlights="false"/></renderpath>'))
        local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
        local texture=Texture2D:new();self.texture=texture;texture:SetNumLevels(1)
        assert(texture:SetSize(source:GetWidth(),source:GetHeight(),Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'Cannot allocate oriented snapshot')
        texture:SetFilterMode(FILTER_BILINEAR);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        local viewport=Viewport:new(scene,camera);viewport:SetRenderPath(path)
        local surface=texture:GetRenderSurface();surface:SetViewport(0,viewport);surface.updateMode=SURFACE_MANUALUPDATE
    end)
    if not ok then print('[OrientedCopy] unavailable '..tostring(err));self:Release();self.done=source end
    return self
end
-- Drop the copy pass; keep the copied target only when it is the result.
---@param keep boolean|nil
function M:Release(keep)
    local texture=self.texture
    if texture then
        texture:GetRenderSurface():SetNumViewports(0)
        if not keep then M.Retire(texture);self.texture=nil end
    end
    if self.scene then self.scene:Dispose();self.scene=nil end
    if self.material then self.material:Dispose();self.material=nil end
end
--- Advance once per frame. Returns the texture to show when finished (the oriented
--- copy, or the untouched source if orientation could not be determined), else nil.
---@return Texture2D|nil
function M:Step()
    if self.disposed then return nil end
    if self.done then return self.done end
    local frame=Frame()
    if not self.queued then
        OrientationMap.Request()
        if OrientationMap.PaintedAfter(self.start) then
            assert(self.texture):GetRenderSurface():QueueUpdate();self.queued=frame
        elseif frame-self.start>TIMEOUT then
            print('[OrientedCopy] orientation map never painted; showing the snapshot unflipped')
            self:Release();self.done=self.source
        end
        return self.done
    end
    if frame<self.queued+2 then return nil end
    self:Release(true);self.done=self.texture
    return self.done
end
--- Retire the copy (never the source, which its owner disposes).
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self:Release();self.done=nil
end
return M
