local Weapons=require 'combat.WeaponSystem'
local BP=require 'construction.Blueprint'
local Data=require 'combat.ArenaData'
local Spec=require 'drive.VehicleSpec'
local Space=require 'physics.Space'
local Math=require 'core.Math3'
local Missiles=require 'combat.MissileWeapons'
local Drill=require 'combat.DrillAttack'
local Loadout=require 'combat.WeaponLoadout'
local Defs=require 'combat.WeaponDefs'
local output='';local mode='profile';local label='baseline'
for _,arg in ipairs(GetArguments()) do
 output=arg:match('^%-probe%-output=(.+)$') or output
 mode=arg:match('^%-probe%-mode=(.+)$') or mode
 label=arg:match('^%-probe%-label=(.+)$') or label
end
local function Clock() return Time:GetSystemTime() end
local function Hash()
 local n=0xcbf29ce484222325
 local function Bytes(s) for i=1,#s do n=(n~s:byte(i))*0x100000001b3 end end
 local seen={}
 local function Add(v,path)
  local t=type(v)
  if t=='number' then Bytes('n'..string.pack('<d',v))
  elseif t=='string' then Bytes('s'..#v..':'..v)
  elseif t=='boolean' then Bytes(v and 't' or 'f')
  elseif t=='nil' then Bytes('nil')
  elseif t=='function' then Bytes('function')
  elseif t=='table' then
   if seen[v] then Bytes('@'..seen[v]);return end
   seen[v]=path
   local keys={};for k in pairs(v) do keys[#keys+1]=k end
   table.sort(keys,function(a,b)if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
   Bytes('{');for _,k in ipairs(keys) do Add(k,path..':key');Add(v[k],path..'.'..tostring(k)) end;Bytes('}')
  else error('Unexpected snapshot type '..t) end
 end
 return {add=function(v)seen={};Add(v,'root')end,get=function()return string.format('%016x',n)end}
end
local function Instrument(envs)
 local rows,restores,stack={},{},{}
 local function Wrap(object,key,name)
  local original=assert(object[key]);local row={name=name,calls=0,ms=0,selfMs=0};rows[#rows+1]=row
  object[key]=function(...)
   local entry={children=0};stack[#stack+1]=entry
   local at=Clock();local a,b,c=original(...);local elapsed=(Clock()-at)&0xffffffff
   stack[#stack]=nil;row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-entry.children
   if #stack>0 then stack[#stack].children=stack[#stack].children+elapsed end
   return a,b,c
  end
  restores[#restores+1]=function()object[key]=original end
 end
 for _,key in ipairs({'Step','Energy','Aim','Tick','Ready','Aligned','Fire','Muzzle','Spend','Beam','Integrate'}) do Wrap(Weapons,key,'weapons.'..key) end
 Wrap(Drill,'Step','drill.Step');Wrap(Missiles,'Lock','missiles.Lock');Wrap(Missiles,'Step','missiles.Step')
 for i,env in ipairs(envs) do for _,key in ipairs({'castRay','hit','explode','lockables'}) do Wrap(env,key,'env.'..key..'.'..i) end end
 return rows,function()for _,restore in ipairs(restores) do restore() end end
end
local function Specs(all)
 local specs,meta={},{}
 if all then
  local keys={};for key in pairs(Defs.STATS) do keys[#keys+1]=key end;table.sort(keys)
  for i,key in ipairs(keys) do
   local part=Loadout.Part({id=i,type=key,pos={0,0,0},rot=0})
   if part then specs[#specs+1]={weapons={part}};meta[#meta+1]={type=key,weapons=1} end
  end
 else
  for i,role in ipairs({'assault','heavy','sniper','assault','heavy','sniper'}) do
   local bp=BP.New():Load(assert(Data.prefabs[(i>3 and 'red' or 'blue')..':3:'..role..':0']))
   local spec=Spec.Build(bp);assert(spec.ok);specs[#specs+1]=spec
   local types={};for _,w in ipairs(spec.weapons) do types[#types+1]=w.type end
   meta[#meta+1]={role=role,weapons=#spec.weapons,types=types}
  end
 end
 return specs,meta
end
local function Scenario(name,all,firing,equivalence)
 math.randomseed(16102026)
 -- Native Bullet query target: a broad wall at source z=60; no vehicle physics
 -- or damage mutation. Ray/hit/recoil outputs are recorded by the environment.
 local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
 local target=scene:CreateChild('Target');target.position=Vector3(0,20,60)
 local rigid=target:CreateComponent('RigidBody');rigid.collisionLayer=1
 target:CreateComponent('CollisionShape'):SetBox(Vector3(20000,80,2))
 space:Register(rigid,{type='target'});space:Step(1/60)
 local specs,metadata=Specs(all);local systems,states,envs={},{},{}
 local trace,stateDigest=Hash(),Hash();local counts={rays=0,hits=0,recoils=0,explosions=0,shots=0}
 local lockable={pos={0,4,60},alive=true};local lockables={lockable}
 local function Trace(v) if equivalence then trace.add(v) end end
 for i,spec in ipairs(specs) do
  local sys=Weapons.New(spec);systems[i]=sys
  local x=(i-#specs*.5)*8
  local body={applyImpulseAtPoint=function(j,p,wake)counts.recoils=counts.recoils+1;Trace({'recoil',i,j,p,wake})end,
   isValid=function()return true end,linvel=function()return {x=0,y=0,z=0}end,
   setLinvel=function()end,setAngvel=function()end,enableCcd=function()end,isCcdEnabled=function()return false end,
   bodyType=function()return BT_DYNAMIC end,rotation=function()return {x=0,y=0,z=0,w=1}end,
   applyImpulse=function()end,mass=function()return 1000 end}
  states[i]={pos={x,3,0},quat={x=0,y=0,z=0,w=1},vel={0,0,0},aim={x,5,60},body=body,team='blue',live=true}
  envs[i]={stats={shots=0},castRay=function(p,d,length)
    counts.rays=counts.rays+1;local hit=space:Raycast(p,d,length)
    Trace({'ray',i,p,d,length,hit and {hit.dist,hit.point,hit.normal} or false});return hit
   end,hit=function(hit,damage,d,impulse,pierce)counts.hits=counts.hits+1;Trace({'hit',i,hit.dist,hit.point,hit.normal,damage,d,impulse,pierce})end,
   explode=function(p,r,damage)counts.explosions=counts.explosions+1;Trace({'explode',i,p,r,damage})end,
   lockables=function()return lockables end,killHeight=-80}
 end
 local steps=equivalence and 2400 or 12000
 local function Step(index)
  local yaw=math.sin(index/200)*.08
  for i,sys in ipairs(systems) do
   local state=states[i]
   state.quat={x=0,y=math.sin(yaw*.5),z=0,w=math.cos(yaw*.5)}
   state.aim={state.pos[1]+math.sin(index/230)*10,5+math.sin(index/290)*4,60}
   state.firing=firing and index%1200<780;state.salvo=all and index%600<300
   lockable.pos={state.aim[1],state.aim[2],state.aim[3]}
   -- Drills are covered at aim/idle level here. Body dash/cut rules are not
   -- exercised by this query-target fixture.
   if all and sys:Group().weapons[1].stats.drill then state.firing=false end
   if all and equivalence then
    local w=sys:Group().weapons[1]
    if w.stats.homing and index%600==1 then
     w.lock=1;w.lockRef=lockable;w.volleyTarget=lockable;w.mphase='fire'
     w.volley=#w.tubes;w.volleyAt=sys.time;w.barrel=1
    end
   end
   sys:Step(1/60,state,envs[i])
  end
 end
 if not equivalence then for i=1,600 do Step(i) end end
 local rows,restore={},function()end
 if mode=='profile' then rows,restore=Instrument(envs) end
 collectgarbage('collect');local initial=collectgarbage('count');local snapshots={}
 local started=Clock()
 for step=1,steps do
  Step(step+(equivalence and 0 or 600))
  if equivalence then
   for i,sys in ipairs(systems) do stateDigest.add({i,sys}) end
   if step%600==0 then
    local sample={step=step,systems={}}
    for i,sys in ipairs(systems) do local ww={};for _,g in ipairs(sys.groups) do for _,w in ipairs(g.weapons) do
     ww[#ww+1]={type=w.type,yaw=w.yaw,pitch=w.pitch,prevYaw=w.prevYaw,prevPitch=w.prevPitch,err=w.err,limited=w.limited,cool=w.cool,
      spin=w.spin,windup=w.windup,barrel=w.barrel,bloom=w.bloom or 0,phase=w.mphase or '',lock=w.lock or 0}
    end end;sample.systems[i]={energy=sys.energy,offline=sys.offline,projectiles=#sys.projectiles,shots=envs[i].stats.shots,weapons=ww} end
    snapshots[#snapshots+1]=sample
   end
  end
 end
 local total=(Clock()-started)&0xffffffff;local endKiB=collectgarbage('count');restore()
 for _,env in ipairs(envs) do counts.shots=counts.shots+env.stats.shots end
 local tail={};for i=1,32 do tail[i]=math.random() end
 local result={name=name,systems=#systems,metadata=metadata,equivalence=equivalence,steps=steps,totalMs=total,perStepMs=total/steps,
  stages=rows,counts=counts,stateDigest=stateDigest.get(),traceDigest=trace.get(),snapshots=snapshots,randomTail=tail,
  heapBeforeKiB=initial,heapAfterKiB=endKiB}
 space:Dispose();scene:Dispose();collectgarbage('collect');return result
end
function Start()
 local ok,result=xpcall(function()
  return {status='PASS',mode=mode,label=label,seed=16102026,runtime='0.9.0-beta.40_20261015.121839.6dc5c357cced',
   scenarios={Scenario('six-t3-idle',false,false,mode=='equivalence'),Scenario('six-t3-fire',false,true,mode=='equivalence'),Scenario('all-tiers-fire',true,true,mode=='equivalence')},
   boundary='Production weapon modules and real prefab/spec assets in Native, Bullet static target queries. No vehicle physics/AI/render/audio/UI/damage mutation. Drills held idle. Profile wrappers perturb stage totals; 1ms clock quantization. Not whole frame/FPS or phone acceptance.'}
 end,debug.traceback)
 if not ok then result={status='FAIL',mode=mode,label=label,error=tostring(result)} end
 local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
