-- Real native objects only. No vehicle, debris, geometry or physics substitutes.
-- This isolated scene measures CPU/native submission, not GPU or Web performance.
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Unit=require 'combat.CarUnit'
local TrackWorld=require 'drive.TrackWorld'
local Space=require 'physics.Space'
local Debris=require 'combat.Debris'
local CombatView=require 'render.CombatView'
local Metrics=require 'drive.TrialMetrics'
local THRESHOLD=100
local report={schema=1,source='2b169a9964645f5f346a7158bcb14447f040814a',
    scope='native CPU/submission only; no rendered GPU, Web or device acceptance',
    thresholdMs=THRESHOLD,fixtures={},complete=false,
    graphicsApi=graphics.apiName,quality=require('render.Quality').current.name,
    physicalWidth=graphics:GetWidth(),physicalHeight=graphics:GetHeight(),dpr=graphics:GetDPR()}
local reportPath
for _,arg in ipairs(GetArguments()) do
    local value=arg:match('^%-damage%-timing%-output=(.+)$');if value then reportPath=value end
end
assert(reportPath,'-damage-timing-output is required')
local function Write()
    local file=assert(io.open(reportPath,'wb'));file:write(cjson.encode(report));file:close()
end
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function Clock() return {cpu=os.clock(),wall=Time:GetSystemTime()} end
local function Elapsed(start)
    return {cpuMs=(os.clock()-start.cpu)*1000,wallMs=(Time:GetSystemTime()-start.wall)&0xffffffff}
end
local function Add(a,b)
    return {cpuMs=a.cpuMs+b.cpuMs,wallMs=a.wallMs+b.wallMs}
end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<=1e-5*math.max(1,math.abs(b)) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Within(value,name)
    V.assert(value.wallMs<=THRESHOLD and value.cpuMs<=THRESHOLD,
        name..' <=100 ms (wall='..value.wallMs..', CPU='..string.format('%.3f',value.cpuMs)..')')
end
local current
local function Cleanup()
    local c=current;if not c then return end
    if c.unit then c.unit:Dispose() end
    c.world.debris:Clear();c.view:Consume(c.world);c.view:Dispose()
    c.camera:Dispose()
    V.assert(next(c.world.space.bodies)==nil,c.name..' releases every native body registration')
    V.assert(c.scene:GetNumChildren(true)==0,c.name..' releases every scene child')
    c.world.space:Dispose();c.scene:Dispose();current=nil
