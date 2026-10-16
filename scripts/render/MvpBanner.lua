-- Fixed source canvas, rendered once per award; screen DPR does not resize it.
local RenderTargetLifetime=require("render.RenderTargetLifetime")

---@class MvpBanner
---@field chars string[]
local M={};M.__index=M
function M.New(name,material)
    local self=setmetatable({material=material},M)
    material:SetSurfaceTexture('shape_map',assert(cache:GetResource('Texture2D','Mvp/texture-3.png')))
    local chars={};for _,cp in utf8.codes(name or '机修师') do if #chars==8 then break end;chars[#chars+1]=utf8.char(cp) end
    self.chars=chars
    self.texture=Texture2D:new();self.texture:SetNumLevels(1);self.texture:SetSRGB(false)
    assert(self.texture:SetSize(640,1120,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET))
    self.texture:SetFilterMode(FILTER_BILINEAR);self.texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);self.texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    self.vg=assert(nvgCreate(1));nvgSetRenderTarget(self.vg,self.texture);nvgSetColorSpace(self.vg,NVG_COLOR_GAMMA)
    self.renders=0
    SubscribeToEvent(self.vg,'NanoVGRender',function()
        if self.bound or self.disposed then return end
        nvgBeginFrame(self.vg,640,1120,1)
        nvgSave(self.vg);nvgGlobalCompositeOperation(self.vg,NVG_COPY)
        nvgBeginPath(self.vg);nvgRect(self.vg,0,0,640,1120);nvgFillColor(self.vg,nvgRGBA(0,0,0,0));nvgFill(self.vg);nvgRestore(self.vg)
        self:Draw(self.vg);nvgEndFrame(self.vg)
        material:SetSurfaceTexture('albedo_map',self.texture)
        self.bound=true;self.renders=self.renders+1
    end)
    return self
end
function M:Draw(vg)
    if not self.image then
        self.image=nvgCreateImage(vg,'Mvp/texture-3.png',0);assert(self.image>0)
        assert(nvgCreateFont(vg,'mvp-name','Fonts/VoxIndustrial-Bold.otf')>=0)
    end
    nvgBeginPath(vg);nvgRect(vg,0,0,640,1120);nvgFillPaint(vg,nvgImagePattern(vg,0,0,640,1120,0,self.image,1));nvgFill(vg)
    local size=math.min(38,300/math.max(1,#self.chars));nvgFontFace(vg,'mvp-name');nvgFontSize(vg,size);nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    for i,ch in ipairs(self.chars) do
        local x,y=548,240+(i-1)*(size+4)
        nvgFillColor(vg,nvgRGBA(90,10,10,255))
        for j=0,7 do local a=j*math.pi/4;nvgText(vg,x+math.cos(a)*size*.045,y+size*.05+math.sin(a)*size*.045,ch) end
        -- Canvas's four-stop gold gradient, clipped to each glyph by NanoVG.
        nvgFillPaint(vg,nvgLinearGradient(vg,x,y-size/2,x,y+size/2,nvgRGBA(255,246,196,255),nvgRGBA(255,208,80,255)));nvgText(vg,x,y,ch)
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    UnsubscribeFromEvent(self.vg,'NanoVGRender')
    if self.image then nvgDeleteImage(self.vg,self.image) end
    nvgDelete(self.vg);self.vg=nil
    RenderTargetLifetime.Retire(self.texture);self.texture=nil
end
return M
