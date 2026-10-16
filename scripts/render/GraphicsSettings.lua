-- Original H5 graphics values. Never publish a setting that only changes Lua.
local Quality=require("render.Quality")
local CraterPostProcess=require("render.CraterPostProcess")

local Exposure=require 'render.FixedExposure'
local CraterTonemap=require 'render.CraterTonemap'
local Viewports=require 'render.WindowViewports'
local M={};M.__index=M
local ranges={bloom={0,.8},mist={0,.2},exposure={.6,1.4},vignette={0,.6},grain={0,.06}}
local supported={bloom=true,exposure=true,vignette=true,quality=true}
function M.Defaults() return {v=2,quality=Quality.current.name=='mobile' and 'medium' or 'high',bloom=.18,mist=.04,exposure=1.1,vignette=.3,grain=0,ao=true} end
function M.Valid(data)
    if type(data)~='table' or data.v~=2 or type(data.ao)~='boolean' then return false end
    if data.quality~='high' and data.quality~='medium' and data.quality~='low' then return false end
    for k,r in pairs(ranges) do local n=data[k];if type(n)~='number' or n~=n or n<r[1] or n>r[2] then return false end end
    return true
end
local function Legacy(data)
    if type(data)~='table' or data.v~=1 then return false end
    for _,key in ipairs({'bloom','vignette'}) do
        local n=data[key];local r=ranges[key]
        if type(n)~='number' or n~=n or n<r[1] or n>r[2] then return false end
    end
    return true
end
function M.ValidSaved(data) return M.Valid(data) or Legacy(data) end
function M.New(app)
    Viewports.Start()
    local saved=not app.isValidation and app.store:Read('graphics',function(d) return M.Valid(d) or Legacy(d) end) or nil
    local data=saved or M.Defaults();local migrate=saved and saved.v==1 or false
    if migrate then data=M.Defaults();data.bloom=saved.bloom;data.vignette=saved.vignette end
    return setmetatable({app=app,data=data,pending=migrate,delay=0,error=''},M)
end
function M:Supports(key) return supported[key]==true or (self.post~=nil and (key=='mist' or key=='grain')) end
function M:ParkPost()
    local post=self.post;if not post then return end
    local retained=self.retainedPost
    if retained and post.scene==retained.scene and post.camera==retained.camera then retained.post=post
    else post:Dispose() end
    self.post=nil
end
function M:RetainPost(scene,camera)
    assert(not self.retainedPost,'A post-process scene is already retained')
    self.retainedPost={scene=scene,camera=camera}
end
function M:ReleasePost(scene)
    local retained=self.retainedPost
    if not retained or retained.scene~=scene then return end
    local post=retained.post
    if self.post and self.post.scene==scene then post=self.post;self.post=nil end
    self.retainedPost=nil
    if post then
        local output=post.graph and post.graph.output
        if output and Viewports.Get(0)==output then Viewports.Set(0,nil) end
        if output and self.suspendedViewport==output then self.suspendedViewport=nil end
        post:Dispose()
    end
end
function M:Apply(scene)
    if not self.app.ownsScene or not scene then return end
    local zone=scene:GetComponent('Zone',true);if not zone then return end
    local d=self.data
    if not scene:GetVar('VoxPreview'):GetBool() then Quality.Apply(d.quality) end
    if self.post and self.post.scene~=scene then self:ParkPost() end
    if self.post then self.post:Set(d);return end
    zone:SetAttribute('Bloom Enable',Variant(true)) -- Keep tonemap even at zero bloom.
    zone.tonemapMode=TONEMAP_MODE_ACES;zone.bloomMode=BLOOM_MODE_UE
    zone.bloomUEIntensity=d.bloom
    zone.bloomUEThreshold=1.3 -- H5 Pipeline: bloom.threshold; exclude ordinary surfaces.
    zone.vignetteEnabled=d.vignette>0;zone.vignetteIntensity=d.vignette
    if self.tonemap and self.tonemap.zone~=zone then self.tonemap:Dispose();self.tonemap=nil end
    if CraterTonemap.Available(scene) then
        self.tonemap=self.tonemap or CraterTonemap.New(zone)
        zone.tonemapMode=TONEMAP_MODE_LUT;self.tonemap:Set(d.exposure)
    else Exposure.Apply(zone,d.exposure) end
end
function M:Show(scene,camera)
    self.suspendedViewport=nil
    if CraterTonemap.Available(scene) then
        if self.post and (self.post.scene~=scene or self.post.camera~=camera) then self:ParkPost() end
        local retained=self.retainedPost
        local post=self.post or (retained and retained.scene==scene and retained.camera==camera and retained.post)
        if post then post:Set(self.data)
        else post=CraterPostProcess.New(scene,camera,self.data,{fixedResolution=self.app.isValidation}) end
        if retained and retained.scene==scene and retained.camera==camera then retained.post=post end
        if self.tonemap then self.tonemap:Dispose();self.tonemap=nil end
        self.post=post;post.graph:Queue();Viewports.Set(0,post.graph.output)
    else
        self:ParkPost()
        Viewports.Set(0,Viewport:new(scene,camera))
    end
end
function M:SetSceneVisible(visible)
    if not self.app.ownsScene then return end
    if visible and self.suspendedViewport then
        Viewports.Set(0,self.suspendedViewport);self.suspendedViewport=nil
    elseif not visible and not self.suspendedViewport then
        self.suspendedViewport=Viewports.Get(0);Viewports.Set(0,nil)
    end
end
function M:Set(key,value)
    if not self:Supports(key) then return false end
    local data={};for k,v in pairs(self.data) do data[k]=v end;data[key]=value
    if not M.Valid(data) then return false end
    self.data=data;self:Apply(self.app.scene);self.pending=true;self.delay=.35;self.error='';return true
end
function M:Reset()
    self.data=M.Defaults();self:Apply(self.app.scene);self.pending=true;self.delay=0
end
function M:Flush()
    if not self.pending then return true end
    local ok,err=self.app.store:Write('graphics',self.data,M.Valid)
    if ok then self.pending=false;self.error='' else self.error=err;self.delay=5 end
    return ok,err
end
function M:Update(dt)
    Viewports.Refresh()
    if self.post and not self.suspendedViewport and Viewports.Drawable() then self.post:Update(dt) end
    if self.tonemap then self.tonemap:Update() end
    if self.pending then self.delay=self.delay-dt;if self.delay<=0 then self:Flush() end end
end
function M:PostUpdate()
    Viewports.Refresh()
    if self.post and not self.suspendedViewport and Viewports.Drawable() then self.post:PostUpdate() end
end
function M:Dispose()
    self.suspendedViewport=nil
    self:Flush()
    if self.retainedPost then self:ReleasePost(self.retainedPost.scene) end
    if self.post then self.post:Dispose();self.post=nil end
    if self.tonemap then self.tonemap:Dispose();self.tonemap=nil end
end
return M
