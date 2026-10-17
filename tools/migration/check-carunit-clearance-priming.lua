local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Cache=require 'drive.SpawnSpecCache'
local Range=require 'construction.TurretRange'
local Base=assert(load(baseline_unit_source,'baseline-CarUnit'))()
local Candidate=assert(load(candidate_unit_source,'candidate-CarUnit'))()
local function Up(fn,name)
    for i=1,100 do local k,v=debug.getupvalue(fn,i);if k==name then return v end;if not k then break end end
    error('Missing upvalue '..name)
end
local cached=Up(Range.For,'cached')
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local labels={}
local function Check(v,label) assert(v,label);labels[#labels+1]=label end
local function StopBeforeNative(module,source,cache)
    local retained=false;local progress={};local env={time=0,viewEvents={}}
    function env:NewVehicle() error('Native construction reached in offline test') end
    local ok,err=pcall(module.New,env,source,{name='offline',team='blue',combat=false,spawnSpecCache=cache},function(p)
        assert(type(p)=='number' and p>=0 and p<=1,'Numeric loading progress required')
        progress[#progress+1]=p
        if p==.9 then error('EXPECTED_PRE_NATIVE_STOP',0) end
    end,function(u) assert(not retained);retained=u end)
    assert(not ok and tostring(err):find('EXPECTED_PRE_NATIVE_STOP',1,true),tostring(err))
    return retained,progress
end
for i,row in ipairs(priming_roster) do
    local cache=Cache.New();Check(cache:Prepare(row.source),'K '..i..' real cache prepared')
    local template=cache:Get(row.source)
    local baseline,bp=StopBeforeNative(Base,row.source,cache)
    local candidate,cp=StopBeforeNative(Candidate,row.source,cache)
    Check(not cached[baseline.bp],'K '..i..' cached baseline actual bp cold')
    Check(cached[candidate.bp]~=nil,'K '..i..' cached candidate actual bp warm')
    Check(Equal(baseline.bp:ToTable(),candidate.bp:ToTable()),'K '..i..' actual blueprint exact')
    Check(Equal(baseline.hp,candidate.hp) and Equal(baseline.shields,candidate.shields),'K '..i..' hp and shields exact')
    Check(Equal(template,cache:Get(row.source)),'K '..i..' spec template unchanged')
    local expected=Range.For(baseline.bp,template.rotorOf)
    local actual=Range.For(candidate.bp,template.rotorOf)
    Check(Equal(expected,actual),'K '..i..' final ranges exact')
    Check(Equal(cached[baseline.bp],cached[candidate.bp]),'K '..i..' final occupancy/rays exact')
    local n=0;for _,p in ipairs(cp) do if p==.75 then n=n+1 end end
    Check(n>0,'K '..i..' prime checkpoints adapted to .75')
    baseline:Dispose();candidate:Dispose()
    -- No checkpoint means synchronous respawn; stop only at real native boundary.
    local retained=false;local env={time=0,viewEvents={}}
    function env:NewVehicle() error('EXPECTED_NATIVE_BOUNDARY',0) end
    local ok,err=pcall(Candidate.New,env,row.source,{name='sync',team='blue',combat=false,spawnSpecCache=cache},nil,function(u) retained=u end)
    Check(not ok and tostring(err):find('EXPECTED_NATIVE_BOUNDARY',1,true),'K '..i..' synchronous path reaches native boundary')
    Check(retained and not cached[retained.bp],'K '..i..' synchronous path not primed');retained:Dispose()
    -- Cache miss still uses actual Spec.Build, preserving direct-path cache behavior.
    local miss=Cache.New();local direct=StopBeforeNative(Candidate,row.source,miss)
    Check(miss.misses==1 and cached[direct.bp]~=nil,'K '..i..' cache miss direct Spec path warm');direct:Dispose();miss:Dispose()
    -- Actual constructor retains ownership before first prime scheduling point.
    local cancelled=false;local events={};local cancelEnv={time=0,viewEvents=events}
    function cancelEnv:NewVehicle() error('Cancelled constructor reached native body') end
    local co=coroutine.create(function()
        Candidate.New(cancelEnv,row.source,{name='cancel',team='blue',combat=false,spawnSpecCache=cache},function(p)
            assert(p==.75 and cancelled and cancelled.bp and not cancelled.vehicle)
            coroutine.yield('PRIME_PAUSE')
        end,function(u) cancelled=u end)
    end)
    local resumed,value=coroutine.resume(co)
    Check(resumed and value=='PRIME_PAUSE' and coroutine.status(co)=='suspended','K '..i..' retained before prime yield')
    Check(coroutine.close(co),'K '..i..' pending prime closes cleanly')
    cancelled:Dispose();Check(not cancelled.alive and #events==1 and events[1].type=='unitRemoved','K '..i..' retained partial unit disposes')
    local errored=false
    local ok2,err2=pcall(Candidate.New,cancelEnv,row.source,{name='error',team='blue',combat=false,spawnSpecCache=cache},function(p)
        assert(p==.75 and errored and not errored.vehicle);error('EXPECTED_PRIME_CANCEL',0)
    end,function(u) errored=u end)
    Check(not ok2 and tostring(err2):find('EXPECTED_PRIME_CANCEL',1,true),'K '..i..' prime error propagated')
    errored:Dispose();cache:Dispose()
end
return labels
