-- Isolated CPU attribution; every observed method calls its real implementation.
local BP=require 'construction.Blueprint'
local Spec=require 'drive.VehicleSpec'
local Unit=require 'combat.CarUnit'
local Vehicle=require 'drive.Vehicle'
local Space=require 'physics.Space'
local TrackWorld=require 'drive.TrackWorld'
local Debris=require 'combat.Debris'
local Metrics=require 'drive.TrialMetrics'
local CombatView=require 'render.CombatView'
local DriveView=require 'render.DriveView'
local VehicleView=require 'render.VehicleView'
local JoinedMesh=require 'render.JoinedMesh'
local Rotors=require 'construction.Rotors'
local TurretRange=require 'construction.TurretRange'
local WeaponSystem=require 'combat.WeaponSystem'
local output=false
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local function Clock() return {wall=Time:GetSystemTime(),cpu=os.clock()} end
local function Elapsed(start) return {wallMs=(Time:GetSystemTime()-start.wall)&0xffffffff,cpuMs=(os.clock()-start.cpu)*1000} end
local function Read(path) local f=assert(io.open(path,'rb'));local v=cjson.decode(f:read('*a'));f:close();return v end
local function Copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=Copy(x) end;return t end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<=1e-5*math.max(1,math.abs(b)) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local report={status='INCOMPLETE',steps={},metadata={}}
local function Write() local f=assert(io.open(assert(output),'wb'));f:write(cjson.encode(report));f:close() end
local function Run()
    math.randomseed(17102026)
    assert(collectgarbage('isrunning'),'Automatic GC must remain enabled')
    local fixture=Read('damage-roster.json');assert(#fixture.roster==8)
    report.fixture=fixture.identity
    report.boundary='Frozen c935 actual eight K blueprints; real CarUnit/Spec/Bullet/Debris/CombatView. Three sequential direct noncore Destroy/Flush events per living car, combat=true, without projectile/HP trajectories. Empty isolated scene, no map/AI/audio/render/presentation or FPS acceptance. Normal automatic GC; no forced collection or mode changes. Timers and sample allocation add observer cost. Inclusive parents overlap children; self excludes only wrapped children. Native findings do not establish Web spike causes or mobile FPS.'
    local scene=Scene();scene:CreateComponent('Octree')
    local camera=scene:CreateChild('ProbeCamera');camera.position=Vector3(0,45,-65);camera:LookAt(Vector3(0,30,0));camera:CreateComponent('Camera').fov=60
    local space=Space.New(scene)
    local world=setmetatable({scene=scene,space=space,time=0,viewEvents={},fx={},units={},
        stats={shots=0,hits=0,damage=0,kills=0},metrics=Metrics.New({}),debris=Debris.New(space)},TrackWorld)
    local view=CombatView.New(scene)
    local sources={}
    for i,row in ipairs(fixture.roster) do
        sources[i]=Copy(row.source)
        local u=Unit.New(world,row.source,{name=row.name,team=row.team,combat=true,externalControl=true,autoRespawn=false,spawn={pos={(i-1)*50,30,0},yaw=.3}})
        assert(u.alive and u.vehicle,'Actual K source failed '..i);world.units[i]=u
        report.metadata[i]={name=row.name,parts=u.bp:Size(),wheels=#u.vehicle.wheels,mass=u.vehicle.mass}
    end
    view:Consume(world);view:Update(1,0,{time=0,camera=camera,fov=60})
    local active=false;local stats={};local stack={};local samples={};local originals={}
    local function Wrap(object,key,label)
        local old=assert(object[key],label);originals[#originals+1]={object,key,old}
        object[key]=function(...)
            if not active then return old(...) end
            local entry={label=label,start=Clock(),childWall=0,childCpu=0};stack[#stack+1]=entry
            local result=table.pack(old(...));local elapsed=Elapsed(entry.start);stack[#stack]=nil
            local parent=stack[#stack]
            if parent then parent.childWall=parent.childWall+elapsed.wallMs;parent.childCpu=parent.childCpu+elapsed.cpuMs end
            local row=stats[label] or {calls=0,wallMs=0,cpuMs=0,selfWallMs=0,selfCpuMs=0,maxWallMs=0};stats[label]=row
            row.calls=row.calls+1;row.wallMs=row.wallMs+elapsed.wallMs;row.cpuMs=row.cpuMs+elapsed.cpuMs
            row.selfWallMs=row.selfWallMs+math.max(0,elapsed.wallMs-entry.childWall)
            row.selfCpuMs=row.selfCpuMs+math.max(0,elapsed.cpuMs-entry.childCpu);row.maxWallMs=math.max(row.maxWallMs,elapsed.wallMs)
            samples[#samples+1]={label=label,wallMs=elapsed.wallMs,cpuMs=elapsed.cpuMs,selfWallMs=math.max(0,elapsed.wallMs-entry.childWall),selfCpuMs=math.max(0,elapsed.cpuMs-entry.childCpu)}
            return table.unpack(result,1,result.n)
        end
    end
    for _,row in ipairs({
        {Unit,'Destroy','unit.Destroy'},{Unit,'Flush','unit.Flush'},{Unit,'Die','unit.Die'},
        {Unit,'DisposeVehicle','unit.DisposeVehicle'},{Unit,'Build','unit.Build'},
        {BP,'Graph','bp.Graph'},{BP,'Connectivity','bp.Connectivity'},
        {Spec,'Build','spec.Build'},{Spec,'BuildParts','spec.BuildParts'},{Spec,'MergeBoxes','spec.MergeBoxes'},{Spec,'Debris','spec.Debris'},
        {Rotors,'Spec','rotors.Spec'},{TurretRange,'For','turretRange.For'},
        {Vehicle,'New','vehicle.New'},{Vehicle,'init','vehicle.init'},{Vehicle,'Dispose','vehicle.Dispose'},
        {WeaponSystem,'Refit','weapons.Refit'},{Debris,'Spawn','debris.Spawn'},
        {CombatView,'Consume','visual.Consume'},{DriveView,'Bind','visual.Bind'},
        {VehicleView,'RemovePart','visual.RemovePart'},{JoinedMesh,'Update','visual.JoinedMesh.Update'}
    }) do Wrap(table.unpack(row)) end
    for i,u in ipairs(world.units) do for step=1,3 do
        if not u.alive then break end
        local part=false;local parts=u.bp:List()
        for j=#parts,1,-1 do if parts[j].type=='cube' then part=parts[j];break end end
        if not part then for j=#parts,1,-1 do if parts[j].type~='core' then part=parts[j];break end end end
        assert(part,'Actual source has no removable part '..i)
        world.time=world.time+.25;world.debris:Advance(world.time);view:Consume(world)
        local before=u.vehicle;local state=before:GetState();local oldId=before.node:GetID()
        local row={unit=i,step=step,target=part.id,partType=part.type,partsBefore=u.bp:Size(),heapBeforeKiB=collectgarbage('count')}
        stats={};samples={};active=true
        local started=Clock();u:Destroy(part.id);row.destroy=Elapsed(started)
        started=Clock();u:Flush();row.flush=Elapsed(started)
        active=false
        row.events={};for _,e in ipairs(world.viewEvents) do row.events[#row.events+1]={type=e.type,id=e.id or false,reason=e.reason or false} end
        active=true;started=Clock();view:Consume(world);row.visualConsume=Elapsed(started)
        started=Clock();view:Update(1,0,{time=world.time,camera=camera,fov=60});row.visualUpdate=Elapsed(started);active=false
        row.stats=stats;row.samples=samples;row.heapAfterKiB=collectgarbage('count');row.alive=u.alive;row.partsAfter=u.bp:Size();row.debris=#world.debris.pieces
        report.steps[#report.steps+1]=row;Write()
        assert(before.disposed and before.native==nil and space.bodies[oldId]==nil,'Old native body retained')
        assert(not u.bp.parts[part.id],'Destroyed part retained')
        assert(#world.viewEvents==0 and #world.debris.events==0,'Events were not drained')
        assert(Same(fixture.roster[i].source,sources[i]),'Source blueprint mutated')
        if u.alive then
            local after=u.vehicle:GetState();for _,key in ipairs({'p','q','lv','av'}) do assert(Same(state[key],after[key]),'Rebuild changed '..key) end
            local owner=space.bodies[u.vehicle.node:GetID()];assert(owner and owner.owner.ref==u,'New native owner missing')
            assert(view.units[u] and not view.units[u].view.visuals[part.id],'Actual visual removal failed')
        else assert(u.vehicle==nil and view.units[u]==nil,'Killed native/view retained') end
        row.behaviorChecks=true
    end end
    for _,v in ipairs(originals) do v[1][v[2]]=v[3] end
    for _,u in ipairs(world.units) do u:Dispose() end
    world.debris:Clear();view:Consume(world);view:Dispose();camera:Dispose()
    assert(next(space.bodies)==nil,'Native body registration leaked')
    assert(scene:GetNumChildren(true)==0,'Scene child leaked')
    space:Dispose();scene:Dispose();report.cleanup=true;report.collectorRunning=collectgarbage('isrunning');report.status='PASS';return report
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    if not ok then report.status='FAIL';report.error=tostring(result) end
    Write();engine:Exit()
end