end
local function Create(name,combat)
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('DamageProbeCamera');camera.position=Vector3(0,45,-65)
    camera:LookAt(Vector3(0,30,0));camera:CreateComponent('Camera').fov=60
    local space=Space.New(scene)
    local world=setmetatable({scene=scene,space=space,time=0,viewEvents={},fx={},units={},
        stats={shots=0,hits=0,damage=0,kills=0},metrics=Metrics.New({}),debris=Debris.New(space)},TrackWorld)
    local fixture={name=name,combat=combat,steps={},nativeBuilds={},debrisBuilds={}}
    report.fixtures[#report.fixtures+1]=fixture
    current={name=name..' combat='..tostring(combat),scene=scene,camera=camera,world=world,view=CombatView.New(scene),fixture=fixture}
    -- Wrappers only observe actual production factories; they always call originals.
    function world:NewVehicle(spec,unit)
        local start=Clock();local result=TrackWorld.NewVehicle(self,spec,unit)
        local entry=Elapsed(start)
        entry.parts=#spec.partIds;entry.node=result.node:GetID()
        entry.components=result.node:GetNumComponents()
        entry.native=result.native==result.node:GetComponent('RigidBody')
        fixture.nativeBuilds[#fixture.nativeBuilds+1]=entry
        assert(entry.native,'production factory returned a real native RigidBody')
        return result
    end
    local spawn=world.debris.Spawn
    function world.debris:Spawn(parts,...)
        local start=Clock();local result=spawn(self,parts,...);local entry=Elapsed(start)
        entry.parts=#parts;entry.created=result~=nil
        fixture.debrisBuilds[#fixture.debrisBuilds+1]=entry
        return result
    end
    local bp=Prefab.Create(BP.New(),name)
    local missing={}
    for _,path in ipairs(require('parts.Dependencies').For(bp:List())) do
        if not cache:Exists(path) then missing[#missing+1]=path end
    end
    V.assert(#missing==0,current.name..' uses complete local authored resources')
    assert(#missing==0,'missing dependencies: '..table.concat(missing,', '))
    local source=bp:ToTable();current.source=source;current.sourceCopy=BP.New():Load(source):ToTable()
    fixture.sourceParts=bp:Size()
    local start=Clock()
    local unit=Unit.New(world,source,{name=current.name,spawn={pos={0,30,0},yaw=.3},
        combat=combat,autoRespawn=false,externalControl=true},nil,function(candidate) current.unit=candidate end)
    fixture.initialSpawn=Elapsed(start);current.unit=unit;world.units={unit}
    start=Clock();current.view:Consume(world);current.view:Update(1,0,{time=0,camera=camera,fov=60})
    fixture.initialVisual=Elapsed(start)
    V.assert(unit.alive and unit.vehicle and current.view.units[unit],current.name..' starts alive with native physics and full view')
    assert(unit.alive and unit.vehicle,'invalid authored native fixture')
    unit.vehicle.body.setLinvel({x=2,y=1,z=3});unit.vehicle.body.setAngvel({x=.1,y=.2,z=.05})
    fixture.spawnedParts=unit.bp:Size();Write()
end
local function Damage(id,kind)
    local c=current;local u,w,view=c.unit,c.world,c.view
    assert(u.alive and u.bp.parts[id],'damage target must be a living actual part')
    w.time=w.time+.25;w.debris:Advance(w.time)
    local before=u.vehicle;local beforeState=before:GetState();local previousView=view.units[u]
    local originalVisuals={}
    for id,visual in pairs(previousView.view.visuals) do originalVisuals[id]=visual end
    local oldNode=before.node:GetID();local partsBefore=u.bp:Size()
    local buildFrom=#c.fixture.nativeBuilds;local debrisFrom=#c.fixture.debrisBuilds
    local row={kind=kind,target=id,partsBefore=partsBefore,removed={},nativeRebuilds=0,debrisCreated=0}
    local all=Clock();local start=Clock()
    row.damageAmount=u:Damage(id,1e9,{0,30,0});row.damage=Elapsed(start)
    start=Clock();u:Flush();row.flush=Elapsed(start)
    for _,event in ipairs(w.viewEvents) do
        if event.type=='partRemoved' then row.removed[#row.removed+1]={id=event.id,reason=event.reason} end
    end
    start=Clock();view:Consume(w);row.visualConsume=Elapsed(start)
    row.transferred=view.lastTransferred or 0;row.verifiedTransferred=0
    local transferParents=true
    for _,piece in ipairs(w.debris.pieces) do
        local detached=view.pieces[piece]
        if detached then for id,visual in pairs(detached.view.visuals) do
            if visual==originalVisuals[id] then
                row.verifiedTransferred=row.verifiedTransferred+1
                if visual.node.parent~=detached.view.root then transferParents=false end
            end
        end end
    end
    start=Clock();view:Update(1,0,{time=w.time,camera=c.camera,fov=60});row.visualUpdate=Elapsed(start)
    row.total=Elapsed(all);row.partsAfter=u.bp:Size();row.alive=u.alive
    row.removedCount=#row.removed
    row.nativeRebuilds=#c.fixture.nativeBuilds-buildFrom
    row.nativeRebuild={cpuMs=0,wallMs=0};row.debrisBuild={cpuMs=0,wallMs=0}
    for i=buildFrom+1,#c.fixture.nativeBuilds do row.nativeRebuild=Add(row.nativeRebuild,c.fixture.nativeBuilds[i]) end
    for i=debrisFrom+1,#c.fixture.debrisBuilds do
        local item=c.fixture.debrisBuilds[i];row.debrisBuild=Add(row.debrisBuild,item)
        if item.created then row.debrisCreated=row.debrisCreated+1 end
    end
    row.debrisAlive=#w.debris.pieces;row.debrisVisuals=Count(view.pieces)
    c.fixture.steps[#c.fixture.steps+1]=row
    -- Always persist raw timings before assertions, including a failed 100 ms gate.
    Write()
    V.assert(row.damageAmount>0,c.name..' '..kind..' applies real damage')
    V.assert(before.disposed and before.native==nil and w.space.bodies[oldNode]==nil,
        c.name..' '..kind..' retires original native body')
    V.assert(row.debrisAlive==row.debrisVisuals and row.debrisAlive<=Debris.MAX_PIECES,
        c.name..' '..kind..' displays all bounded actual debris')
    V.assert(#w.viewEvents==0 and #w.debris.events==0,c.name..' '..kind..' drains events exactly once')
    V.assert(Same(c.source,c.sourceCopy),c.name..' '..kind..' leaves source blueprint unchanged')
    V.assert(row.transferred==row.verifiedTransferred and transferParents,
        c.name..' '..kind..' transfers exact static visuals with live detached parents')
    if u.alive then
        V.assert(row.nativeRebuilds==1 and u.vehicle~=before,c.name..' '..kind..' rebuilds exactly one native vehicle')
        local after=u.vehicle:GetState()
        for _,key in ipairs({'p','q','lv','av'}) do V.assert(Same(beforeState[key],after[key]),c.name..' '..kind..' preserves '..key) end
        local entry=w.space.bodies[u.vehicle.node:GetID()]
        V.assert(entry and entry.owner.ref==u,c.name..' '..kind..' registers replacement owner')
        for _,removed in ipairs(row.removed) do
            V.assert(view.units[u].view.visuals[removed.id]==nil,c.name..' removed visual '..removed.id)
        end
    else
        V.assert(u.vehicle==nil and view.units[u]==nil and previousView.disposed,c.name..' '..kind..' releases killed car view')
        V.assert(row.debrisCreated>0,c.name..' '..kind..' creates real native wreck')
    end
    for _,piece in ipairs(w.debris.pieces) do
        local p=piece.body.translation();local owner=w.space.bodies[piece.node:GetID()]
        V.assert(owner and owner.owner.ref==piece and p.x==p.x and p.y==p.y and p.z==p.z,c.name..' debris native owner and finite pose')
    end
    Within(row.total,c.name..' '..kind..' Damage/Flush/Consume/Update')
end
local function Exercise(name,combat)
    Create(name,combat);coroutine.yield()
    if not combat then
        for step=1,3 do
            local u=current.unit;local parts=u.bp:List();local id
            for i=#parts,1,-1 do if parts[i].type~='core' then id=parts[i].id;break end end
            assert(id,'fixture has removable non-core part')
            Damage(id,'part '..step);coroutine.yield()
            if not u.alive then break end
        end
    end
    if current.unit.alive then Damage(assert(current.unit.bp:CoreParts()[1]).id,combat and 'combat hull kill' or 'core kill') end
    V.assert(not current.unit.alive,current.name..' final damage kills unit')
    coroutine.yield()
    local c=current;local start=Clock()
    c.world.debris:Advance(c.world.time+Debris.LIFE+.01);c.view:Consume(c.world)
    c.fixture.expiry=Elapsed(start);Write()
    V.assert(#c.world.debris.pieces==0 and next(c.view.pieces)==nil,current.name..' native and visual debris expire')
    V.assert(next(c.world.space.bodies)==nil,current.name..' expiry leaves no native bodies')
    Cleanup();coroutine.yield()
end
local exercise=coroutine.create(function()
    for _,name in ipairs({'raceCar','megaMech'}) do
        -- Per-part benchmark uses the real test-drive damage mode. Combat mode is
        -- separately measured through its unmodified hull/structure kill path.
        Exercise(name,false);Exercise(name,true)
    end
    report.complete=true;Write();V.finish()
end)
for frame=47,115 do V.atFrame(frame,function()
    if coroutine.status(exercise)=='dead' then return end
    local ok,err=coroutine.resume(exercise)
    if not ok then
        report.error=tostring(err);Write();local cleaned,why=pcall(Cleanup)
        if not cleaned then report.cleanupError=tostring(why);Write() end
        error(err)
    end
end) end
V.atFrame(118,function() V.assert(report.complete,'all four native fixture lifecycles completed');V.finish() end)
