-- Native-only allocation decomposition; timings are intentionally invalid.
local Factory=require 'qa-single-step-allocation'
local World=require 'drive.CraterWorld'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local Actions=require 'combat.DriverActions'
local Rotor=require 'drive.RotorMotion'
local config=assert(VEHICLE_ALLOCATION_CONFIG,'Derived isolated fixture configuration required')
local output=false
for _,arg in ipairs(GetArguments())do output=arg:match('^%-probe%-output=(.+)$')or output end
local probe=false;local world=false;local scene=false
local rawGc=collectgarbage
local function RestoreGuard() collectgarbage=rawGc end
local function Read(file)
    local stream=assert(io.open(file,'rb'));local bytes=stream:read('*a');stream:close();return cjson.decode(bytes)
end
local function Run()
    assert(collectgarbage('isrunning'),'Normal automatic GC must start running')
    assert(config.seed==1016 and config.fixedDt==1/60 and config.samples<=16 and config.normalBetween>=1)
    math.randomseed(config.seed)
    local source=Read('allocation-roster.json');assert(#source.roster==8,'Eight actual captured vehicle sources')
    scene=Scene();scene:CreateComponent('Octree');world=World.New(scene)
    local mapBodies=0;for _ in pairs(world.space.bodies)do mapBodies=mapBodies+1 end
    local entries,metadata={},{}
    for index,row in ipairs(source.roster)do
        local blue=row.team=='blue';local x=((index-1)%4-1.5)*18;local z=-140+(blue and -20 or 20)
        local unit=Unit.New(world,row.source,{name=row.name,team=row.team,combat=true,externalControl=true,
            autoRespawn=true,spawn={pos={x,world:GroundAt(x,z)+2,z},yaw=blue and 0 or math.pi}})
        assert(unit.alive,'Actual source assembly failed '..index);world.units[#world.units+1]=unit
        local driver=index>1 and Driver.New(world,unit,row.role,index,{tier=3,seed=1016+index,aimSkill=1})or false
        entries[index]={unit=unit,driver=driver}
        metadata[index]={name=row.name,team=row.team,role=row.role or false,parts=unit.bp:Size(),mass=unit.vehicle.mass,
            wheels=#unit.vehicle.wheels,legs=#unit.spec.legs,mechLegs=#(unit.spec.mechLegs or {}),hovers=#unit.spec.hovers,
            wings=#(unit.spec.wings or {}),sourceParts=#row.source.parts,manual=index==1}
    end
    local helpers={}
    function helpers.Pick(unit)
        local selected=false;local distance=math.huge;local p=unit:Position()
        for _,other in ipairs(entries)do if other.unit.team~=unit.team and other.unit.alive then
            local q=other.unit:Position();local d=(q[1]-p[1])^2+(q[3]-p[3])^2
            if d<distance then selected=other.unit;distance=d end
        end end
        return selected
    end
    function helpers.DrainUnit(unit)unit.weapons.fx={}end
    function helpers.DrainWorld()world.fx={};world.viewEvents={};world.debris.events={}end
    local stepNumber=0;local manualCalls=0;local aiCalls=0;local firingRequests=0
    local api={}
    function api.Step(index)
        stepNumber=index
        for _,entry in ipairs(entries)do local unit=entry.unit
            if unit.alive then
                local target=helpers.Pick(unit);local aim=target and target:Position()or unit:Position()
                local cmd,firing,info
                unit:RegenerateStructure(1/60)
                if entry.driver then cmd,aim,firing,info=entry.driver:Step(1/60,target);aiCalls=aiCalls+1
                else cmd={throttle=.22,steer=0,firing=true};firing=true;manualCalls=manualCalls+1 end
                unit:Flush()
                if unit.alive then
                    Actions.Apply(unit,info);local vehicle=unit.vehicle
                    vehicle:StepRotors(aim,cmd.rotorStep,1/60);Rotor.Weapons(vehicle.rotors,unit.weapons)
                    vehicle:Step(cmd,1/60)
                    local p,v=vehicle.body.translation(),vehicle.body.linvel()
                    world.attacker=unit
                    if firing then firingRequests=firingRequests+1 end
                    unit.weapons:Step(1/60,{firing=firing==true,aim=aim or unit:Position(),pos={p.x,p.y,p.z},
                        quat=vehicle.body.rotation(),vel={v.x,v.y,v.z},body=vehicle.body,team=unit.team,live=true,
                        salvo=info and info.salvo},world.env)
                    world.attacker=nil
                    helpers.DrainUnit(unit)
                end
            end
        end
        world:Step(1/60);helpers.DrainWorld()
    end
    for index=1,config.warmup do api.Step(index)end
    local bodies={}
    for index,entry in ipairs(entries)do
        assert(entry.unit.alive,'Vehicle died during normal-GC warmup; keep failed workload evidence')
        bodies[index]=entry.unit.vehicle.body
    end
    probe=Factory.New{gc=collectgarbage,clock=function()return Time:GetSystemTime()end,
        capacity=config.samples,limitKiB=16384,deadlineMs=250}
    collectgarbage=function(operation,...)
        if probe.active and operation~='count' and operation~='isrunning' then
            error('Production collector mutation during single-step sample: '..tostring(operation))
        end
        return rawGc(operation,...)
    end
    local wanted={
        {'drive.Vehicle','Step'},{'drive.Vehicle','StepRotors'},{'drive.Vehicle','PostStep'},{'drive.Vehicle','ApplyRotors'},
        {'drive.RaySuspension','Sample'},{'drive.RaySuspension','Apply'},
        {'drive.ContactControl','Step'},{'drive.ChassisStability','Step'},
        {'drive.HoverControl','Step'},{'drive.HoverControl','Motion'},
        {'drive.ThrusterControl','Step'},{'drive.WingControl','Step'},
        {'drive.LegControl','Step'},{'drive.LegControl','Cast'},{'drive.LegGait','Step'},
        {'drive.MechControl','Step'},{'drive.LegHitboxes','Update'},{'drive.MechHitboxes','Update'},
        {'physics.Body','Wrap'},{'physics.Space','Step'},{'physics.Space','Raycast'},{'drive.TrackWorld','CastRay'},
        {'combat.WeaponSystem','Step'},{'combat.WeaponSystem','Aim'},{'combat.WeaponSystem','Tick'},
        {'combat.WeaponSystem','Integrate'},{'combat.WeaponSystem','Fire'},{'combat.WeaponSystem','Muzzle'},
        {'combat.EnemyDriver','Step'},{'combat.CarUnit','Flush'},
        {'combat.EnemyDriverThink','Run'},{'combat.EnemyDriverThink','Sniper'},{'combat.EnemyDriverThink','Route'},
        {'combat.EnemyDriverMotion','Run'},{'combat.EnemyDriverMotion','Crowd'},{'combat.EnemyDriverMotion','Recover'},
        {'combat.EnemyDriver','Missiles'},
        {'combat.EnemyDriverNav','Graph'},{'combat.EnemyDriverNav','Path'},{'combat.EnemyDriverNav','Nearest'},
        {'combat.EnemyDriverNav','Direct'},{'combat.EnemyDriverNav','Visible'},
        {'combat.EnemyDriverTactics','Cover'},{'combat.EnemyDriverTactics','Firing'},
        {'combat.EnemyDriverTactics','Strafe'},{'combat.EnemyDriverTactics','Slide'},
        {'drive.LegGait','Foothold'},{'drive.LegControl','Clear'},{'drive.LegControl','Reachable'},
        {'parts.LegIK','Solve'},{'parts.LegIK','Reachable'},
        {'render.CombatEffects','Path'},{'render.CombatEffects','Helix'},{'render.CombatEffects','Projectiles'},
        {'render.WeaponEffects','Bands'},{'render.WeaponEffects','Motes'},{'render.WeaponEffects','Swirl'},
        {'render.WeaponEffects','Arcs'},{'render.WeaponEffects','Path'},
    }
    for _,item in ipairs(wanted)do probe:Wrap(require(item[1]),item[2],item[1]..'.'..item[2])end
    local bodyMethods={'beginReadScope','endReadScope','mass','translation','rotation','linvel','angvel','localCom','center',
        'impulseDenominator','velocityAtPoint','addForce','applyImpulse','addTorque','applyTorqueImpulse',
        'addForceAtPoint','applyImpulseAtPoint','resetForces','resetTorques','setTranslation','setRotation','setLinvel','setAngvel'}
    for _,body in ipairs(bodies)do
        for _,method in ipairs(bodyMethods)do probe:Wrap(body,method,'vehicleBody.'..method)end
        if body.addFlightAngularAcceleration then probe:Wrap(body,'addFlightAngularAcceleration','vehicleBody.addFlightAngularAcceleration')end
    end
    probe:Wrap(helpers,'Pick','fixture.Pick');probe:Wrap(helpers,'DrainUnit','fixture.DrainUnit')
    probe:Wrap(helpers,'DrainWorld','fixture.DrainWorld');probe:Wrap(world,'Step','fixed.WorldStep');probe:Wrap(api,'Step','fixed.CompleteStep')
    local snapshots={};local baseline={shots=world.stats.shots,hits=world.stats.hits,damage=world.stats.damage,
        manualCalls=manualCalls,aiCalls=aiCalls,firingRequests=firingRequests}
    local measuredShots=0
    for sample=1,config.samples do
        for _=1,config.normalBetween do assert(collectgarbage('isrunning'));api.Step(stepNumber+1)end
        for i,entry in ipairs(entries)do
            assert(entry.unit.alive and entry.unit.vehicle.body==bodies[i],'Eight-body topology changed before measured step')
        end
        local shotsBefore,hitsBefore,requestsBefore=world.stats.shots,world.stats.hits,firingRequests
        local measured=probe:Capture(stepNumber+1,api.Step,stepNumber+1)
        measured.shots=world.stats.shots-shotsBefore;measured.hits=world.stats.hits-hitsBefore
        measured.firingRequests=firingRequests-requestsBefore;measured.cooldownOnly=measured.shots==0
        measuredShots=measuredShots+measured.shots
        local state={step=stepNumber,cars={}}
        for i,entry in ipairs(entries)do
            assert(entry.unit.alive and entry.unit.vehicle.body==bodies[i],'Eight-body topology changed inside measured step')
            state.cars[i]={state=entry.unit.vehicle:GetState(),parts=entry.unit.bp:Size(),driver=entry.driver and entry.driver.mode or false}
        end
        snapshots[sample]=state
    end
    assert(measuredShots>0,'No actual shots inside stopped-GC samples; do not claim firing allocation coverage')
    local report=probe:Report();probe:Restore();RestoreGuard()
    local exercised,unexercised={},{}
    for _,row in ipairs(report.totals)do
        if row.calls>0 then exercised[#exercised+1]=row.name else unexercised[#unexercised+1]=row.name end
    end
    local result={status='ALLOCATION_DIAGNOSTIC_PASS',timingValidity='INVALID_FOR_PERFORMANCE',configuration=config,
        rosterIdentity=source.identity,map={kind='crater',bodiesBeforeVehicles=mapBodies},metadata=metadata,
        allocation=report,exercised=exercised,unexercised=unexercised,snapshots=snapshots,
        collectorMutationGuard=true,collectorGuardRestored=collectgarbage==rawGc,measuredShots=measuredShots,
        workload={baseline=baseline,final={shots=world.stats.shots,hits=world.stats.hits,damage=world.stats.damage,
            manualCalls=manualCalls,aiCalls=aiCalls,firingRequests=firingRequests},steps=stepNumber},
        boundary='Actual eight captured sources, real crater collision/Bullet, one manual slow-forward firing vehicle and seven actual AI drivers. One 1/60 step per stopped-GC interval, normal automatic GC between steps, no forced collection or collector mode changes. Target is nearest live enemy rather than BattleController objectives; this inherited CPU fixture has no render/audio/UI/objective consumers. Requested fire/weapon/projectile/physical simulation remain active; FX output queues are drained without constructing render effects. Unexercised effect methods are listed explicitly. Not a full-match replay, wall-time performance comparison or device FPS acceptance.'}
    world:Dispose();world=false;scene:Dispose();scene=false;return result
end
function Start()
    local ok,result=xpcall(Run,function(value)return tostring(value)end)
    local restoreOk,restoreError=pcall(function()if probe then probe:Restore()end end)
    RestoreGuard()
    if not ok or not restoreOk then
        local partial=false
        if probe then local good,value=pcall(probe.Report,probe);if good then partial=value end end
        result={status='FAIL',error=tostring(result),restoreError=not restoreOk and tostring(restoreError)or false,
            allocation=partial,collectorRunning=collectgarbage('isrunning'),timingValidity='INVALID_FOR_PERFORMANCE'}
    end
    pcall(function()if world then world:Dispose()end;if scene then scene:Dispose()end end)
    local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
