    local timing=false
    collectgarbage=function(operation,...)
        assert(operation=='count' or operation=='isrunning','Collector mutation prohibited in normal-GC fixture')
        return rawGc(operation,...)
    end
    if config.profile then
        timing=require('qa-native-owner-times').New(function()return Time:GetSystemTime()end)
        local wanted={{'drive.TrackWorld','CastRay'},{'combat.VehicleRay','Cast'},
            {'drive.Vehicle','Step'},{'combat.WeaponSystem','Step'},{'combat.EnemyDriver','Step'},
            {'physics.Space','Raycast'},{'physics.Space','Step'}}
        for _,item in ipairs(wanted)do timing:Wrap(require(item[1]),item[2],item[1]..'.'..item[2])end
    end
    for index=1,config.warmup do api.Step(index)end
    local function Snapshot()
        local state={step=stepNumber,cars={},shots=world.stats.shots,hits=world.stats.hits,
            damage=world.stats.damage,manualCalls=manualCalls,aiCalls=aiCalls,firingRequests=firingRequests}
        for index,entry in ipairs(entries)do local unit=entry.unit
            state.cars[index]={alive=unit.alive,state=unit.vehicle:GetState(),parts=unit.bp:Size(),
                hp=unit:Health(),driver=entry.driver and entry.driver.mode or false}
        end
        return state
    end
    local initial=Snapshot();local frames={};local snapshots={}
    for index=1,config.steps do frames[index]={}end
    if timing then timing.enabled=true end
    local sum=0;local maximum=0;local heapBefore=collectgarbage('count')
    for index=1,config.steps do
        assert(collectgarbage('isrunning'))
        local started=Time:GetSystemTime();api.Step(config.warmup+index)
        local elapsed=(Time:GetSystemTime()-started)&0xffffffff
        sum=sum+elapsed;maximum=math.max(maximum,elapsed)
        local row=frames[index];row.ms=elapsed;row.shots=world.stats.shots;row.hits=world.stats.hits
        row.damage=world.stats.damage;row.alive=0;row.parts=0
        for _,entry in ipairs(entries)do
            if entry.unit.alive then row.alive=row.alive+1 end
            row.parts=row.parts+entry.unit.bp:Size()
        end
        if index%60==0 then snapshots[#snapshots+1]=Snapshot()end
    end
    local heapAfter=collectgarbage('count');local profile=false
    if timing then timing.enabled=false;profile=timing:Report();timing:Restore()end
    local randomAfter={};for index=1,16 do randomAfter[index]=math.random()end
    assert(collectgarbage('isrunning'));RestoreGuard()
    local result={status='NORMAL_GC_TIMING_PASS',configuration=config,metadata=metadata,initial=initial,
        frames=frames,snapshots=snapshots,randomAfter=randomAfter,profile=profile,
        totalStepMs=sum,meanStepMs=sum/config.steps,maxStepMs=maximum,
        heapBeforeKiB=heapBefore,heapAfterKiB=heapAfter,collectorRunning=collectgarbage('isrunning'),
        collectorGuardRestored=collectgarbage==rawGc,
        boundary='Integer wall timing per actual fixed step, includes normal automatic GC/native calls/preemption. Snapshot/row accounting outside each step timer; no forced collection or mode changes. Optional profile is separate from unwrapped primary timing. No rendering/audio/UI or full BattleController objectives. Initial eight cars may naturally die; per-step workload is recorded for exact A/B validation. Not FPS or target-device acceptance.'}
    world:Dispose();world=false;scene:Dispose();scene=false;return result
end
function Start()
    local ok,result=xpcall(Run,function(value)return tostring(value)end)
    RestoreGuard()
    if not ok then result={status='FAIL',error=tostring(result),collectorRunning=collectgarbage('isrunning')}end
    pcall(function()if world then world:Dispose()end;if scene then scene:Dispose()end end)
    local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
