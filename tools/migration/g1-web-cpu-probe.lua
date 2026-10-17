-- Dedicated QA entrypoint. It never starts App, TrialSession, UI or audio.
local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Gait=require 'drive.LegGait'
local Legs=require 'drive.LegControl'
local Suspension=require 'drive.RaySuspension'
local Config=assert(G1_WEB_CPU_CONFIG,'Dedicated CPU QA configuration required')
local clock=function()return Time:GetSystemTime()end
local function Hash()
 local value=0xcbf29ce484222325
 local function Bytes(s)for i=1,#s do value=(value~s:byte(i))*0x100000001b3 end end
 local function Add(x)
  if cjson.null~=nil and x==cjson.null then Bytes('null');return end
  local t=type(x)
  if t=='number'then Bytes('n'..string.pack('<d',x))
  elseif t=='string'then Bytes('s'..#x..':'..x)
  elseif t=='boolean'then Bytes(x and 't'or'f')
  elseif t=='nil'then Bytes('nil')
  elseif t=='table'then
   local keys={};for k in pairs(x)do keys[#keys+1]=k end
   table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
   Bytes('{');for _,k in ipairs(keys)do Add(k);Add(x[k])end;Bytes('}')
  else error('Unsupported digest type '..t)end
 end
 return {add=Add,get=function()return string.format('%016x',value)end}
end
local function Instrument()
 local rows,stack,restores={},{},{}
 local function Wrap(object,key,name)
  local old=assert(object[key]);local row={name=name,calls=0,ms=0,selfMs=0};rows[#rows+1]=row
  object[key]=function(...)
   local scope={children=0};stack[#stack+1]=scope;local at=clock()
   local result=table.pack(old(...));local elapsed=(clock()-at)&0xffffffff
   stack[#stack]=nil;row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-scope.children
   if #stack>0 then stack[#stack].children=stack[#stack].children+elapsed end
   return table.unpack(result,1,result.n)
  end
  restores[#restores+1]=function()object[key]=old end
 end
 for _,entry in ipairs({{Vehicle,'Step','vehicle.Step'},{Vehicle,'PostStep','vehicle.PostStep'},
  {Vehicle,'StepRotors','vehicle.StepRotors'},{Space,'Step','physics.Step'},{Space,'Raycast','physics.Raycast'},
  {Gait,'Step','gait.Step'},{Gait,'Foothold','gait.Foothold'},
  {Legs,'Step','leg.Step'},{Legs,'Cast','leg.Cast'},{Legs,'Clear','leg.Clear'},
  {Legs,'Reachable','leg.Reachable'},{Legs,'Target','leg.Target'},
  {Suspension,'Sample','suspension.Sample'},{Suspension,'Apply','suspension.Apply'}})do Wrap(table.unpack(entry))end
 return rows,function()assert(#stack==0,'CPU scopes unclosed');for _,restore in ipairs(restores)do restore()end end
end
local function Fixture()
 math.randomseed(Config.seed)
 local scene=Scene();scene:CreateComponent('Octree')
 local world=nil ---@type table?
 local space=nil ---@type table?
 local map={kind=Config.scenario,initializationMs=0}
 local started=clock()
 if Config.scenario=='crater'then
  local CraterWorld=require 'drive.CraterWorld'
  local CraterPhysics=require 'drive.CraterPhysics'
  world=CraterWorld.New(scene,true);space=world.space
  local lastYield=clock()
  CraterPhysics.Build(world,function()if ((clock()-lastYield)&0xffffffff)>=8 then coroutine.yield();lastYield=clock()end end)
  local count=0;for _ in pairs(space.bodies)do count=count+1 end
  local authored=0;for _,block in ipairs(world.layout.blocks)do if not block.noPhysics then authored=authored+1 end end
  local chunks=math.ceil(world.layout.terrain.n/32)^2
  assert(count==chunks+authored+world.boulderCount,'Observed crater registrations must match authored collision build')
  map.bodies=count;map.terrainChunks=chunks;map.authored=authored;map.boulders=world.boulderCount;map.cameraBodies=world.cameraObstacleCount
 else space=Space.New(scene)end
 -- Source lanes mirror X at the engine boundary. Floor supports suspension;
 -- 0.4 m step and 8 m wall exercise stance, swings and clipping identically.
 local function Box(name,x,y,z,sx,sy,sz)
  local node=scene:CreateChild(name);node.position=Vector3(-x,y,z)
  local body=node:CreateComponent('RigidBody');body.friction=.8;body.collisionLayer=1;body.collisionMask=0xffff
  node:CreateComponent('CollisionShape'):SetBox(Vector3(sx,sy,sz));space:Register(body,{type='ground'})
 end
 if Config.scenario~='crater'then Box('floor',0,-1,0,4000,2,4000)end
 local cars,metadata={},{}
 for _,team in ipairs({'blue','red'})do for _,role in ipairs({'assault','heavy','sniper'})do
  local bp=BP.New():Load(assert(Data.prefabs[team..':3:'..role..':0']));local spec=Spec.Build(bp);assert(spec.ok)
  local v=Vehicle.New(space,spec);local index=#cars+1;local x=#cars*100;local spawn={x,0,0};local yaw=0
  if world then
   x=((index%4)-1.5)*18;local z=-140+(team=='blue'and -20 or 20)
   spawn={x,world:GroundAt(x,z)+2,z};yaw=team=='blue'and 0 or math.pi
  end
  v:Place(spawn,yaw);cars[#cars+1]=v
  metadata[#metadata+1]={team=team,role=role,mass=v.mass,wheels=#v.wheels,legs=#spec.legs,spawn=spawn,yaw=yaw}
  if not world then Box('step'..#cars,x,.2,22,20,.4,1);Box('wall'..#cars,x,4,45,20,8,1)end
 end end
 map.initializationMs=(clock()-started)&0xffffffff
 if not world then map.bodies=13 end
 print('G1_WEB_CPU_MAP '..cjson.encode(map))
 local function Step(index)
  local cmd={throttle=index%240<180 and .6 or -.4,steer=math.sin(index/120)*.35,
   handbrake=index%180>160,jump=index%300==0,climb=0,strafe=index%500>400 and .2 or 0}
  for _,v in ipairs(cars)do v:StepRotors(nil,false,1/60);v:Step(cmd,1/60)end
  space:Step(1/60)
 end
 local function Snapshot(index)
  local out={step=index,cars={}}
  for _,v in ipairs(cars)do
   local boxes={};for _,b in ipairs(v.legHitboxes.items)do boxes[#boxes+1]={partId=b.partId,name=b.name,center=b.center,quat=b.quat,half=b.half}end
   out.cars[#out.cars+1]={state=v:GetState(),telemetry=v.telemetry,legs=v.legControl and v.legControl:Snapshot()or false,boxes=boxes}
  end
  return out
 end
 return {step=Step,snapshot=Snapshot,metadata=metadata,map=map,dispose=function()
  for _,v in ipairs(cars)do v:Dispose()end
  if world then world:Dispose()else space:Dispose()end
  scene:Dispose()
 end,cars=cars}
end
---@type thread
local worker=nil
local emitted=false
local function Emit(result)
 if emitted then return end;emitted=true
 local bytes=cjson.encode(result);local count=math.ceil(#bytes/3500)
 for index=1,count do print('G1_WEB_CPU_CHUNK '..cjson.encode({index=index,count=count,data=bytes:sub((index-1)*3500+1,index*3500)}))end
end
local function Run()
 if Config.scenario=='damage'then
  local result={status='PASS',configuration=Config,damage=G1_WEB_CPU_DAMAGE.Run(Config,Hash,clock)}
  Emit(result);return
 end
 local fixture=Fixture();local digest=Hash();local rayDigest=Hash();local rays=0;local snapshots={};local samples={};local rows={};local restore=function()end
 for index=1,Config.warmup do coroutine.yield();fixture.step(index)end
 collectgarbage('collect')
 if Config.mode=='profile'then rows,restore=Instrument()end
 local originalRay=Space.Raycast
 if Config.mode=='equivalence'then
  local owners={};for i,v in ipairs(fixture.cars)do owners[v.body]=i;owners[v]=i end
  Space.Raycast=function(self,origin,direction,length,excluded,skipOwnerType,fixedOnly,mask)
   local hit=originalRay(self,origin,direction,length,excluded,skipOwnerType,fixedOnly,mask);rays=rays+1
   rayDigest.add({origin=origin,direction=direction,length=length,excluded=owners[excluded]or false,
    skipOwnerType=skipOwnerType,fixedOnly=fixedOnly,mask=mask,
    hit=hit and {distance=hit.dist,point=hit.point,normal=hit.normal,ownerType=hit.owner and hit.owner.type,
     ownerIndex=hit.owner and owners[hit.owner.ref]}or false})
   return hit
  end
 end
 local total=0
 for index=1,Config.steps do
  coroutine.yield()
  local step=Config.warmup+index;local at=clock();fixture.step(step);local elapsed=(clock()-at)&0xffffffff
  total=total+elapsed;samples[index]=elapsed
  if Config.mode=='equivalence'or index%Config.snapshotEvery==0 then
   local sample=fixture.snapshot(step);digest.add(sample)
   if index%Config.snapshotEvery==0 then snapshots[#snapshots+1]=sample end
  end
 end
 restore()
 Space.Raycast=originalRay
 local tail={};for i=1,32 do tail[i]=math.random()end
 local result={status='PASS',configuration=Config,steps=Config.steps,fixedDt=1/60,vehicles=6,
  expectedVehicleStepCalls=Config.steps*6,expectedPhysicsSteps=Config.steps,totalMs=total,msPerStep=total/Config.steps,
  samplesMs=samples,scopes=rows,metadata=fixture.metadata,map=fixture.map,stateDigest=digest.get(),snapshots=snapshots,randomTail=tail,
  rayEquivalence=Config.mode=='equivalence'and {calls=rays,digest=rayDigest.get()}or false,
  boundary='Dedicated Web QA entrypoint. One fixed six-vehicle step per actual Update event. Timer contains Vehicle.StepRotors/Step and Bullet Space.Step only. No App/Trial/AI/firing/render/audio/UI workload. Timing mode has no wrappers. Integer wall clock includes preemption/GC/bindings and is not exact CPU time or whole-frame/FPS/mobile acceptance. Profile parents overlap children. Equivalence hashes full listed snapshot every step outside timer.'}
 fixture.dispose();Emit(result)
end
function Start()
 assert(Config.mode=='timing'or Config.mode=='profile'or Config.mode=='equivalence','Unknown CPU QA mode')
 assert(Config.scenario=='lanes'or Config.scenario=='crater'or Config.scenario=='damage','Unknown CPU QA scenario')
 assert(Config.steps>=60 and Config.steps<=1200 and Config.warmup>=0 and Config.warmup<=300,'CPU QA bounds')
 assert(Config.snapshotEvery>=1 and Config.steps%Config.snapshotEvery==0,'Snapshot cadence')
 worker=coroutine.create(Run)
 SubscribeToEvent('Update','G1WebCpuUpdate')
 print('G1_WEB_CPU_READY '..cjson.encode(Config))
end
function G1WebCpuUpdate()
 if not worker or coroutine.status(worker)=='dead'then return end
 local ok,error=coroutine.resume(worker)
 if not ok then Emit({status='FAIL',configuration=Config,error=tostring(error)})end
end
