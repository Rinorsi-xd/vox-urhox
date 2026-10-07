-- PC H5 post chain. The source scene is rendered once; all later passes are quads.
local Graph=require 'render.FilterGraph'
local M={};M.__index=M
local shaderRoot='Shaders/BLGL/CraterPost/'
local function Half(n) return math.max(1,math.floor(n/2+.5)) end
function M.Specs(viewport,width,height,data)
    local specs={{viewport=viewport}}
    local function Add(shader,inputs,parameters,w,h)
        specs[#specs+1]={shader=shaderRoot..shader..'.shader',inputs=inputs,parameters=parameters,width=w,height=h}
        return #specs
    end
    local function Bloom(source,threshold,strength,radius)
        local w,h=Half(width),Half(height)
        local input=Add('HighPass',{source_map=source},{threshold=threshold},w,h)
        local levels={}
        for level=1,5 do
            local horizontal=Add('Blur'..level,{source_map=input},{direction=Vector2(1/w,0)},w,h)
            input=Add('Blur'..level,{source_map=horizontal},{direction=Vector2(0,1/h)},w,h)
            levels['level'..level]=input;w=Half(w);h=Half(h)
        end
        return Add('Composite',levels,{strength=strength,radius=radius},Half(width),Half(height))
    end
    local clamped=Add('Clamp',{source_map=1})
    local bloom=data.bloom>.001 and Bloom(clamped,1.3,data.bloom,.6) or nil
    local sum=bloom and Add('Add',{source_map=clamped,bloom_map=bloom}) or clamped
    local mist=data.mist>.001 and Bloom(sum,0,data.mist,1) or nil
    local grade=Add('Grade',{source_map=sum,bloom_map=mist or sum},{exposure=data.exposure,bloom_weight=mist and 1 or 0})
    local lens=Add('Lens',{source_map=grade},{resolution=Vector2(width,height),vignette=data.vignette,grain=data.grain})
    return specs,{clamp=clamped,bloom=bloom,mist=mist,grade=grade,lens=lens}
end
function M.New(scene,camera,data,options)
    local self=setmetatable({},M)
    local ok,err=pcall(self.Init,self,scene,camera,data,options)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Init(scene,camera,data,options)
    self.scene=scene;self.camera=camera;self.data=data;self.zone=scene:GetComponent('Zone',true)
    self.fixedResolution=options and options.fixedResolution or false
    self.adaptive=require('render.AdaptiveResolution').New(not self.fixedResolution)
    self.source=Viewport:new(scene,camera);self.source:SetRenderPath(renderer:GetDefaultRenderPath():Clone())
    self:Resize(self:RenderSize());self:ConfigureSource()
end
function M:RenderSize()
    return self.adaptive:Size(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR(),self.data.quality,self.fixedResolution)
end
function M:ConfigureSource()
    -- Tone mapping is in Grade.shader, after both bloom pyramids.
    self.zone:SetAttribute('Bloom Enable',Variant(false))
    self.zone:SetAttribute('Auto Exposure Enable',Variant(false));self.zone.vignetteEnabled=false
end
function M:Resize(width,height,force)
    if not force and self.graph and self.graph.width==width and self.graph.height==height then return false end
    local specs,indices=M.Specs(self.source,width,height,self.data)
    local graph=Graph.New(specs,width,height)
    local previous=self.graph;self.graph=graph;self.indices=indices
    -- Replace the renderer's output before invalidating its old scene/camera.
    if previous then renderer:SetViewport(0,graph.output) end
    if previous then previous:Dispose() end
    return true
end
function M:Set(data)
    self.data=data;self:ConfigureSource()
    -- Coalesce rapid setting changes; at most one allocation transaction/frame.
    self.rebuild=(data.bloom>.001)~=(self.indices.bloom~=nil) or (data.mist>.001)~=(self.indices.mist~=nil)
    if self.indices.bloom then self.graph:Parameter(self.indices.bloom,'strength',data.bloom) end
    if self.indices.mist then self.graph:Parameter(self.indices.mist,'strength',data.mist) end
    self.graph:Parameter(self.indices.grade,'exposure',data.exposure)
    self.graph:Parameter(self.indices.lens,'vignette',data.vignette)
    self.graph:Parameter(self.indices.lens,'grain',data.grain)
end
function M:Update(dt)
    self.adaptive:Sample(dt,input.focus and not input.minimized)
    local width,height=self:RenderSize()
    if self:Resize(width,height,self.rebuild) then renderer:SetViewport(0,self.graph.output) end
    self.rebuild=false
    self.graph:Queue()
end
local sunDirection=Vector3(.52,.5,-.69).normalized
local function Smooth(a,b,x)
    local t=math.max(0,math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)
end
function M:PostUpdate()
    -- Called after the third-person camera, so shafts use this frame's pose.
    local camera=self.camera;local facing=camera.node.worldDirection:DotProduct(sunDirection)
    local on=0
    if facing>0 and self.data.quality~='low' then
        local sun=camera:WorldToScreenPoint(camera.node.worldPosition+sunDirection*1500)
        local off=math.max(math.abs(sun.x*2-1),math.abs(sun.y*2-1))
        on=Smooth(.05,.45,facing)*(1-Smooth(1.2,2.2,off))
        self.graph:Parameter(self.indices.clamp,'shaft_sun',sun)
    end
    self.graph:Parameter(self.indices.clamp,'shaft_on',on)
    self.graph:Parameter(self.indices.clamp,'shaft_aspect',graphics:GetWidth()/graphics:GetHeight())
end
function M:Dispose()
    if self.graph then self.graph:Dispose();self.graph=nil end
    self.source=nil;self.scene=nil;self.camera=nil;self.zone=nil
end
return M
