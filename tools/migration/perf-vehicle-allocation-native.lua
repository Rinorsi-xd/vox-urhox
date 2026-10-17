-- Isolated Native CPU probe: actual crater, eight assembled vehicles and helpers.
local Factory=require 'qa-allocation-owners'
local Timing=require 'qa-native-owner-times'
local World=require 'drive.CraterWorld'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local DriverActions=require 'combat.DriverActions'
local RotorMotion=require 'drive.RotorMotion'
local Data=require 'combat.ArenaData'
local Vehicle=require 'drive.Vehicle'
local Body=require 'physics.Body'
local Space=require 'physics.Space'
local output=false
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local function Clock()return Time:GetSystemTime()end
local function Elapsed(a,b)return(a-b)&0xffffffff end
local originalMode=false
local originalRunning=false
local changedCollector=false
local function RestoreCollector()
    if not changedCollector then return end
    if originalMode then collectgarbage(originalMode)end
    if originalRunning then collectgarbage('restart')else collectgarbage('stop')end
    assert(collectgarbage('isrunning')==originalRunning,'Collector restore failed')
    changedCollector=false
end
local function Run()
    math.randomseed(1016)
    local scene=Scene();scene:CreateComponent('Octree')
    local world=World.New(scene)
    local entries,metadata={},{}
    for _,team in ipairs({'blue','red'})do for _,role in ipairs({'assault','heavy','sniper','assault'})do
        local index=#entries+1;local blue=team=='blue'
        local x=((index-1)%4-1.5)*18;local z=-140+(blue and -20 or 20)
        local unit=Unit.New(world,assert(Data.prefabs[team..':3:'..role..':0']),{
            name=team..'-'..role..'-'..index,team=team,combat=true,externalControl=true,autoRespawn=true,
            spawn={pos={x,world:GroundAt(x,z)+2,z},yaw=blue and 0 or math.pi}})
        assert(unit.alive,'Probe assembly failed')
        world.units[#world.units+1]=unit
        entries[index]={unit=unit,driver=Driver.New(world,unit,role,index,{tier=3,seed=1016+index,aimSkill=1})}
        metadata[index]={team=team,role=role,variant=0,parts=unit.bp:Size(),wheels=#unit.vehicle.wheels,
            legs=#unit.spec.legs,mechLegs=#(unit.spec.mechLegs or {}),mass=unit.vehicle.mass,spawn=unit.spawnAt}
    end end
    local phase='off';local stepNumber=0
    local alloc=Factory.New{gc=collectgarbage,phase=function()return phase end,frame=function()return stepNumber end}
    local timer=Timing.New(Clock)
    local wanted={
        {'drive.Vehicle','Step'},{'drive.Vehicle','StepRotors'},{'drive.Vehicle','PostStep'},
        {'drive.RaySuspension','Sample'},{'drive.RaySuspension','Apply'},
        {'drive.ContactControl','Step'},{'drive.ChassisStability','Step'},
        {'drive.HoverControl','Step'},{'drive.HoverControl','Motion'},
        {'drive.ThrusterControl','Step'},{'drive.WingControl','Step'},
        {'drive.LegControl','Step'},{'drive.LegControl','Cast'},
        {'drive.MechControl','Step'},{'drive.LegHitboxes','Update'},{'drive.MechHitboxes','Update'},
        {'physics.Space','Raycast'},{'physics.Space','Step'},{'physics.Body','Wrap'},
        {'combat.WeaponSystem','Step'},{'combat.EnemyDriver','Step'},
    }
    for _,item in ipairs(wanted)do
        local module=require(item[1]);local name=item[1]..'.'..item[2]
        timer:Wrap(module,item[2],name);alloc:Wrap(module,item[2],name)
    end
    -- This entry supplies explicit methods instead of the browser callback setup.
    alloc.prepared=true;alloc.trialPrepared=true
    local bodyWrapCalls,unregisteredWrapCalls,wrappedStatic,wrappedDynamic=0,0,0,0
    local originalWrap=Body.Wrap
    Body.Wrap=function(native)
        if phase=='B' then
            bodyWrapCalls=bodyWrapCalls+1
            if not world.space.bodies[native.node:GetID()] then unregisteredWrapCalls=unregisteredWrapCalls+1 end
            if native.mass==0 and not native.kinematic then wrappedStatic=wrappedStatic+1 else wrappedDynamic=wrappedDynamic+1 end
        end
        return originalWrap(native)
    end
    local function Step(index)
        stepNumber=index
        for _,entry in ipairs(entries)do
            local u=entry.unit;assert(u.alive and u.vehicle,'Keep eight-vehicle no-fire roster')
            local target=false;local nearest=math.huge;local pos=u:Position()
            for _,other in ipairs(entries)do if other.unit.team~=u.team then
                local p=other.unit:Position();local d=(p[1]-pos[1])^2+(p[3]-pos[3])^2
                if d<nearest then target=other.unit;nearest=d end
            end end
            u:RegenerateStructure(1/60)
            local cmd,aim,_,info=entry.driver:Step(1/60,target)
            u:Flush();DriverActions.Apply(u,info)
            local v=u.vehicle;v:StepRotors(aim,cmd.rotorStep,1/60);RotorMotion.Weapons(v.rotors,u.weapons)
            v:Step(cmd,1/60)
            local p,velocity=v.body.translation(),v.body.linvel()
            world.attacker=u
            u.weapons:Step(1/60,{firing=false,aim=aim or u:Position(),pos={p.x,p.y,p.z},quat=v.body.rotation(),
                vel={velocity.x,velocity.y,velocity.z},body=v.body,team=u.team,live=true},world.env)
            world.attacker=nil;u.weapons.fx={}
        end
        world:Step(1/60);world.fx={};world.viewEvents={};world.debris.events={}
    end
    for i=1,120 do Step(i)end
    originalRunning=collectgarbage('isrunning');originalMode=collectgarbage('incremental')
    changedCollector=true;collectgarbage(originalMode)
    local snapshots,batches={},{}
    for batch=1,6 do
        assert(collectgarbage('isrunning'),'Begin allocation batch with running collector')
        collectgarbage('collect')
        local initial=collectgarbage('count');assert(initial<131072,'Lua absolute budget before batch')
        local started=Clock();local completed=0;local maxGrowth=0
        collectgarbage('stop');phase='B'
        local ok,err=xpcall(function()
            for offset=1,4 do
                stepNumber=120+(batch-1)*4+offset
                assert(alloc:BeginFrame(),'Allocation frame begins')
                Step(stepNumber)
                assert(alloc:EndFrame(),'Allocation frame ends')
                completed=completed+1
                local growth=collectgarbage('count')-initial;maxGrowth=math.max(maxGrowth,growth)
                assert(growth<=8192 and collectgarbage('count')<=131072,'Native no-GC memory budget')
                assert(Elapsed(Clock(),started)<=250,'Native no-GC 250ms deadline')
            end
        end,debug.traceback)
        if alloc.active then alloc:EndFrame()end
        phase='off';collectgarbage('restart')
        assert(ok,err)
        batches[#batches+1]={steps=completed,wallMs=Elapsed(Clock(),started),growthKiB=maxGrowth}
        local snapshot={step=stepNumber,cars={}}
        for _,entry in ipairs(entries)do snapshot.cars[#snapshot.cars+1]={state=entry.unit.vehicle:GetState(),
            telemetry=entry.unit.vehicle.telemetry,driverMode=entry.driver.mode,parts=entry.unit.bp:Size()}end
        snapshots[#snapshots+1]=cjson.decode(cjson.encode(snapshot))
    end
    RestoreCollector()
    assert(collectgarbage('isrunning'),'Normal automatic GC must run during helper wall timing')
    timer.enabled=true;local normalStarted=Clock()
    local timingOk,timingError=xpcall(function()for i=145,744 do Step(i)end end,debug.traceback)
    local normalGcWallMs=Elapsed(Clock(),normalStarted);timer.enabled=false
    assert(timingOk,timingError)
    assert(collectgarbage('isrunning'),'Normal collector must remain running after CPU loop')
    local finalState={step=stepNumber,cars={}}
    for _,entry in ipairs(entries)do finalState.cars[#finalState.cars+1]={state=entry.unit.vehicle:GetState(),telemetry=entry.unit.vehicle.telemetry}end
    Body.Wrap=originalWrap;alloc:RestoreWrappers();timer:Restore()
    local allocation=alloc:Report();assert(not allocation.invalid,'Allocation accounting invalid')
    local result={status='PASS',metadata=metadata,allocation=allocation,batches=batches,snapshots=snapshots,
        bodyWrap={total=bodyWrapCalls,unregistered=unregisteredWrapCalls,static=wrappedStatic,dynamic=wrappedDynamic},
        collectorRestored=not changedCollector,steps=24,normalGcSteps=600,normalGcWallMs=normalGcWallMs,
        helperTiming=timer:Report(),finalState=finalState,
        boundary='Native headless diagnostic, actual crater/eight T3 vehicles/AI/no firing. Initial warmup 120 steps; six bounded allocation batches of four steps; then separate 600-step normal automatic-GC helper wall timing. No original game algorithms transformed. Net Lua heap growth includes observation/native-binding overhead, not GPU/WASM allocations. Integer wall times include instrumentation/GC/preemption and are not thread CPU or Web/TapTap FPS. Fixture has no objectives/rendering/audio/UI.'}
    world:Dispose();scene:Dispose();return result
end
function Start()
    local ok,result=xpcall(Run,debug.traceback)
    local restored,restoreError=pcall(RestoreCollector)
    if not ok or not restored then result={status='FAIL',error=tostring(result),restoreError=not restored and tostring(restoreError)or false}end
    local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
