-- Render original opening poses behind its opaque boot page, without running
-- narrative, physics or audio. SceneWarmup restores masks on cancel and finish.
local Coord=require 'core.Coord'
local Warm=require 'render.SceneWarmup'
local M={};M.__index=M
local function Pose(camera,at,look,fov)
 camera.node.position=Coord.Vec(table.unpack(at));camera.node:LookAt(Coord.Vec(table.unpack(look)));camera.fov=fov
end
function M.New(state,host,done)
 local self=setmetatable({state=state,host=host,done=done,index=0,frames=0,batches=0,rest=0,seen={},sampleCounts={},repeated=0},M)
 self.hallPose={position=state.hallCamera.node.position,rotation=state.hallCamera.node.rotation,fov=state.hallCamera.fov}
 local c=state.session.camera:GetCamera();self.craterPose={position=c.node.position,rotation=c.node.rotation,fov=c.fov}
 self.garageEnabled=state.garage.root.enabled;self.heroEnabled=state.hallActor.root.enabled
 self.phases={'idyll','idyll-crossing','build','brief','drive','effects','effects-single'};return self
end
function M:Next()
 if self.batch then self.batch:Restore();self.batches=self.batches+self.batch.batches;self.batch=nil end
 self.index=self.index+1;self.rest=0
 local id=self.phases[self.index];self.phase=id
 if not id then self:Dispose();self.completed=true;self.done();return end
 local s=self.state;local idyllic=id=='idyll' or id=='idyll-crossing';local hall=idyllic or id=='build';self.host.UseScene(hall and 'garage' or 'crater')
 local camera=hall and s.hallCamera or s.session.camera:GetCamera()
 s.session.combat.montage:SetWarmVisible(id=='drive' or id=='effects' or id=='effects-single')
 s.hallActor:SetVisible(id=='build');s.garage.root:SetEnabledRecursive(idyllic)
 if idyllic then
  Pose(camera,{2,5,-40},{-4,16,-90},46);local t=id=='idyll' and 3 or 6;s.garage:Update(t-s.garage.time,{time=t},camera)
 elseif id=='build' then Pose(camera,{15,6,21},{0,3,0},44);s.assembly:WarmFlash(true)
 elseif id=='brief' then
  Pose(camera,{98,self.host.GroundAt(98,-212)+13,-212},{46,self.host.GroundAt(46,-140)+2,-140},50)
 elseif id=='drive' then
  local p=s.session.combat.player:Position();Pose(camera,{p[1]-9,p[2]+4,p[3]-12},{p[1],p[2]+1.5,p[3]+20},56)
 elseif id=='effects' then
  local p=s.session.combat.player:Position();local y=p[2]+3
  Pose(camera,{p[1]+18,p[2]+12,p[3]-18},{p[1],y,p[3]},50)
  self.strike=require('intro.IntroStrike').New(s.scene,p);self.strike:Update(.01,1.98)
  self.effects=require('render.CombatEffects').New(s.scene,function(x,z)return self.host.GroundAt(x,z)end)
  local a={p[1],y,p[3]};local b={p[1],y,p[3]+12}
  self.effects:Consume({{type='shot',kind='laser',tier=5,pos=a,dir={0,0,1}},
   {type='shot',kind='mg',tier=5,pos=a,dir={0,0,1},spin=1},
   {type='shot',kind='sniper',tier=5,pos=a,dir={0,0,1}},
   {type='beam',kind='laser',tier=5,from=a,to=b,dir={0,0,1},hit=true},
   {type='beam',kind='sniper',tier=5,from=a,to=b,dir={0,0,1},hit=true},
   {type='impact',kind='mg',tier=5,pos=b,dir={0,0,1}},
   {type='break',pos=b,dir={0,0,1},cells=4,color=0x7f9fba},
   {type='shot',kind='missile',tier=3,pos=a,dir={0,0,1},locked=true},
   {type='blast',kind='missile',tier=3,pos=b,dir={0,0,1},radius=2.5},
   {type='explode',pos=b,radius=4}})
  local missiles={};for i=1,4 do missiles[i]={fx='missile',pos={p[1]+i*.3,y,p[3]+6},vel={0,0,20},trail={a,{p[1],y,p[3]+3}},s={tier=3}} end
  self.effects:Update(.04,missiles,camera.node)
  self.equipment=require('intro.IntroEquipmentWarmup').New(s.scene,p,camera)
  self.missileSample=missiles[1]
  -- Flash light permutations apply to original nearby model layouts, including
  -- instancing; a private boot-only range covers the full rendered scene.
  self.effects.light.light.range=2000;self.effects.light.light.brightness=1;self.effects.light.light.enabled=true
  self.weaponBatches={};local Batch=require 'render.EffectBatch'
  for _,kind in ipairs({'Glow','Band','Swirl','Ribbon'}) do
   local batch=Batch.New(s.scene,kind,4,'Shaders/BLGL/WeaponFx/');batch:Begin(a,0)
   batch:Disc(b,1,{1,1,1},1,{1,0,0},{0,1,0});batch:Finish();self.weaponBatches[#self.weaponBatches+1]=batch
  end
 elseif id=='effects-single' then
  self.equipment:Single()
  self.effects:Update(0,{self.missileSample},camera.node)
  for i,slot in ipairs(self.effects.chips.slots) do slot.node.enabled=i==1 end
 end
 if not hall and s.session.environment then s.session.environment:Update(0,camera.node) end
 s.app.graphicsSettings:PostUpdate()
 local scene=hall and s.hall or s.scene
 local lights={}
 for _,light in ipairs(scene:GetComponents('Light',true)) do
  if light.enabled and light.node.enabled then lights[#lights+1]=table.concat({tostring(light.lightType),tostring(light.castShadows),tostring(light.lightMask)},':') end
 end
 table.sort(lights);local lighting=table.concat(lights,';')
 self.batch=Warm.New(scene,8,camera,function(drawable,kind)
  if not drawable.enabledEffective then return false end
  if kind~='StaticModel' then
   if self.seen[drawable] then self.repeated=self.repeated+1;return false end
   self.seen[drawable]=true;return true
  end
  -- Exact immutable Model identity includes vertex layouts and geometry. Keep
  -- four real copies of each mask/material combination for instanced variants.
  local model=drawable.model;if not model then return true end
  local key={id,tostring(scene),kind,tostring(model),lighting,tostring(drawable.zone),
   tostring(drawable.viewMask),tostring(drawable.lightMask),tostring(drawable.shadowMask),tostring(drawable.zoneMask),
   tostring(drawable.castShadows),tostring(drawable.maxLights),tostring(drawable.useInstanceColor),tostring(drawable.useInstanceCustomData)}
  for i=0,model.numGeometries-1 do key[#key+1]=tostring(drawable:GetMaterial(i)) end
  key=table.concat(key,'|');local count=self.sampleCounts[key] or 0
  if count>=4 then self.repeated=self.repeated+1;return false end
  self.sampleCounts[key]=count+1;return true
 end)
 print('[IntroWarmup] '..id..' visible='..#self.batch.items..' skipped='..self.batch.skipped..' reused='..self.repeated)
end
function M:Presented()
 if self.disposed then return end
 self.frames=self.frames+1
 if self.batch then
  if self.batch:Rendered() then self.batches=self.batches+self.batch.batches;self.batch=nil;self.rest=2 end
 elseif self.rest>0 then self.rest=self.rest-1
 else self:Next() end
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true
 if self.batch then self.batch:Restore();self.batch=nil end
 if self.strike then self.strike:Dispose();self.strike=nil end
 if self.effects then self.effects:Dispose();self.effects=nil end
 if self.equipment then self.equipment:Dispose();self.equipment=nil end
 self.missileSample=nil
 for _,batch in ipairs(self.weaponBatches or {}) do batch:Dispose() end;self.weaponBatches={}
 local s=self.state;local p=self.hallPose;local c=s.hallCamera
 s.assembly:WarmFlash(false)
 s.session.combat.montage:SetWarmVisible(false)
 c.node.position=p.position;c.node.rotation=p.rotation;c.fov=p.fov
 p=self.craterPose;c=s.session.camera:GetCamera();c.node.position=p.position;c.node.rotation=p.rotation;c.fov=p.fov
 s.garage.root:SetEnabledRecursive(self.garageEnabled);s.garage.time=0;s.hallActor:SetVisible(self.heroEnabled)
 self.host.UseScene('garage');s.app.car:SetVisible(false)
 print('[IntroWarmup] restored frames='..self.frames..' batches='..self.batches)
end
return M
