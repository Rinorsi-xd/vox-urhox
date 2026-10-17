-- Isolated rendering diagnostic: production parts/rigs; no gameplay or physics.
local Gate=require 'app.ResourceGate'
local Dependencies=require 'parts.Dependencies'
local View=require 'render.VehicleView'
local RotorView=require 'render.RotorView'
local Rot=require 'core.Rotations'
local types={'rotor','rotorSpin','rotorStep'}
local stages={{name='top-default',y=15,z=-4,cull=false},{name='top-double',y=15,z=-4,cull=true},
 {name='bottom-default',y=-15,z=-4,cull=false},{name='bottom-double',y=-15,z=-4,cull=true},
 {name='oblique-default',y=10,z=-8,cull=false},{name='oblique-double',y=10,z=-8,cull=true}}
local gate,scene,cameraNode,camera=nil,nil,nil,nil
local items,clones={},{}
local index,frames=1,0
local ready,sent,finished=false,false,false
local function Emit(kind,row)print('ROTOR_DISC_'..kind..' '..cjson.encode(row))end
local function Vec(v)return {v.x,v.y,v.z}end
local function Projected(item)
 local lo,hi=Vector2(1,1),Vector2(0,0)
 local size={0,0,0}
 for _,slot in ipairs(item.slots)do
  local box=slot.model.worldBoundingBox
  local b=slot.model.model.boundingBox.size;size={b.x,b.y,b.z}
  for _,x in ipairs({box.min.x,box.max.x})do for _,y in ipairs({box.min.y,box.max.y})do for _,z in ipairs({box.min.z,box.max.z})do
   local p=camera:WorldToScreenPoint(Vector3(x,y,z))
   lo=Vector2(math.min(lo.x,p.x),math.min(lo.y,p.y));hi=Vector2(math.max(hi.x,p.x),math.max(hi.y,p.y))
  end end end
 end
 return {lo.x,lo.y,hi.x,hi.y},size
end
local function Stage()
 local stage=stages[index]
 cameraNode.position=Vector3(0,stage.y,stage.z)
 cameraNode:LookAt(Vector3.ZERO)
 for _,item in ipairs(items)do for _,slot in ipairs(item.slots)do
  slot.model:SetMaterial(slot.index,stage.cull and slot.double or slot.original)
 end end
 frames=0;sent=false
