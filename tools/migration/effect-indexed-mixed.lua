-- Real CombatEffects, unwrapped timed Update, separate native equivalence mode.
local Batch=require 'render.EffectBatch'
local output,mode,variant,label='','timing','A',''
for _,arg in ipairs(GetArguments()) do
    output=arg:match('^%-probe%-output=(.+)$') or output;mode=arg:match('^%-probe%-mode=(.+)$') or mode
    variant=arg:match('^%-probe%-variant=(.+)$') or variant;label=arg:match('^%-probe%-label=(.+)$') or label
end
if variant=='B' then Batch.New=require('dev.IndexedEffectCandidate').New end
local Effects=require 'render.CombatEffects'
local function Clock() return Time:GetSystemTime() end
local function Hash()
    local value=0xcbf29ce484222325
    local function Bytes(s) for i=1,#s do value=(value~s:byte(i))*0x100000001b3 end end
    local function Add(x)
        local kind=type(x)
        if kind=='number' then Bytes('n'..string.pack('<d',x)) elseif kind=='string' then Bytes('s'..#x..':'..x)
        elseif kind=='nil' then Bytes('nil') elseif kind=='boolean' then Bytes(x and 't' or 'f')
        elseif kind=='table' then
            local keys={};for k in pairs(x) do keys[#keys+1]=k end
            table.sort(keys,function(a,b)if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
            Bytes('{');for _,k in ipairs(keys) do Add(k);Add(x[k]) end;Bytes('}')
        else error('Unsupported hash value '..kind) end
    end
    return {add=Add,get=function()return string.format('%016x',value)end}
end
local function Vertex(batch,index,vertices,indices)
    if not batch.vb then
        local v=batch.mesh:GetVertex(0,index);local p,n,uv=v.position,v.normal,v.texCoord
        local r={p.x,p.y,p.z,n.x,n.y,n.z,v.color,uv.x,uv.y}
        if batch.kind=='Streak' then local t=v.tangent;r[10]=t.x;r[11]=t.y;r[12]=t.z;r[13]=t.w end
        return r
    end
    local offset=batch.largeIndices and indices:ReadUInt() or indices:ReadUShort()
    vertices:Seek(offset*batch.vb:GetVertexSize())
    local p,n,c,uv=vertices:ReadVector3(),vertices:ReadVector3(),vertices:ReadUInt(),vertices:ReadVector2()
    local r={p.x,p.y,p.z,n.x,n.y,n.z,c,uv.x,uv.y}
    if batch.kind=='Streak' then local t=vertices:ReadVector4();r[10]=t.x;r[11]=t.y;r[12]=t.z;r[13]=t.w end
    return r
end
local function GeometryDigest(batch,digest)
    digest.add({batch.kind,batch.count,batch.mesh.enabled})
    if batch.count==0 then return 0 end
    local vertices=batch.vb and batch.vb:GetData();local indices=batch.ib and batch.ib:GetData()
    if indices then indices:Seek(0) end
    for index=0,batch.count*6-1 do digest.add(Vertex(batch,index,vertices,indices)) end
    if vertices then vertices:Clear();indices:Clear() end
    return batch.count*6
end
local function Feed(effects,frame)
    if frame%6==1 then for i=1,6 do effects:Consume({
        {type='shot',kind='mg',tier=3,pos={i*3,3,0},dir={0,0,1},spin=1},
        {type='impact',tier=3,pos={i*3,3,25},dir={0,0,1},normal={0,0,-1},target=true,material='metal'}}) end end
    if frame%30==1 then for i,kind in ipairs({'laser','sniper'}) do effects:Consume({
        {type='shot',kind=kind,tier=5,pos={i*4,3,0},dir={0,0,1}},
        {type='beam',kind=kind,tier=5,from={i*4,3,0},to={i*4,3,32},dir={0,0,1},hit=true,normal={0,0,-1}}}) end end
    if frame%90==1 then effects:Consume({{type='break',pos={6,3,20},dir={0,0,1},cells=3,color=0x8090a0}}) end
    if frame%120==1 then effects:Consume({{type='blast',kind='missile',tier=3,pos={12,3,24},radius=2.5,normal={0,1,0}}}) end
end
local function Run()
    assert(collectgarbage('isrunning'),'Normal automatic GC required')
    local equivalence=mode=='equivalence';assert(equivalence or mode=='timing','Unknown mode')
    local prior=io.open(output,'rb');if prior then prior:close();error('Preserve prior evidence') end
    math.randomseed(17102026)
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('Camera');camera.position=Vector3(8,7,-12);camera.rotation=Quaternion(12,20,0)
    local groundCalls=0
    local effects=Effects.New(scene,function(x,z)groundCalls=groundCalls+1;return math.sin(x*.02)*.3+math.cos(z*.03)*.2 end)
    effects:Reserve({arc=true,chips=96})
    local projectiles={};for i=1,24 do projectiles[i]={fx='bolt',pos={i%6*3,3,15+i*.4},vel={0,0,120},dist=8,s={tier=3},seed=i/24} end
    for frame=1,60 do coroutine.yield();Feed(effects,frame);effects:Update(1/60,projectiles,camera) end
    local frames=equivalence and 180 or 480;local total=0;local heapStart=collectgarbage('count')
    local geometry,state=Hash(),Hash();local batchTotals,peak={},{};local deindexedVertices=0
    for frame=1,frames do
        coroutine.yield();Feed(effects,frame+60)
        local at=Clock();effects:Update(1/60,projectiles,camera);total=total+((Clock()-at)&0xffffffff)
        for _,key in ipairs({'Ribbon','Streak','Glow','Ring','Smoke','Arc'}) do
            local batch=effects.batches[key];batchTotals[key]=(batchTotals[key] or 0)+batch.count;peak[key]=math.max(peak[key] or 0,batch.count)
            if equivalence then geometry.add({frame,key});deindexedVertices=deindexedVertices+GeometryDigest(batch,geometry) end
        end
        if equivalence then
            for _,key in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'}) do state.add({frame,key,effects[key]}) end
            for index,c in ipairs(effects.chips.slots) do state.add({frame,index,c.active,c.pos,c.vel,c.spin,c.size,c.life,c.age,c.sequence,
                c.axis and {c.axis.x,c.axis.y,c.axis.z},c.rotation and {c.rotation.x,c.rotation.y,c.rotation.z,c.rotation.w}}) end
            state.add(effects.missiles.booms);state.add(effects.missiles.log)
            local light=effects.light;local p,c=light.node.position,light.light.color
            state.add({frame,light.intensity,light.decay,light.light.brightness,light.light.enabled,{p.x,p.y,p.z},{c.r,c.g,c.b,c.a}})
        end
    end
    local heapEnd=collectgarbage('count');local tail={};for i=1,32 do tail[i]=math.random() end
    local result={status='PASS',variant=variant,mode=mode,label=label,seed=17102026,warmup=60,frames=frames,totalMs=total,
        perFrameMs=total/frames,heapStartKiB=heapStart,heapEndKiB=heapEnd,collectorRunning=collectgarbage('isrunning'),
        stateDigest=state.get(),geometryDigest=geometry.get(),deindexedVertices=deindexedVertices,
        batchTotals=batchTotals,peakBatches=peak,groundCalls=groundCalls,randomTail=tail,
        boundary='Isolated real CombatEffects mixed event loop, one Update per native engine Update; no viewport. Normal automatic GC, no instrumentation wrappers or forced collections. Timing mode makes no equality claim; separate equivalence mode hashes actual native deindexed vertices and effect state outside timer. Not full battle/Web/TapTap/845 FPS acceptance.'}
    effects:Dispose();scene:Dispose();return result
end
---@type thread|nil
local worker=nil
function Start()
    engine.maxFps=120;engine.maxInactiveFps=120
    worker=coroutine.create(function()
        local ok,result=xpcall(Run,debug.traceback)
        if not ok then result={status='FAIL',variant=variant,mode=mode,label=label,error=tostring(result)} end
        local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
    end)
    SubscribeToEvent('Update','IndexedMixedUpdate')
end
function IndexedMixedUpdate()
    if not worker or coroutine.status(worker)=='dead' then return end
    local ok,err=coroutine.resume(worker)
    if not ok then print('[IndexedMixed] FAIL '..tostring(err));engine:Exit() end
end
