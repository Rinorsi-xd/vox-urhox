local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Gait=require 'drive.LegGait'
local Legs=require 'drive.LegControl'
local Boxes=require 'drive.LegHitboxes'
local IK=require 'parts.LegIK'
local output
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local function Run()
 math.randomseed(1016)
 local stats={};local active=false
 local function Wrap(object,key,label)
  local old=object[key];stats[label]={calls=0,ms=0}
  object[key]=function(...)
   if not active then return old(...) end
   local start=Time:GetSystemTime();local result=table.pack(old(...));local row=stats[label]
   row.ms=row.ms+((Time:GetSystemTime()-start)&0xffffffff);row.calls=row.calls+1
   return table.unpack(result,1,result.n)
  end
 end
 Wrap(Gait,'Step','gait');Wrap(Legs,'Step','legs');Wrap(Boxes,'Update','hitboxes');Wrap(IK,'Solve','ik');Wrap(Space,'Raycast','raycast');Wrap(Space,'Step','physics');Wrap(Vehicle,'Step','vehicle')
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
 -- Flat floor, low step and vertical wall exercise support, swing and clipping.
 local function Box(name,pos,size)
  local node=scene:CreateChild(name);node.position=Vector3(table.unpack(pos))
  local body=node:CreateComponent('RigidBody');body.friction=.8;body.collisionLayer=1;body.collisionMask=0xffff
  node:CreateComponent('CollisionShape'):SetBox(Vector3(table.unpack(size)));space:Register(body,{type='ground'})
 end
 Box('floor',{0,-1,0},{4000,2,4000})
 local cars,metadata={},{}
 for _,team in ipairs({'blue','red'}) do for _,role in ipairs({'assault','heavy','sniper'}) do
  local bp=BP.New():Load(assert(Data.prefabs[team..':3:'..role..':0']));local spec=Spec.Build(bp);assert(spec.ok)
  local v=Vehicle.New(space,spec);v:Place({#cars*100,0,0},0);cars[#cars+1]=v
  metadata[#metadata+1]={team=team,role=role,mass=v.mass,wheels=#v.wheels,legs=#spec.legs}
  Box('step'..#cars,{-((#cars-1)*100),.2,22},{20,.4,1})
  Box('wall'..#cars,{-((#cars-1)*100),4,45},{20,8,1})
 end end
 local snapshots={};local function Snapshot(index)
  local all={step=index,cars={}}
  for _,v in ipairs(cars) do
   local legs={};for _,s in ipairs(v.legControl and v.legControl.list or {}) do legs[#legs+1]={partId=s.leg.partId,foot=s.foot,target=s.target,mode=s.mode,force=s.force,grounded=s.grounded} end
   local boxes={};for _,b in ipairs(v.legHitboxes.items) do boxes[#boxes+1]={partId=b.partId,name=b.name,center=b.center,quat=b.quat,half=b.half} end
   all.cars[#all.cars+1]={state=v:GetState(),telemetry=v.telemetry,legs=legs,boxes=boxes}
  end;snapshots[#snapshots+1]=all
 end
 local function Step(index)
  local cmd={throttle=index%240<180 and .6 or -.4,steer=math.sin(index/120)*.35,handbrake=index%180>160,jump=index%300==0,climb=0,strafe=index%500>400 and .2 or 0}
  for _,v in ipairs(cars) do v:StepRotors(nil,false,1/60);v:Step(cmd,1/60) end
  space:Step(1/60)
 end
 for i=1,180 do Step(i) end
 collectgarbage('collect');active=true
 local start=Time:GetSystemTime()
 for i=181,2580 do Step(i);if i%120==0 then Snapshot(i) end end
 local elapsed=(Time:GetSystemTime()-start)&0xffffffff;active=false
 local boxStart=Time:GetSystemTime()
 for i=1,20000 do for _,v in ipairs(cars) do v.legHitboxes:Update() end end
 local boxOnlyMs=(Time:GetSystemTime()-boxStart)&0xffffffff
 local randomTail={};for i=1,32 do randomTail[i]=math.random() end
 local result={status='PASS',wallMs=elapsed,boxOnlyMs=boxOnlyMs,boxOnlyCalls=120000,timingSteps=2400,stats=stats,metadata=metadata,snapshots=snapshots,randomTail=randomTail,boundary='Six real T3 vehicles, native Bullet, flat floor+steps+walls; 180 warmup and 2400 timed steps. Per-method integer wall milliseconds include child calls and wrapper overhead. Separate hitbox-only loop repeats 20000 same-pose updates per car and does not advance physics. No rendering, audio, AI or firing. No target-device FPS claim.'}
 for _,v in ipairs(cars) do v:Dispose() end;space:Dispose();scene:Dispose();return result
end
function Start()
 local ok,result=xpcall(Run,debug.traceback);if not ok then result={status='FAIL',error=tostring(result)} end
 local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
