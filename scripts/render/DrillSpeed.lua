-- One additive overlay draw, no intermediate color/depth texture or CPU particles.
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local M={};M.__index=M
function M.New()
    local self=setmetatable({},M);self:init();return self
end
function M:init() self.rush=0;self.time=0;self.visible=false;self.scene=nil end
function M:Prepare()
    self.scene=Scene();self.scene:CreateComponent('Octree')
    local camera=self.scene:CreateChild('OverlayCamera'):CreateComponent('Camera')
    camera.node.position=Vector3(0,0,-2);camera.orthographic=true;camera.orthoSize=2;camera.autoAspectRatio=false;camera.aspectRatio=1
    local mesh=self.scene:CreateChild('SpeedStreaks'):CreateComponent('CustomGeometry');self.mesh=mesh
    mesh:BeginGeometry(0,TRIANGLE_LIST)
    for _,p in ipairs({{-1,-1,0,1},{-1,1,0,0},{1,1,1,0},{-1,-1,0,1},{1,1,1,0},{1,-1,1,1}}) do
        mesh:DefineVertex(Vector3(p[1],p[2],0));mesh:DefineNormal(Vector3(0,0,-1));mesh:DefineTexCoord(Vector2(p[3],p[4]))
    end
    mesh:Commit();self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/Combat/DrillSpeed.shader'))
    self.material.depthTestMode=CMP_ALWAYS;mesh:SetMaterial(self.material)
    local xml=XMLFile:new();assert(xml:FromString('<renderpath><command type="scenepass" pass="alpha" vertexlights="false"/></renderpath>'))
    local path=renderer:GetDefaultRenderPath():Clone();assert(path:Load(xml));xml:Dispose()
    self.viewport=Viewport:new(self.scene,camera);self.viewport:SetRenderPath(path)
    self.index=renderer.numViewports;renderer:SetNumViewports(self.index+1);renderer:SetViewport(self.index,self.viewport)
end
function M:Update(dt,camera,system,live)
    local a=system.drill.active;local want=live and a and a.phase=='dash' and (a.grinding and .55 or 1) or 0
    self.rush=self.rush+(want-self.rush)*(1-math.exp(-dt*(want>self.rush and 12 or 6)))
    if not live then self.rush=0 end
    self.time=self.time+dt;self.visible=self.rush>.01
    if self.visible and not self.scene then self:Prepare() end
    if self.mesh then self.mesh.enabled=self.visible end
    if not self.visible then return end
    local m=self.material;m:SetShaderParameter('power',Variant(self.rush));m:SetShaderParameter('elapsed',Variant(self.time));m:SetShaderParameter('aspect',Variant(camera.aspectRatio))
    if a then
        local at=camera.node.worldPosition+Coord.Vec(table.unpack(V.Scale(a.dir,60)))
        local p=camera:WorldToScreenPoint(at)
        m:SetShaderParameter('center',Variant(Vector2(V.Clamp(p.x*2-1,-.45,.45),V.Clamp(1-p.y*2,-.3,.3))))
        m:SetShaderParameter('pink',Variant(a.w.stats.easter and 1 or 0))
    end
end
function M:Clear() self.rush=0;self.visible=false;if self.mesh then self.mesh.enabled=false end end
function M:Dispose()
    if self.viewport and renderer:GetViewport(self.index)==self.viewport then
        renderer:SetViewport(self.index,nil)
        if renderer.numViewports==self.index+1 then renderer:SetNumViewports(self.index) end
    end
    if self.scene then self.scene:Dispose();self.material:Dispose() end
    self.scene=nil;self.mesh=nil;self.material=nil;self.viewport=nil
end
return M
