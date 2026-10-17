-- Isolated diagnostic only. Source identity is recorded by the preparation tool.
local Scope=require 'perf-drive-sections-scope'
_G.VOX_DRIVE_SCOPE=Scope
local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Gait=require 'drive.LegGait'
local Legs=require 'drive.LegControl'
local Contact=require 'drive.ContactControl'
local output=nil ---@type string?
local timing=false
for _,arg in ipairs(GetArguments()) do
 output=arg:match('^%-probe%-output=(.+)$') or output
 if arg=='-probe-sections=1' then timing=true end
end
local function Run()
 math.randomseed(1016)
 if timing then
  Scope.Wrap(Gait,'Foothold','gait.foothold',true)
  for _,key in ipairs({'Cast','Clear','Reachable','Target'}) do Scope.Wrap(Legs,key,'leg.'..key,true) end
 end
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
 -- Source-space six-car lanes are mirrored into engine X. Flat/step/wall
 -- contacts exercise stance, swings and clipping; geometry never changes.
 local function Box(name,x,y,z,sx,sy,sz)
  local node=scene:CreateChild(name);node.position=Vector3(-x,y,z)
  local body=node:CreateComponent('RigidBody');body.friction=.8;body.collisionLayer=1;body.collisionMask=0xffff
  node:CreateComponent('CollisionShape'):SetBox(Vector3(sx,sy,sz));space:Register(body,{type='ground'})
 end
 Box('floor',0,-1,0,4000,2,4000)
 local cars,metadata={},{}
 for _,team in ipairs({'blue','red'}) do for _,role in ipairs({'assault','heavy','sniper'}) do
  local bp=BP.New():Load(assert(Data.prefabs[team..':3:'..role..':0']));local spec=Spec.Build(bp);assert(spec.ok)
  local v=Vehicle.New(space,spec);local x=#cars*100;v:Place({x,0,0},0);cars[#cars+1]=v
  metadata[#metadata+1]={team=team,role=role,mass=v.mass,wheels=#v.wheels,legs=#spec.legs}
  Box('step'..#cars,x,.2,22,20,.4,1);Box('wall'..#cars,x,4,45,20,8,1)
 end end
 local snapshots={};local counts={vehicle=0,raycast=0,physics=0,gait=0,contact=0,foothold=0}
 local function Count(object,key,name)
  local old=object[key];object[key]=function(...)counts[name]=counts[name]+1;return old(...)end
 end
 Count(Vehicle,'Step','vehicle');Count(Space,'Raycast','raycast');Count(Space,'Step','physics')
 Count(Gait,'Step','gait');Count(Contact,'Step','contact');Count(Gait,'Foothold','foothold')
 local function Snapshot(index)
  local out={step=index,cars={}}
  for _,v in ipairs(cars) do
   local boxes={};for _,b in ipairs(v.legHitboxes.items) do boxes[#boxes+1]={partId=b.partId,name=b.name,center=b.center,quat=b.quat,half=b.half} end
   out.cars[#out.cars+1]={state=v:GetState(),telemetry=v.telemetry,legs=v.legControl and v.legControl:Snapshot() or false,boxes=boxes}
  end;snapshots[#snapshots+1]=cjson.decode(cjson.encode(out))
 end
 local function Step(index)
  local cmd={throttle=index%240<180 and .6 or -.4,steer=math.sin(index/120)*.35,handbrake=index%180>160,jump=index%300==0,climb=0,strafe=index%500>400 and .2 or 0}
  for _,v in ipairs(cars) do v:StepRotors(nil,false,1/60);v:Step(cmd,1/60) end
  space:Step(1/60);Scope.AssertClosed()
 end
 for i=1,180 do Step(i) end
 collectgarbage('collect');Scope.active=timing
 local started=Time:GetSystemTime()
 for i=181,2580 do Step(i);if i%120==0 then Snapshot(i) end end
 local elapsed=(Time:GetSystemTime()-started)&0xffffffff;Scope.active=false
 local tail={};for i=1,32 do tail[i]=math.random() end
 local result={status='PASS',sections=timing,wallMs=elapsed,timingSteps=2400,stats=Scope.rows,counts=counts,metadata=metadata,snapshots=snapshots,randomTail=tail,
  boundary='Integer wall milliseconds with diagnostic calls/wrappers, not unbiased CPU time. Six real vehicles/native Bullet; flat/steps/walls. No AI, firing, rendering, audio, UI or target-device FPS claim. Compare exact state and counts before interpreting timing. Source sections and nested child scopes must not be summed.'}
 for _,v in ipairs(cars) do v:Dispose() end;space:Dispose();scene:Dispose();return result
end
function Start()
 local ok,result=xpcall(Run,debug.traceback);if not ok then result={status='FAIL',error=tostring(result)} end
 local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
