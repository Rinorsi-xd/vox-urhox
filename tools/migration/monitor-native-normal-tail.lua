    -- Keep module residency and module initialization equal before either arm
    -- starts; these are the exact lazy dependency lists in frozen Bindings.
    for _,name in ipairs({'scene.Hangar','scene.HangarAtmosphere','scene.HangarPanels',
        'ui.GarageHud','ui.BayPreviews','render.ReflectionFilter','render.VehicleView','render.WeaponEffects',
        'drive.ContactControl','drive.ChassisStability','drive.HoverControl','drive.ThrusterControl',
        'drive.WingControl','drive.LegGait','render.WeaponView'})do require(name) end
    local Monitor=require 'diagnostics.PerformanceMonitor'
    local Bindings=require 'diagnostics.PerformanceBindings'
    local sinkCalls=0;local sinkTypes={}
    local function Sink(record)
        sinkCalls=sinkCalls+1
        local kind=record and record.type or 'padding'
        sinkTypes[kind]=(sinkTypes[kind] or 0)+1
    end
    local monitor=Monitor.New({enabled=config.variant=='A',noFile=true,sink=Sink,session='matched-native'})
    local trial={world=world,scene=scene,vehicle=entries[1].unit.vehicle,
        combat={entries=entries},map={id='crater'},fixedSteps=0,accumulator=0}
    local app={trial=trial,scene=scene,mode='trial'}
    local rawVehicleStep=getmetatable(entries[1].unit.vehicle).__index.Step
    collectgarbage=function(operation,...)
        assert(operation=='count' or operation=='isrunning','Collector mutation prohibited in normal-GC fixture')
        return rawGc(operation,...)
    end
    local function Frame(index,finish)
        local callsBefore=sinkCalls
        if monitor.enabled then
            monitor:BeginFrame(1/60)
            local attachStart=Time:GetSystemTime()
            Bindings.Attach(monitor,app)
            monitor.monitorMs=(monitor.monitorMs or 0)+((Time:GetSystemTime()-attachStart)&0xffffffff)
        end
        local token=monitor:Begin('main.Update')
        api.Step(index)
        monitor:End(token)
        trial.fixedSteps=trial.fixedSteps+1
        local postToken=monitor:Begin('main.PostUpdate')
        monitor:End(postToken)
        if monitor.enabled then
            monitor:EndFrame(Bindings.Context(app))
            if finish then monitor:Finalize(Time:GetSystemTime(),true) end
        end
        -- Production Emit can invoke at most slow/error + sample in one frame.
        -- The last step also closes its pending frame inside the timer. Pad the
        -- identical trivial callback to four calls in both arms; no JSON,
        -- retained records, console or files execute in the measurement window.
        assert(sinkCalls-callsBefore<=4,'Unexpected per-frame Emit count')
        while sinkCalls-callsBefore<4 do Sink(false) end
    end
    for index=1,config.warmup do Frame(index) end
    -- A snapshot is an observer pause, not a game stall. Clear the genuine
    -- warmup pending row before the expensive initial digest, without a clock
    -- override. Only initial/final digests run in this primary timing fixture.
    if monitor.enabled then monitor:Finalize(Time:GetSystemTime(),true) end
    local class=getmetatable(entries[1].unit.vehicle).__index
    assert((class.Step~=rawVehicleStep)==monitor.enabled,'True disabled must never install vehicle wrappers')
    local external={[world]='world',[world.space]='space',[world.env]='environment',[scene]='scene'}
    if world.layout then external[world.layout]='layout' end
    if world.layout and world.layout.nav then external[world.layout.nav]='navigation' end
    -- Digest reachable unit/AI/weapon data and their caches, excluding external
    -- world/space/env/layout/nav roots. Functions/metatables/userdata are excluded;
    -- native vehicle/debris transforms are separately exported below.
    local function Digest(value)
        local h1,h2,nodes,scalars=2166136261,2654435769,0,0
        local seen={};local skipped={functions=0,userdata=0,threads=0};local bytes=0
        local function Feed(text)
            bytes=bytes+#text
            for index=1,#text do local byte=string.byte(text,index)
                h1=((h1~byte)*16777619)&0xffffffff;h2=((h2~byte)*33)&0xffffffff
            end
        end
        local Visit
        Visit=function(item)
            local kind=type(item)
            if kind=='table' then
                if external[item] then Feed('external:'..external[item]..';');return end
                if seen[item] then Feed('reference:'..seen[item]..';');return end
                nodes=nodes+1;seen[item]=nodes;Feed('table:'..nodes..'{')
                local keys={}
                for key,child in pairs(item) do
                    local kt,vt=type(key),type(child)
                    assert(kt=='number' or kt=='string','Unexpected non-scalar Lua table key in state')
                    if vt~='function' then keys[#keys+1]=key else skipped.functions=skipped.functions+1 end
                end
                table.sort(keys,function(a,b)if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
                for _,key in ipairs(keys)do Visit(key);Visit(item[key]) end
                Feed('}')
            elseif kind=='number' then scalars=scalars+1;Feed('number:'..string.format('%.17g',item)..';')
            elseif kind=='string' then scalars=scalars+1;Feed('string:'..#item..':'..item..';')
            elseif kind=='boolean' or kind=='nil' then scalars=scalars+1;Feed(kind..':'..tostring(item)..';')
            elseif kind=='userdata' then skipped.userdata=skipped.userdata+1;Feed('userdata;')
            elseif kind=='thread' then skipped.threads=skipped.threads+1;Feed('thread;')
            else error('Unexpected state type '..kind) end
        end
        Visit(value)
        return {hash=string.format('%08x%08x',h1,h2),tables=nodes,scalars=scalars,bytes=bytes,skipped=skipped}
    end
    local function BodyState(body)
        return {position=body.translation(),rotation=body.rotation(),velocity=body.linvel(),angularVelocity=body.angvel()}
    end
    local function Snapshot()
        local state={step=stepNumber,cars={},shots=world.stats.shots,hits=world.stats.hits,
            damage=world.stats.damage,manualCalls=manualCalls,aiCalls=aiCalls,firingRequests=firingRequests,
            worldDigest=Digest({stats=world.stats,time=world.time,debris=world.debris}),debris={}}
        for index,entry in ipairs(entries)do local unit=entry.unit
            local physical={state=unit.vehicle:GetState(),body=BodyState(unit.vehicle.body)}
            state.cars[index]={alive=unit.alive,state=physical.state,parts=unit.bp:Size(),hp=unit:Health(),
                driver=entry.driver and entry.driver.mode or false,
                digest=Digest({unit=unit,driver=entry.driver}),body=physical.body,physicalDigest=Digest(physical)}
        end
        for index,piece in ipairs(world.debris.pieces)do local body=BodyState(piece.body)
            state.debris[index]={id=piece.id,body=body,physicalDigest=Digest(body)}
        end
        return state
    end
    local initial=Snapshot();local frames={};local snapshots={}
    for index=1,config.steps do frames[index]={} end
    local sum=0;local maximum=0;local heapBefore=collectgarbage('count');local timedSinkBefore=sinkCalls
    local sinkBefore={};for kind,count in pairs(sinkTypes)do sinkBefore[kind]=count end
    for index=1,config.steps do
        assert(collectgarbage('isrunning'))
        local started=Time:GetSystemTime();Frame(config.warmup+index,index==config.steps)
        local elapsed=(Time:GetSystemTime()-started)&0xffffffff
        sum=sum+elapsed;maximum=math.max(maximum,elapsed)
        local row=frames[index];row.ms=elapsed;row.shots=world.stats.shots;row.hits=world.stats.hits
        row.damage=world.stats.damage;row.alive=0;row.parts=0
        for _,entry in ipairs(entries)do
            if entry.unit.alive then row.alive=row.alive+1 end
            row.parts=row.parts+entry.unit.bp:Size()
        end
    end
    local heapAfter=collectgarbage('count');local timedSinkCalls=sinkCalls-timedSinkBefore
    snapshots[1]=Snapshot()
    local timedSinkTypes={};for kind,count in pairs(sinkTypes)do timedSinkTypes[kind]=count-(sinkBefore[kind] or 0) end
    local stages=monitor.enabled and monitor:StageRows() or false
    local stageNames=monitor.enabled and monitor:StageNames() or false
    local monitorErrors=monitor.errors or {};assert(#monitorErrors==0,'Monitor captured Lua error')
    local randomAfter={};for index=1,16 do randomAfter[index]=math.random() end
    local aiRandomAfter={}
    for index,entry in ipairs(entries)do
        aiRandomAfter[index]={}
        if entry.driver then for draw=1,16 do aiRandomAfter[index][draw]=entry.driver.random() end end
    end
    assert(collectgarbage('isrunning'));RestoreGuard()
    monitor:Dispose()
    assert(class.Step==rawVehicleStep,'Dispose must restore production methods')
    local result={status='NORMAL_GC_TIMING_PASS',configuration=config,metadata=metadata,initial=initial,
        frames=frames,snapshots=snapshots,randomAfter=randomAfter,aiRandomAfter=aiRandomAfter,
        profile=false,totalStepMs=sum,meanStepMs=sum/config.steps,maxStepMs=maximum,
        timedSinkCalls=timedSinkCalls,timedSinkTypes=timedSinkTypes,monitorErrors=monitorErrors,stages=stages,stageNames=stageNames,
        wholeInstrumentation=monitor.frame>0,wrappersInstalledDuringTest=monitor.frame>0,wrappersRestored=true,
        heapBeforeKiB=heapBefore,heapAfterKiB=heapAfter,collectorRunning=collectgarbage('isrunning'),
        collectorGuardRestored=collectgarbage==rawGc,
        boundary='Native real eight-source CPU simulation with normal automatic GC. A includes actual production BeginFrame/Finalize, Bindings.Attach, wrappers/Begin/End, Context, EndFrame and pending-frame bookkeeping; C disabled from creation never installs wrappers. Exactly four identical trivial sink calls per timed step in each arm, actual Emit/padding types recorded. Initial/final unit/AI/weapon digests only, no intermediate observer stalls; warmup pending cleared before initial digest and final pending closed inside final timer. Real lastSample clock is unchanged, so the initial observer pause may affect the first sample cadence. JSON/files/console/UI/panel/render/audio/full match objectives excluded; this is not complete Web monitor overhead, FPS or mobile acceptance. Lua-data digests exclude external world/space/environment/layout/navigation roots and functions/metatables/native userdata internals; explicit world stats/time/debris roots plus native moving-body states are exported separately, global and per-AI RNG tails compared. Snapshot/row accounting outside timers; no forced GC.'}
    world:Dispose();world=false;scene:Dispose();scene=false;return result
end
function Start()
    local ok,result=xpcall(Run,function(value)return tostring(value)end)
    RestoreGuard()
    if not ok then result={status='FAIL',error=tostring(result),collectorRunning=collectgarbage('isrunning')} end
    pcall(function()if world then world:Dispose()end;if scene then scene:Dispose()end end)
    local file=assert(io.open(assert(output),'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
