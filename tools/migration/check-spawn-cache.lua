local Cache=require 'drive.SpawnSpecCache'
local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Prefab=require 'construction.Prefab'
local checks={}
local function Check(value,name) assert(value,name);checks[#checks+1]=name end
local function Equal(a,b,memo)
    if a==b then return true end
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return false end
    memo=memo or {};if memo[a] then return memo[a]==b end;memo[a]=b
    for k,v in pairs(a) do if not Equal(v,b[k],memo) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Async(fn)
    local result,yields=nil,0
    local co=coroutine.create(function() result=fn(function() coroutine.yield() end) end)
    while coroutine.status(co)~='dead' do local ok,why=coroutine.resume(co);assert(ok,why);yields=yields+1 end
    return result,yields-1
end
local originalRandom,originalSeed=math.random,math.randomseed
math.random=function() error('cache consumed RNG') end
math.randomseed=function() error('cache reseeded RNG') end
local cache=Cache.New()
local source=Prefab.Create(BP.New(),'raceCar'):ToTable()
Check(cache:Get(source)==nil and cache.prepared==0,'unprepared source misses without preparing at runtime')
for _,id in ipairs({'raceCar','megaMech','scorpion','hawk','feather','vanguard','tianyuan','fuyuan','fox','trooper'}) do
    local data=Prefab.Create(BP.New(),id):ToTable()
    local expected=Spec.Build(BP.New():Load(data))
    local ok,yields=Async(function(pause) return cache:Prepare(data,pause) end)
    Check(ok and yields>0,'prepares under cooperative loading '..id)
    local a,b=cache:Get(data),cache:Get(Cache.Clone(data))
    Check(Equal(a,expected) and Equal(b,expected),'actual complete spec matches direct build '..id)
    Check(a~=b and a.bounds~=b.bounds and a.hulls~=b.hulls,'runtime clones isolated '..id)
    a.bounds.min[1]=a.bounds.min[1]+777;a.motion.mass=0
    if a.hulls[1] then a.hulls[1].center[1]=888 end
    Check(Equal(cache:Get(data),expected) and Equal(b,expected),'consumer mutations cannot poison template '..id)
end
local prepared=cache.prepared
Check(cache:Prepare(source) and cache.prepared==prepared,'identical prepared contents deduplicate')
local old=source.parts[1][2];source.parts[1][2]=old+1
Check(cache:Get(source)==nil,'in-place source position mutation misses')
source.parts[1][2]=old;Check(cache:Get(source)~=nil,'restored content matches template')
source.parts[1],source.parts[2]=source.parts[2],source.parts[1]
Check(cache:Get(source)==nil,'source row ordering is part of identity')
source.parts[1],source.parts[2]=source.parts[2],source.parts[1]
source.parts[1][6]=(source.parts[1][6] or 0)+1
Check(cache:Get(source)==nil,'non-geometry source content changes also invalidate')
local special={x=1};local sparse={[0]=special,[8]=special,lo=-math.huge,hi=math.huge};sparse.self=sparse
local clone=Cache.Clone(sparse)
Check(clone~=sparse and clone[0]~=special and clone[0]==clone[8] and clone.self==clone,'clone preserves sparse keys aliases and cycles')
Check(clone.lo==-math.huge and clone.hi==math.huge,'clone preserves infinite angle bounds')
local nullClone=Cache.Clone({a=cjson.null});Check(nullClone.a==cjson.null,'source null singleton preserved')
local changing=Prefab.Create(BP.New(),'vanguard'):ToTable();local original=Cache.Clone(changing)
local capture=Cache.New();local co=coroutine.create(function() capture:Prepare(changing,function() coroutine.yield() end) end)
assert(coroutine.resume(co));changing.parts[1][2]=changing.parts[1][2]+42
while coroutine.status(co)~='dead' do local ok,why=coroutine.resume(co);assert(ok,why) end
Check(capture:Get(changing)==nil and capture:Get(original)~=nil,'input mutated while suspended cannot poison prepared key')
capture:Dispose();Check(capture:Get(original)==nil and next(capture.entries)==nil,'scene release empties entries and disables reads')
Check(not capture:Prepare(original),'disposed scene cannot repopulate')
local cancel=Cache.New();local cancelCo=coroutine.create(function() return cancel:Prepare(original,function() coroutine.yield() end) end)
assert(coroutine.resume(cancelCo));cancel:Dispose()
while coroutine.status(cancelCo)~='dead' do local ok,why=coroutine.resume(cancelCo);assert(ok,why) end
Check(next(cancel.entries)==nil and cancel.prepared==0,'dispose during cooperative prepare cannot repopulate')
local Unit=require 'combat.CarUnit'
local sourceUnit=Prefab.Create(BP.New(),'raceCar'):ToTable();assert(cache:Prepare(sourceUnit))
local specBuild=Spec.Build;local calls=0
Spec.Build=function(...) calls=calls+1;return specBuild(...) end
local env={time=0,viewEvents={},units={}}
function env:NewVehicle(spec)
    return {Dispose=function() end,Place=function() end,
        body={translation=function() return {x=0,y=0,z=0} end,rotation=function() return {x=0,y=0,z=0,w=1} end,
            center=function() return {x=0,y=0,z=0} end}}
end
local config={name='cached fixture',spawn={pos={0,0,0},yaw=0},spawnSpecCache=cache}
local u=Unit.New(env,sourceUnit,config)
Check(u.alive and calls==0 and u.spec~=cache:Get(sourceUnit),'actual CarUnit uses a private prepared spec')
u:Spawn();Check(calls==0,'pristine spawn reuses only explicitly prepared content')
u:Dispose();Check(u.spawnSpecCache==nil,'Unit.Dispose severs scene cache reference')
local altered=Cache.Clone(sourceUnit);altered.parts[1][6]=(altered.parts[1][6] or 0)+1
local v=Unit.New(env,altered,config);Check(v.alive and calls==1,'actual CarUnit misses changed source and builds synchronously');v:Dispose()
Spec.Build=specBuild
package.loaded['combat.EnemyDriver']={New=function() return {} end}
package.loaded['render.StoryStomp']={Emit=function() end}
local Mission=require 'story.Mission'
local Data=require 'story.MissionData';local Arena=require 'combat.ArenaData'
for levelNo,level in ipairs(Data.levels) do
    local mission=setmetatable({level=level,tier=2},{__index=Mission})
    local last=0
    local _,yields=Async(function(pause) mission:PrepareSpawnSpecs(function(p) assert(p>=last and p<=1);last=p;pause() end) end)
    Check(mission.spawnSpecCache and last==1 and yields>0,'actual mission prepares owned cache with progress '..levelNo)
    local count=0
    local function Included(e,role)
        local tier=math.max(1,math.min(5,mission.tier+(e.tier or 0)))
        local data=e.source or Arena.prefabs['red:'..tier..':'..(e.role or role or 'assault')..':0']
        Check(data and mission.spawnSpecCache:Get(data)~=nil,'mission '..levelNo..' known enemy '..count);count=count+1
    end
    for _,step in ipairs(level.steps) do
        for _,e in ipairs(step.enemies or {}) do Included(e,step.role) end
        for _,group in ipairs({step.guards or {},step.counter or {}}) do for _,e in ipairs(group) do Included(e) end end
        for _,beat in ipairs(step.beats or {}) do for _,e in ipairs(beat.spawn or {}) do Included(e) end end
        if step.drillSource then Included({source=step.drillSource}) end
    end
    if levelNo==3 then
        mission.world=env;env.layout={nav={nodes={}}};env.stats={};env.CastRay=function() return nil end
        mission.entries={};mission.player={pos={10,0,10},vehicle={body={}}};mission.rules={time=7}
        mission.session={effects={}};mission.damageScale=.6
        local builds=0;Spec.Build=function(...) builds=builds+1;return specBuild(...) end
        local step={enemies={{at={0,0,0},role='assault'}}}
        Mission.Spawn(mission,step);Mission.Spawn(mission,step)
        Check(builds==0 and #mission.entries==2,'actual runtime Mission.Spawn uses prepared pool without Spec.Build')
        Check(mission.entries[1].unit.spec~=mission.entries[2].unit.spec,'actual successive story spawns have distinct specs')
        Check(mission.rules.time==7,'prepared spawn does not advance mission clock')
        for _,entry in ipairs(mission.entries) do entry.unit:Dispose() end
        Spec.Build=specBuild
    end
    local retained=mission.spawnSpecCache
    mission.entries={};mission.world={units={}};mission.session={};Mission.Dispose(mission)
    Check(retained.disposed and next(retained.entries)==nil and mission.spawnSpecCache==nil,'actual Mission.Dispose releases prepared templates '..levelNo)
end
cache:Dispose()
math.random,math.randomseed=originalRandom,originalSeed
Check(true,'preparation cloning lookup and disposal never consume or reseed RNG')
return checks
