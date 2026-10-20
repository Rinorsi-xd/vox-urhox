-- Bounded premultiplied NanoVG group. The runtime image bridge treats textures
-- as straight alpha, so store coverage and opaque premultiplied RGB separately.
-- Composite coverage first, then RGB additively without changing alpha.
local RenderTargetLifetime=require("render.RenderTargetLifetime")
local SourceDraw=require("ui.SourceDraw")

local M={};M.__index=M
function M.New(order,prepare,draw)
    local self=setmetatable({prepare=prepare,draw=draw,images={},renders=0,allocations=0},M)
    self.vg=assert(nvgCreate(1),'UI group context unavailable')
    nvgSetRenderOrder(self.vg,order);nvgSetColorSpace(self.vg,NVG_COLOR_GAMMA)
    -- 弹窗 / 浮层按 UI 的逻辑像素绘制到屏幕，手机小字下限同样适用
    SourceDraw.ScreenContext(self.vg)
    SubscribeToEvent(self.vg,'NanoVGRender',function() self:Render() end)
    return self
end
local function Rect(vg,x,y,w,h)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
end
function M:ReleaseTexture()
    for context,handles in pairs(self.images) do for _,handle in ipairs(handles) do nvgDeleteVideo(context,handle) end end
    self.images={}
    for _,key in ipairs({'texture','rgbTexture'}) do
        if self[key] then RenderTargetLifetime.Retire(self[key]);self[key]=nil end
    end
    self.ready=false;self.bytes=0
end
function M:Resize(width,height,scale)
    local pw,ph=math.ceil(width*scale),math.ceil(height*scale)
    if self.pw==pw and self.ph==ph and self.scale==scale and self.texture then return end
    self:ReleaseTexture()
    for _,key in ipairs({'texture','rgbTexture'}) do
        local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetSRGB(false)
        assert(texture:SetSize(pw,ph,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),'UI group texture allocation failed')
        texture:SetFilterMode(FILTER_BILINEAR);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        self[key]=texture
    end
    self.pw=pw;self.ph=ph;self.scale=scale;self.width=pw/scale;self.height=ph/scale
    self.bytes=pw*2*ph*4;self.allocations=self.allocations+1
end
function M:Render()
    if self.disposed then return end
    local rect,dirty=self.prepare()
    if not rect then return end
    self:Resize(rect.w,rect.h,rect.scale)
    if self.ready and dirty==false then return end
    local vg=self.vg;local w,h=self.width,self.height
    -- Mode B: logical CSS pixels with UI's scale as DPR; allocation rounds up.
    for copy=0,1 do
        nvgSetRenderTarget(vg,copy==0 and self.texture or self.rgbTexture)
        nvgBeginFrame(vg,w,h,self.scale)
        nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_COPY)
        Rect(vg,0,0,w,h);nvgFillColor(vg,nvgRGBA(0,0,0,0));nvgFill(vg);nvgRestore(vg)
        nvgSave(vg);nvgScissor(vg,0,0,w,h)
        self.draw(vg,rect)
        if copy==1 then
            nvgGlobalCompositeBlendFuncSeparate(vg,NVG_ZERO,NVG_ONE,NVG_ONE,NVG_ZERO)
            Rect(vg,0,0,w,h);nvgFillColor(vg,nvgRGBA(0,0,0,255));nvgFill(vg)
        end
        nvgRestore(vg);nvgEndFrame(vg)
    end
    self.ready=true;self.renders=self.renders+1
end
function M:Draw(vg,x,y,alpha)
    if not self.ready or not self.texture or alpha<=0 then return end
    local handles=self.images[vg]
    if not handles then
        handles={nvgCreateVideo(vg,self.texture),nvgCreateVideo(vg,self.rgbTexture)}
        assert(handles[1]>0 and handles[2]>0,'UI group image unavailable');self.images[vg]=handles
    end
    local w,h=self.width,self.height
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    Rect(vg,x,y,w,h)
    nvgFillPaint(vg,nvgImagePatternTinted(vg,x,y,w,h,0,handles[1],nvgRGBA(0,0,0,255)));nvgFill(vg)
    nvgGlobalCompositeBlendFuncSeparate(vg,NVG_ONE,NVG_ONE,NVG_ZERO,NVG_ONE)
    Rect(vg,x,y,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,handles[2],1));nvgFill(vg);nvgRestore(vg)
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self:ReleaseTexture()
    UnsubscribeFromEvent(self.vg,'NanoVGRender');nvgDelete(self.vg);self.vg=nil
    self.prepare=nil;self.draw=nil
end
return M
