-- Standalone measurement entry. Loads the frozen, unmodified production main.
local output
local mode='fine'
local scenario='spawn'
for _,arg in ipairs(GetArguments()) do
    output=arg:match('^%-profile%-output=(.+)$') or output
    mode=arg:match('^%-profile%-mode=(.+)$') or mode
    scenario=arg:match('^%-profile%-scenario=(.+)$') or scenario
end
assert(output,'-profile-output required')
math.randomseed(20261016)
local script=assert(loadfile('scripts/main.lua','t',_ENV));script()
local productionStart=Start
local productionUpdate=HandleUpdate
local productionPresented=HandleFramePresented
local frame,session,app
local stack={}
local phase='boot'
local since=0
local frames={}
local skipped={}
local done=false
local errors={}
local beginWall=Time:GetSystemTime()
local lastUpdateWall
local measuredCounter=0
local function Now() return Time:GetSystemTime() end
local function Delta(a,b) return (a-b)&0xffffffff end
local function Write(result,message)
    local file=assert(io.open(output,'wb'))
    file:write(cjson.encode({result=result,message=message,phase=phase,mode=mode,scenario=scenario,frames=frames,skipped=skipped,errors=errors,
        scope='Normal production Update/Tick/PostUpdate; real dt and catch-up retained. Scripted input adapters only; all method timings inclusive and exclusive. Native Windows; no mobile or GPU timing claim.'}))
    file:close()
