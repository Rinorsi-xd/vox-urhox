local Effects=require 'render.CombatEffects'
local Height=require 'core.HeightField'
local Original=require 'qa.HeightFieldOriginal'
local config=assert(HEIGHTFIELD_EFFECTS_CONFIG)
local output
for _,argument in ipairs(GetArguments())do output=argument:match('^%-probe%-output=(.+)$')or output end
local rawGc=collectgarbage
local function RestoreGuard()collectgarbage=rawGc end
local function Digest()
 local hash=0xcbf29ce484222325
 local function Bytes(s)for i=1,#s do hash=(hash~s:byte(i))*0x100000001b3 end end
 local function Add(value)
  local kind=type(value)
  if kind=='number'then Bytes('n'..string.pack('<d',value))
  elseif kind=='string'then Bytes('s'..#value..':'..value)
  elseif kind=='boolean'then Bytes(value and't'or'f')
  elseif kind=='nil'then Bytes('nil')
  elseif kind=='table'then
   local keys={};for key in pairs(value)do keys[#keys+1]=key end
   table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
   Bytes('{');for _,key in ipairs(keys)do Add(key);Add(value[key])end;Bytes('}')
  else error('Unsupported state '..kind)end
 end
 return {add=Add,get=function()return string.format('%016x',hash)end}
end
local function VerifyHeight()
 local checks=0
 for _,name in ipairs({'Crater/VisualHeight.bin','Salvage/Height.bin'})do
  local a,b=Original.New(name),Height.New(name)
  local function Check(x,z)
   assert(string.pack('<d',a:Sample(x,z))==string.pack('<d',b:Sample(x,z)),'Native exact height mismatch '..name)
   checks=checks+1
  end
  for i=0,1200 do
   local x=a.x+((i*131)%a.n+.375)*a.step
   local z=a.z+((i*97)%a.n+.625)*a.step
   Check(x,z);Check(x+.001,z-.001)
  end
  for _,p in ipairs({{a.x,a.z},{a.x+a.n*a.step,a.z+a.n*a.step},{a.x-1e6,a.z+1e6},{a.x+math.huge,a.z-math.huge}})do Check(p[1],p[2])end
  for i=0,24 do
   local k=i%2==0 and 0 or 4096
   Check(a.x+(math.floor(k/(a.n+1))+.37)*a.step,a.z+(k%(a.n+1)+.62)*a.step)
  end
  a:Dispose();b:Dispose();b:Dispose()
  local ok,err=pcall(b.Sample,b,0,0)
  assert(not ok and tostring(err):find('Height field already released',1,true))
 end
 return checks
end
local scene,height,effects
local function Run()
 assert(config.steps==480 and config.warmup==120 and config.fixedDt==1/60)
 assert(rawGc('isrunning'),'Collector must be running before fixture')
 collectgarbage=function(operation,...)
  assert(operation=='count'or operation=='isrunning','Collector mutation prohibited')
  return rawGc(operation,...)
 end
 local heightChecks=VerifyHeight()
 scene=Scene();scene:CreateComponent('Octree')
 local camera=scene:CreateChild('Camera');camera.position=Vector3(8,12,-12);camera.rotation=Quaternion(12,20,0)
 height=Height.New('Crater/VisualHeight.bin')
 effects=Effects.New(scene,function(x,z)return height:Sample(x,z)end)
 effects:Reserve({chips=96})
 math.randomseed(config.seed)
 local projectiles={}
 local function Emit(frame)
  if frame%6==1 then for i=1,6 do
   local x,z=(i-3)*4,20+(i%2)*3
   local y=height:Sample(x,z)+1
   effects:Burst({x,y,z},24,6,{7,4.2,1.2},{0,1,0},.08,.8,12,.4)
   effects:Puff({x,y,z},3,.5,1.8,.35)
  end end
 end
 for frame=1,config.warmup do coroutine.yield();Emit(frame);effects:Update(config.fixedDt,projectiles,camera)end
 local frames,snapshots={},{};local total,maximum=0,0
 for frame=1,config.steps do frames[frame]={}end
 local heapBefore=collectgarbage('count')
 local initial={particles=#effects.particles,smoke=#effects.smoke,maxParticles=effects.maxParticles,maxSmoke=effects.maxSmoke}
 local stateDigest=Digest()
 for frame=1,config.steps do
  coroutine.yield();Emit(frame+config.warmup)
  assert(collectgarbage('isrunning'))
  local started=Time:GetSystemTime();effects:Update(config.fixedDt,projectiles,camera)
  local elapsed=(Time:GetSystemTime()-started)&0xffffffff
  total=total+elapsed;maximum=math.max(maximum,elapsed)
  local row=frames[frame];row.ms=elapsed;row.particles=#effects.particles;row.smoke=#effects.smoke;row.batches={}
  for key,batch in pairs(effects.batches)do row.batches[key]=batch.count end
  if frame%60==0 then
   stateDigest.add({frame,effects.particles,effects.smoke})
   snapshots[#snapshots+1]={frame=frame,digest=stateDigest.get()}
  end
 end
 local heapAfter=collectgarbage('count');local tail={};for i=1,16 do tail[i]=math.random()end
 assert(collectgarbage('isrunning'));RestoreGuard()
 local result={status='NORMAL_GC_TIMING_PASS',configuration=config,heightChecks=heightChecks,initial=initial,
  frames=frames,snapshots=snapshots,stateDigest=stateDigest.get(),randomAfter=tail,
  totalStepMs=total,meanStepMs=total/config.steps,maxStepMs=maximum,
  heapBeforeKiB=heapBefore,heapAfterKiB=heapAfter,collectorGuardRestored=collectgarbage==rawGc,collectorRunning=rawGc('isrunning'),
  boundary='Unwrapped real Effects.Update with real Native height VectorBuffer and geometry. Emission/full state hashing outside Update timer. Normal GC includes allocation pressure from diagnostics; compare only matched A/B. Fixed stress workload of bursts/smoke, not recorded match or FPS/mobile acceptance.'}
 effects:Dispose();effects=nil;height:Dispose();height=nil;scene:Dispose();scene=nil
 return result
end
local worker
local function Finish(ok,result)
 RestoreGuard()
 if not ok then
  result={status='FAIL',error=tostring(result),collectorRunning=rawGc('isrunning')}
  pcall(function()if effects then effects:Dispose()end;if height then height:Dispose()end;if scene then scene:Dispose()end end)
 end
 local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
function Start()
 engine.maxFps=120;engine.maxInactiveFps=120
 worker=coroutine.create(function()local ok,result=xpcall(Run,function(err)return tostring(err)end);Finish(ok,result)end)
 SubscribeToEvent('Update','HeightEffectsUpdate')
end
function HeightEffectsUpdate()
 if not worker or coroutine.status(worker)=='dead'then return end
 local ok,err=coroutine.resume(worker);if not ok then Finish(false,err)end
end
