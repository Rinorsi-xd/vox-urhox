local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Equal(a,b,memo)
    if a==b then return true end
    if type(a)~=type(b) or type(a)~='table' then return false end
    memo=memo or {};if memo[a] then return memo[a]==b end;memo[a]=b
    for k,v in pairs(a) do if not Equal(v,b[k],memo) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(name) return read_resource(name) end}
package.loaded['combat.EnemyDriver']={New=function() return {} end}
package.loaded['combat.DrillRaiderDriver']={New=function() return {} end}
local Cache=require 'drive.SpawnSpecCache'
local Spec=require 'drive.VehicleSpec'
local Data=require 'endless.Data'
local Unit=require 'combat.CarUnit'
local New=require 'app.EndlessSession'
local Old=assert(load(reference,'@before-endless-spawn-cache','t',_ENV))()
local build=Spec.Build;local builds=0
Spec.Build=function(...) builds=builds+1;return build(...) end
local function Environment()
    local env={time=100,viewEvents={},units={},stats={},layout={enemyGates={
        {id='N',pos={1000,2,0},yaw=.4},{id='N',pos={2000,2,0},yaw=.8},{id='N',pos={3000,2,0},yaw=1.2}}}}
    function env:NewVehicle(spec)
        local p={x=0,y=0,z=0};local yaw=0
        return {Dispose=function() end,Place=function(_,pos,a) p={x=pos[1],y=pos[2],z=pos[3]};yaw=a end,
            body={translation=function() return p end,rotation=function() return {x=0,y=math.sin(yaw/2),z=0,w=math.cos(yaw/2)} end,
                center=function() return p end}}
    end
    function env:RecordDamage() end
    return env
end
local function State(run)
    local out={};for key,value in pairs(run) do if type(value)~='function' then out[key]=value end end;return out
end
local function Controller(kind,key,drop)
    local env=Environment();for _,gate in ipairs(env.layout.enemyGates) do gate.drop=drop end
    local run={state='combat',wave=20,time=100,nextSpawn=0,alive={},queue={}}
    for i=1,3 do run.queue[i]={id='enemy'..i,prefab=key,role=key:match('^boss:') and 'boss' or 'assault',hpScale=1+i*.25,damageScale=1.7,elite=i==2} end
    function run:TakeSpawn() local meta=table.remove(self.queue,1);self.alive[meta.id]=true;self.nextSpawn=self.time+Data.config.spawnInterval;return meta end
    local ctl=setmetatable({world=env,run=run,rules=run,session={},entries={},pending={},spawnSerial=0,
        specCache={},spawnRadii={},spawnSpecCache=Cache.New(),view={Warn=function() end,Dispose=function() end},audio={Dispose=function() end}},kind)
    return ctl
end
local function Cleanup(ctl)
    for _,u in ipairs(ctl.world.units) do u:Dispose() end
    ctl:Dispose()
