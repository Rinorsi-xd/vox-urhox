local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Baseline=require 'perf-suspension-baseline'
local Candidate=require 'drive.RaySuspension'
local Math=require 'core.Math3'
local Rotors=require 'construction.Rotors'
local output='';local mode='baseline'
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output;mode=arg:match('^%-probe%-mode=(.+)$') or mode end
local class=mode=='candidate' and Candidate or Baseline
local function Hash()
 local value=0xcbf29ce484222325
 local function Bytes(bytes) for i=1,#bytes do value=(value~bytes:byte(i))*0x100000001b3 end end
 local function Add(v)
  local kind=type(v)
  if kind=='number' then Bytes('n'..string.pack('<d',v))
  elseif kind=='boolean' then Bytes(v and 't' or 'f')
  elseif kind=='nil' then Bytes('nil')
  elseif kind=='string' then Bytes('s'..#v..':'..v)
  elseif kind=='table' then
   local keys={};for k in pairs(v) do keys[#keys+1]=k end
   table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
   Bytes('{');for _,k in ipairs(keys) do Add(k);Add(v[k]) end;Bytes('}')
  else error('unsupported digest type '..kind) end
 end
 return {add=Add,get=function()return string.format('%016x',value)end}
end
local function WheelStates(v)
 local out={}
 for i,s in ipairs(v.suspension.states) do
  local row={};for key,value in pairs(s) do if key~='groundBody' then row[key]=value end end;out[i]=row
 end
 return out
end
local function Scenario(name,equivalence)
 math.randomseed(16102026)
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
 local floor=scene:CreateChild('Floor');floor.position=Vector3(0,-1,0)
 local ground=floor:CreateComponent('RigidBody');ground.friction=.8;ground.collisionLayer=1;ground.collisionMask=0xffff
 floor:CreateComponent('CollisionShape'):SetBox(Vector3(4000,2,4000));local platform=space:Register(ground,{type='ground'})
 local cars,metadata,bases={},{},{}
 local roles=name=='six-t3' and {'assault','heavy','sniper','assault','heavy','sniper'} or {'assault'}
 for i,role in ipairs(roles) do
  local bp=BP.New():Load(assert(Data.prefabs[(i>3 and 'red' or 'blue')..':3:'..role..':0']))
  local spec=Spec.Build(bp);assert(spec.ok)
  local v=Vehicle.New(space,spec);setmetatable(v.suspension,class);v:Place({i*100,0,0},0)
  cars[#cars+1]=v;local tracks=0;for _,w in ipairs(v.wheels) do if w.track then tracks=tracks+1 end end
  metadata[#metadata+1]={role=role,mass=v.mass,wheels=#v.wheels,tracks=tracks,legs=#spec.legs}
  if name=='rotor-moving-floor' then
   bases[i]={}
   for j,w in ipairs(v.wheels) do bases[i][j]={down=w.down,axle=w.contactAxle};w.rotor=1 end
  end
 end
 if name=='rotor-moving-floor' then ground.kinematic=true end
 local traces=Hash();local counts={rays=0,hits=0,impulses=0,denominators=0,groundVelocity=0}
 if equivalence then
  local ray=space.Raycast
  function space:Raycast(origin,direction,length,excluded,skip,fixed,mask)
   local hit=ray(self,origin,direction,length,excluded,skip,fixed,mask)
   counts.rays=counts.rays+1;if hit then counts.hits=counts.hits+1 end
   traces.add({origin,direction,length,skip,fixed,mask,hit and {hit.dist,hit.point,hit.normal,hit.body==platform} or false})
   return hit
  end
  for _,v in ipairs(cars) do
   local impulse=v.body.applyImpulseAtPoint;local denominator=v.body.impulseDenominator
   v.body.applyImpulseAtPoint=function(j,p,wake) counts.impulses=counts.impulses+1;traces.add({'impulse',j,p,wake});return impulse(j,p,wake) end
   v.body.impulseDenominator=function(p,d) local n=denominator(p,d);counts.denominators=counts.denominators+1;traces.add({'denominator',p,d,n});return n end
  end
  local velocity=platform.velocityAtPoint
  platform.velocityAtPoint=function(p) local result=velocity(p);counts.groundVelocity=counts.groundVelocity+1;traces.add({'platformVelocity',p,result});return result end
 end
 local sampleMs,applyMs,sampleCalls,applyCalls=0,0,0,0
 if not equivalence then for _,v in ipairs(cars) do
  local suspension=v.suspension
  suspension.Sample=function(self)
   local t=Time:GetSystemTime();class.Sample(self);sampleMs=sampleMs+((Time:GetSystemTime()-t)&0xffffffff);sampleCalls=sampleCalls+1
  end
  suspension.Apply=function(self,dt)
   local t=Time:GetSystemTime();class.Apply(self,dt);applyMs=applyMs+((Time:GetSystemTime()-t)&0xffffffff);applyCalls=applyCalls+1
  end
 end end
 local function Step(index)
  if name=='rotor-moving-floor' then
   -- Real native kinematic ground plus the rotor-wheel suspension branch. Wheel
   -- frames are supplied directly here; this does not validate RotorMotion itself.
   platform.setNextKinematicTranslation({x=math.sin(index/90)*2,y=-1+math.sin(index/150)*.05,z=0})
   platform.setLinvel({x=math.cos(index/90)*2/90*60,y=math.cos(index/150)*.05/150*60,z=0})
   local q=Rotors.AxisQuat({0,0,1},math.sin(index/110)*.12)
   for i,v in ipairs(cars) do for j,w in ipairs(v.wheels) do
    w.down=Math.Rotate(q,bases[i][j].down);w.contactAxle=Math.Rotate(q,bases[i][j].axle)
   end end
  end
  local cmd={throttle=index%240<150 and .65 or -.35,steer=math.sin(index/130)*.4,handbrake=index%180>155,jump=index%300==0,climb=0,strafe=0}
  for _,v in ipairs(cars) do
   if index%450==0 then v.body.setLinvel({x=.4,y=6,z=2}) end
   v:Step(cmd,1/60)
  end
  space:Step(1/60)
 end
 local snapshots={};local digest=Hash();local totalMs=0
 local steps=equivalence and 900 or 3600
 if not equivalence then for i=1,600 do Step(i) end;sampleMs=0;applyMs=0;sampleCalls=0;applyCalls=0 end
 local start=Time:GetSystemTime()
 for step=1,steps do
  local index=equivalence and step or step+600
  local t=Time:GetSystemTime();Step(index);totalMs=totalMs+((Time:GetSystemTime()-t)&0xffffffff)
  if equivalence or step%300==0 then
   local states={};for i,v in ipairs(cars) do states[i]={vehicle=v:GetState(),wheels=WheelStates(v),telemetry=v.telemetry} end
   digest.add(states);if step%300==0 then snapshots[#snapshots+1]={step=step,states=states} end
  end
 end
 local elapsed=(Time:GetSystemTime()-start)&0xffffffff
 local randomTail={};for i=1,32 do randomTail[i]=math.random() end
 local result={name=name,equivalence=equivalence,steps=steps,dt=1/60,metadata=metadata,stepTotalMs=totalMs,elapsedMs=elapsed,
  sampleMs=sampleMs,applyMs=applyMs,sampleCalls=sampleCalls,applyCalls=applyCalls,stateDigest=digest.get(),traceDigest=traces.get(),counts=counts,snapshots=snapshots,randomTail=randomTail}
 for _,v in ipairs(cars) do v:Dispose() end;space:Dispose();scene:Dispose();collectgarbage('collect')
 return result
end
function Start()
 local ok,result=xpcall(function()
  return {status='PASS',mode=mode,seed=16102026,runtime='0.9.0-beta.40_20261015.121839.6dc5c357cced',
   scenarios={Scenario('six-t3',true),Scenario('rotor-moving-floor',true),Scenario('six-t3',false),Scenario('rotor-moving-floor',false)},
   boundary='Native real Bullet and production vehicle steps; no rendering, AI, firing, audio, HUD or map. Rotor wheel frame supplied directly; kinematic platform real. Integer-ms per-call quantization; aggregate stage and loop elapsed, not GPU or phone FPS.'}
 end,debug.traceback)
 if not ok then result={status='FAIL',mode=mode,error=tostring(result)} end
 local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
