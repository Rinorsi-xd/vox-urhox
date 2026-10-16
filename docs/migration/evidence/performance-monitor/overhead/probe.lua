local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Monitor=require 'diagnostics.PerformanceMonitor'
local Bindings=require 'diagnostics.PerformanceBindings'
local output;local enabled=false
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output;enabled=enabled or arg=='-probe-enabled=1' end
local function Run()
 math.randomseed(25149307)
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
 local floor=scene:CreateChild('Floor');floor.position=Vector3(0,-1,0)
 local ground=floor:CreateComponent('RigidBody');ground.friction=.8;ground.restitution=0;ground.collisionLayer=1;ground.collisionMask=0xffff
 floor:CreateComponent('CollisionShape'):SetBox(Vector3(4000,2,4000));space:Register(ground,{type='ground'})
 local cars,units,metadata={},{},{}
 for _,team in ipairs({'blue','red'}) do for _,role in ipairs({'assault','heavy','sniper'}) do
  local bp=BP.New():Load(assert(Data.prefabs[team..':3:'..role..':0']));local spec=Spec.Build(bp);assert(spec.ok)
  local v=Vehicle.New(space,spec);v:Place({#cars*100,0,0},0);cars[#cars+1]=v;units[#units+1]={vehicle=v,alive=true}
  metadata[#metadata+1]={team=team,role=role,mass=v.mass,wheels=#v.wheels,legs=#spec.legs}
 end end
 local trial={vehicle=cars[1],map={id='flat-floor'},scene=scene,world={units=units,space=space},fixedSteps=0,accumulator=0,droppedTime=0}
 local app={trial=trial,mode='trial',scene=scene}
 local records,bytes=0,0
 local monitor=Monitor.New{enabled=enabled,noFile=true,session='isolated-overhead',sink=function(record)records=records+1;bytes=bytes+#cjson.encode(record)end}
 local function Step(index)
  if enabled then monitor:BeginFrame(1/60);Bindings.Attach(monitor,app) end
  local scope=enabled and monitor:Begin('main.Update') or nil
  local cmd={throttle=index%240<180 and .6 or -.4,steer=math.sin(index/120)*.35,handbrake=index%180>160,jump=index%300==0,climb=0,strafe=0}
  for _,v in ipairs(cars) do v:StepRotors(nil,false,1/60);v:Step(cmd,1/60) end
  space:Step(1/60);trial.fixedSteps=trial.fixedSteps+1
  if enabled then monitor:End(scope);monitor:EndFrame(Bindings.Context(app)) end
 end
 for i=1,180 do Step(i) end
 local a=Time:GetSystemTime();local ac=os.clock()
 for i=181,1380 do Step(i) end
 local ms=(Time:GetSystemTime()-a)&0xffffffff;local clockMs=(os.clock()-ac)*1000
 local states={};for i,v in ipairs(cars) do states[i]={state=v:GetState(),telemetry=v.telemetry} end
 local randomTail={};for i=1,32 do randomTail[i]=math.random() end
 monitor:Dispose()
 local result={status='PASS',enabled=enabled,seed=25149307,dt=1/60,warmupSteps=180,timingSteps=1200,wallMs=ms,clockMs=clockMs,metadata=metadata,states=states,randomTail=randomTail,serializedRecords=records,serializedBytes=bytes,
 boundary='Actual six T3 vehicles and Bullet flat floor; monitor attaches actual vehicle/suspension/leg/physics classes every step and captures Context. Sink cjson encodes in memory, no console/file/network log I/O; no map, AI, weapons firing, rendering/audio/HUD. Background existing Native/browser may add scheduling noise. os.clock not verified thread CPU.'}
 for _,v in ipairs(cars) do v:Dispose() end;space:Dispose();scene:Dispose();return result
end
function Start()
 local ok,result=xpcall(Run,debug.traceback)
 if not ok then result={status='FAIL',error=tostring(result)} end
 local f=assert(io.open(assert(output),'wb'));f:write(cjson.encode(result));f:close();engine:Exit()
end
