local function Copy(v) return {x=v.x,y=v.y,z=v.z} end
local function Snap(v)
 local b=v.body;return cjson.decode(cjson.encode({p=b.translation(),q=b.rotation(),lv=b.linvel(),av=b.angvel(),wing=v.wingState,telemetry=v.telemetry}))
end
local function Command(throttle,steer,climb) return {throttle=throttle,steer=steer,climb=climb,strafe=0,handbrake=false,boost=false} end
local function Run()
 local BP=require 'construction.Blueprint';local Prefab=require 'construction.Prefab';local Spec=require 'drive.VehicleSpec';local Vehicle=require 'drive.Vehicle';local Space=require 'physics.Space'
 local rows={}
 for _,id in ipairs({'feather','hawk','raceCar'}) do
  local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
  local bp=Prefab.Create(BP.New(),id);local spec=Spec.Build(bp);assert(spec.ok,'invalid '..id);local v=Vehicle.New(space,spec)
  local r={id=id,blueprint=bp:ToTable(),mass=v.mass,nativeMass=v.native.mass,nativeComSource=v.body.localCom(),localComNative=Copy(v.native.centerOfMass),linearDamping=v.native.linearDamping,angularDamping=v.native.angularDamping,spec={boxes=spec.boxes,hulls=spec.hulls,wheels=spec.wheels,wings=spec.wings,thrusters=spec.thrusters,motion=spec.motion,bounds=spec.bounds},impulse={},segments={}}
  for _,yaw in ipairs({0,.7}) do
   v:Place({0,80,0},yaw);local e={yaw=yaw,rotation=v.body.rotation(),axes={}}
   for a=1,3 do
    v.body.setAngvel({x=0,y=0,z=0});v.body.resetForces();local j={x=a==1 and 1 or 0,y=a==2 and 1 or 0,z=a==3 and 1 or 0}
    v.body.applyTorqueImpulse(j);e.axes[#e.axes+1]={sourceTorqueImpulse=j,sourceAngularVelocity=v.body.angvel(),nativeAngularVelocity=Copy(v.native.angularVelocity)}
   end
   r.impulse[#r.impulse+1]=e
  end
  space.world.gravity=Vector3.ZERO;v:Place({0,80,0},0);v.wingState=nil;v.body.setAngvel({x=1,y=0,z=0});r.freeDamping={initial=Snap(v),samples={}}
  for s=1,120 do space:Step(1/60);if s==1 or s==30 or s==60 or s==120 then r.freeDamping.samples[#r.freeDamping.samples+1]={step=s,state=Snap(v)} end end
  space.world.gravity=Vector3(0,-9.81,0)
  local scenarios={{name='neutral',speed=26},{name='steerRight',speed=26,steer=1},{name='pitchUp',speed=26,climb=1},{name='cruise',speed=26,throttle=1},{name='steerRelease',speed=26,steer=1,release=60},{name='climbRelease',speed=26,climb=1,release=60},{name='reverse',speed=26,throttle=-1},{name='lowSpeed',speed=2}}
  if id=='raceCar' then scenarios={{name='nonWingNeutral',speed=26},{name='nonWingDrive',speed=26,throttle=1,steer=.3}} end
  for _,e in ipairs(scenarios) do
   v:Place({0,80,0},0);v.wingState=nil;v.body.setTranslation({x=0,y=80,z=0});v.body.setLinvel({x=0,y=0,z=e.speed})
   local segment={name=e.name,initial=Snap(v),samples={},commands={}}
   for s=1,120 do
    local active=not e.release or s<=e.release;local cmd=Command(e.throttle or 0,active and (e.steer or 0) or 0,active and (e.climb or 0) or 0)
    segment.commands[s]=cmd;segment.command=segment.command or cmd
    v:StepRotors(nil,false,1/60);v:Step(cmd,1/60);space:Step(1/60)
    segment.samples[#segment.samples+1]={step=s,state=Snap(v)}
   end
   r.segments[#r.segments+1]=segment
  end
  rows[#rows+1]=r;v:Dispose();space:Dispose();scene:Dispose()
 end
 return {result='PASS',timeStep=1/60,steps=120,rows=rows,runtime='0.9.0-beta.40_20261015.121839.6dc5c357cced',coordinates='H5 source through Body axial/polar conversion',scope='Native actual Vehicle empty fresh world per prefab, no map/render, segment wing cleared, all 120 steps retained'}
end
function Start()
 local ok,r=xpcall(Run,debug.traceback);if not ok then r={result='FAIL',error=tostring(r)};print(r.error) end
 local f=assert(io.open('native-motion-result.json','wb'));f:write(cjson.encode(r));f:close();engine:Exit()
end