end
local function Wrap(object,key,name)
    if mode=='none' then return end
    if mode=='coarse' and not (name=='app.HangarApp.Update' or name=='app.HangarApp.PostUpdate'
        or name=='app.TrialSession.Tick' or name=='combat.BattleController.BeforeStep'
        or name=='combat.BattleController.AfterStep' or name=='physics.Space.Step'
        or name=='render.CombatView.Update' or name=='hud.Update') then return end
    if type(object[key])~='function' then skipped[#skipped+1]=name;return end
    local original=object[key]
    object[key]=function(...)
        if not frame or not frame.sampled then return original(...) end
        local row=frame.methods[name]
        if not row then row={calls=0,wallMs=0,cpuMs=0,selfWallMs=0,selfCpuMs=0};frame.methods[name]=row end
        local parent=stack[#stack]
        local clock={wall=Now(),cpu=os.clock(),childWall=0,childCpu=0}
        stack[#stack+1]=clock
        local values=table.pack(pcall(original,...))
        local wall,cpu=Delta(Now(),clock.wall),(os.clock()-clock.cpu)*1000
        stack[#stack]=nil
        row.calls=row.calls+1;row.wallMs=row.wallMs+wall;row.cpuMs=row.cpuMs+cpu
        row.selfWallMs=row.selfWallMs+wall-clock.childWall;row.selfCpuMs=row.selfCpuMs+cpu-clock.childCpu
        if parent then parent.childWall=parent.childWall+wall;parent.childCpu=parent.childCpu+cpu end
        if not values[1] then errors[#errors+1]=name..': '..tostring(values[2]);error(values[2],0) end
        return table.unpack(values,2,values.n)
    end
end
local function Setup()
    session=app.trial
    assert(session.battle and #session.battle.entries==8,'Expected actual production 4v4')
    if session.intro and not session.intro.done then session.intro:Finish() end
    -- Adapt only input/focus for an unattended hidden window, not the update loop.
    session.HasFocus=function() return true end
    session.pointer.Poll=function(self) self.captured=true end
    session.controls.Read=function()
        local command={throttle=.3,steer=0,strafe=0,climb=0,firing=phase=='player-fire',handbrake=false}
        if scenario=='engagement' then
            for _,entry in ipairs(session.battle.entries) do
                if entry.unit.team~=session.battle.player.team and entry.unit.alive then
                    command.aim=entry.unit:Position();command.aim[2]=command.aim[2]+.6;break
                end
            end
        end
        return command
    end
    local targets={
        {'app.HangarApp',{'Update','PostUpdate'}},
        {'app.TrialSession',{'Update','Tick','PostUpdate','Aim','ConsumeWorldEvents'}},
        {'combat.BattleController',{'BeforeStep','AfterStep','Pick','WorldState','SyncPlayer'}},
        {'combat.BattleObjectives',{'Update','UnitTick'}},
        {'render.ObjectiveView',{'Update','Refresh'}},
        {'combat.EnemyDriver',{'Step'}},
        {'combat.MatchTarget',{'Pick'}},
        {'combat.CarUnit',{'Flush','Step','RegenerateStructure','SavePose','Health','Life','Integrity'}},
        {'construction.Blueprint',{'Graph','Connectivity'}},
        {'drive.VehicleSpec',{'Build','BuildParts'}},
        {'drive.Vehicle',{'New','init','Dispose','Step','StepRotors','ApplyRotors','PostStep'}},
        {'drive.TrackWorld',{'NewVehicle'}},
        {'drive.RaySuspension',{'Sample','Apply'}},
        {'drive.ContactControl',{'Step'}},
        {'drive.ChassisStability',{'Step'}},
        {'drive.HoverControl',{'Step','Motion'}},
        {'drive.LegControl',{'Step','Cast'}},
        {'drive.LegGait',{'Step','Foothold'}},
        {'drive.MechControl',{'Step','Cast'}},
        {'drive.ThrusterControl',{'Step'}},
        {'drive.WingControl',{'Step'}},
        {'drive.LegHitboxes',{'Update'}},
        {'drive.MechHitboxes',{'Update'}},
        {'combat.WeaponSystem',{'Step','Aim','Integrate'}},
        {'physics.Space',{'Step','Raycast'}},
        {'drive.TrackWorld',{'Step','CastRay','Lockables'}},
        {'render.CombatView',{'Update','Consume','SavePose'}},
        {'render.DriveView',{'Update','SavePose'}},
        {'render.VehicleView',{'UpdateIdle','UpdateWeaponEffects','Rebuild','RemovePart','ApplyEdits'}},
        {'render.WeaponView',{'Update'}},
        {'render.PartRig',{'SetWheel','SetTrack','SetWeapon','SetLegTarget','SetMechPose'}},
        {'render.CombatEffects',{'Update','Consume'}},
        {'render.CraterEffects',{'Update'}},
        {'scene.Crater',{'Update'}},
        {'audio.DrivingAudio',{'Update','Observe'}},
        {'audio.WeaponAudio',{'Update','Consume'}},
        {'audio.CombatFeedbackAudio',{'Update','Consume'}},
        {'audio.CollisionAudio',{'BeforeStep','AfterStep'}},
        {'ui.DriveOverlay',{'Update'}},
        {'ui.ReticleState',{'Update'}},
    }
    for _,target in ipairs(targets) do
        local module=require(target[1])
        for _,key in ipairs(target[2]) do Wrap(module,key,target[1]..'.'..key) end
    end
    if session.hud then Wrap(session.hud,'Update','hud.Update') end
    if scenario=='engagement' then
        local k=0
        for _,entry in ipairs(session.battle.entries) do
            k=k+1;local blue=entry.unit.team=='blue'
            local x=((k%4)-1.5)*18;local z=-140+(blue and -20 or 20)
            entry.unit.vehicle:Place({x,session.world:GroundAt(x,z)+2,z},blue and 0 or math.pi)
            entry.unit:SavePose();entry.unit.previous=entry.unit.current
        end
        session.view:ResetPose()
    end
    phase='warm';since=Now()
end
local function Tick(realDt)
    if done then return end
    local currentWall=Now()
    local wallGap=lastUpdateWall and Delta(currentWall,lastUpdateWall) or 0
    lastUpdateWall=currentWall
    engine.maxInactiveFps=120
    if Delta(Now(),beginWall)>240000 then done=true;Write('FAIL','240s wall deadline');engine:Exit();return end
    if not app and VOX_HANGAR then app=VOX_HANGAR.app end
    if phase=='boot' and app and not app.loadingFlow.active then
        local roster=require('combat.Matchmaker').Find({Read=function() return nil end,Write=function() return true end},
            4,(app.blueprint:Stats().fitTier or {id=5}).id,nil,20261016)
        assert(app:EnterTrial('crater','conquest',roster),'production battle entry')
        phase='loading'
    elseif phase=='loading' and app.trial and not app.loadingFlow.active then Setup() end
    if phase=='warm' and Delta(Now(),since)>=20000 and session.battle.rules.state=='live' then
        phase='player-neutral';since=Now()
    end
    if phase=='player-neutral' or phase=='player-fire' then
        local alive=0;local units={};local projectiles=0
        for _,e in ipairs(session.battle.entries) do
            local u=e.unit;if u.alive then alive=alive+1 end
            projectiles=projectiles+#u.weapons.projectiles
            units[#units+1]={name=u.name,role=e.member.role,alive=u.alive,parts=u.bp:Size(),
                wheels=u.vehicle and #u.vehicle.wheels or 0,legs=u.spec and #(u.spec.legs or {}) or 0}
        end
        measuredCounter=measuredCounter+1
        frame={phase=phase,wall=Now(),wallGapMs=wallGap,dt=realDt,projectiles=projectiles,
            sampled=mode~='sampled' or measuredCounter%20==0,
            firing=session.firing==true,dialog=session.dialog~=nil,worldShots=session.world.stats.shots,
            fixedBefore=session.fixedSteps,
            droppedBefore=session.droppedTime,alive=alive,units=units,methods={},luaKB=collectgarbage('count')}
    end
end
local function End()
    if done then return end
    if frame then
        assert(#stack==0,'unbalanced method stack')
        assert(#errors==0,table.concat(errors,'\n'))
        frame.fixedSteps=session.fixedSteps-frame.fixedBefore
        frame.droppedSeconds=session.droppedTime-frame.droppedBefore
        frame.batches=renderer.numBatches;frame.primitives=renderer.numPrimitives
        frame.firingActual=session.firing==true
        frame.shotsAfter=session.world.stats.shots
        frame.damageAfter=session.world.stats.damage
        frame.updateToEndMs=Delta(Now(),frame.wall)
        frames[#frames+1]=frame;frame=nil
    end
    if (phase=='player-neutral' or phase=='player-fire') and Delta(Now(),since)>=60000 then
        if phase=='player-neutral' then phase='player-fire';since=Now();Write('RUNNING','neutral window complete')
        else
            session:Pause();session.onReturn()
            phase='done';done=true;Write('PASS','two actual wall-time windows complete; normal return invoked')
            engine:Exit()
        end
    end
end
function ProfileBegin(realDt)
    local ok,err=xpcall(function() Tick(realDt) end,debug.traceback)
    if not ok then done=true;frame=nil;Write('FAIL',err);engine:Exit() end
end
function ProfileEnd()
    local ok,err=xpcall(End,debug.traceback)
    if not ok then done=true;frame=nil;Write('FAIL',err);engine:Exit() end
end
function Start()
    engine.maxInactiveFps=120
    productionStart()
end
function HandleUpdate(eventType,eventData)
    ProfileBegin(eventData:GetFloat('TimeStep'))
    if not done then
        local ok,err=xpcall(function() productionUpdate(eventType,eventData) end,debug.traceback)
        if not ok then done=true;frame=nil;Write('FAIL',err);engine:Exit() end
    end
end
function HandleFramePresented(...)
    productionPresented(...)
    ProfileEnd()
end
