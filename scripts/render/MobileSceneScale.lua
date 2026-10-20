-- 手机端战斗场景降分辨率渲染：3D 场景按「CSS 像素 × 倍率」画进离屏目标，再拉伸到屏幕；
-- 界面（NanoVG）仍按原生分辨率绘制，字和按钮不糊。手机 WebGL 的画面几乎完全受像素填充率限制，
-- 渲染像素数直接决定 GPU 耗时。只由 GraphicsSettings 在触屏战斗场景里创建。
local Graph=require 'render.FilterGraph'
local PortraitCheck=require 'render.PortraitCheck'
---@class MobileSceneScale
---@field graph table|nil
---@field level string
---@field width integer
---@field height integer
local M={};M.__index=M
-- 相对 CSS 像素的倍率；native 表示不缩放（不创建本对象）。
M.levels={low=1,medium=1.25,high=1.6}
M.order={'low','medium','high','native'}
M.default='medium'
local shader='Shaders/BLGL/UI/SceneUpscale.shader'
function M.Size(level)
    local pw,ph=math.max(1,graphics:GetWidth()),math.max(1,graphics:GetHeight())
    local k=M.levels[level] or M.levels[M.default]
    local scale=math.min(1,k/math.max(1,graphics:GetDPR()))
    return math.max(1,math.floor(pw*scale+.5)),math.max(1,math.floor(ph*scale+.5)),scale
end
--- 该档位在当前屏幕上是否真的缩小了（DPR 不高的设备上可能等于原生）。
function M.Reduces(level)
    if not M.levels[level] then return false end
    local _,_,scale=M.Size(level);return scale<.999
end
local fallback
local function Fallback()
    if fallback then return fallback end
    local image=Image:new();image:SetSize(1,1,4);image:SetPixel(0,0,Color(0,0,0,0))
    local texture=Texture2D:new();texture:SetNumLevels(1);assert(texture:SetData(image),'Scene upscale fallback texture failed');image:Dispose()
    fallback=texture;return fallback
end
function M.New(scene,camera,level)
    local self=setmetatable({scene=scene,camera=camera,level=level,frames=0},M)
    self.source=Viewport:new(scene,camera)
    local ok,err=pcall(self.Rebuild,self)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Rebuild()
    local w,h=M.Size(self.level)
    local graph=Graph.New({{viewport=self.source,width=w,height=h},{shader=shader,inputs={source_map=1}}},w,h)
    -- 设备上读渲染目标是否上下颠倒，交给 GPU 现场判断（不做 CPU 读回，WebGPU 同样适用）
    local sentinel=PortraitCheck.Request();self.sentinel=sentinel~=nil
    assert(graph.materials[2]:SetSurfaceTexture('sentinel_map',sentinel or Fallback()),'Scene upscale sentinel binding failed')
    local previous=self.graph;self.graph=graph;self.width=w;self.height=h;self.output=graph.output;self.frames=0
    if previous then previous:Dispose() end
    print(string.format('[MobileSceneScale] %s %dx%d of %dx%d (dpr %.2f)',self.level,w,h,graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR()))
    return true
end
--- 每帧调用：屏幕尺寸变了就重建，并排队渲染场景目标。返回 true 表示输出视口换了。
function M:Update()
    if not self.graph then return false end
    local changed=false
    local w,h=M.Size(self.level)
    if w~=self.width or h~=self.height then self:Rebuild();changed=true end
    -- 哨兵目标创建后要隔几帧才画好，前几帧再请求一次，保证判定用的是画好的结果
    self.frames=self.frames+1
    if self.sentinel and self.frames==3 then PortraitCheck.Request() end
    self.graph:Queue()
    return changed
end
function M:Dispose()
    if self.graph then self.graph:Dispose();self.graph=nil end
    self.output=nil;self.source=nil;self.scene=nil;self.camera=nil
end
return M
