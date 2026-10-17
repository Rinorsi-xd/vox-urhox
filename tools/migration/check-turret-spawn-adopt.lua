local BP=require 'construction.Blueprint'
local BaseRange=require 'construction.TurretRange'
local BaseSpec=require 'drive.VehicleSpec'
local BaseCache=require 'drive.SpawnSpecCache'
local BaseUnit=assert(load(baseline_unit_source,'baseline-CarUnit'))()
local Range=assert(load(candidate_range_source,'candidate-TurretRange'))()
package.loaded['construction.TurretRange']=Range
package.loaded['drive.VehicleSpec']=nil
local Spec=require 'drive.VehicleSpec'
local Cache=assert(load(candidate_cache_source,'candidate-SpawnSpecCache'))()
local Unit=assert(load(candidate_unit_source,'candidate-CarUnit'))()
local function Up(fn,name)
    for i=1,100 do local k,v=debug.getupvalue(fn,i);if k==name then return v end;if not k then break end end
    error('Missing upvalue '..name)
end
local baseCached,cached=Up(BaseRange.For,'cached'),Up(Range.For,'cached')
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local labels={}
adopt_footprints={}
local function Check(v,label) assert(v,label);labels[#labels+1]=label end
local function BeforeNative(module,source,cache)
    local retained=false;local progress={};local env={time=0,viewEvents={}}
    function env:NewVehicle() error('Unexpected native body') end
    local ok,err=pcall(module.New,env,source,{name='offline',team='blue',combat=false,spawnSpecCache=cache},function(p)
        assert(type(p)=='number' and p>=0 and p<=1)
        progress[#progress+1]=p
        if p==.9 then error('EXPECTED_PRE_NATIVE_STOP',0) end
    end,function(u) retained=u end)
    assert(not ok and tostring(err):find('EXPECTED_PRE_NATIVE_STOP',1,true),tostring(err))
    return retained,progress
end
local function Independent(a,b)
    if type(a)~='table' or type(b)~='table' then return true end
    assert(a~=b,'Mutable cache table shared')
    for key,value in pairs(a) do
        if key~='samples' and key~='def' then Independent(value,b[key]) end
    end
    return true
end
for index,row in ipairs(adopt_roster) do
    local baseCache,cache=BaseCache.New(),Cache.New()
    Check(baseCache:Prepare(row.source) and cache:Prepare(row.source),'K '..index..' prepare both actual specs')
    Check(Equal(baseCache:Get(row.source),cache:Get(row.source)),'K '..index..' pristine specs exact')
    local a=BeforeNative(BaseUnit,row.source,baseCache)
    local b,progress=BeforeNative(Unit,row.source,cache)
    Check(baseCached[a.bp]==nil and cached[b.bp]~=nil,'K '..index..' actual baseline cold and adopted warm')
    Check(Equal(a.bp:ToTable(),b.bp:ToTable()) and Equal(a.hp,b.hp) and Equal(a.shields,b.shields),'K '..index..' constructor blueprint hp shields exact')
    local seen={};local tableCount,packedBytes,packedCount=0,0,0
    local function Footprint(value,key)
        if key=='def' or key=='samples' then return end
        if type(value)~='table' or seen[value] then return end
        seen[value]=true;tableCount=tableCount+1
        for k,v in pairs(value) do Footprint(v,k) end
    end
    Footprint(cached[b.bp])
    for _,entry in pairs(cached[b.bp].entries) do
        for _,rays in pairs(entry.context and entry.context.rays or {}) do
            for _,ray in pairs(rays) do if type(ray)=='string' then packedCount=packedCount+1;packedBytes=packedBytes+#ray end end
        end
    end
    adopt_footprints[#adopt_footprints+1]={unit=index,copiedMutableTablesPerSnapshotOrAdoption=tableCount,sharedPackedRayStringBytes=packedBytes,sharedPackedRayStrings=packedCount}
    local prime=0;for _,p in ipairs(progress) do if p==.75 then prime=prime+1 end end
    Check(prime==0,'K '..index..' no redundant prime checkpoint')
    local template=cache:Get(row.source)
    local fresh=BP.New():Load(row.source);cache:Get(row.source,fresh)
    Check(Independent(cached[b.bp],cached[fresh]),'K '..index..' two units independent mutable cache')
    local expected=BaseRange.For(a.bp,template.rotorOf)
    local actual=Range.For(b.bp,template.rotorOf)
    Check(Equal(expected,actual),'K '..index..' unchanged exact ranges')
    Check(Equal(baseCached[a.bp],cached[b.bp]),'K '..index..' unchanged exact full contexts rays')
    local removed={}
    for _,part in ipairs(a.bp:List()) do
        if #removed<3 and not require('parts.Defs').PARTS[part.type].weapon then removed[#removed+1]=Cache.Clone(part) end
    end
    for step,part in ipairs(removed) do
        a.bp:Remove(part.id);b.bp:Remove(part.id)
        local x,y=BaseSpec.Build(a.bp),Spec.Build(b.bp)
        Check(Equal(x,y),'K '..index..' cumulative damage '..step..' exact full spec')
        Check(Equal(baseCached[a.bp],cached[b.bp]),'K '..index..' cumulative damage '..step..' exact cache')
    end
    for _,part in ipairs(removed) do a.bp:Add(part);b.bp:Add(Cache.Clone(part)) end
    Check(Equal(BaseSpec.Build(a.bp),Spec.Build(b.bp)),'K '..index..' repair exact full spec')
    Check(Equal(baseCached[a.bp],cached[b.bp]),'K '..index..' repair exact cache')
    local first=b.bp:List()[1]
    if first then
        local movedA=Cache.Clone(a.bp.parts[first.id]);local movedB=Cache.Clone(b.bp.parts[first.id])
        a.bp:Remove(first.id);b.bp:Remove(first.id)
        movedA.pos[1]=movedA.pos[1]+20;movedB.pos[1]=movedB.pos[1]+20
        a.bp:Add(movedA);b.bp:Add(movedB)
        Check(Equal(BaseSpec.Build(a.bp),Spec.Build(b.bp)),'K '..index..' moved part exact')
    end
    local pristine=BP.New():Load(row.source);local pristineSpec=Spec.Build(pristine)
    local token=Range.Capture(pristine,pristineSpec.rotorOf)
    Check(token~=nil,'K '..index..' capture valid precomputed cache')
    local adopter=BP.New():Load(row.source)
    Check(Range.Adopt(adopter,pristineSpec.rotorOf,token),'K '..index..' direct adopt identical full source')
    Check(Independent(cached[pristine],cached[adopter]),'K '..index..' snapshot independent original cache')
    local wrongOwner=Cache.Clone(pristineSpec.rotorOf);local p=adopter:List()[1]
    wrongOwner[p.id]=(wrongOwner[p.id] or 0)+999
    local reject=BP.New():Load(row.source)
    Check(not Range.Adopt(reject,wrongOwner,token) and not cached[reject],'K '..index..' owner signature mismatch cold')
    local typedOwner=Cache.Clone(pristineSpec.rotorOf);typedOwner[p.id]=tostring(typedOwner[p.id])
    local typedReject=BP.New():Load(row.source)
    Check(not Range.Adopt(typedReject,typedOwner,token) and not cached[typedReject],'K '..index..' owner type mismatch cold')
    local altered=BP.New():Load(row.source);local alteredPart=altered:List()[1]
    alteredPart._cells[1][1]=alteredPart._cells[1][1]+1
    Check(not Range.Adopt(altered,pristineSpec.rotorOf,token) and not cached[altered],'K '..index..' derived cells mismatch cold')
    local shifted=BP.New():Load(row.source);local shiftedPart=shifted:List()[1]
    shiftedPart.pos[1]=shiftedPart.pos[1]+1e-13
    Check(not Range.Adopt(shifted,pristineSpec.rotorOf,token) and not cached[shifted],'K '..index..' sub-string-precision position mismatch cold')
    local ownerA,ownerB=BP.New():Load(row.source),BP.New():Load(row.source)
    BaseSpec.Build(ownerA)
    cache:Get(row.source,ownerB)
    Check(Equal(BaseRange.For(ownerA,wrongOwner),Range.For(ownerB,wrongOwner)),'K '..index..' changed owner actual range exact')
    Check(Equal(baseCached[ownerA],cached[ownerB]),'K '..index..' changed owner actual cache exact')
    local changed=Cache.Clone(row.source);changed.name=tostring(changed.name)..'-changed'
    local changedBp=BP.New():Load(changed)
    Check(cache:Get(changed,changedBp)==nil and not cached[changedBp],'K '..index..' changed canonical source cache miss cold')
    -- Neither later mutations of the source cache nor one adopted unit affect another.
    local untouched=Cache.Clone(cached[adopter])
    pristine:Remove(pristine:List()[1].id);Range.For(pristine,pristineSpec.rotorOf)
    Check(Equal(untouched,cached[adopter]),'K '..index..' later source cache mutation isolated')
    local third=BP.New():Load(row.source);Check(Range.Adopt(third,pristineSpec.rotorOf,token),'K '..index..' snapshot survives source mutation')
    Check(Equal(untouched,cached[third]) and Independent(cached[adopter],cached[third]),'K '..index..' snapshot remains pristine and independent')
    -- Cancellation during capture must not publish a half-prepared entry.
    local cancel=Cache.New();local realCapture=Range.Capture
    Range.Capture=function(bp,owner,checkpoint)
        return realCapture(bp,owner,function() cancel:Dispose();if checkpoint then checkpoint() end end)
    end
    local prepared=cancel:Prepare(row.source,function() end);Range.Capture=realCapture
    Check(not prepared and cancel.disposed and not next(cancel.entries) and not next(cancel.turretCaches),'K '..index..' Dispose during capture publishes nothing')
    local failing=Cache.New()
    Range.Capture=function(bp,owner) return realCapture(bp,owner,function() error('EXPECTED_CAPTURE_CANCEL',0) end) end
    local ok,err=pcall(failing.Prepare,failing,row.source);Range.Capture=realCapture
    Check(not ok and tostring(err):find('EXPECTED_CAPTURE_CANCEL',1,true) and not next(failing.entries),'K '..index..' capture exception leaves no entry')
    local disposedBp=BP.New():Load(row.source);cache:Dispose()
    Check(cache:Get(row.source,disposedBp)==nil and not cached[disposedBp] and not next(cache.turretCaches),'K '..index..' Dispose clears scene snapshot handles')
    a:Dispose();b:Dispose();baseCache:Dispose();failing:Dispose()
end
-- A disconnected source part is captured before CarUnit's existing pruning.
local disconnected=BP.New():Load(adopt_roster[1].source)
local nonweapon
for _,p in ipairs(disconnected:List()) do if not require('parts.Defs').PARTS[p.type].weapon then nonweapon=p;break end end
assert(nonweapon)
disconnected:Add{type=nonweapon.type,pos={999,999,999},rot=nonweapon.rot}
local source=disconnected:ToTable()
local c0,c1=BaseCache.New(),Cache.New();assert(c0:Prepare(source) and c1:Prepare(source))
local d0,d1=BeforeNative(BaseUnit,source,c0),BeforeNative(Unit,source,c1)
Check(#d1.bp:List()<#disconnected:List(),'disconnected source pruned by original constructor')
Check(Equal(BaseSpec.Build(d0.bp),Spec.Build(d1.bp)),'disconnected pruning exact next rebuild spec')
Check(Equal(baseCached[d0.bp],cached[d1.bp]),'disconnected pruning exact next rebuild cache')
local miss=Cache.New();local direct=BeforeNative(Unit,source,miss)
Check(miss.misses==1 and cached[direct.bp]~=nil,'cache miss preserves original Spec.Build warm cache')
local synchronous,env=false,{time=0,viewEvents={}}
function env:NewVehicle() error('EXPECTED_NATIVE_BOUNDARY',0) end
local ok,err=pcall(Unit.New,env,source,{name='sync',team='blue',combat=false,spawnSpecCache=c1},nil,function(u) synchronous=u end)
Check(not ok and tostring(err):find('EXPECTED_NATIVE_BOUNDARY',1,true) and synchronous and cached[synchronous.bp]~=nil,'synchronous cached spawn adopts without scheduling')
local mutable=Cache.Clone(source);local frozen=Cache.Clone(source);local mutationCache=Cache.New();local changed=false
assert(mutationCache:Prepare(mutable,function() if not changed then changed=true;mutable.name='mutated-while-yielding' end end))
Check(mutationCache:Get(mutable)==nil and mutationCache:Get(frozen)~=nil,'source snapshot before checkpoint remains canonical')
local pending=Cache.New();local captured=false;local realCapture=Range.Capture
Range.Capture=function(bp,owner,checkpoint)
    return realCapture(bp,owner,function() captured=true;coroutine.yield('CAPTURE_PAUSE');if checkpoint then checkpoint() end end)
end
local co=coroutine.create(function() pending:Prepare(source,function() end) end)
local resumed,value=coroutine.resume(co)
Check(resumed and value=='CAPTURE_PAUSE' and captured and not next(pending.entries),'capture coroutine suspended without publishing')
Check(coroutine.close(co),'capture coroutine cancellation closes cleanly');Range.Capture=realCapture
pending:Dispose();d0:Dispose();d1:Dispose();direct:Dispose();synchronous:Dispose();c0:Dispose();c1:Dispose();miss:Dispose();mutationCache:Dispose()
return labels
