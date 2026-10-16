local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Wing=require 'drive.WingControl'
local ROOT='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/g1-ground-damage-20261016/'
local function Clone(v) return cjson.decode(cjson.encode(v)) end
local function Read(path) local f=assert(io.open(path,'rb'));local t=cjson.decode(f:read('*a'));f:close();return t end
local function Pose(v) local b=v.body;return {p=b.translation(),q=b.rotation(),lv=b.linvel(),av=b.angvel()} end
local function Run()
 local input=Read(ROOT..'native-snapshot/native-ground-result.json');local rows={}
 for _,row in ipairs(input.rows) do if row.name=='takeoff' then
  local checkpoints=row.id=='feather' and {133,150,180,210,240,280,300,360,420,480} or {180,240,360}
  for _,checkpoint in ipairs(checkpoints) do for _,mode in ipairs({'free','wing','full'}) do
   local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
   local floor=scene:CreateChild('ProbeGround');floor.position=Vector3(0,-1,0)
   local ground=floor:CreateComponent('RigidBody');ground.friction=.8;ground.restitution=0;ground.collisionLayer=1;ground.collisionMask=0xffff
   floor:CreateComponent('CollisionShape'):SetBox(Vector3(1000,2,1000));space:Register(ground,{type='ground'})
   local v=Vehicle.New(space,Spec.Build(Prefab.Create(BP.New(),row.id)))
   local seed=Clone(row.samples[checkpoint].state);seed.steer=0;seed.hoverHeightScale=1;v:SetState(seed)
   local calls={};local totalForce={x=0,y=0,z=0};local totalAlpha={x=0,y=0,z=0}
   for _,name in ipairs({'addForce','addTorque','addForceAtPoint','addFlightAngularAcceleration','applyImpulse','applyImpulseAtPoint','applyTorqueImpulse'}) do
    local fn=v.body[name]
    if fn then v.body[name]=function(a,b,c)
     calls[#calls+1]={method=name,value=Clone(a),point=type(b)=='table' and Clone(b) or nil}
     if name=='addForce' then for _,k in ipairs({'x','y','z'}) do totalForce[k]=totalForce[k]+a[k] end end
     if name=='addFlightAngularAcceleration' then for _,k in ipairs({'x','y','z'}) do totalAlpha[k]=totalAlpha[k]+a[k] end end
     return fn(a,b,c)
    end end
   end
   local r={id=row.id,checkpoint=checkpoint,mode=mode,seed=Clone(seed),before=Clone(Pose(v)),linearDamping=v.native.linearDamping,angularDamping=v.native.angularDamping}
   local cmd={throttle=1,steer=0,climb=1,strafe=0,handbrake=false,boost=false}
   if mode=='wing' then r.telemetry=Wing.Step(v,cmd,1/60,0,0)
   elseif mode=='full' then v:StepRotors(nil,false,1/60);v:Step(cmd,1/60);r.telemetry=Clone(v.telemetry) end
   r.afterVehicle=Clone(Pose(v));r.calls=calls;r.totalForce=totalForce;r.totalAlpha=totalAlpha;r.wing=Clone(v.wingState)
   if v.flightResponse then r.response={com=v.flightResponse.com,inertia=v.flightResponse.inertia,inverse=v.flightResponse.inverse} end
   space:Step(1/60);r.afterPhysics=Clone(Pose(v));rows[#rows+1]=r
   v:Dispose();space:Dispose();scene:Dispose()
  end end
 end end
 return {status='PASS',timeStep=1/60,rows=rows}
end
function Start()
 local ok,r=xpcall(Run,debug.traceback);if not ok then r={status='FAIL',error=tostring(r)};print(r.error) end
 local f=assert(io.open(ROOT..'native-climb-result.json','wb'));f:write(cjson.encode(r));f:close();engine:Exit()
end