end
local rows={};local keys={};for key in pairs(Data.prefabs) do keys[#keys+1]=key end;table.sort(keys)
local rng,seed=math.random,math.randomseed
math.random=function() error('spawn cache consumed RNG') end;math.randomseed=function() error('spawn cache reseeded RNG') end
for _,key in ipairs(keys) do
    local source=Cache.Clone(Data.prefabs[key]);local old,new=Controller(Old,key,false),Controller(New,key,false)
    local oldStart=builds
    for _=1,3 do old.run.time=old.run.time+2;old:Spawn() end
    local oldBuilds=builds-oldStart;local newStart=builds
    for _=1,3 do new.run.time=new.run.time+2;new:Spawn() end
    local newBuilds=builds-newStart
    Check(oldBuilds==4 and newBuilds==1,key..' actual Spec.Build 4 -> 1 for three spawns')
    Check(#old.entries==3 and #new.entries==3,key..' actual three CarUnit spawns')
    Check(Equal(State(old.run),State(new.run)),key..' queue/alive/clock/nextSpawn unchanged')
    Check(Equal(old.world.viewEvents[1].type,new.world.viewEvents[1].type),key..' unitSpawn event unchanged')
    for i=1,3 do
        local a,b=old.entries[i].unit,new.entries[i].unit
        Check(Equal(a.spec,b.spec),key..' '..i..' entire real vehicle spec unchanged')
        Check(Equal(a.hp,b.hp) and a.bodyHp==b.bodyHp and a.partScale==b.partScale,key..' '..i..' elite hp scale unchanged')
        Check(Equal(a:Position(),b:Position()) and Equal(a.spawnAt,b.spawnAt),key..' '..i..' centered placement/yaw unchanged')
        Check(b.spawnSpecCache==new.spawnSpecCache,key..' '..i..' actual Unit owns scene cache reference')
    end
    local first,second=new.entries[1].unit,new.entries[2].unit
    local pristine=Cache.Clone(second.spec);local sourceBefore=Cache.Clone(Data.prefabs[key])
    local core=first.bp:CoreParts()[1]
    Check(first:Damage(core.id,1e9,first:Position(),{armor=1})>0 and first.bodyHp==0,key..' actual production core damage consumes hull')
    first.spec.bounds.min[1]=999;first.spec.motion.mass=0
    if first.spec.hulls[1] then first.spec.hulls[1].center[1]=888 end
    if first.spec.weapons[1] then first.spec.weapons[1].muzzle[1]=777 end
    local part=first.bp:List()[1];first.hp[part.id]=0;part.pos[1]=part.pos[1]+20
    Check(Equal(second.spec,pristine),key..' sibling spec isolated from runtime mutation')
    Check(Equal(new.spawnSpecCache:Get(Data.prefabs[key]),pristine),key..' pristine template isolated from runtime mutation')
    Check(Equal(Data.prefabs[key],sourceBefore) and Equal(sourceBefore,source),key..' source stays immutable')
    local start=builds
    new:SpawnUnit({id='after-damage',prefab=key,role='assault',hpScale=1.5,damageScale=1.7},{pos={4000,2,0},yaw=.4},false)
    local replacement=new.entries[4].unit
    Check(builds==start and Equal(replacement.spec,pristine),key..' spawn after damage restores complete spec without Build')
    Check(replacement.bodyHp==replacement.bodyHpMax and Equal(replacement.hp,second.hp),key..' spawn after damage restores independent full health')
    local radius=math.sqrt((pristine.bounds.max[1]-pristine.bounds.min[1])^2+(pristine.bounds.max[3]-pristine.bounds.min[3])^2)/2
    Check(type(new.spawnRadii[key])=='number' and new.spawnRadii[key]==radius,key..' only radius retained alongside pristine cache')
    local retained=new.spawnSpecCache;Cleanup(new)
    Check(retained.disposed and next(retained.entries)==nil and new.spawnSpecCache==nil and next(new.spawnRadii)==nil,key..' scene teardown frees templates and radii')
    new:Dispose();Check(new.disposed,key..' repeated teardown safe')
    Cleanup(old);rows[#rows+1]={key=key,oldBuilds=oldBuilds,newBuilds=newBuilds,spawns=3,parts=#source.parts}
end
-- A direct QA/airdrop SpawnUnit must prepare once even without an earlier Spawn.
for _,air in ipairs({false,true}) do
    local key=keys[1];local old,new=Controller(Old,key,false),Controller(New,key,false)
    local gate={pos={30,4,50},yaw=.75};local meta={id='direct',prefab=key,role='assault',hpScale=2.4,damageScale=1.1}
    local start=builds;old:SpawnUnit(meta,gate,air);old:SpawnUnit(meta,gate,air);local before=builds-start
    start=builds;new:SpawnUnit(meta,gate,air);new:SpawnUnit(meta,gate,air);local after=builds-start
    Check(before==2 and after==1,'direct SpawnUnit '..tostring(air)..' actual Spec.Build 2 -> 1')
    Check(Equal(old.entries[1].unit.spec,new.entries[1].unit.spec),'direct SpawnUnit '..tostring(air)..' complete spec unchanged')
    Check(Equal(old.entries[1].unit.spawnAt,new.entries[1].unit.spawnAt),'direct SpawnUnit '..tostring(air)..' placement unchanged')
    Check(old.entries[1].unit.airdropActive==new.entries[1].unit.airdropActive,'direct SpawnUnit '..tostring(air)..' airdrop flag unchanged')
    Cleanup(old);Cleanup(new)
end
-- Gate occupancy, delay, cap and airborne warning retain source session decisions.
for _,case in ipairs({'blocked','interval','cap','airdrop'}) do
    local key=keys[1];local old,new=Controller(Old,key,case=='airdrop'),Controller(New,key,case=='airdrop')
    for _,ctl in ipairs({old,new}) do
        if case=='blocked' then ctl.world.units={};for _,g in ipairs(ctl.world.layout.enemyGates) do local at=g.pos;ctl.world.units[#ctl.world.units+1]={alive=true,spec={bounds={min={-1,-1,-1},max={1,1,1}}},Position=function() return at end,Dispose=function() end} end
        elseif case=='interval' then ctl.run.nextSpawn=101
        elseif case=='cap' then for i=1,8 do ctl.run.alive[i]=true end end
        ctl:Spawn()
    end
    Check(Equal(State(old.run),State(new.run)),'gate '..case..' source queue/clock/alive unchanged')
    Check(Equal(old.pending,new.pending) and #old.entries==#new.entries,'gate '..case..' source pending/spawn decision unchanged')
    Cleanup(old);Cleanup(new)
end
Spec.Build=build;math.random,math.randomseed=rng,seed
spawn_cache_rows=rows
return checks
