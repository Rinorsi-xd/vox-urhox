-- Ordered SurfaceShader passes. No generated shader names or texture slots.
-- Runtime 20260923 renders queued surfaces in reverse registration order;
-- allocate the entire DAG backwards, including on resize, before binding it.
-- tools/migration/verify-filter-graph.ps1 guards same-frame HDR propagation.
local RenderTargetLifetime=require("render.RenderTargetLifetime")

local M={};M.__index=M
local vertices={{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}
function M.New(specs,width,height)
    local self=setmetatable({},M)
    local ok,err=pcall(self.Init,self,specs,width,height)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:Init(specs,width,height)
    width,height=math.max(1,math.floor(width)),math.max(1,math.floor(height))
    self.scenes={};self.materials={};self.textures={};self.viewports={};self.samples={};self.width=width;self.height=height;self.colorBytes=0
    -- All inputs must reference an earlier pass, so feedback is impossible.
    for i,spec in ipairs(specs) do for _,source in pairs(spec.inputs or {}) do assert(source<i,'Filter graph cycle') end end
    for i=#specs-1,1,-1 do
        local spec=specs[i];local texture=Texture2D:new();self.textures[i]=texture;texture:SetNumLevels(1)
        local w=math.max(1,math.floor(spec.width or self.width))
        local h=math.max(1,math.floor(spec.height or self.height))
        -- Optional MSAA (scene source only): auto-resolved before later passes sample it.
        local samples=math.max(1,math.floor(spec.multiSample or 1))
        local format=Graphics:GetRGBAFloat16Format()
        if samples>1 and not texture:SetSize(w,h,format,TEXTURE_RENDERTARGET,samples,true) then samples=1 end
        if samples==1 then assert(texture:SetSize(w,h,format,TEXTURE_RENDERTARGET),'HDR filter allocation failed') end
        self.samples[i]=samples
        texture.filterMode=FILTER_BILINEAR;texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        -- A multisampled target also owns its single-sample resolve texture.
        self.colorBytes=self.colorBytes+w*h*8*(samples>1 and samples+1 or 1)
    end
    local xml=XMLFile:new()
    assert(xml:FromString('<renderpath><command type="clear" color="0 0 0 1" depth="1"/><command type="scenepass" pass="base" vertexlights="false"/></renderpath>'))
    local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
    for i,spec in ipairs(specs) do
        local viewport=spec.viewport
        if not viewport then
            local scene=Scene();self.scenes[#self.scenes+1]=scene;scene:CreateComponent('Octree')
            local camera=scene:CreateChild('FilterCamera'):CreateComponent('Camera')
            camera.node.position=Vector3(0,0,-2);camera.orthographic=true;camera.orthoSize=2
            camera.autoAspectRatio=false;camera.aspectRatio=1
            local geometry=scene:CreateChild('FilterQuad'):CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
            for _,v in ipairs(vertices) do
                geometry:DefineVertex(Vector3(v[1],v[2],0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(v[3],v[4]))
            end
            geometry:Commit()
            local material=Material:new();self.materials[i]=material
            assert(material:SetSurfaceShader(spec.shader),'Cannot load filter '..spec.shader)
            for sampler,source in pairs(spec.inputs or {}) do assert(material:SetSurfaceTexture(sampler,self.textures[source])) end
            for name,value in pairs(spec.parameters or {}) do material:SetShaderParameter(name,Variant(value)) end
            geometry:SetMaterial(material);viewport=Viewport:new(scene,camera);viewport:SetRenderPath(path)
        end
        self.viewports[i]=viewport
        if self.textures[i] then
            local surface=self.textures[i].renderSurface;surface:SetViewport(0,viewport);surface.updateMode=SURFACE_MANUALUPDATE
        else self.output=viewport end
    end
    self.passCount=#specs
end
function M:Queue()
    for _,texture in ipairs(self.textures) do texture.renderSurface:QueueUpdate() end
end
function M:Parameter(index,name,value) self.materials[index]:SetShaderParameter(name,Variant(value)) end
function M:Dispose()
    for _,texture in pairs(self.textures) do texture.renderSurface:SetNumViewports(0) end
    for _,scene in ipairs(self.scenes) do scene:Dispose() end
    for _,material in pairs(self.materials) do material:Dispose() end
    for _,texture in pairs(self.textures) do RenderTargetLifetime.Retire(texture) end
    self.scenes={};self.materials={};self.textures={};self.viewports={};self.samples={};self.output=nil
end
return M