end
local function Build()
 scene=Scene();scene:CreateComponent('Octree')
 local zone=scene:CreateChild('Zone'):CreateComponent('Zone')
 zone.boundingBox=BoundingBox(-100,100);zone.ambientColor=Color(.6,.6,.6)
 zone.fogColor=Color(.01,.01,.01);zone.depthFogStart=50;zone.depthFogEnd=100
 local sunNode=scene:CreateChild('Sun');sunNode.direction=Vector3(.5,-1,.4)
 local sun=sunNode:CreateComponent('Light');sun.lightType=LIGHT_DIRECTIONAL;sun.color=Color(.8,.8,.8);sun.castShadows=false
 local bottom=scene:CreateChild('BottomSun');bottom.direction=Vector3(.5,1,.4)
 local lamp=bottom:CreateComponent('Light');lamp.lightType=LIGHT_DIRECTIONAL;lamp.color=Color(.8,.8,.8);lamp.castShadows=false
 cameraNode=scene:CreateChild('Camera');camera=cameraNode:CreateComponent('Camera')
 camera.farClip=100;camera.orthographic=true;camera.orthoSize=11
 renderer:SetViewport(0,Viewport:new(scene,camera))
 for row,kind in ipairs(types)do for column=1,2 do
  local x=column==1 and -4 or 4
  local part={id=row*10+column,type=kind,pos={x,0,0},rot=Rot.IDENTITY,color=0x7a91ad}
  local view=View.New(scene,'Rotor'..part.id);local vis=view:AddPart(part)
  assert(vis.head and #vis.models>0,'Authored rotor head/model missing')
  local angle=.8;local physics={spec={rotorOf={}},rotors={{partId=part.id,prev=angle,angle=angle,sign=x<0 and -1 or 1,pivot={0,0,0},axis={0,1,0}}}}
  local motion=RotorView.New(view,physics);motion:Update(1)
  -- Isolate the authored head so a base cannot conceal a culling defect.
  vis.node.position=Vector3.ZERO;view.root.position=Vector3((column-1.5)*4,0,(row-2)*3)
  local slots={}
  for _,model in ipairs(vis.models)do
   model.castShadows=false
   if model.node==vis.head then
    for n=0,model.numGeometries-1 do
     local original=assert(model:GetMaterial(n));local copy=original:Clone();copy.cullMode=CULL_NONE
     assert(copy.cullMode==CULL_NONE,'Double-sided diagnostic must apply')
     clones[#clones+1]=copy;slots[#slots+1]={model=model,index=n,original=original,double=copy}
    end
   else model.enabled=false end
  end
  assert(#slots>0,'Head slots missing')
  items[#items+1]={view=view,vis=vis,part=part,slots=slots}
 end end
 ready=true;Stage()
end
function Start()
 SubscribeToEvent('Update','RotorDiscRenderUpdate')
 local parts={};for _,kind in ipairs(types)do parts[#parts+1]={type=kind,rot=Rot.IDENTITY}end
 gate=Gate.New();gate:Start(Dependencies.For(parts),function(ok,message)assert(ok,tostring(message));Build()end)
end
function RotorDiscRenderUpdate(_,eventData)
 if finished then return end
 local ok,message=pcall(function()
  Gate.UpdatePending(eventData:GetFloat('TimeStep'));if not ready then return end
  frames=frames+1
  if not sent and frames>=15 then
   local rows={};local stage=stages[index]
   for _,item in ipairs(items)do
    local vis=item.vis;local p=camera:WorldToScreenPoint(vis.head.worldPosition)
    local normal=vis.head.worldRotation*Vector3.UP
    local toCamera=(cameraNode.worldPosition-vis.head.worldPosition):Normalized()
    local incidence=math.abs(normal.x*toCamera.x+normal.y*toCamera.y+normal.z*toCamera.z)
    assert(incidence>=.6,'Rotor authored face must point sufficiently toward actual camera')
    local bounds,size=Projected(item)
    local culls={};for _,slot in ipairs(item.slots)do culls[#culls+1]=slot.model:GetMaterial(slot.index).cullMode end
    rows[#rows+1]={id=item.part.id,type=item.part.type,sourceX=item.part.pos[1],rot=item.part.rot,scale=Vec(vis.head.scale),
     angle=vis.rotorAngle,sign=vis.rotorSign,screen={p.x,p.y},slots=#item.slots,culls=culls,
     world=Vec(vis.head.worldPosition),normal=Vec(normal),incidence=incidence,bounds=bounds,modelSize=size}
    assert(vis.head.scale.x==(item.part.pos[1]<0 and -1 or 1),'Production mirror must survive real binding')
   end
   sent=true;Emit('CAMERA',{stage=stage.name,position=Vec(cameraNode.worldPosition),direction=Vec(cameraNode.worldDirection),
    rotation={cameraNode.worldRotation.w,cameraNode.worldRotation.x,cameraNode.worldRotation.y,cameraNode.worldRotation.z},orthoSize=camera.orthoSize,identityRotation=Rot.IDENTITY})
   Emit('SNAPSHOT',{stage=stage.name,frames=frames,rows=rows,cullNone=CULL_NONE,fixture=true})
  elseif sent and input:GetKeyPress(KEY_F8)then
   index=index+1
   if index>#stages then
    renderer:SetViewport(0,nil)
    for _,item in ipairs(items)do item.view:Dispose()end;items={}
    scene:Dispose();scene=nil
    for _,material in ipairs(clones)do material:Dispose()end;clones={}
    finished=true;Emit('DONE',{status='PASS',stages=#stages,released=true,
     boundary='Actual production head meshes/transforms. Synthetic diagnostic poses, no complete flight, damage, natural input or performance acceptance. Double-sided stages are fixture-only.'})
   else Stage()end
  end
 end)
 if not ok then finished=true;Emit('DONE',{status='FAIL',error=tostring(message)})end
end
function Stop()
 UnsubscribeFromEvent('Update');if gate then gate:Cancel()end
 if scene then renderer:SetViewport(0,nil);scene:Dispose();scene=nil end
 for _,material in ipairs(clones)do material:Dispose()end;clones={}
end
