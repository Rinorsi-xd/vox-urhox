local function Copy(v) return {x=v.x,y=v.y,z=v.z} end
local function Mul(a,b) return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w} end
local function Axis(a,v) local s=math.sin(a/2);return {w=math.cos(a/2),x=v[1]*s,y=v[2]*s,z=v[3]*s} end
local function Reset(v,q)
 v.body.setTranslation({x=0,y=80,z=0});v.body.setRotation(q);v.body.setLinvel({x=0,y=0,z=0});v.body.setAngvel({x=0,y=0,z=0});v.body.resetForces()
end
local function Run()
 local BP=require 'construction.Blueprint';local Prefab=require 'construction.Prefab';local Spec=require 'drive.VehicleSpec';local Vehicle=require 'drive.Vehicle';local Space=require 'physics.Space'
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene);space.world.gravity=Vector3.ZERO;local rows={}
 local rotations={{name='identity',q={w=1,x=0,y=0,z=0}},{name='yaw0.7',q=Axis(.7,{0,1,0})},{name='yaw0.7_pitch0.4_roll-0.5',q=Mul(Mul(Axis(.7,{0,1,0}),Axis(.4,{1,0,0})),Axis(-.5,{0,0,1}))}}
 for _,id in ipairs({'feather','hawk','raceCar'}) do
  local bp=Prefab.Create(BP.New(),id);local spec=Spec.Build(bp);local v=Vehicle.New(space,spec);v:Place({0,80,0},0)
  local r={id=id,wings=#spec.wings,mass=v.native.mass,com=Copy(v.native:GetCenterOfMass()),damping=v.native.angularDamping,linearDamping=v.native.linearDamping,helperAvailable=type(v.body.addFlightAngularAcceleration),requests={},dampingSamples={}}
  v.native.angularDamping=0;v.native.linearDamping=0;v.native.useGravity=false
  for _,rot in ipairs(rotations) do
   for _,alpha in ipairs({{x=1,y=0,z=0},{x=0,y=1,z=0},{x=0,y=0,z=1},{x=.5,y=-.7,z=1.2}}) do
    for _,scoped in ipairs({false,true}) do
     Reset(v,rot.q)
     if scoped then v.body.beginReadScope() end
     v.body.addFlightAngularAcceleration(alpha)
     if scoped then v.body.endReadScope() end
     space:Step(1/60);local actual=v.body.angvel();local expected={x=alpha.x/60,y=alpha.y/60,z=alpha.z/60}
     local err=math.max(math.abs(actual.x-expected.x),math.abs(actual.y-expected.y),math.abs(actual.z-expected.z))
     r.requests[#r.requests+1]={rotation=rot.name,q=rot.q,alpha=alpha,scoped=scoped,expected=expected,actual=actual,maxAbsoluteError=err,pass=err<.000001}
    end
   end
  end
  Reset(v,{w=1,x=0,y=0,z=0});v.native.angularDamping=r.damping;v.body.setAngvel({x=1,y=0,z=0})
  for s=1,120 do space:Step(1/60);if s==1 or s==30 or s==60 or s==120 then
   local expected=(1+.6/60)^(-s);local actual=v.body.angvel()
   r.dampingSamples[#r.dampingSamples+1]={step=s,expectedRapierFormula=expected,actual=actual,errorX=actual.x-expected}
  end end
  rows[#rows+1]=r;v:Dispose()
 end
 space:Dispose();scene:Dispose();return {status='PASS',runtime='0.9.0-beta.40_20261015.121839.6dc5c357cced',rows=rows}
end
function Start()
 local ok,r=xpcall(Run,debug.traceback);if not ok then r={status='FAIL',error=tostring(r)};print(r.error) end
 local f=assert(io.open('D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/flight-parity-20261016/native-helper-result.json','wb'));f:write(cjson.encode(r));f:close();engine:Exit()
end
