local Coord=require 'core.Coord'
local BP=require 'construction.Blueprint'
local M={};M.__index=M
function M.New(scene,data,checkpoint)
 local self=setmetatable({root=scene:CreateChild('OpeningProps'),hovers={},time=0},M)
 self.dove=self.root:CreateChild('PeaceDove');self.dove.position=Coord.Vec(-6,22,-86)
 local geometry=self.dove:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
 for j=0,17 do for i=0,17 do
  local rnd=math.random();local rnd2=math.random()
  for _,v in ipairs({{0,0},{1,1},{1,0},{0,0},{0,1},{1,1}}) do
   local x,y=(i+v[1])/18,(j+v[2])/18
   geometry:DefineVertex(Vector3(-(x-.5)*24,(y-.5)*24,0));geometry:DefineNormal(Vector3(0,0,-1));geometry:DefineTexCoord(Vector2(x,y))
   geometry:DefineColor(Color((i+.5)/18,(j+.5)/18,rnd,rnd2))
  end
 end end
 geometry:Commit();self.material=Material:new();assert(self.material:SetSurfaceShader('Intro/Shaders/BLGL/Dove.shader'));self.material:SetSurfaceTexture('dove_map',assert(cache:GetResource('Texture2D',data.images.dove)));geometry:SetMaterial(self.material)
 for i,source in ipairs(data.actors.hovers or {}) do
  local view=require('render.VehicleView').New(self.root,'Flyby'..i);local bp=BP.New():Load(source)
  for n,p in ipairs(bp:List()) do view:AddPart(p);if checkpoint then checkpoint((i-1+n/bp:Size())/3,'intro-flyby') end end
  view.joined:Update();view.root:SetScale(1)
  self.hovers[#self.hovers+1]={view=view,index=i-1,seed=math.random()*6.28}
 end
 self.root:SetEnabledRecursive(false);return self
end
function M:Shot(id)
 self.root:SetEnabledRecursive(id=='idyll');if id=='idyll' then self.time=0 end
end
function M:Update(dt,I,camera)
 if not self.root.enabled then return end
 self.time=self.time+dt;local t=self.time
 self.dove.rotation=Quaternion(math.atan(camera.node.position.x-self.dove.position.x,camera.node.position.z-self.dove.position.z)*180/math.pi,Vector3.UP)
 self.material:SetShaderParameter('clock',Variant(I.time));self.material:SetShaderParameter('opacity',Variant(math.min(1,t*.8)))
 for _,car in ipairs(self.hovers) do local i=car.index;local root=car.view.root
  root.position=Coord.Vec(-130+t*24-i*18,16+i*4+math.sin(t*1.6+car.seed)*.6,-112-i*14)
  root.rotation=Quaternion(-90,Vector3.UP)*Quaternion(.12*180/math.pi,Vector3.FORWARD);car.view:UpdateIdle(dt,I.time)
 end
end
function M:Dispose()
 for _,car in ipairs(self.hovers) do car.view:Dispose() end
 self.root:Dispose();self.material:Dispose()
end
return M
