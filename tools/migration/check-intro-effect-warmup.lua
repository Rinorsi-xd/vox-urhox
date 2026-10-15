local Equipment=require 'intro.IntroEquipmentWarmup'
local Resources=require 'render.EquipmentResources'
local Warm=require 'render.SceneWarmup'
local Missile=require 'render.MissileView'
local scene,camera,equipment,missiles,warm
local previousUsers=0;local batches=0;local single=false;local done=false
V.atFrame(2,function()
 previousUsers=Resources.users;scene=Scene();scene:CreateComponent('Octree')
 local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100));zone.ambientColor=Color(.2,.2,.2)
 local sun=scene:CreateChild('Sun'):CreateComponent('Light');sun.lightType=LIGHT_DIRECTIONAL
 camera=scene:CreateChild('Camera'):CreateComponent('Camera');camera.node.position=Vector3(8,8,-10);camera.node:LookAt(Vector3(0,3,3))
 renderer:SetViewport(0,Viewport:new(scene,camera));equipment=Equipment.New(scene,{0,0,0},camera)
 missiles=Missile.New(scene,4);missiles:Begin()
 for i=1,4 do missiles:Add({pos={i*.4,3,4},vel={0,0,20},s={tier=3}})end;missiles:Finish()
 V.assert(Resources.users==previousUsers+1,'private original equipment material ownership acquired once')
 V.assert(#equipment.root:GetComponents('StaticModel',true)==8 and #missiles.slots==4,'actual boot scene contains four thruster four hover and four original missile layouts')
 for kind,list in pairs(equipment.models)do for _,model in ipairs(list)do
  V.assert(model.model==Resources.Box() and model.material==Resources.Material(kind) and not model.castShadows and model.enabled,'proxy matches real powered equipment model material and flags')
 end end
 V.assert(equipment.batches.Mote.count>0 and equipment.batches.Spot.count>0 and equipment.batches.Flare.count>0,'actual original point hover-contact and exhaust-flare batches contain renderable geometry')
 warm=Warm.New(scene,8,camera)
end)
for frame=3,45 do V.atFrame(frame,function()
 if done or not warm then return end
 if warm:Rendered()then
  batches=batches+warm.batches;warm=nil
  if not single then
   single=true;equipment:Single();missiles:Begin();missiles:Add({pos={.4,3,4},vel={0,0,20},s={tier=3}});missiles:Finish()
   local n=0;for _,list in pairs(equipment.models)do for _,model in ipairs(list)do if model.enabled then n=n+1 end end end
   V.assert(n==2 and missiles.slots[1].enabled and not missiles.slots[2].enabled,'single phase disables pooled siblings without replacing actual shader resources')
   warm=Warm.New(scene,8,camera)
  else
   V.assert(batches>1,'single and instanced original effects were submitted through presented warmup batches')
   equipment:Dispose();equipment:Dispose();missiles:Dispose()
   V.assert(Resources.users==previousUsers and not scene:GetChild('OpeningEquipmentWarmup') and not scene:GetChild('MissileBodies'),'private effect actors and exact resource owner released idempotently')
   scene:Dispose();done=true;V.finish()
  end
 end
end)end
V.atFrame(46,function()V.assert(done,'actual single and instanced equipment warmup completes');V.finish()end)
