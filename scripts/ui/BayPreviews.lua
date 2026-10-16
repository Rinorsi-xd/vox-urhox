-- Visible-only textures backed by saved-generation images. The app's capture
-- service serializes all missing images; this widget owns no 3D scene.
-- UI owns the NanoVG frame; this widget never starts a second frame.
local SourceDraw=require("ui.SourceDraw")

local Panel=require 'urhox-libs/UI/Widgets/Panel'
local Picture=Panel:Extend('VoxBayPicture')
function Picture:Release()
    for context,handle in pairs(self.images or {}) do if handle~=0 then nvgDeleteVideo(context,handle) end end
    self.images={}
    self.image=nil;self.imageContext=nil
    -- The native NVG bridge retains this Texture2D. After deleting its image,
    -- release our reference instead of invalidating the shared native object
    -- with Dispose (reproduced crash on entering build with the current runtime).
    if self.texture then self.texture=nil end
end
function Picture:Render(nvg)
    Panel.Render(self,nvg)
    if not self.texture or not self.ready then return end
    self.images=self.images or {}
    if not self.images[nvg] then self.images[nvg]=nvgCreateVideo(nvg,self.texture) end
    self.image=self.images[nvg];self.imageContext=nvg
    if self.image==0 then return end
    local r=self:GetAbsoluteLayout()
    nvgSave(nvg);nvgIntersectScissor(nvg,r.x,r.y,r.w,r.h)
    if self.cut then SourceDraw.Path(nvg,{r.x,r.y,r.x+r.w-self.cut,r.y,r.x+r.w,r.y+self.cut,r.x+r.w,r.y+r.h,r.x,r.y+r.h})
    else nvgBeginPath(nvg);nvgRect(nvg,r.x,r.y,r.w,r.h) end
    local scale=math.max(r.w/320,r.h/200);local w,h=320*scale,200*scale
    nvgFillPaint(nvg,nvgImagePattern(nvg,r.x+(r.w-w)/2,r.y+(r.h-h)/2,w,h,0,self.image,1));nvgFill(nvg);nvgRestore(nvg)
end
function Picture:Destroy() self:Release();Panel.Destroy(self) end
local M={};M.__index=M
function M.New(scroll,service) return setmetatable({scroll=scroll,service=assert(service),items={},job=false},M) end
function M:Add(data,options)
    local item=Picture{width='100%',height=options and options.height or 72,pointerEvents='none',flexShrink=0}
    item.cut=options and options.cut
    item.data=data;self.items[#self.items+1]=item;return item
end
function M:FinishJob()
    for _,item in ipairs(self.items) do self.service:Cancel(item.request);item.request=nil end
    self.job=false;self.closed=true
end
function M:Update(dt)
    if self.closed then return end
    self.job=false
    local clip=self.scroll:GetAbsoluteLayoutForHitTest();if clip.w<=0 then return end
    for _,item in ipairs(self.items) do
        local r=item:GetAbsoluteLayoutForHitTest();local visible=self.scroll:IsVisible() and r.w>0 and r.x+r.w>clip.x and r.x<clip.x+clip.w and r.y+r.h>clip.y and r.y<clip.y+clip.h
        if not visible then
            self.service:Cancel(item.request);item.request=nil
            if item.texture then item:Release();item.ready=false end
        elseif not item.texture and not item.request and not item.failed then
            item.request=self.service:Request(item.data,function(image,err)
                item.request=nil
                if not image then item.failed=true;print('[BayPreviews] '..tostring(err));return end
                local texture=Texture2D:new();texture:SetNumLevels(1)
                local ok=texture:SetData(image);image:Dispose()
                if not ok then texture:Dispose();item.failed=true;return end
                texture:SetFilterMode(FILTER_BILINEAR);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
                item.texture=texture;item.ready=true
            end)
        end
        if item.request then self.job=item.request end
    end
end
function M:Clear()
    self:FinishJob()
    for _,item in ipairs(self.items) do item:Release() end
    self.items={};self.closed=false
end
function M:Dispose() self:Clear() end
return M
