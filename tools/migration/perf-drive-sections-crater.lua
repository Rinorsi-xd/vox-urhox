-- Probe-only full crater collision and production simulation modules; no rendering.
local Scope=require 'perf-drive-sections-scope'
_G.VOX_DRIVE_SCOPE=Scope
local World=require 'drive.CraterWorld'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local DriverActions=require 'combat.DriverActions'
local RotorMotion=require 'drive.RotorMotion'
local Data=require 'combat.ArenaData'
local Vehicle=require 'drive.Vehicle'
local Gait=require 'drive.LegGait'
local Legs=require 'drive.LegControl'
local Contact=require 'drive.ContactControl'
local Space=require 'physics.Space'
local Weapons=require 'combat.WeaponSystem'
local output=nil ---@type string?
local sections,firing,ai=false,false,true
for _,arg in ipairs(GetArguments()) do
 output=arg:match('^%-probe%-output=(.+)$') or output
 if arg=='-probe-sections=1' then sections=true end
 if arg=='-probe-firing=1' then firing=true end
 if arg=='-probe-ai=0' then ai=false end
end
local function Clock() return Time:GetSystemTime() end
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function Run()
 math.randomseed(1016)
 local scene=Scene();scene:CreateComponent('Octree')
 local start=Clock();local world=World.New(scene);local mapInitializationMs=(Clock()-start)&0xffffffff
 local initialBodies=Count(world.space.bodies)
 local entries,metadata={},{}
 for _,team in ipairs({'blue','red'}) do for _,role in ipairs({'assault','heavy','sniper'}) do
  local index=#entries+1;local blue=team=='blue'
  local x=((index%4)-1.5)*18;local z=-140+(blue and -20 or 20)
  local source=assert(Data.prefabs[team..':3:'..role..':0'])
  local unit=Unit.New(world,source,{name=team..'-'..role,team=team,combat=true,externalControl=true,autoRespawn=true,
   spawn={pos={x,world:GroundAt(x,z)+2,z},yaw=blue and 0 or math.pi}})
  assert(unit.alive,'Invalid probe unit '..unit.name)
  world.units[#world.units+1]=unit
  local member={tier=3,seed=1016+index,aimSkill=1}
  entries[index]={unit=unit,driver=Driver.New(world,unit,role,index,member)}
  metadata[index]={team=team,role=role,variant=0,parts=unit.bp:Size(),mass=unit.vehicle.mass,wheels=#unit.vehicle.wheels,
   legs=#unit.spec.legs,weapons=#unit.spec.weapons,spawn=unit.spawnAt}
 end end
 -- Same physical map and real damage path, but no objectives/round controller,
 -- player view, draw calls or audio. All six cars use real drivers when enabled.
 local counts={vehicle=0,raycast=0,physics=0,gait=0,contact=0,foothold=0,weapons=0,ai=0,shots=0}
 local function CountMethod(object,key,name)
  local original=assert(object[key]);object[key]=function(...) counts[name]=counts[name]+1;return original(...) end
 end
 CountMethod(Vehicle,'Step','vehicle');CountMethod(Space,'Raycast','raycast');CountMethod(Space,'Step','physics')
 CountMethod(Gait,'Step','gait');CountMethod(Contact,'Step','contact');CountMethod(Gait,'Foothold','foothold')
 CountMethod(Weapons,'Step','weapons');CountMethod(Driver,'Step','ai')
 local function Wrap(object,key,name) Scope.Wrap(object,key,name,false) end
 Wrap(Vehicle,'Step','vehicle.Step');Wrap(Vehicle,'StepRotors','vehicle.StepRotors')
 Wrap(Vehicle,'PostStep','vehicle.PostStep');Wrap(Space,'Step','physics.Step');Wrap(Space,'Raycast','physics.Raycast')
 Wrap(Driver,'Step','ai.Step');Wrap(Unit,'Flush','unit.Flush');Wrap(Unit,'SavePose','unit.SavePose')
 Wrap(Unit,'Spawn','unit.Spawn');Wrap(Unit,'Build','unit.Build');Wrap(Unit,'RegenerateStructure','unit.RegenerateStructure')
 Wrap(Weapons,'Step','weapons.Step')
 for _,key in ipairs({'Energy','Aim','Tick','Ready','Aligned','Fire','Muzzle','Spend','Beam','Integrate'}) do Wrap(Weapons,key,'weapons.'..key) end
 for name,methods in pairs({
  ['drive.RaySuspension']={'Sample','Apply'},['drive.ChassisStability']={'Step'},['drive.HoverControl']={'Step','Motion'},
  ['drive.ThrusterControl']={'Step'},['drive.WingControl']={'Step'},['drive.LegControl']={'Step','Cast','Clear','Reachable','Target'},
  ['drive.LegHitboxes']={'Update'},['drive.LegGait']={'Foothold'},['combat.EnemyDriverThink']={'Run','Sniper','Route'},
  ['combat.EnemyDriverNav']={'Nearest','Path','Direct','Visible','Height'},['combat.VehicleRay']={'Cast'},
 }) do local module=require(name);for _,key in ipairs(methods) do Wrap(module,key,name..'.'..key) end end
 Wrap(world,'CastRay','world.CastRay');Wrap(world,'Hit','world.Hit');Wrap(world,'Explode','world.Explode');Wrap(world,'Step','world.Step')
 local function Step(index)
  Scope.Enter('simulation.Step')
  for _,entry in ipairs(entries) do local unit=entry.unit
   if unit.alive then
    local target=nil ---@type table?
    local nearest=math.huge;local pos=unit:Position()
    for _,other in ipairs(entries) do if other.unit.alive and other.unit.team~=unit.team then
     local p=other.unit:Position();local d=(p[1]-pos[1])^2+(p[3]-pos[3])^2
     if d<nearest then nearest=d;target=other.unit end
    end end
    local cmd,aim,trigger,info={throttle=0,steer=0,handbrake=true},nil,false,nil
    unit:RegenerateStructure(1/60)
    if ai then cmd,aim,trigger,info=entry.driver:Step(1/60,target) end
    unit:Flush()
    if unit.alive then
     DriverActions.Apply(unit,info)
     local v=unit.vehicle;v:StepRotors(aim,cmd.rotorStep,1/60);RotorMotion.Weapons(v.rotors,unit.weapons)
     v:Step(cmd,1/60)
     local p,velocity=v.body.translation(),v.body.linvel()
     world.attacker=unit
     unit.weapons:Step(1/60,{firing=firing and trigger,aim=aim or unit:Position(),pos={p.x,p.y,p.z},quat=v.body.rotation(),
      vel={velocity.x,velocity.y,velocity.z},body=v.body,team=unit.team,live=true,salvo=firing and info and info.salvo},world.env)
     world.attacker=nil
     -- Production effects/audio consumers clear the weapon event queue after use.
     -- No visual events are rendered in this headless simulation probe.
     unit.weapons.fx={}
    end
   end
  end
  world:Step(1/60)
  world.fx={};world.viewEvents={};world.debris.events={}
  Scope.Leave();Scope.AssertClosed()
 end
 local snapshots={};local population={min=6,max=0,samples={},byAlive={}}
 local function Snapshot(index)
  local out={step=index,time=world.time,cars={}}
  for _,entry in ipairs(entries) do local u=entry.unit
   out.cars[#out.cars+1]={name=u.name,alive=u.alive,hp=u:Health(),parts=u.bp:Size(),
    state=u.vehicle and u.vehicle:GetState() or false,mode=entry.driver.mode,shots=world.stats.shots}
  end
  snapshots[#snapshots+1]=cjson.decode(cjson.encode(out))
 end
 for i=1,120 do Step(i) end
 collectgarbage('collect');Scope.active=sections;start=Clock()
 for i=121,720 do
  Step(i)
  local alive=0;for _,entry in ipairs(entries) do if entry.unit.alive then alive=alive+1 end end
  population.min=math.min(population.min,alive);population.max=math.max(population.max,alive)
  population.byAlive[tostring(alive)]=(population.byAlive[tostring(alive)] or 0)+1
  if i%120==0 then Snapshot(i);population.samples[#population.samples+1]=alive end
 end
 local wallMs=(Clock()-start)&0xffffffff;Scope.active=false;counts.shots=world.stats.shots
 local tail={};for i=1,32 do tail[i]=math.random() end
 local result={status='PASS',sections=sections,firing=firing,ai=ai,wallMs=wallMs,timingSteps=600,stats=Scope.rows,counts=counts,
  metadata=metadata,snapshots=snapshots,randomTail=tail,population=population,
  bodyCounts={map=initialBodies,final=Count(world.space.bodies)},mapInitializationMs=mapInitializationMs,
  boundary='Native headless wall milliseconds including wrappers/snapshots, not whole battle/Web FPS. Production crater collision, six T3 variant0 vehicles, real AI/weapon/damage/physics. No objectives, round rules, shields, player, rendering/audio/UI. Fire/no-fire populations may differ; not an equivalent optimization A/B. Nested stage totals overlap.'}
 world:Dispose();scene:Dispose();return result
end
function Start()
 local ok,result=xpcall(Run,debug.traceback);if not ok then result={status='FAIL',error=tostring(result)} end
 local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
