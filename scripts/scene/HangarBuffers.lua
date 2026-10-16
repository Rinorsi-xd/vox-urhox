-- Transient half-resolution reflection; environment meshes are stored in assets.
local WindowViewports=require("render.WindowViewports")
local ReflectionFilter=require("render.ReflectionFilter")
local RenderTargetLifetime=require("render.RenderTargetLifetime")

local REFLECTOR_MASK=2
local Quality=require "render.Quality"
local Garage={}
function Garage:BuildReflection()
    self.reflNode = self.scene:CreateChild("ReflectionCamera")
    local cam = self.reflNode:CreateComponent("Camera") --[[@as Camera]]
    local plane = Plane(Vector3.UP, Vector3(0, 0, 0))
    cam.useReflection = true
    cam.reflectionPlane = plane
    cam.useClipping = true
    cam.clipPlane = plane
    cam.viewMask = 0xffffffff & ~REFLECTOR_MASK
    cam.nearClip = 0.05
    cam.farClip = 120
    cam.autoAspectRatio = false
    self.reflCam = cam
    self:ResizeReflection()
end

--- 反射贴图跟随窗口尺寸（半分辨率）
function Garage:ResizeReflection(cam)
    local quality=Quality.current
    local width,height=graphics:GetWidth(),graphics:GetHeight()
    local viewport=WindowViewports.Get(0)
    if self.renderSize then width,height=self.renderSize[1],self.renderSize[2]
    elseif cam and viewport and viewport.camera==cam then
        local rect=viewport.rect
        if rect.right>rect.left and rect.bottom>rect.top then width=rect.right-rect.left;height=rect.bottom-rect.top end
    elseif cam then
        width=math.max(16,math.floor(height*cam.aspectRatio))
    end
    self.reflAspect=width/math.max(1,height)
    local scale=math.min(quality.reflectionScale,quality.reflectionMax/math.max(1,width,height))
    local w = math.max(16, math.floor(width*scale))
    local h = math.max(16, math.floor(height*scale))
    if w == self.reflW and h == self.reflH then return end
    local tex = Texture2D:new()
    tex:SetNumLevels(1)
    if not tex:SetSize(w, h, Graphics:GetRGBAFloat16Format(), TEXTURE_RENDERTARGET) then tex:Dispose();error('Cannot allocate hangar reflection') end
    tex.filterMode = FILTER_BILINEAR
    tex:SetAddressMode(COORD_U, ADDRESS_CLAMP)
    tex:SetAddressMode(COORD_V, ADDRESS_CLAMP)
    local surface = tex.renderSurface
    local vp = Viewport:new(self.scene, self.reflCam)
    surface:SetViewport(0, vp)
    surface.updateMode = SURFACE_MANUALUPDATE
    surface:QueueUpdate()
    self.nextReflection=0
    local ok,filtered=pcall(ReflectionFilter.New,tex)
    if not ok then RenderTargetLifetime.Retire(tex);error(filtered) end
    local previous,previousFilter=self.reflTex,self.reflFilter
    self.reflTex = tex
    self.reflFilter=filtered
    self.reflW, self.reflH = w, h
    for _, m in ipairs(self.reflMats) do filtered:Bind(m) end
    filtered:Queue()
    if previousFilter then previousFilter:Dispose() end
    if previous then RenderTargetLifetime.Retire(previous) end
end


return Garage
