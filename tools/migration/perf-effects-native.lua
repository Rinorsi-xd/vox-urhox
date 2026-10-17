local Effects=require 'render.CombatEffects'
local Batch=require 'render.EffectBatch'
local Chips=require 'render.ChipEffects'
local Missiles=require 'render.MissileEffects'
local Light=require 'render.CombatLight'
local output,mode,label='','profile','baseline'
for _,arg in ipairs(GetArguments()) do
 output=arg:match('^%-probe%-output=(.+)$') or output
 mode=arg:match('^%-probe%-mode=(.+)$') or mode
 label=arg:match('^%-probe%-label=(.+)$') or label
end
local function Clock() return Time:GetSystemTime() end
local function Hash()
 local value=0xcbf29ce484222325
 local function Bytes(s) for i=1,#s do value=(value~s:byte(i))*0x100000001b3 end end
 local function Add(x)
  local kind=type(x)
  if kind=='number' then Bytes('n'..string.pack('<d',x))
  elseif kind=='string' then Bytes('s'..#x..':'..x)
  elseif kind=='nil' then Bytes('nil')
  elseif kind=='boolean' then Bytes(x and 't' or 'f')
  elseif kind=='table' then
   local keys={};for k in pairs(x) do keys[#keys+1]=k end
   table.sort(keys,function(a,b)if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
   Bytes('{');for _,k in ipairs(keys) do Add(k);Add(x[k]) end;Bytes('}')
  else error('Unsupported digest value '..kind) end
 end
 return {add=Add,get=function()return string.format('%016x',value)end}
end
local function Instrument()
 local rows,restores,stack={},{},{}
 local function Wrap(object,key,name)
  local original=assert(object[key]);local row={name=name,calls=0,ms=0,selfMs=0};rows[#rows+1]=row
  object[key]=function(...)
   local entry={children=0};stack[#stack+1]=entry;local at=Clock()
   local result=table.pack(original(...));local elapsed=(Clock()-at)&0xffffffff
   stack[#stack]=nil;row.calls=row.calls+1;row.ms=row.ms+elapsed;row.selfMs=row.selfMs+elapsed-entry.children
   if #stack>0 then stack[#stack].children=stack[#stack].children+elapsed end
   return table.unpack(result,1,result.n)
  end
  restores[#restores+1]=function()object[key]=original end
 end
 for _,key in ipairs({'Update','Helix','Path','Hit'}) do Wrap(Effects,key,'effects.'..key) end
 for _,key in ipairs({'Begin','Quad','Segment','Disc','Finish'}) do Wrap(Batch,key,'batch.'..key) end
 Wrap(Chips,'Update','chips.Update');Wrap(Missiles,'Update','missiles.Update');Wrap(Light,'Update','light.Update')
 return rows,function()for _,restore in ipairs(restores) do restore() end end
end
local function FakeGeometry(batch,digest,counts)
 local original=batch.mesh
 local geom={enabled=false}
 local function Record(method,...)
  counts[method]=(counts[method] or 0)+1;digest.add({batch.kind,method,...})
 end
 function geom:BeginGeometry(index,primitive) Record('begin',index,primitive) end
 function geom:DefineVertex(v) Record('position',v.x,v.y,v.z) end
 function geom:DefineNormal(v) Record('normal',v.x,v.y,v.z) end
 function geom:DefineColor(v) Record('color',v.r,v.g,v.b,v.a) end
 function geom:DefineTexCoord(v) Record('uv',v.x,v.y) end
 function geom:DefineTangent(v) Record('tangent',v.x,v.y,v.z,v.w) end
 function geom:Commit() Record('commit') end
 batch.mesh=geom
 return function()batch.mesh=original end
end
local function VerifyNativeCopy()
 local scene=Scene();scene:CreateComponent('Octree');local batch=Batch.New(scene,'Streak',4)
 local points={{1,2,3},{4,5,6},{7,8,9},{10,11,12}};local uvs={{.1,.2},{.3,.4},{.5,.6},{.7,.8}}
 local color={2,3,4};local params={.2,.4,.6,.8}
 batch:Begin({0,0,-4},1);batch:Quad(points,uvs,color,.7,params);batch:Finish()
 -- Mutating caller data and reusable native-value containers after submission
 -- must not mutate the CustomGeometry-owned six-vertex buffer.
 for _,p in ipairs(points) do for i=1,3 do p[i]=99 end end
 for _,uv in ipairs(uvs) do uv[1]=99;uv[2]=99 end
 if batch.nativePoints then for i=1,4 do batch.nativePoints[i]=Vector3(99,99,99);batch.nativeUVs[i]=Vector2(99,99) end end
 color[1]=99;params[1]=99
 local order={1,2,3,3,2,4};local expectedPoints={{-1,2,3},{-4,5,6},{-7,8,9},{-10,11,12}}
 local expectedUV={{.1,.2},{.3,.4},{.5,.6},{.7,.8}};local actual={}
 for index,corner in ipairs(order) do
  local vertex=batch.mesh:GetVertex(0,index-1);local p,n,uv,t=vertex.position,vertex.normal,vertex.texCoord,vertex.tangent
  local expected=expectedPoints[corner];local euv=expectedUV[corner]
  assert(math.abs(p.x-expected[1])<1e-5 and math.abs(p.y-expected[2])<1e-5 and math.abs(p.z-expected[3])<1e-5,'native position copy')
  assert(math.abs(uv.x-euv[1])<1e-5 and math.abs(uv.y-euv[2])<1e-5,'native UV copy')
  assert(math.abs(n.x-.2)<1e-5 and math.abs(n.y-.4)<1e-5 and math.abs(n.z-.6)<1e-5,'native params copy')
  assert(math.abs(t.x-.8)<1e-5 and t.w==1,'native tangent copy')
  assert(t.y==0 and t.z==0,'native tangent transverse copy')
  actual[index]={p.x,p.y,p.z,n.x,n.y,n.z,uv.x,uv.y,t.x,t.y,t.z,t.w,vertex.color}
 end
 batch:Dispose();scene:Dispose();return actual
end
local function BatchBoundaries()
 local scene=Scene();scene:CreateComponent('Octree');local digest=Hash();local cases={}
 for _,kind in ipairs({'Glow','Streak'}) do for _,limit in ipairs({0,1}) do
  local batch=Batch.New(scene,kind,limit);local calls={};local restore=FakeGeometry(batch,digest,calls)
  for index,alpha in ipairs({-1,0,.7,1,2}) do
   batch:Begin({1,2,-3},index);batch:Finish();assert(not batch.mesh.enabled and batch.count==0,'empty batch')
   local points={{1,2,3},{4,5,6},{7,8,9},{10,11,12}};local uv={{0,0},{1,0},{0,1},{1,1}}
   batch:Begin({1,2,-3},index)
   batch:Quad(points,uv,{2,3,4},alpha,index%2==0 and {.2,.4,.6,.8} or nil)
   batch:Quad(points,uv,{2,3,4},alpha,nil);batch:Finish()
   assert(batch.count==limit and batch.mesh.enabled==(limit>0),'bounded batch')
   digest.add({kind,limit,index,batch.count,batch.mesh.enabled})
   batch:Begin({1,2,-3},index+1);batch:Finish();assert(not batch.mesh.enabled,'cleared batch visibility')
  end
  cases[#cases+1]={kind=kind,limit=limit,calls=calls};restore();batch:Dispose()
 end end
 scene:Dispose();return {digest=digest.get(),cases=cases}
end
local function Scenario(name)
 math.randomseed(17102026)
 local equivalence=mode=='equivalence';local scene=Scene();scene:CreateComponent('Octree')
 local camera=scene:CreateChild('Camera');camera.position=Vector3(8,7,-12);camera.rotation=Quaternion(12,20,0)
 local groundCalls=0
 local effects=Effects.New(scene,function(x,z)groundCalls=groundCalls+1;return math.sin(x*.02)*.3+math.cos(z*.03)*.2 end)
 effects:Reserve({arc=true,chips=96})
 local trace,state=Hash(),Hash();local counts={};local fakeRestores,geometryDigests={},{}
 if equivalence then for _,key in ipairs({'Ribbon','Streak','Glow','Ring','Smoke','Arc'}) do
  geometryDigests[key]=Hash()
  fakeRestores[#fakeRestores+1]=FakeGeometry(effects.batches[key],geometryDigests[key],counts)
 end end
 local projectiles={}
 if name~='idle' then for i=1,24 do projectiles[i]={fx='bolt',pos={i%6*3,3,15+i*.4},vel={0,0,120},dist=8,s={tier=3},seed=i/24} end end
 local function Feed(frame)
  if name~='mixed' then return end
  if frame%6==1 then for i=1,6 do
   local pos={i*3,3,0};local hit={i*3,3,25}
   effects:Consume({{type='shot',kind='mg',tier=3,pos=pos,dir={0,0,1},spin=1},
    {type='impact',tier=3,pos=hit,dir={0,0,1},normal={0,0,-1},target=true,material='metal'}})
  end end
  if frame%30==1 then for i,kind in ipairs({'laser','sniper'}) do effects:Consume({
   {type='shot',kind=kind,tier=5,pos={i*4,3,0},dir={0,0,1}},
   {type='beam',kind=kind,tier=5,from={i*4,3,0},to={i*4,3,32},dir={0,0,1},hit=true,normal={0,0,-1}}}) end end
  if frame%90==1 then effects:Consume({{type='break',pos={6,3,20},dir={0,0,1},cells=3,color=0x8090a0}}) end
  if frame%120==1 then effects:Consume({{type='blast',kind='missile',tier=3,pos={12,3,24},radius=2.5,normal={0,1,0}}}) end
 end
 local frames=equivalence and 180 or 600
 if not equivalence then for i=1,120 do coroutine.yield();Feed(i);effects:Update(1/60,projectiles,camera) end end
 local rows,restore={},function()end
 if mode=='profile' then rows,restore=Instrument() end
 collectgarbage('collect');local heapStart=collectgarbage('count');local total=0;local batches={};local peak={}
 for frame=1,frames do
  coroutine.yield()
  Feed(frame+(equivalence and 0 or 120))
  local at=Clock();effects:Update(1/60,projectiles,camera);total=total+((Clock()-at)&0xffffffff)
  for key,b in pairs(effects.batches) do batches[key]=(batches[key] or 0)+b.count;peak[key]=math.max(peak[key] or 0,b.count) end
  if equivalence then
   for _,key in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'}) do state.add({frame,key,effects[key]}) end
   for _,key in ipairs({'Ribbon','Streak','Glow','Ring','Smoke','Arc'}) do local b=effects.batches[key];trace.add({frame,key,b.count,b.mesh.enabled,geometryDigests[key].get()}) end
   for index,c in ipairs(effects.chips.slots) do
    state.add({frame,index,c.active,c.pos,c.vel,c.spin,c.size,c.life,c.age,c.sequence,
     c.axis and {c.axis.x,c.axis.y,c.axis.z},c.rotation and {c.rotation.x,c.rotation.y,c.rotation.z,c.rotation.w}})
   end
   state.add(effects.missiles.booms);state.add(effects.missiles.log)
   local light=effects.light;local lp=light.node.position;local lc=light.light.color
   state.add({frame,light.intensity,light.decay,light.light.brightness,light.light.enabled,{lp.x,lp.y,lp.z},{lc.r,lc.g,lc.b,lc.a}})
  end
 end
 local heapEnd=collectgarbage('count');restore()
 local tail={};for i=1,32 do tail[i]=math.random() end
 local result={name=name,frames=frames,totalMs=total,perFrameMs=total/frames,stages=rows,batches=batches,peakBatches=peak,
  groundCalls=groundCalls,stateDigest=state.get(),geometryDigest=trace.get(),geometryCalls=counts,randomTail=tail,heapStartKiB=heapStart,heapEndKiB=heapEnd}
 for _,restoreMesh in ipairs(fakeRestores) do restoreMesh() end
 effects:Dispose();scene:Dispose();collectgarbage('collect');return result
end
local function Run()
 local ok,result=xpcall(function()local copy=mode=='equivalence' and VerifyNativeCopy() or nil;local boundaries=mode=='equivalence' and BatchBoundaries() or nil;return {status='PASS',mode=mode,label=label,seed=17102026,nativeCopy=copy,batchBoundaries=boundaries,
  scenarios={Scenario('idle'),Scenario('bolts'),Scenario('mixed')},
  boundary='Controlled real CombatEffects with Native CustomGeometry, hidden normal graphics Runtime and no viewport. Exactly one Effects.Update per engine Update event, with engine frames allowed to submit between samples. Fixed 24 bolt projectiles; mixed six machinegun emitters, T5 laser/sniper, impacts, chips and missile blasts. Profile includes method wrappers. Equivalence substitutes geometry recorder and hashes every vertex attribute, FX state and RNG tail. No full combat, frame rendering, shader visual acceptance or mobile FPS claim.'}
 end,debug.traceback)
 if not ok then result={status='FAIL',mode=mode,label=label,error=tostring(result)} end
 local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
---@type thread
local worker=nil
function Start()
 engine.maxFps=120;engine.maxInactiveFps=120
 worker=coroutine.create(Run)
 SubscribeToEvent('Update','PerfEffectsUpdate')
end
function PerfEffectsUpdate()
 if not worker or coroutine.status(worker)=='dead' then return end
 local ok,error=coroutine.resume(worker)
 if not ok then
  local file=assert(io.open(output,'wb'));file:write(cjson.encode({status='FAIL',mode=mode,label=label,error=tostring(error)}));file:close();engine:Exit()
 end
end
