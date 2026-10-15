-- Original 24-sided SkyBeam; only length and power change on the GPU.
local Coord=require 'core.Coord'
local M={};M.__index=M
function M.New(scene,point)
 local self=setmetatable({},M);self.node=scene:CreateChild('OpeningAllySkyBeam');self.clock=0
 local geometry=self.node:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
 for segment=0,23 do
  for _,v in ipairs({{0,0},{1,0},{1,1},{0,0},{1,1},{0,1}}) do
   local u=(segment+v[1])/24;local angle=u*math.pi*2
   geometry:DefineVertex(Vector3(math.sin(angle),v[2],math.cos(angle)))
   geometry:DefineNormal(Vector3(math.sin(angle),0,math.cos(angle)));geometry:DefineTexCoord(Vector2(u,v[2]))
  end
 end
 geometry:Commit();self.material=Material:new();assert(self.material:SetSurfaceShader('Intro/Shaders/BLGL/SkyBeam.shader'));geometry:SetMaterial(self.material)
 local from=Coord.Vec(point[1]+40,point[2]+300,point[3]-60);local to=Coord.Vec(point[1],point[2]-1,point[3])
 local delta=to-from;self.node.position=from;self.node.rotation=Quaternion(Vector3.UP,delta.normalized);self.node:SetScale(Vector3(2.6,delta.length,2.6));self.node.enabled=false
 return self
end
function M:Update(dt,age)
 self.clock=self.clock+dt;self.node.enabled=age>=1.8 and age<2.75
 self.material:SetShaderParameter('clock',Variant(self.clock))
 self.material:SetShaderParameter('beam_length',Variant(math.max(0,math.min(1,(age-1.8)/.25*3))))
 self.material:SetShaderParameter('power',Variant(1.4*math.max(0,1-math.max(0,age-2.05)/.7)))
end
function M:Dispose() self.node:Dispose();self.material:Dispose() end
return M
