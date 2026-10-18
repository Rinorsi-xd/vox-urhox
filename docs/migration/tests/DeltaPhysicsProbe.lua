local checks=0
local function Check(ok,label) assert(ok,label);checks=checks+1;print('[DELTA] PASS '..label) end
function Start()
 local ok,err=xpcall(function()
  local Space=require 'physics.Space';local Camera=require 'controls.CameraCollision';local Slide=require 'drive.ObstacleSlide'
  local scene=Scene();local space=Space.New(scene)
  local function Box(name,pos,size,mass,offset,layer)
   local n=scene:CreateChild(name);n.position=pos
   local b=n:CreateComponent('RigidBody');b.mass=mass or 0;b.collisionLayer=layer or 1
   local sh=n:CreateComponent('CollisionShape');sh:SetBox(size,offset or Vector3.ZERO)
   return n,b,sh
  end
  local wall,wb=Box('Wall',Vector3(0,2,5),Vector3(20,4,1))
  local car,cb,shape=Box('Car',Vector3(0,2,0),Vector3(1,1,1),100,nil,2)
  local v={native=cb,node=car,space=space}
  local hit=Camera.Cast(space,{0,2,0},{0,0,1},10,cb)
  Check(hit and math.abs(hit-4.15)<.05,'sphere hits wall before center: '..tostring(hit))
  Check(cb.collisionLayer==2,'camera restores excluded body layer')
  Check(not Slide.Clear(v,{0,0,0},{0,0,8}),'chassis sweep blocks thick wall crossing')
  Check(Slide.Clear(v,{0,0,0},{0,0,3}),'chassis sweep allows clear segment')
  Check(not Slide.Clear(v,{0,0,0},{0,0,4.6}),'chassis sweep rejects endpoint inside wall')
  local ground,gb=Box('Ground',Vector3(0,1.04,0),Vector3(30,1,30))
  Check(not Slide.Clear(v,{0,0,0},{0,0,8}),'wall sweep remains blocked with initial floor penetration')
  ground:Dispose()
  shape.position=Vector3(0,0,2)
  local h=space.world:ConvexCast(shape,cb.position,cb.rotation,cb.position+Vector3(0,0,8),cb.rotation,1)
  print('[DELTA] offset raw sweep hit '..tostring(h.distance))
  Check(not Slide.Clear(v,{0,0,0},{0,0,2.2}),'offset chassis shape blocks early')
  Check(Slide.Clear(v,{0,0,0},{0,0,1}),'offset chassis permits safe movement')
  shape.position=Vector3.ZERO
  local soft,sb=Box('PassRock',Vector3(0,2,2),Vector3(1,1,1),0,nil,0x1000)
  Check(math.abs(Camera.Cast(space,{0,2,0},{0,0,1},10,cb)-4.15)<.05,'camera passes drive-through rock')
  sb.collisionLayer=8
  Check(math.abs(Camera.Cast(space,{0,2,0},{0,0,1},10,cb)-4.15)<.05,'camera ignores debris')
  sb.collisionLayer=4;sb.trigger=true
  Check(math.abs(Camera.Cast(space,{0,2,0},{0,0,1},10,cb)-4.15)<.05 and sb.collisionLayer==4,'camera ignores sensor and restores it')
  sb.collisionLayer=0x8000
  Check(Camera.Cast(space,{0,2,0},{0,0,1},10,cb)<2,'camera respects camera-only surface')
  Slide.Install(v);space:Register(cb,{type='test'});v.staticContacts={}
  cb.position=Vector3(0,2,4.3);space:Step(1/60)
  Check(#v.staticContacts>0,'NodeCollision callback reads real static contacts')
  local normal=v.staticContacts[1].normal
  Check(normal[3]<-.5,'collision normal points away from wall')

  local s2=Scene();local sp=Space.New(s2)
  local floor=s2:CreateChild('Floor');local fb=floor:CreateComponent('RigidBody');fb.collisionLayer=1
  floor.position=Vector3(0,-.5,0);floor:CreateComponent('CollisionShape'):SetBox(Vector3(300,1,300))
  local BP=require 'construction.Blueprint';local Spec=require 'drive.VehicleSpec';local Vehicle=require 'drive.Vehicle'
  local source=require('core.ResourceData').Read('Salvage/RunData.json').enemies.manta[1].source
  local hover=Vehicle.New(sp,Spec.Build(BP.New():Load(source)));hover:Place({0,5,0},0)
  Check(hover.hoverMode,'manta uses real hover chassis')
  for i=1,240 do hover:Step({throttle=0,steer=0},1/60);sp:Step(1/60) end
  local y=hover.body.translation().y
  Check(y>0 and y<8,'hover stabilizes above floor: '..y)
  local yaw=hover:Yaw()
  for i=1,90 do hover:Step({throttle=0,steer=.7},1/60);sp:Step(1/60) end
  Check(math.abs(hover:Yaw()-yaw)>.3,'hover A/D rotates in place')
  local from=hover.body.translation()
  for i=1,90 do hover:Step({throttle=0,steer=0,strafe=1},1/60);sp:Step(1/60) end
  local to=hover.body.translation()
  Check(math.sqrt((to.x-from.x)^2+(to.z-from.z)^2)>2,'hover Q/E produces lateral travel')
  hover:Place({0,20,0},0);hover.native.rotation=Quaternion(70,Vector3.RIGHT)
  for i=1,120 do hover:Step({throttle=0,steer=0},1/60);sp:Step(1/60) end
  Check((hover.native.rotation*Vector3.UP).y>.7,'hover recovers pitch without ground-ray support')
  local slide=require 'drive.ObstacleSlide';local Config=require 'Config';Config.OBSTACLE_SLIDE=false
  slide.Prepare(hover,{throttle=1},1/60,{up={0,1,0},fwd={0,0,1}})
  Check(hover.slideBefore==nil,'experimental slide switch disables correction');Config.OBSTACLE_SLIDE=true
  hover.telemetry={contact=0,hovers=0,legContacts=0};hover.slideStep=nil
  slide.Prepare(hover,{throttle=1},1/60,{up={0,1,0},fwd={0,0,1}})
  Check(hover.slideBefore==nil,'airborne craft cannot initiate obstacle correction')
  hover:Dispose()
  local racer=Vehicle.New(sp,Spec.Build(BP.New():Load(require('core.ResourceData').Read('Salvage/RunData.json').enemies.racer[1].source)))
  local function Trial(boosting)
   racer:Place({0,3,0},0)
   for i=1,180 do racer:Step({throttle=0,steer=0},1/60);sp:Step(1/60) end
   local peak=0;local active=false
   for i=1,90 do
    racer:Step({throttle=1,steer=0,groundBoost=boosting},1/60);sp:Step(1/60)
    peak=math.max(peak,racer.telemetry.totalSpeed or 0);active=active or racer.telemetry.groundBoost
   end
   return peak,active
  end
  local normal=Trial(false);local boosted,active=Trial(true)
  Check(active and boosted>normal*1.1,'native ground boost increases speed: '..normal..' -> '..boosted)
  Check(racer.groundBoost.left<racer.groundBoost.tuning.duration,'native boost spends reserve')
  racer:Dispose();sp:Dispose();s2:Dispose()

  local s3=Scene();local sp3=Space.New(s3)
  local floor=s3:CreateChild('Floor');floor.position=Vector3(0,-.5,0);floor:CreateComponent('RigidBody').collisionLayer=1
  floor:CreateComponent('CollisionShape'):SetBox(Vector3(20,1,20))
  local step=s3:CreateChild('LowStep');step.position=Vector3(0,.1,1);step:CreateComponent('RigidBody').collisionLayer=1
  step:CreateComponent('CollisionShape'):SetBox(Vector3(4,.2,1))
  local car=s3:CreateChild('SlideCar');car.position=Vector3(0,.65,.03)
  local native=car:CreateComponent('RigidBody');car:CreateComponent('CollisionShape'):SetBox(Vector3.ONE);native.mass=100;native.collisionLayer=2
  local cv={native=native,node=car,space=sp3,body=sp3:Register(native,{type='test'}),telemetry={},wheels={{radius=.5}},spec={bounds={min={-.5,-.5,-.5},max={.5,.5,.5}}}}
  slide.Install(cv);sp3:Step(1/60)
  cv.slideBefore={dt=1/60,wish={0,0,1},velocity={0,0,3},expected={x=0,y=0,z=0}}
  local old=native.position;slide.Finish(cv);local now=native.position
  Check(cv.telemetry.obstacleSlide=='step' and now.y>old.y and now.z>old.z,'contact correction climbs a 20 cm step')
  Check(now.y-old.y<=.251,'step height is bounded')
  print('[DELTA] PHYSICS PASS '..checks)
 end,debug.traceback)
 if not ok then print('[DELTA] FAIL '..tostring(err)) end
 engine:Exit()
end
