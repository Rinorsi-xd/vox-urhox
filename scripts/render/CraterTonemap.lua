-- H5 GradeShader then Three ACES, sampled by the engine's desktop LUT pass.
-- Only preference changes rebuild the volume. Keep the old complete volume
-- visible until the next one is ready; never upload a partially built LUT.
local Exposure=require 'render.FixedExposure'
local Platform=require 'urhox-libs.Platform.PlatformUtils'
---@class CraterTonemap
---@field zone Zone|nil
---@field resource ColorLUT|nil
---@field texture Texture3D|nil
---@field image Image|nil
---@field job thread|nil
---@field exposure number
---@field requested number|nil
---@field maxSliceMs number
---@field lastUploadMs number
---@field sliceStart number
---@field buildFrames integer
local M={};M.__index=M
local path='Crater/Tonemap.cube'
local states=setmetatable({},{__mode='k'})
local size=49
local axis={};local zero=2^(-444/1023*14)*.18
for i=0,size-1 do axis[i+1]=math.max(0,2^((i/(size-1)-444/1023)*14)*.18-zero) end
local function Clamp(v) return math.max(0,math.min(1,v)) end
local function Fit(v) return (v*(v+.0245786)-.000090537)/(v*(.983729*v+.432951)+.238081) end
local function Encode(v) v=Clamp(v);return v<=.0031308 and v*12.92 or 1.055*v^(1/2.4)-.055 end
local function ColorAt(r,g,b,exposure)
    local w=Clamp((r*.2126+g*.7152+b*.0722-.02)/.58);w=w*w*(3-2*w)
    r=.18*(r*(.93+.13*w)/.18+1e-5)^1.08
    g=.18*(g*(.98+.02*w)/.18+1e-5)^1.08
    b=.18*(b*(1.05-.14*w)/.18+1e-5)^1.08
    local lum=(r*.2126+g*.7152+b*.0722)*-.05;local e=exposure/.6
    r=math.max(0,lum+r*1.05)*e;g=math.max(0,lum+g*1.05)*e;b=math.max(0,lum+b*1.05)*e
    local x=Fit(.59719*r+.35458*g+.04823*b)
    local y=Fit(.076*r+.90834*g+.01566*b)
    local z=Fit(.02840*r+.13383*g+.83777*b)
    return Encode(1.60475*x-.53108*y-.07367*z),Encode(-.10208*x+1.10813*y-.00605*z),Encode(-.00327*x-.07276*y+1.07602*z)
end
function M.Available(scene)
    return Platform.IsDesktopPlatform() and scene:GetVar('VoxColorGrade'):GetString()=='crater'
end
function M.New(zone)
    -- ColorLUT is the native resource type; Texture3D cannot load .cube files.
    local resource=cache:GetExistingResource('ColorLUT',path)
    if resource and not states[resource] then assert(cache:ReloadResource(resource)) end
    resource=resource or assert(cache:GetResource('ColorLUT',path),'Missing crater color LUT')
    local self=setmetatable({zone=zone,resource=resource,texture=resource:GetTexture3D(),exposure=states[resource] or 1.1,maxSliceMs=0,lastUploadMs=0,buildFrames=0,sliceStart=0},M)
    states[resource]=self.exposure
    assert(zone:SetAttribute('Tonemap LUT',Variant(VAR_RESOURCEREF,'ColorLUT;'..path)))
    zone.tonemapMode=TONEMAP_MODE_LUT
    return self
end
function M:Cancel()
    if self.job then coroutine.close(self.job);self.job=nil end
    if self.image then self.image:Dispose();self.image=nil end
end
function M:Set(exposure)
    Exposure.Apply(self.zone,exposure/self.exposure)
    if exposure==self.requested then return end
    self:Cancel();self.requested=exposure
    if exposure==self.exposure then return end
    self.image=Image:new();assert(self.image:SetSize(size,size,size,4))
    local pixel=Color(0,0,0,1)
    self.maxSliceMs=0;self.buildFrames=0
    self.job=coroutine.create(function()
        for b=0,size-1 do for g=0,size-1 do
            for r=0,size-1 do
                local red,green,blue=ColorAt(axis[r+1],axis[g+1],axis[b+1],exposure)
                pixel.r=red;pixel.g=green;pixel.b=blue;self.image:SetPixel(r,g,b,pixel)
            end
            if os.clock()-self.sliceStart>=.001 then coroutine.yield() end
        end end
        -- Encode to sRGB storage to retain dark-tone precision in Image's 8-bit
        -- channels. Hardware decodes each sample before trilinear filtering.
        local upload=os.clock();self.texture:SetSRGB(true)
        assert(self.texture:SetData(self.image),'Cannot upload crater color LUT')
        self.lastUploadMs=(os.clock()-upload)*1000
        self.image:Dispose();self.image=nil;self.exposure=exposure;states[self.resource]=exposure
        Exposure.Apply(self.zone,1)
    end)
end
function M:Update()
    local texture=self.resource:GetTexture3D()
    if texture~=self.texture then
        self:Cancel();self.texture=texture;self.exposure=1.1;states[self.resource]=1.1
        local requested=self.requested;self.requested=nil;self:Set(requested or 1.1)
    end
    if not self.job then return end
    self.buildFrames=self.buildFrames+1;self.sliceStart=os.clock();local ok,err=coroutine.resume(self.job)
    self.maxSliceMs=math.max(self.maxSliceMs,(os.clock()-self.sliceStart)*1000)
    if not ok then self:Cancel();error(err) end
    if coroutine.status(self.job)=='dead' then self.job=nil end
end
function M:Dispose()
    self:Cancel()
    self.zone=nil;self.texture=nil;self.resource=nil
end
return M
