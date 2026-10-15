-- Exact powered-equipment layouts, isolated from the paused actors' physics.
local Coord=require 'core.Coord'
local Resources=require 'render.EquipmentResources'
local Batch=require 'render.EffectBatch'
local M={};M.__index=M
function M.New(scene,position,camera)
 Resources.Acquire()
 local self=setmetatable({root=scene:CreateChild('OpeningEquipmentWarmup'),models={},batches={},disposed=false},M)
 for _,kind in ipairs({'Thruster','Hover'}) do
  self.models[kind]={}
  for i=1,4 do
   local node=self.root:CreateChild(kind..i);node.position=Coord.Vec(position[1]+(i-2)*.7,position[2]+2,position[3]+3)
   node.scale=Vector3(.5,1,.5)
   local model=node:CreateComponent('StaticModel');model.model=Resources.Box();model.material=Resources.Material(kind)
   model.castShadows=false;model.instanceCustomData=Vector4(1,.3,2,12);self.models[kind][i]=model
  end
 end
 local right=camera.node.worldRotation*Vector3.RIGHT;local up=camera.node.worldRotation*Vector3.UP
 for _,kind in ipairs({'Mote','Spot','Flare'}) do
  local batch=Batch.New(self.root,kind,4,'Shaders/BLGL/Equipment/');batch:Begin(position,0)
  if kind=='Flare' then batch.material:SetSurfaceTexture('flow_map',Resources.Flow()) end
  batch:Disc({position[1],position[2]+3,position[3]+2},1,{.1,.7,1.5},1,
   {-right.x,right.y,right.z},{-up.x,up.y,up.z});batch:Finish();self.batches[kind]=batch
 end
 Resources.Clock(0);return self
end
function M:Single()
 for _,list in pairs(self.models) do for i,model in ipairs(list) do model.enabled=i==1 end end
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true
 for _,batch in pairs(self.batches) do batch:Dispose() end
 self.root:Dispose();self.models={};self.batches={};Resources.Release()
end
return M
