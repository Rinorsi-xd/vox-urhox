local Rules=require 'render.AimLinesRules'
local Batch=require 'render.EffectBatch'
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local M={};M.__index=M
function M.New(scene)
    local self=setmetatable({},M);self.root=scene:CreateChild('SniperAimLines')
    self.mesh=self.root:CreateComponent('CustomGeometry');self.mesh.dynamic=true;self.mesh.castShadows=false
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/AimLine.shader'));self.mesh.material=self.material;self.material.renderOrder=147
    self.glow=Batch.New(self.root,'Glow',256,'Shaders/BLGL/Combat/');return self
end
function M:Draw(pos,dir,hit,len,enemy,k,wind,camera,time)
    local style=Rules.Style(pos,camera,enemy,k,wind,time);local tip=V.Add(pos,V.Scale(dir,len))
    -- Each endpoint expands in view pixels, matching Line2 at all distances.
    local side=V.Normalize(V.Cross(dir,V.Sub(pos,camera)))
    if V.Length(side)<.0001 then side=self.right end
    local p={};local pixels=2*math.tan(self.fov*.5)/self.height
    local a=V.Dot(V.Sub(pos,camera),self.forward);local b=V.Dot(V.Sub(tip,camera),self.forward)
    local wa=math.max(self.near,a)*pixels*style.width*.5;local wb=math.max(self.near,b)*pixels*style.width*.5
    p[1]=V.Add(pos,V.Scale(side,-wa));p[2]=V.Add(pos,V.Scale(side,wa));p[3]=V.Add(tip,V.Scale(side,-wb));p[4]=V.Add(tip,V.Scale(side,wb))
    local uv={{0,-1},{0,1},{1,-1},{1,1}}
    local color=Color(style.color[1],style.color[2],style.color[3],style.opacity)
    for _,i in ipairs({1,2,3,3,2,4}) do
        self.mesh:DefineVertex(Coord.Vec(p[i][1],p[i][2],p[i][3]));self.mesh:DefineColor(color);self.mesh:DefineTexCoord(Vector2(uv[i][1],uv[i][2]))
    end
    self.count=self.count+1
    if hit then
        local size=math.max(.06,V.Length(V.Sub(hit.point,camera))*.0012*2.5)*(1+wind)*2
        self.glow:Disc(hit.point,size,style.color,style.opacity,self.right,self.up)
    end
    self.glow:Disc(pos,style.glowSize,style.color,style.glowOpacity,self.right,self.up)
end
function M:Update(units,me,cast,camera,time)
    local node=camera:GetNode();local p=node.worldPosition;local pos={-p.x,p.y,p.z}
    local function Source(v) return {-v.x,v.y,v.z} end
    self.right=Source(node.worldRotation*Vector3.RIGHT);self.up=Source(node.worldRotation*Vector3.UP);self.forward=Source(node.worldRotation*Vector3.FORWARD)
    self.fov=camera.fov*math.pi/180;self.near=camera.nearClip;self.height=math.max(1,graphics:GetHeight())
    self.count=0;self.mesh:BeginGeometry(0,TRIANGLE_LIST);self.glow:Begin(pos,time)
    local warnings=Rules.Scan(units,me,cast,pos,time,function(...) self:Draw(...) end)
    self.mesh.enabled=self.count>0;if self.count>0 then self.mesh:Commit() end;self.glow:Finish();return warnings
end
function M:Hide() self.mesh.enabled=false;self.glow.mesh.enabled=false end
function M:Dispose() self.glow:Dispose();self.root:Dispose();self.material:Dispose() end
return M
