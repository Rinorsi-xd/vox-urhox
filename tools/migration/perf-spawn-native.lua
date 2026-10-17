-- Isolated diagnostic: unchanged real CarUnit.Spawn, same eight captured sources.
local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Unit=require 'combat.CarUnit'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local Cache=require 'drive.SpawnSpecCache'
local output=false
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local function Now() return Time:GetSystemTime() end
local function Diff(a,b) return (a-b)&0xffffffff end
local function Read(path)
    local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close();return cjson.decode(bytes)
end
local function Equal(a,b,seen,path)
    path=path or '$'
    if type(a)~=type(b) then return false,path..':type' end
    if type(a)~='table' then
        if a==b or type(a)=='number' and a~=a and b~=b then return true end
        return false,path..':value'
    end
    seen=seen or {};if seen[a] then return seen[a]==b,path..':alias' end;seen[a]=b
    for k,v in pairs(a) do local ok,why=Equal(v,b[k],seen,path..'.'..tostring(k));if not ok then return false,why end end
    for k in pairs(b) do if a[k]==nil then return false,path..':extra:'..tostring(k) end end
    return true
end
local function Tables(value,set)
    if type(value)~='table' or set[value] then return end;set[value]=true
    for k,v in pairs(value) do Tables(k,set);Tables(v,set) end
end
local function Run()
    math.randomseed(1016)
    assert(collectgarbage('isrunning'),'Use normal automatic GC')
    local fixture=Read('spawn-roster.json');assert(#fixture.roster==8)
    local scene=Scene();scene:CreateComponent('Octree');local space=Space.New(scene)
    local floor=scene:CreateChild('floor');floor.position=Vector3(0,-1,0)
    local body=floor:CreateComponent('RigidBody');body.collisionLayer=1;body.collisionMask=0xffff
    floor:CreateComponent('CollisionShape'):SetBox(Vector3(4000,2,4000));space:Register(body,{type='ground'})
    local env={space=space,time=0,viewEvents={}}
    function env:NewVehicle(spec,unit)
        local vehicle=Vehicle.New(self.space,spec);self.space:SetOwner(vehicle.native,{type='car',ref=unit});return vehicle
    end
    local units,metadata={},{}
    local cache=Cache.New();local prepareStarted=Now()
    for i,row in ipairs(fixture.roster) do assert(cache:Prepare(row.source),'Prepare source '..i) end
    local prepareMs=Diff(Now(),prepareStarted)
    local isolation={noSharedTables=true,mutationsIsolated=true,sourceChangeMiss=true}
    for i,row in ipairs(fixture.roster) do
        local a,b=cache:Get(row.source),cache:Get(row.source);local left,right={},{};Tables(a,left);Tables(b,right)
        for t in pairs(left) do assert(not right[t],'Cache returned shared mutable table '..i) end
        local center=a.boxes[1] and a.boxes[1].center
        if center then local old=b.boxes[1].center[1];center[1]=center[1]+123;assert(cache:Get(row.source).boxes[1].center[1]==old,'Cache mutation leaked') end
        local changed=Cache.Clone(row.source);changed.name=tostring(changed.name)..'-signature-check'
        assert(cache:Get(changed)==nil,'Changed source must miss cache')
        local u=Unit.New(env,row.source,{name=row.name,team=row.team,combat=true,externalControl=true,autoRespawn=false,
            spawn={pos={(i-1)*50,0,0},yaw=0}})
        assert(u.alive,'Actual source assembly failed '..i);units[i]=u
        metadata[i]={name=row.name,team=row.team,role=row.role or false,parts=u.bp:Size(),mass=u.vehicle.mass,
            wheels=#u.vehicle.wheels,legs=#u.spec.legs,hovers=#u.spec.hovers}
    end
    local active=false;local stats=false;local originals={}
    local function Wrap(object,key,label)
        local old=object[key];originals[#originals+1]={object,key,old}
        object[key]=function(...)
            if not active then return old(...) end
            local started=Now();local result=table.pack(old(...));local ms=Diff(Now(),started)
            local row=stats[label] or {calls=0,ms=0,maxMs=0};stats[label]=row
            row.calls=row.calls+1;row.ms=row.ms+ms;row.maxMs=math.max(row.maxMs,ms)
            return table.unpack(result,1,result.n)
        end
    end
    Wrap(Unit,'Spawn','unit.Spawn');Wrap(Spec,'Build','spec.Build');Wrap(Unit,'Build','unit.Build')
    Wrap(BP,'Graph','bp.Graph');Wrap(BP,'Load','bp.Load');Wrap(Cache,'Get','cache.Get')
    local reference={};local passes={};local order={'baseline','cache','cache','baseline'}
    for pass,mode in ipairs(order) do
        env.viewEvents={};stats={}
        local started=Now();active=true
        for _,u in ipairs(units) do u.spawnSpecCache=mode=='cache' and cache or nil;u:Spawn() end
        local elapsed=Diff(Now(),started);active=false
        local states={}
        for i,u in ipairs(units) do
            states[i]={spec=Cache.Clone(u.spec),state=Cache.Clone(u.vehicle:GetState()),hp=Cache.Clone(u.hp),
                repairOrder=Cache.Clone(u.repairOrder),source=Cache.Clone(u.bp:ToTable()),bodyHp=u.bodyHp,bodyHpMax=u.bodyHpMax,
                rawHpMax=u.rawHpMax,budget0=u.budget0,alive=u.alive}
            if pass==1 then reference[i]=states[i] else local equal,why=Equal(reference[i],states[i]);if not equal then error('Pass '..pass..' source '..i..' mismatch '..tostring(why)) end end
        end
        passes[#passes+1]={pass=pass,mode=mode,wallMs=elapsed,spawns=#units,stats=stats,eventCount=#env.viewEvents,equivalent=true}
    end
    for _,entry in ipairs(originals) do entry[1][entry[2]]=entry[3] end
    local result={status='PASS',fixture=fixture.identity,order=order,passes=passes,prepareMs=prepareMs,metadata=metadata,
        isolation=isolation,cache={hits=cache.hits,misses=cache.misses,prepared=cache.prepared},
        boundary='One process ABBA, 8 unchanged actual J sources per pass, actual CarUnit/Bullet/WeaponSystem, normal GC. Spec/state/hp/repair order compared after every spawn; cache mutable tables disjoint. Warmup and cache preparation excluded from respawn timing. Integer wall milliseconds include nested wrappers/GC; do not sum parent and child times. No rendering/audio/AI/fire, map population, real BattleController, Web or target-device FPS acceptance.'}
    for _,u in ipairs(units) do u:Dispose() end;cache:Dispose();space:Dispose();scene:Dispose();return result
end
function Start()
    local ok,result=xpcall(Run,debug.traceback);if not ok then result={status='FAIL',error=tostring(result)} end
    local f=assert(io.open(assert(output),'wb'));f:write(cjson.encode(result));f:close();engine:Exit()
end
