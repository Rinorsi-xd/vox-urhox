local original=HandleUpdate
local lastObservedApp
local updateTiming={}
local timedObjects=setmetatable({},{__mode='k'})
local audioPreparation={events={},serial=0,limit=64}
local audioGates=setmetatable({},{__mode='k'})
local function ObserveAudioGate(gate,kind)
    if type(gate)~='table' or audioGates[gate] then return end
    local start,cancel=gate.Start,gate.Cancel
    if type(start)~='function' or type(cancel)~='function' then return end
    local observer={};audioGates[gate]=observer
    gate.Cancel=function(self,...)
        local record=observer.current
        if record and not record.downloadCompleteWall and not record.cancelWall then
            record.cancelWall=Time:GetSystemTime()
        end
        return cancel(self,...)
    end
    gate.Start=function(self,paths,callback)
        audioPreparation.serial=audioPreparation.serial+1
        local record={sequence=audioPreparation.serial,kind=kind,paths={},requestWall=Time:GetSystemTime()}
        for i,path in ipairs(paths) do record.paths[i]=path end
        local events=audioPreparation.events;events[#events+1]=record
        if #events>audioPreparation.limit then table.remove(events,1) end
        local result=start(self,paths,function(ok,err)
            -- This callback can hold the native download lock: copy scalars only.
            record.downloadCompleteWall=Time:GetSystemTime();record.downloadOK=ok==true
            record.downloadError=not ok and tostring(err) or nil
            return callback(ok,err)
        end)
        observer.current=record;record.group=self.group
        return result
    end
end
local function ObserveAudioSlot(gate,preparation,sound,source)
    local observer=gate and audioGates[gate];local record=observer and observer.current
    if not record then return end
    local now=Time:GetSystemTime()
    if preparation and preparation.queued and not record.queuedObservedWall then record.queuedObservedWall=now end
    if preparation and preparation.error then record.prepareError=tostring(preparation.error) end
    -- These are upper-bound observation times, not native EndLoad instrumentation.
    if sound and not record.readyObservedWall then record.readyObservedWall=now end
    if source and not record.sourceObservedWall then record.sourceObservedWall=now end
end
local function ObserveAudioPreparation(app)
    if not app then return end
    local music=app.music
    for i,slot in ipairs(music and music.slots or {}) do
        ObserveAudioGate(slot.gate,'music')
        ObserveAudioSlot(slot.gate,slot.preparation,slot.sound,slot.source)
        local observer=audioGates[slot.gate];local record=observer and observer.current
        if record then
            record.id=slot.track and slot.track.id or record.id
            record.slot=i;record.pending=music.pending==i
        end
    end
    local ambience=app.ambience
    if ambience then
        ObserveAudioGate(ambience.gate,'ambience')
        local current=ambience.current;local pending=ambience.pending
        local observer=audioGates[ambience.gate];local record=observer and observer.current
        if record then
            if pending then record.id=pending.id end
            local matching=not pending and current and current.id==record.id
            ObserveAudioSlot(ambience.gate,pending,matching and current.sound,matching and current.source)
            record.pending=pending~=nil
        end
    end
end
local function AudioPreparationState(app)
    local music=app and app.music;local ambience=app and app.ambience
    local pendingMusic=music and music.slots and music.slots[music.pending]
    local musicRecord=pendingMusic and audioGates[pendingMusic.gate]
    local ambienceRecord=ambience and audioGates[ambience.gate]
    return {events=audioPreparation.events,total=audioPreparation.serial,limit=audioPreparation.limit,
        music={pending=music and music.pending~=nil or false,paths=musicRecord and musicRecord.current and musicRecord.current.paths},
        ambience={pending=ambience and ambience.pending~=nil or false,
            paths=ambience and ambience.pending and ambienceRecord and ambienceRecord.current and ambienceRecord.current.paths},
        timestampScope='request/download callback wall; queued/ready/source are wrapper observation upper bounds, not native EndLoad times'}
end
local function TimedCall(label,method,quiet)
    local stats=updateTiming[label] or {calls=0,totalMs=0,maxMs=0,lastMs=0,slowCalls=0}
    updateTiming[label]=stats
    return function(...)
        local started=Time:GetSystemTime()
        local first,second,third,fourth=method(...)
        local ended=Time:GetSystemTime();local elapsed=ended-started
        stats.calls=stats.calls+1;stats.totalMs=stats.totalMs+elapsed;stats.lastMs=elapsed
        stats.lastStartWall=started;stats.lastEndWall=ended
        if elapsed>stats.maxMs then
            stats.maxMs=elapsed;stats.maxStartWall=started;stats.maxEndWall=ended
        end
        if elapsed>=100 then
            stats.slowCalls=stats.slowCalls+1
            if not quiet then print('[QAUpdateTiming] '..label..' ms='..elapsed..' startWall='..started..' wall='..ended..
                ' calls='..stats.calls..' totalMs='..stats.totalMs..' maxMs='..stats.maxMs) end
        end
        return first,second,third,fourth
    end
end
local function WrapUpdateTiming(object,method,label,audioApp,options)
    if type(object)~='table' or type(object[method])~='function' then return end
    local methods=timedObjects[object]
    if not methods then methods={};timedObjects[object]=methods end
    if methods[method]==object[method] then return end
    local methodCall=object[method]
    if label=='audio.MusicPlayer.PreparePending' or label=='audio.GameAmbience.Prepare' then
        methodCall=function(...)
            ObserveAudioPreparation(audioApp)
            local first,second,third,fourth=methods[method..':original'](...)
            ObserveAudioPreparation(audioApp)
            return first,second,third,fourth
        end
        methods[method..':original']=object[method]
    end
    local rawOriginal=rawget(object,method)
    local wrapped=TimedCall(label,methodCall,options and options.quiet)
    object[method]=wrapped;methods[method]=wrapped
    if options and options.bindings then
        options.bindings[#options.bindings+1]={object=object,method=method,original=rawOriginal,wrapped=wrapped}
    end
end
local function EnsureUpdateTiming(app)
    if not app or app.stopped then return end
    ObserveAudioPreparation(app)
    -- Engine require caches need not appear in package.loaded. Bind the actual
    -- instances used by main.lua; the gate metatable is its actual module.
    WrapUpdateTiming(app,'Update','app.HangarApp.Update')
    WrapUpdateTiming(app,'AdvanceOpeningRetirements','app.HangarApp.AdvanceOpeningRetirements')
    WrapUpdateTiming(app,'ReleaseSettledAssets','app.HangarApp.ReleaseSettledAssets')
    WrapUpdateTiming(app,'Install','app.HangarApp.Install')
    WrapUpdateTiming(app.loader,'Update','app.SceneLoader.Update')
    WrapUpdateTiming(app.loader,'ReadScene','app.SceneLoader.ReadScene')
    WrapUpdateTiming(app.loader,'Commit','app.SceneLoader.Commit')
    WrapUpdateTiming(app.loadingFlow,'Advance','app.LoadingFlow.Advance')
    WrapUpdateTiming(app.loadingFlow,'Rendered','app.LoadingFlow.Rendered')
    WrapUpdateTiming(app.loadingFlow,'Finish','app.LoadingFlow.Finish')
    WrapUpdateTiming(app.music,'Update','audio.MusicPlayer.Update')
    WrapUpdateTiming(app.music,'Next','audio.MusicPlayer.Next')
    WrapUpdateTiming(app.music,'PreparePending','audio.MusicPlayer.PreparePending',app)
    WrapUpdateTiming(app.ambience,'Update','audio.GameAmbience.Update')
    WrapUpdateTiming(app.ambience,'Prepare','audio.GameAmbience.Prepare',app)
    WrapUpdateTiming(app.vehicleGate and getmetatable(app.vehicleGate),'UpdatePending','app.ResourceGate.UpdatePending')
end
local battleTiming={enabled=false,epoch=0,toggles=0,boundMethods=0,active=false,unitLimit=5,sampledUnits=0,missing={},
    boundary='Explicit F15 opt-in QA CPU wall milliseconds; inclusive nested calls must not be summed. No GPU or isolated frame timing. At most five sampled units; combat vehicle view labels aggregate actual vehicle views, never part traversal. Missing methods are reported without substitution. Actual view metatables instrument New/Rebuild before spawn; other new or rebuilt instances bind at the next QA update.'}
local battleBindings={}
local function RestoreBattleBinding(binding)
    if binding.object[binding.method]==binding.wrapped then binding.object[binding.method]=binding.original end
end
local function SetBattleTiming(enabled)
    battleTiming.enabled=enabled==true;battleTiming.toggles=battleTiming.toggles+1
    if enabled then
        battleTiming.epoch=battleTiming.epoch+1
        for label in pairs(updateTiming) do if label:sub(1,7)=='battle.' then updateTiming[label]=nil end end
    end
    for _,binding in ipairs(battleBindings) do RestoreBattleBinding(binding) end
    battleBindings={};battleTiming.boundMethods=0;battleTiming.active=false;battleTiming.sampledUnits=0;battleTiming.missing={}
end
local function EnsureBattleTiming(app)
    if not battleTiming.enabled then return end
    local trial=app and not app.stopped and app.trial
    if trial and trial.disposed then trial=nil end
    local desired={};local options={quiet=true,bindings=battleBindings}
    local missing={}
    local function Bind(object,method,label)
        if type(object)~='table' or type(object[method])~='function' then missing[#missing+1]=label;return end
        local methods=desired[object];if not methods then methods={};desired[object]=methods end
        methods[method]=true
        WrapUpdateTiming(object,method,label,nil,options)
    end
    local function VehicleView(drive,label)
        Bind(drive,'Update',label..'.DriveView.Update')
        local view=drive and drive.view
        for _,method in ipairs({'Update','UpdateIdle','UpdateWeaponEffects'}) do Bind(view,method,label..'.VehicleView.'..method) end
    end
    local units={};local seen={}
    local function Unit(unit,label)
        if type(unit)~='table' or seen[unit] or #units>=battleTiming.unitLimit then return end
        seen[unit]=true;units[#units+1]=unit
        Bind(unit,'Flush',label..'.Flush')
        local vehicle=unit.vehicle
        Bind(vehicle,'Step',label..'.Vehicle.Step')
        Bind(vehicle,'StepRotors',label..'.Vehicle.StepRotors')
        Bind(unit.weapons,'Step',label..'.Weapons.Step')
        Bind(vehicle and vehicle.mechControl,'Step',label..'.MechControl.Step')
        for _,entry in ipairs(trial.combat and trial.combat.entries or {}) do
            if entry.unit==unit and entry.driver then Bind(entry.driver,'Step',label..'.Driver.Step');break end
        end
    end
    if trial then
        Bind(trial,'Tick','battle.Trial.Tick');Bind(trial,'RenderViews','battle.Trial.RenderViews')
        Bind(trial,'PostUpdate','battle.Trial.PostUpdate')
        Bind(trial,'ConsumeWorldEvents','battle.Trial.ConsumeWorldEvents')
        local world=trial.world;Bind(world,'Step','battle.World.Step');Bind(world and world.space,'Step','battle.Space.Step')
        local story=trial.story
        for _,method in ipairs({'BeforeStep','AfterStep','Update'}) do Bind(story,method,'battle.Mission.'..method) end
        if trial.combat and trial.combat~=story then
            for _,method in ipairs({'BeforeStep','AfterStep','Update'}) do Bind(trial.combat,method,'battle.Combat.'..method) end
        end
        local boss=story and story.boss
        for _,method in ipairs({'BeforeStep','StepAllies','Projectiles','Update'}) do Bind(boss,method,'battle.Boss.'..method) end
        Bind(boss and boss.view,'Update','battle.BossView.Update')
        Unit(story and story.player or trial.combat and trial.combat.player,'battle.Player')
        Unit(boss and boss.unit,'battle.BossUnit')
        for i=1,3 do local ally=boss and boss.allies and boss.allies[i];Unit(ally and ally.unit,'battle.Ally'..i) end
        for i=1,battleTiming.unitLimit do Unit(world and world.units and world.units[i],'battle.Unit'..i) end
        VehicleView(trial.view,'battle.PlayerView')
        -- Bind the actual classes already used by this trial; no eager require.
        -- Shared constructor/rebuild bindings see first-spawn work before the
        -- next observer frame can discover the newly constructed instance.
        Bind(trial.view and getmetatable(trial.view),'New','battle.DriveView.New')
        Bind(trial.view and trial.view.view and getmetatable(trial.view.view),'Rebuild','battle.VehicleView.Rebuild')
        Bind(trial.combatView,'Consume','battle.CombatView.Consume')
        Bind(trial.combatView,'Update','battle.CombatView.Update')
        for _,drive in pairs(trial.combatView and trial.combatView.units or {}) do VehicleView(drive,'battle.CombatVehicle') end
    end
    -- Restore retired instance methods without overwriting a later external replacement.
    for i=#battleBindings,1,-1 do
        local binding=battleBindings[i];local methods=desired[binding.object]
        if not methods or not methods[binding.method] or binding.object[binding.method]~=binding.wrapped then
            RestoreBattleBinding(binding);table.remove(battleBindings,i)
        end
    end
    battleTiming.active=trial~=nil and trial~=false;battleTiming.boundMethods=#battleBindings
    battleTiming.sampledUnits=#units;battleTiming.missing=missing
end
local function BattleTimingState() return battleTiming end
VOX_SKIP_TUTORIAL=true
VOX_CLOUD_VALIDATION=true
local UI=require 'urhox-libs/UI'
local shell=require 'render.RestoreFlash'
local originalShellAdd=shell.Add
local hitFlashCalls={total=0,white=0,shield=0}
local aimDraws={warm=0,live=0,enemy=0,ally=0}
local commsCueCalls={requested={},played={}}
local uiSoundTrace={pointer=0,play=0}
local uiSoundModule=require 'audio.UiSound'
local originalUiSoundPlay=uiSoundModule.Play
uiSoundModule.Play=function(id)
    local played=originalUiSoundPlay(id)
    uiSoundTrace.play=uiSoundTrace.play+1
    uiSoundTrace.lastPlay={id=id,played=played,focus=input.focus,minimized=input.minimized}
    return played
end
local originalUiSoundStart=uiSoundModule.Start
uiSoundModule.Start=function(...)
    local result=originalUiSoundStart(...)
    UI.Input.On('PointerDown',function(event)
        local scale=UI.GetScale();local x,y=event.x/scale,event.y/scale
        local widget=UI.FindWidgetAt(x,y);local classes={};local class=widget
        while class do classes[#classes+1]={name=class._className,button=class==UI.Button};class=class._super end
        uiSoundTrace.pointer=uiSoundTrace.pointer+1
        uiSoundTrace.lastPointer={x=x,y=y,primary=event:IsPrimaryAction(),classes=classes,
            disabled=widget and widget.props.disabled or false,focus=input.focus,minimized=input.minimized}
    end,10000)
    return result
end
local commsCueModule=require 'audio.StoryCommsCues'
local originalCommsCuePlay=commsCueModule.Play
commsCueModule.Play=function(self,name)
    commsCueCalls.requested[name]=(commsCueCalls.requested[name] or 0)+1
    local played=originalCommsCuePlay(self,name)
    if played then commsCueCalls.played[name]=(commsCueCalls.played[name] or 0)+1 end
    return played
end
local aimModule=require 'render.AimLines'
local originalAimDraw=aimModule.Draw
aimModule.Draw=function(self,pos,dir,hit,len,enemy,...)
    local loading=lastObservedApp and lastObservedApp.loadingFlow and lastObservedApp.loadingFlow.active
    local phase=loading and 'warm' or 'live';aimDraws[phase]=aimDraws[phase]+1
    if not loading then
        local team=enemy and 'enemy' or 'ally';aimDraws[team]=aimDraws[team]+1
    end
    return originalAimDraw(self,pos,dir,hit,len,enemy,...)
end
shell.Add=function(self,part,options)
    local result=originalShellAdd(self,part,options)
    if options and options.pop==false then
        hitFlashCalls.total=hitFlashCalls.total+1
        local color=options.color
        local kind=color and color[1]==1 and color[2]==1 and color[3]==1 and 'white' or 'shield'
        hitFlashCalls[kind]=hitFlashCalls[kind]+1
        hitFlashCalls.lastPart=part.id;hitFlashCalls.lastColor=color
    end
    return result
end
local captureModule=require 'render.MatchMapShot'
local originalMapCapture=captureModule.New
local observedCapture
local captureSequence=0
local observedOwners=setmetatable({},{__mode='v'})
captureModule.New=function(...)
    local value=originalMapCapture(...);observedCapture=value;captureSequence=captureSequence+1
    return value
end
local wheelTrace={}
local originalWheel=UI.HandleWheel
UI.HandleWheel=function(dx,dy)
    local owner=require('ui.GarageHud').GetState()
    local modal=owner and owner.dialog
    if not (modal and modal.helpContent) then return originalWheel(dx,dy) end
    local chain={};local widget=UI.GetHoveredWidget()
    while widget do
        chain[#chain+1]={class=widget._className,id=widget.props.id,wheel=widget.OnWheel~=nil}
        widget=widget.parent
    end
    local _,before=modal.scroll:GetScroll()
    originalWheel(dx,dy)
    local _,after=modal.scroll:GetScroll()
    wheelTrace={dx=dx,dy=dy,chain=chain,before=before,after=after}
    print('OUTGAME_HELP_WHEEL '..cjson.encode(wheelTrace))
end
local frames=0;local previous='';local samples={}
local sampleMode=''
local pendingTrialDump=false
local pendingPresentationHistory=false
local pendingBattleObjects=false
local pendingSceneObjects=false
local presentationStory
local presentationFrames={};local presentationHead=0;local presentationCount=0
local presentationFields={'at','frame','objectiveTitle','objectiveAlpha','objectiveX','objectiveDone','objectiveIndex',
    'choiceId','choiceOn','choiceChoosing','choicePicked','choiceAlpha','choiceX','choiceVisible','choiceHideAt'}
local function PresentationHistory(ring,head,count,full)
    local history={}
    local first=full and 1 or math.max(1,count)
    for i=first,count do history[#history+1]=ring[(head-count+i-1)%180+1] end
    return history
end
local function ObserveStoryPresentation(story)
    if story~=presentationStory then presentationStory=story;presentationFrames={};presentationHead=0;presentationCount=0 end
    if not story then return end
    local objective=story.objective and story.objective.sample
    local choice=story.choiceView and story.choiceView.sample
    presentationHead=presentationHead%180+1;presentationCount=math.min(180,presentationCount+1)
    presentationFrames[presentationHead]={Time:GetSystemTime(),GetTime().frameNumber,
        objective and objective.title or false,objective and objective.alpha or false,objective and objective.x or false,
        objective and objective.done or false,objective and objective.index or false,
        choice and choice.choice and choice.choice.id or false,choice and choice.on or false,choice and choice.choosing or false,
        choice and choice.picked or false,choice and choice.alpha or false,choice and choice.x or false,choice and choice.visible or false,
        story.choiceView and story.choiceView.pending[1] or false}
end
local destruction=setmetatable({},{__mode='k'})
local function DamageProbe(session)
    local stats=destruction[session]
    if not stats then
        stats={flushes=0,removed=0,killed=0,totalMs=0,maxMs=0,samples={},seen=setmetatable({},{__mode='k'})}
        destruction[session]=stats
    end
    for _,unit in ipairs(session.world.units) do if not stats.seen[unit] then
        stats.seen[unit]=true
        local event=unit.Event;local lost=0
        unit.Event=function(self,kind,...)
            if kind=='partRemoved' then stats.removed=stats.removed+1;lost=lost+1 end
            if kind=='unitKilled' then stats.killed=stats.killed+1 end
            return event(self,kind,...)
        end
        local flush=unit.Flush
        unit.Flush=function(self,...)
            if not self.dirty or not self.alive then return flush(self,...) end
            local alive=self.alive;local at=Time:GetSystemTime()
            local result=table.pack(flush(self,...));local ms=Time:GetSystemTime()-at
            local removed=lost;lost=0
            stats.flushes=stats.flushes+1
            stats.totalMs=stats.totalMs+ms;stats.maxMs=math.max(stats.maxMs,ms)
            local sample={at=at,ms=ms,name=self.name,removed=removed,killed=alive and not self.alive}
            stats.samples[#stats.samples+1]=sample
            if #stats.samples>60 then table.remove(stats.samples,1) end
            print('DAMAGE_REBUILD '..cjson.encode(sample))
            return table.unpack(result,1,result.n)
        end
    end end
    return {flushes=stats.flushes,removed=stats.removed,killed=stats.killed,totalMs=stats.totalMs,maxMs=stats.maxMs,samples=stats.samples}
end
local function OpeningLoadState(I)
    local state=I.host and I.host.state or {}
    local loader=state.loader
    local function Gate(gate)
        if not gate then return nil end
        return {state=gate.state,total=gate.total,completed=gate.completed,bytes=gate.bytes,totalBytes=gate.totalBytes}
    end
    local warm=state.warmup
    local image=I.page and I.page.imageWarmup
    local session=state.session
    local camera=I.ready and I.host.GetCamera and I.host.GetCamera(I)
    local point=camera and camera.node.position
    local payslip=I.payslipShot
    return {wallMs=Time:GetSystemTime(),audioReady=I.audioReady,sceneDownloaded=I.sceneDownloaded,
        presentation={storyCameraAt=I.storyCameraAt,gateCameraAt=I.gateCameraAt,
            camera=point and {-point.x,point.y,point.z},
            payslipAt=payslip and payslip.at,impactAt=I.payslipImpact and I.payslipImpact.at,
            driversParked=session and session.combat and session.combat.driversParked==true,
            aim=session and session.aimPoint},
        scenePrefetching=I.scenePrefetching,scenePreparing=I.scenePreparing,media=Gate(I.gate),prefetch=Gate(state.prefetchGate),
        loader=loader and {state=loader.state,phase=loader.phase,progress=loader.progress,phaseTimes=loader.phaseTimes,
            prepareStage=loader.prepareStage,prepareFrames=loader.prepareFrames,maxPrepareMs=loader.maxPrepareMs,
            prepareTotalMs=loader.prepareTotalMs,prepareStageMax=loader.prepareStageMax,gate=Gate(loader.gate)},
        warmup=warm and {phase=warm.phase,index=warm.index,frames=warm.frames,batches=warm.batches,completed=warm.completed},
        leaveCapture=state.leaveCapture and {ready=state.leaveCapture.ready==true,frames=state.leaveCapture.frames,
            texture=state.captures and state.captures.leave~=nil,node=state.leaveCapture.node~=nil,viewport=state.leaveCapture.viewport~=nil},
        images=image and {index=image.index,total=#image.items,ready=image.ready}}
end
local function MeasureOpening(I)
    if not I.host or not I.host.state then return nil end
    local profile=I.qaTiming
    if not profile then profile={seen=setmetatable({},{__mode='k'}),totals={}};I.qaTiming=profile end
    local function Wrap(object,method,label)
        if not object or type(object[method])~='function' then return end
        local methods=profile.seen[object]
        if not methods then methods={};profile.seen[object]=methods end
        if methods[method]==object[method] then return end
        local originalMethod=object[method]
        local stats=profile.totals[label]
        if not stats then stats={calls=0,totalMs=0,maxMs=0,lastMs=0};profile.totals[label]=stats end
        local wrapped=function(self,...)
            local started=Time:GetSystemTime()
            local result,second,third,fourth=originalMethod(self,...)
            local elapsed=Time:GetSystemTime()-started
            stats.calls=stats.calls+1;stats.totalMs=stats.totalMs+elapsed;stats.lastMs=elapsed
            if elapsed>stats.maxMs then stats.maxMs=elapsed;stats.maxShot=I.shot;stats.maxAge=I.age end
            if label:sub(1,12)=='openingExit:' then
                print('[OpeningTiming] '..label..' ms='..elapsed..' wall='..Time:GetSystemTime())
            end
            return result,second,third,fourth
        end
        object[method]=wrapped;methods[method]=wrapped
    end
    Wrap(I.page,'Render','openingPage');Wrap(I.page,'Contract','openingContract')
    Wrap(I.page,'Comms','openingComms');Wrap(I.page,'Gate','openingGate')
    Wrap(I.page and I.page.imageWarmup,'Step','imagePrepare')
    Wrap(I.audio,'Update','introAudio');Wrap(I.audio,'Voice','voiceStart');Wrap(I.audio,'PrepareNext','audioPrepare')
    Wrap(I,'Finish','openingExit:request');Wrap(I,'CompleteFinish','openingExit:complete')
    Wrap(I,'Dispose','openingExit:dispose');Wrap(I.page,'Close','openingExit:pageClose')
    Wrap(I.audio,'Dispose','openingExit:audioDispose')
    Wrap(I.host,'BeginFinish','openingExit:beginHost');Wrap(I.host,'Dispose','openingExit:hostDispose')
    Wrap(I.host,'Finish','openingExit:restoreHud')
    Wrap(I.host.state.loader,'Update','sceneLoader')
    if not I.ready or not I.host.state.session then return profile.totals end
    local session=I.host.state.session
    Wrap(session,'Tick','sessionTick');Wrap(session.world,'Step','worldStep')
    Wrap(session.world and session.world.space,'Step','bulletStep')
    Wrap(session.world and session.world.debris,'Advance','debrisAdvance')
    Wrap(session.world and session.world.debris,'CapturePoses','debrisCapture')
    Wrap(session.world and session.world.metrics,'Step','trialMetrics')
    Wrap(session.combat,'BeforeStep','actorsBeforeStep');Wrap(session.combatView,'Update','enemyView')
    Wrap(session.view,'Update','playerView');Wrap(session.effects,'Update','combatEffects')
    Wrap(session.effects,'Consume','effectConsume');Wrap(session.weaponAudio,'Consume','weaponAudioConsume')
    for _,entry in ipairs(session.combat and session.combat.entries or {}) do
        Wrap(entry.unit,'Flush','actorFlush');Wrap(entry.driver,'Step','enemyDriver')
        Wrap(entry.unit,'Step','actorStep');Wrap(entry.unit,'SavePose','actorSavePose')
        Wrap(entry.unit.vehicle,'Step','vehicleStep');Wrap(entry.unit.vehicle,'StepRotors','rotorStep')
        local vehicle=entry.unit.vehicle
        Wrap(vehicle and vehicle.suspension,'Sample','suspensionSample')
        Wrap(vehicle and vehicle.suspension,'Apply','suspensionApply')
        Wrap(vehicle and vehicle.legControl,'Step','legControlStep')
        Wrap(vehicle and vehicle.legHitboxes,'Update','legHitboxesUpdate')
        Wrap(vehicle and vehicle.mechControl,'Step','mechControlStep')
        Wrap(vehicle and vehicle.mechHitboxes,'Update','mechHitboxesUpdate')
        Wrap(entry.unit.weapons,'Step','weaponsStep')
    end
    return profile.totals
end
local function SalvageInventory(app)
    local lobby=app.salvageLobby;if not lobby then return nil end
    local source=app.trial and app.trial.salvage and app.trial.salvage.original or app.blueprint:ToTable()
    local installed={}
    for _,part in ipairs(source.parts) do if part[1]~='core' then
        local id='part:'..part[1];installed[id]=(installed[id] or 0)+1
    end end
    local saved,generation,time=lobby.store:Read('stash',require('app.SalvageLobby').Valid)
    return {items=lobby.data.items,stats=lobby.data.stats,lastRun=lobby.data.lastRun,lastStartedRun=lobby.data.lastStartedRun,
        credits=lobby.data.credits,installed=installed,name=source.name,bayActive=app.bays.active,
        saved={data=saved,generation=generation,time=time}}
end
local function AudioState(owner,app)
    local levels=require('audio.AudioLevels')
    local data={levels=levels.Snapshot(),music={volume=app.music.volume,enabled=app.music.enabled,paused=app.music.userPaused},
        introAudioTail=require('audio.IntroAudioTail').Snapshot(),
        uiSound=require('audio.UiSound').Snapshot(),uiSoundTrace=uiSoundTrace,commsCues=commsCueCalls,rects={}}
    local modal=owner and owner.dialog
    if not modal or not modal.controls or not modal.controls.voice then return data end
    data.open=true;data.status=modal.status:GetText();data.modal=modal.modalLayout_
    data.sourceScale=modal.sourceScale;data.compact=modal.compact
    for key,widget in pairs(modal.controls) do local r=widget:GetAbsoluteLayoutForHitTest();data.rects[key]={r.x,r.y,r.w,r.h} end
    for key,widget in pairs(modal.actions) do local r=widget:GetAbsoluteLayoutForHitTest();data.rects[key]={r.x,r.y,r.w,r.h} end
    data.nextDisabled=modal.actions.next.props.disabled;return data
end
local function PauseState(owner)
    local modal=owner and owner.dialog
    if not modal or not modal.actions or not modal.actions.modeIntro then return nil end
    local data={modal=modal.modalLayout_,compact=modal.compact,scale=modal.sourceScale,rows={}}
    for id,widget in pairs(modal.actions) do
        local r=widget:GetAbsoluteLayoutForHitTest()
        data.rows[id]={text=widget.props.text,subtitle=widget.props.subtitle,disabled=widget.props.disabled,rect={r.x,r.y,r.w,r.h}}
    end
    return data
end
local function TouchState(layer)
    if not layer then return nil end
    local data={menu=layer.menu,expanded=layer.expanded==true,blocked=layer.blocked,aux=layer.aux,contacts=0,rects={}}
    if layer.Snapshot then
        local snapshot=layer.Snapshot();data.editor=snapshot;data.prefs=layer.prefs
        for _ in pairs(layer.pointers) do data.contacts=data.contacts+1 end
        for id,r in pairs(snapshot.buttons) do data.rects[id]={r.x,r.y,r.w,r.h} end
        for i,r in pairs(snapshot.slots) do data.rects['slot-'..i]={r.x,r.y,r.w,r.h} end
        return data
    end
    for _ in pairs(layer.gestures.pointers) do data.contacts=data.contacts+1 end
    local function Rect(id,widget) local r=widget:GetAbsoluteLayoutForHitTest();data.rects[id]={r.x,r.y,r.w,r.h} end
    Rect('stick',layer.stick);Rect('menu',layer.toggle)
    for id,widget in pairs(layer.buttons) do Rect(id,widget) end
    for id,widget in pairs(layer.menuButtons) do Rect('option-'..id,widget) end
    data.prefs=layer.prefs
    if layer.settings then for key,entries in pairs(layer.settings.refs) do for i,entry in ipairs(entries) do Rect('pref-'..key..'-'..i,entry.button) end end end
    return data
end
local function FrameStats()
    if #samples<10 then return nil end
    table.sort(samples);local n=#samples
    local data={count=n,p50=samples[math.ceil(n*.5)]*1000,p95=samples[math.ceil(n*.95)]*1000,p99=samples[math.ceil(n*.99)]*1000,max=samples[n]*1000}
    samples={};return data
end
local function AssetReleaseState(app)
    local coordinator=package.loaded['core.CollectionCycle']
    local cycle=coordinator and type(coordinator.State)=='function' and coordinator.State() or false
    local opening=app and app.opening
    local host=opening and opening.host and opening.host.state
    local background=cache:GetNumBackgroundLoadResources()
    local jobs=app and app.openingRetirements
    local loader=app and app.loader
    local pending=app~=nil and app.pendingAssetRelease~=nil
    local guards={running=app~=nil and not app.stopped,noOpeningRetirements=not jobs,
        loaderNotLoading=loader~=nil and loader.state~='loading',backgroundEmpty=background==0}
    local eligible=pending and guards.running and guards.noOpeningRetirements and guards.loaderNotLoading and guards.backgroundEmpty
    return {appPendingAssetRelease=pending,assetReleaseFrames=app and app.assetReleaseFrames,
        assetReleaseIncremental=app~=nil and app.assetReleaseIncremental==true,
        assetReleaseEpoch=app and app.assetReleaseEpoch,stopped=app~=nil and app.stopped==true,
        openingRetirementJobs=jobs and #jobs or 0,openingRetirementQueuePresent=jobs~=nil,
        hostPresent=host~=nil,hostAssetReleasePending=host~=nil and host.assetReleasePending==true,
        loaderState=loader and loader.state,backgroundLoadResources=background,guards=guards,
        eligible=eligible,framesElapsed=app~=nil and type(app.assetReleaseFrames)=='number' and app.assetReleaseFrames<=0,
        collectionCycle=cycle,collectionFencePassed=cycle~=false and app~=nil and type(app.assetReleaseEpoch)=='number'
            and cycle.epoch>app.assetReleaseEpoch}
end
local function ResourceStats(app)
    local data={luaKiB=collectgarbage('count'),resourceBytes=cache:GetTotalMemoryUse(),
        api=graphics.apiName,desktop=require('urhox-libs.Platform.PlatformUtils').IsDesktopPlatform(),
        modelBytes=cache:GetMemoryUse(StringHash('Model')),arrayBytes=cache:GetMemoryUse(StringHash('Texture2DArray')),
        texture2DBytes=cache:GetMemoryUse(StringHash('Texture2D')),imageBytes=cache:GetMemoryUse(StringHash('Image')),
        materialBytes=cache:GetMemoryUse(StringHash('Material')),xmlBytes=cache:GetMemoryUse(StringHash('XMLFile')),
        soundBytes=cache:GetMemoryUse(StringHash('Sound')),jsonBytes=cache:GetMemoryUse(StringHash('JSONFile')),
        retiredTargets=require('render.RenderTargetLifetime').PendingCount(),updateTiming=updateTiming,battleTiming=BattleTimingState(),
        assetRelease=AssetReleaseState(app),audioPreparation=AudioPreparationState(app)}
    local ambience=app and app.ambience
    if ambience then
        local current=ambience.current
        data.ambience={chosen=ambience.chosen,current=current and current.id,
            pending=ambience.pending and ambience.pending.id,slots=#ambience.slots,
            playing=current and current.source.playing or false,amount=current and current.amount or 0,
            disposed=ambience.disposed==true,focus=input.focus,minimized=input.minimized}
    end
    local trial,minimap=observedOwners.trial,observedOwners.minimap
    local capture=observedCapture
    data.lifecycle={
        trial=trial and {disposed=trial.disposed==true,scene=trial.scene~=nil,world=trial.world~=nil,
            effects=trial.effects~=nil,view=trial.view~=nil,hud=trial.hud~=nil} or false,
        minimap=minimap and {disposed=minimap.disposed==true,texture=minimap.texture~=nil,
            base=minimap.base~=nil,vg=minimap.vg~=nil,capture=minimap.capture~=nil} or false,
        capture=capture and {sequence=captureSequence,disposed=capture.disposed==true,
            baked=capture.baked==true,ready=capture.ready==true,bakePending=capture.bakePending==true,
            gate=capture.bakeGate~=nil,scene=capture.scene~=nil,worker=capture.worker~=nil,
            texture=capture.texture~=nil,result=capture.result~=nil,node=capture.node~=nil,
            camera=capture.camera~=nil,image=capture.image~=nil,uploadTexture=capture.uploadTexture~=nil} or false}
    return data
end
local function BattleObjectState(session,sceneRequested)
    local started=Time:GetSystemTime()
    local function Count(map) local n=0;for _ in pairs(map or {}) do n=n+1 end;return n end
    local function Active(list,key)
        local active=0;for _,slot in ipairs(list or {}) do if slot[key] then active=active+1 end end
        return {count=#(list or {}),active=active}
    end
    local data={at=started,frame=GetTime().frameNumber,
        scope='Explicit F8/F14 post-update table counts; only F14 traverses current battle scene. Counts are not native heap bytes.'}
    -- Node bindings document GetChildren(true) and nonrecursive GetNumComponents.
    -- Only F14 traverses once; ordinary F8/F13 never retain or enumerate descendants.
    data.scene={sampled=false,reason='Full scene counts require explicit F14'}
    if sceneRequested then
    local ok,nodes,components=pcall(function()
        local scene=assert(session.scene,'Battle scene absent')
        local children=scene:GetChildren(true);local total=scene:GetNumComponents()
        for _,node in ipairs(children) do total=total+node:GetNumComponents() end
        return #children+1,total
    end)
    data.scene=ok and {sampled=true,supported=true,nodes=nodes,components=components,includesRoot=true}
        or {sampled=true,supported=false,error=tostring(nodes)}
    end
    local world=session.world or {};local player=session.weapons
    local projectiles={player=0,other=0,total=0,systems=0};local seen={}
    local function Weapons(system)
        if not system or seen[system] then return end;seen[system]=true
        local n=#(system.projectiles or {});local key=system==player and 'player' or 'other'
        projectiles[key]=projectiles[key]+n;projectiles.total=projectiles.total+n;projectiles.systems=projectiles.systems+1
    end
    Weapons(player)
    local alive=0;for _,unit in ipairs(world.units or {}) do
        Weapons(unit.weapons);if unit.alive then alive=alive+1 end
    end
    data.world={units=#(world.units or {}),alive=alive,physicsBodies=Count(world.space and world.space.bodies),
        debris=#(world.debris and world.debris.pieces or {}),projectiles=projectiles}
    local fx=session.effects
    if fx then
        local lists={};for _,key in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'}) do lists[key]=#(fx[key] or {}) end
        local chips=fx.chips;local missiles=fx.missiles;local view=missiles and missiles.view
        local batches={};for key,batch in pairs(fx.batches or {}) do
            batches[key]={count=batch.count,limit=batch.limit,enabled=batch.mesh and batch.mesh.enabled or false}
        end
        data.effects={lists=lists,batches=batches,chips=Active(chips and chips.slots,'active'),
            missileView={count=view and view.count or 0,allocated=view and #view.slots or 0,limit=view and view.limit},
            missileBooms=missiles and #missiles.booms or 0,missileLog=missiles and #missiles.log or 0}
        data.effects.chips.limit=chips and chips.limit
    end
    local explosion=session.story and session.story.explosion
    if explosion then
        local pools={};for kind,list in pairs(explosion.pools or {}) do pools[kind]=Active(list,'active') end
        -- Authoritative lifetime flags live on rules, not the rendering slot wrappers.
        for kind,entry in pairs(pools) do local active=Active(explosion.rules and explosion.rules[kind],'on');entry.active=active.active end
        data.storyExplosion={pools=pools,brands=#(explosion.rules and explosion.rules.brands or {}),
            fires=#(explosion.rules and explosion.rules.fires or {}),timers=#(explosion.rules and explosion.rules.timers or {})}
    end
    local audio=session.weaponAudio
    if audio then data.weaponAudio={voices=#audio.slots,loopSources=#audio.loopSources,loopTails=#audio.loopTails} end
    local combatView=session.combatView
    if combatView then data.combatViews={units=Count(combatView.units),pieces=Count(combatView.pieces)} end
    data.elapsedMs=Time:GetSystemTime()-started
    return data
end
local function DumpTrial(app)
    local s=app.trial;local w,h=UI.GetViewportSize()
    observedOwners.trial=s
    local match=s.hud and s.hud.match and s.hud.match.layer
    if match and match.minimap then observedOwners.minimap=match.minimap end
    local p=(not s.combat or s.combat.player.alive) and s.vehicle and s.vehicle.body.translation();local c=s.camera:GetNode().position
    local center=p and s.vehicle.body.center()
    local data={mode='trial',map=s.map.id,width=w,height=h,touch=s.touch,
        loadingFlow=app.loadingFlow:Snapshot(),sceneVisible=renderer:GetViewport(0)~=nil,
        pointer={captured=s.pointer.captured,pending=s.pointer.pending,ready=s.pointer.ready,skip=s.pointer.skip,left=input:GetMouseButtonDown(MOUSEB_LEFT),fire=s.controls.held.fire},
        camera={position={c.x,c.y,c.z},yaw=s.yaw,pitch=s.pitch,dist=s.cameraDistance},samplePhase='post-update',
        vehicle=p and {position={p.x,p.y,p.z},center={center.x,center.y,center.z},speed=s.vehicle.speed,yaw=s.vehicle:Yaw()} or false,
        weapons={energy=s.weapons.energy,shots=s.world.stats.shots,hits=s.world.stats.hits,kills=s.world.stats.kills,blocked=s.weapons.blocked,turning=s.weapons.turning},
        widgets={},performance=ResourceStats(app),frames=FrameStats()}
    if pendingBattleObjects then
        pendingBattleObjects=false;local sceneRequested=pendingSceneObjects;pendingSceneObjects=false
        data.performance.battleObjects=BattleObjectState(s,sceneRequested)
    end
    if app.tutorial then data.tutorial=app.tutorial:Snapshot() end
    data.performance.batches=renderer.numBatches;data.performance.primitives=renderer.numPrimitives
    data.performance.mapTransition=app.mapTransition and app.mapTransition:Snapshot() or nil
    data.camera.feedback={trauma=s.trauma,rumble=s.rumble,stompY=s.stompY,nodY=s.nodY,drillImpact=s.drillImpact}
    data.audioSettings=AudioState(s,app);data.pauseMenu=PauseState(s)
    data.safeReset={active=s.resetChan~=nil,t=s.resetChan and s.resetChan.t or 0,dur=s.resetChan and s.resetChan.dur or 0,
        ready=s.resetReady or 0,history=s.safeReset and #s.safeReset.safeHist or 0,now=Time:GetSystemTime()}
    if s.practice then
        local count=0;for _,unit in ipairs(s.world.units) do if unit==s.practice.player then count=count+1 end end
        data.practice={alive=s.practice.player.alive,life=s.practice.player:Life(),parts=s.practice.player.bp:Size(),playerCount=count}
    end
    data.salvageInventory=SalvageInventory(app)
    data.camera.firstPerson=s.firstPerson==true
    local visible,models=0,0
    for _,model in ipairs(s.view.view.root:GetComponents('StaticModel',true)) do
        models=models+1;if model.enabledEffective then visible=visible+1 end
    end
    data.camera.playerModels={total=models,visible=visible}
    data.performance.postPasses=app.graphicsSettings.post and app.graphicsSettings.post.graph.passCount or 0
    if s.drivingAudio then data.drivingAudio=s.drivingAudio:Snapshot() end
    data.rotors={}
    local drill=s.weapons.drill;local dg=s.weapons:Group();local dw=dg and dg.weapons[1]
    data.drill={kind=dg and dg.kind,phase=drill.active and drill.active.phase,grinding=drill.active and drill.active.grinding,
        charge=drill.held and drill.held.windup or 0,held=drill.held~=nil,cool=dw and dw.cool,hint=drill:Hint(),
        rush=s.drillSpeed.rush,visible=s.drillSpeed.visible,meshEnabled=s.drillSpeed.mesh and s.drillSpeed.mesh.enabled,
        viewports=renderer.numViewports,nativeKinematic=s.vehicle.native and s.vehicle.native.kinematic or false,
        queryCasts=s.world.drillSweep and s.world.drillSweep.casts or 0,querySensors=s.world.drillSweep and #s.world.drillSweep.sensors or 0}
    if not s.combat and s.world.units[1] then data.drill.targetHealth=s.world.units[1]:Health() end
    for _,r in ipairs(s.vehicle.rotors) do data.rotors[#data.rotors+1]={id=r.partId,mode=r.mode,angle=r.angle,target=r.target} end
    if s.feedbackAudio then data.feedbackAudio=s.feedbackAudio:Snapshot() end
    local rt=s.hud.vitals
    data.reticle={hp=rt.hp,structure=rt.structure,fire=rt.fire,clock=rt.clock,hit=rt.hit,repair=rt.repair,
        scope=s.scope,fov=s.camera:GetCamera().fov,selected=s.weapons.current,groups=#s.weapons.groups,
        layout=require('ui.ReticleState').Layout(w,h),legacyMeter=s.hud.meter:IsVisible()}
    data.reticle.assist=s.assist and {point=s.assist.point,ref=s.assist.ref and s.assist.ref.name,slow=s.assist.slow} or false
    local lines=s.aimLines
    data.aimLines=lines and {count=lines.count or 0,logicalHeight=lines.height,
        enabled=lines.mesh.enabled,glows=lines.glow.count or 0,glowEnabled=lines.glow.mesh.enabled,
        dpr=graphics:GetDPR(),physicalHeight=graphics:GetHeight(),draws=aimDraws} or false
    local feedback=s.hud.overlay.feedback
    data.combatFeedback={hits=#feedback.hits,cubes=#feedback.cubes,repairAge=feedback.repairAge,repairFull=feedback.repairFull,
        score=feedback.score and feedback.score.shown or false,scoreTarget=feedback.score and feedback.score.target or false,streak=feedback.streak}
    data.performance.fixedSteps=s.fixedSteps;data.performance.droppedSeconds=s.droppedTime
    data.performance.maxFps=engine.maxFps;data.performance.maxInactiveFps=engine.maxInactiveFps
    data.performance.focus=input.focus;data.performance.minimized=input.minimized
    data.performance.effects={particles=#s.effects.particles,smoke=#s.effects.smoke,beams=#s.effects.beams,flashes=#s.effects.flashes}
    data.destruction=DamageProbe(s)
    local hitFlash=s.combatView and s.combatView.hitFlash
    data.partHitFlash={supported=hitFlash~=nil,total=hitFlashCalls.total,white=hitFlashCalls.white,shield=hitFlashCalls.shield,
        lastPart=hitFlashCalls.lastPart,lastColor=hitFlashCalls.lastColor,actors=0,active=0,pooled=0}
    if hitFlash then for _,target in pairs(hitFlash.targets) do
        local flash=target.flash
        data.partHitFlash.actors=data.partHitFlash.actors+1
        data.partHitFlash.active=data.partHitFlash.active+#flash.items
        data.partHitFlash.pooled=data.partHitFlash.pooled+#flash.pool
    end end
    data.aimTargets={}
    for _,unit in ipairs(s.world.units) do if unit~=(s.combat and s.combat.player) and unit.alive then
        local pos=unit:Position();local point=require('core.Coord').Vec(pos[1],pos[2]+1,pos[3])
        local camera=s.camera:GetCamera();local uv=camera:WorldToScreenPoint(point)
        data.aimTargets[#data.aimTargets+1]={name=unit.name,team=unit.team,pos=pos,
            x=uv.x,y=uv.y,behind=camera.node:WorldToLocal(point).z<0,parts=unit.bp:Size()}
    end end
    local mouse=input.mousePosition;local hit=UI.FindWidgetAt(mouse.x/UI.GetScale(),mouse.y/UI.GetScale())
    local lock=s.weapons:LockInfo()
    local models=0;for _,vis in pairs(s.view.view.visuals) do if vis.weaponMotion and vis.weaponMotion.kind=='missile' then models=models+#vis.models end end
    data.missile={group=s.weapons:Group() and s.weapons:Group().kind,lock=lock and lock.progress,phase=lock and lock.phase,target=lock and lock.ref and lock.ref.pos,
        projectiles=#s.weapons.projectiles,visible=s.effects.missiles.view and s.effects.missiles.view.count or 0,models=models,energy=s.weapons.energy}
    if s.weaponAudio then data.weaponAudio={counts=s.weaponAudio.counts,voices=#s.weaponAudio.slots,active=s.weaponAudio.active,loops={}}
        for id,loop in pairs(s.weaponAudio.loops) do data.weaponAudio.loops[id]={playing=loop.source.playing,gain=loop.source.gain,frequency=loop.source.frequency} end
    end
    if s.hud.touchControls then
        data.touchControls=TouchState(s.hud.touchControls)
        data.touchRects={}
        local r=s.hud.touchControls.stick:GetAbsoluteLayoutForHitTest();data.touchRects.stick={r.x,r.y,r.w,r.h}
        for id,button in pairs(s.hud.touchControls.buttons) do local r=button:GetAbsoluteLayoutForHitTest();data.touchRects[id]={r.x,r.y,r.w,r.h} end
    end
    data.mouse={x=mouse.x,y=mouse.y,scale=UI.GetScale(),hit=hit and hit.props.text or 'other',overlay=UI.GetTopOverlay()~=nil}
    local function Walk(widget)
        if not widget:IsVisible() then return end
        if widget.props.onClick then local r=widget:GetAbsoluteLayoutForHitTest()
            data.widgets[#data.widgets+1]={text=widget.props.text or '',kind=widget.props.kind,rect={r.x,r.y,r.w,r.h}} end
        for _,child in ipairs(widget.children or {}) do Walk(child) end
    end
    local root=UI.GetRoot();if root then Walk(root) end
    local overlay=UI.GetTopOverlay();if overlay then
        Walk(overlay)
        if overlay.contentContainer_ then Walk(overlay.contentContainer_) end
        if overlay.footerWidget_ then Walk(overlay.footerWidget_) end
    end
    if s.battle then
        data.battle=s.battle:Snapshot()
        local voice=s.battle.voice
        if voice and voice.radio then
            local radio=voice.radio
            local function Jobs(list)
                local out={}
                for _,job in ipairs(list or {}) do
                    out[#out+1]={path=job.path,at=job.at,untilAt=job.untilAt,
                        playing=job.source and job.source.playing or false,
                        gain=job.source and job.source.gain or 0,
                        frequency=job.source and job.source.frequency or 0}
                end
                return out
            end
            local function Paths(map)
                local out={};for path in pairs(map or {}) do out[#out+1]=path end
                table.sort(out);return out
            end
            local pending=radio.pending
            data.battle.radio={voiceTime=voice.time,ready=voice.ready,card=voice.card,
                speaking=require('audio.AudioLevels').Speaking(),speakingUntil=voice.speakingUntil,
                busyUntil=voice.busyUntil,pending=pending and {id=pending.id,
                    downloaded=pending.downloaded,failed=pending.failed} or false,
                jobs=Jobs(radio.jobs),fading=Jobs(radio.fading),loading=Paths(radio.loading),
                touched=Paths(radio.touched),disposed=radio.disposed}
        end
        data.battle.boardOn=s.battle.boardOn==true
        data.battle.spectate=s.battle.spectate or 0
        local watched=require('combat.MatchActions').Watched(s.battle)
        data.battle.watched=watched and watched.name or nil
        data.battle.time=s.world.time
        data.battle.leaveConfirm=s.dialog and s.dialog.matchLeave==true or false
        data.battle.profile=s.app.store:Read('match-profile',require('combat.Matchmaker').Valid)
        local match=s.hud.match and s.hud.match.layer
        local mm=match and match.minimap
        local k=require('ui.MatchBanner').Scale(w,h,s.touch)
        data.matchHud={scale=k,touch=s.touch==true,sourceCompassOffset=100*k,
            minimap=mm and {frames=mm.frames,base=mm.base~=nil,style=mm.style,
                rect={14*k,52*k,236*k,236*k},disposed=mm.disposed==true} or false}
        local feedback=require('ui.MatchFeedback')
        local count,scale,alpha=feedback.CountState(s.battle)
        data.matchHud.feedback={prepCount=s.battle.prepCount or 0,prepCountAt=s.battle.prepCountAt,
            count=count,scale=scale,opacity=alpha,hurtAt=s.battle.hurtAt,hurtFrames=s.battle.hurtFrames or 0,
            hurtFadeAt=s.battle.hurtFadeAt,hurtAlpha=feedback.HurtAlpha(s.battle),alpha=feedback.HurtAlpha(s.battle),
            frame=GetTime().frameNumber,
            repairDisabled=feedback.RepairDisabled(s.battle),intro=s.intro~=nil and not s.intro.done}
    end
    if s.endless then
        local e=s.endless;data.endless=e:Snapshot()
        data.endless.banner=e.banner and {text=e.banner.text,untilAt=e.banner.untilAt} or false
        data.endless.wallNow=Time:GetSystemTime();data.endless.worldTime=e.world.time;data.endless.runTime=e.run.time
        data.endless.alive=e.player.alive
        local root=s.view.view.root;local p=root.position;local wp=root.worldPosition
        local presentation=e.spawnPresentation;local base=presentation and presentation.basePosition
        local bounds=e.player.spec.bounds
        data.endless.spawn={riseUntil=presentation and presentation.riseUntil or 0,invulnerableUntil=e.invulnerableUntil,
            height=bounds.max[2]-bounds.min[2],rootPosition={p.x,p.y,p.z},rootWorldPosition={wp.x,wp.y,wp.z},
            basePosition=base and {base.x,base.y,base.z} or false,rootEnabled=root.enabled,rootEnabledEffective=root.enabledEffective,
            firstPerson=s.firstPerson==true,frame=GetTime().frameNumber}
        local flash=s.restoreFlash
        if flash then local fp=flash.root.worldPosition
            data.endless.spawn.restoreFlash={count=#flash.items,enabled=flash.root.enabled,worldPosition={fp.x,fp.y,fp.z}}
        end
    end
    if s.salvage then
        data.salvageRun=s.salvage:Snapshot();data.salvageRun.cine.skipRect=s.hud.cinema.skipRect
        local ex=s.salvage.rules.ex
        data.salvageRun.extraction=ex and {id=ex.e.id,left=ex.left} or nil
        data.salvageRun.cine.pauseVisible=s.hud.pause:IsVisible();data.salvageRun.cine.reticleVisible=s.hud.vitals:IsVisible()
        data.salvageRun.cine.nativeKinematic=s.salvage.player.alive and s.vehicle.native.kinematic or false
    end
    if s.story then
        data.story=s.story:Snapshot()
        local objective=s.story.objective;local choice=s.story.choiceView
        local full=pendingPresentationHistory;pendingPresentationHistory=false
        local history=presentationStory==s.story and PresentationHistory(presentationFrames,presentationHead,presentationCount,full) or {}
        data.story.presentation={wallNow=Time:GetSystemTime(),objective=objective and objective.sample or false,
            objectiveEnterAt=objective and objective.enterAt,choice=choice and choice.sample or false,
            choiceHideAt=choice and choice.pending[1],frameFields=presentationFields,frames=history,
            historyMode=full and 'full' or 'last',historyCount=#history,historyAvailable=presentationCount,historyLimit=180}
        data.story.collectorModels=#s.story.view.collectors
        data.story.beaconModelsVisible=0
        for _,node in ipairs(s.story.view.beacon.nodes) do
            local model=node:GetComponent('StaticModel')
            if model and model.enabledEffective then data.story.beaconModelsVisible=data.story.beaconModelsVisible+1 end
        end
        data.story.storyGlowCount=s.story.view.glow.count
        data.story.voicePlayed=#s.story.voice.log
        data.story.voicePlaying=s.story.voice.source.playing
        data.story.saved=s.story.saved
        data.story.target=s.story.rules:Target()
        local marker=require('story.MarkerRules').Select(s.story)
        if marker then data.story.marker={target=marker.target,label=marker.label,kind=marker.kind,lift=marker.lift,enemy=marker.enemy,close=marker.close} end
        if s.story.boss then
            local boss=s.story.boss;local feet=boss.unit.vehicle and boss.unit.vehicle.mechControl
            data.story.boss.parts=boss.unit.bp:Size();data.story.boss.feet=feet and #feet.list or 0
            data.story.boss.planes=boss.raid and #boss.view.planes or 0
            data.story.boss.cockpit=boss:Cockpit();data.story.boss.braced=boss.rules:Braced()
        end
        if s.story.qaEpilogue then local ep=s.story.qaEpilogue;data.story.epilogue={active=ep.active,panels=#ep.panels,kind=ep.rules.current.kind,time=ep.rules.time} end
        data.story.naturalEpilogue=s.story.epilogue and s.story.epilogue.active or false
        if s.story.epilogue then local ep=s.story.epilogue;data.story.naturalEpilogueDetail={active=ep.active,index=ep.rules.index,total=#ep.rules.steps,
            panels=#ep.panels,kind=ep.rules.current and ep.rules.current.kind,time=ep.rules.time,voicePlayed=#ep.voice.log,voicePlaying=ep.voice.source.playing,
            voiceDone=#ep.voice.queue==0 and (not ep.voice.card or ep.voice.card.age>ep.voice.card.length),
            voice=ep.voice.card and {text=ep.voice.card.text,age=ep.voice.card.age,typing=ep.voice.card.typing,speakEnd=ep.voice.card.speakEnd}} end
    end
    data.boundary=s.boundary and {walls=#s.boundary.spec.walls,ceiling=s.boundary.spec.ceiling~=nil,enabled=s.boundary.root.enabled} or false
    data.wing={count=#s.view.wings,telemetry=s.vehicle.telemetry,state=s.vehicle.wingState and s.vehicle.wingState.phase}
    data.intro=s.intro and {active=not s.intro.done,shot=s.intro.index,time=s.intro.time,full=s.intro.full,skipRect=s.intro.page and s.intro.page.skipRect} or false
    if G0_StoryRouteState and data.story then data=G0_StoryRouteState(data) end
    print('OUTGAME_STATE '..cjson.encode(data))
end
local function Dump(app)
    local w,h=UI.GetViewportSize()
    local home=require('ui.GarageHud').GetState()
    local data={width=w,height=h,physical={graphics:GetWidth(),graphics:GetHeight()},dpr=graphics:GetDPR(),
        touch=require('controls.TouchMode').Enabled(),tab=home and home.tab or '',build=app.build~=nil,
        inventory=app.build and app.build.inventoryPanel~=nil or false,dialog=(app.build and app.build.dialog~=nil or home and home.dialog~=nil) or false,blueprint=app.blueprint.name,parts=app.blueprint:Size(),
        widgets={},quality=require('render.Quality').current.name}
    data.device={platform=GetPlatform(),native=GetNativePlatform and GetNativePlatform() or nil,
        emulation=input.touchEmulation,compact=require('controls.TouchMode').Compact()}
    data.matchProfile=app.store:Read('match-profile',require('combat.Matchmaker').Valid)
    if app.tutorial then data.tutorial=app.tutorial:Snapshot() end
    data.storage=require('storage.CloudStorage').Snapshot()
    data.audioSettings=AudioState(app.build or home,app);data.pauseMenu=PauseState(app.build or home)
    data.salvageInventory=SalvageInventory(app)
    data.performance=ResourceStats(app);data.performance.batches=renderer.numBatches;data.performance.primitives=renderer.numPrimitives
    data.performance.mapTransition=app.mapTransition and app.mapTransition:Snapshot() or nil
    if not app.scene or not app.camera or not app.hangar then
        data.mode='loading';data.sceneVisible=false
        data.loadingFlow=app.loadingFlow:Snapshot()
        data.loadingFlow.backRect=app.loadingFlow.page.backRect
        data.loading={state=app.loader.state,phase=app.loader.phase,progress=app.loader.progress,
            pending=app.pendingMap and app.pendingMap.id,downloads=app.loader.gate.total,completed=app.loader.gate.completed,
            prepareFrames=app.loader.prepareFrames,prepareStage=app.loader.prepareStage,
            maxPrepareMs=app.loader.maxPrepareMs,prepareStageMax=app.loader.prepareStageMax,phaseTimes=app.loader.phaseTimes}
        print('OUTGAME_STATE '..cjson.encode(data))
        return
    end
    local c=app.camera;local p=c.node.position;local t=c.cur.target
    data.camera={position={p.x,p.y,p.z},target={t.x,t.y,t.z},yaw=c.cur.yaw,pitch=c.cur.pitch,dist=c.cur.dist,fov=c.camera.fov}
    data.camera.desiredDist=c.dist
    local f=c.node.rotation*Vector3.FORWARD;data.camera.forward={f.x,f.y,f.z}
    if app.build then
        local b=app.build
        data.touchControls=TouchState(b.hud.touchControls)
        local backdrop=b.inventoryPanel and b.inventoryPanel.backdrop
        if backdrop and backdrop.graph then
            data.backdrop={passes=backdrop.graph.passCount,width=backdrop.graph.width,height=backdrop.graph.height,
                bytes=backdrop.graph.colorBytes,logical={backdrop.lw,backdrop.lh},active=renderer:GetViewport(0)==backdrop.graph.output}
        end
        data.buildInput={mode=b.buildCamera.mode,captured=b.buildCamera.captured,slot=b.inventory.active,
            tool=b.editor.tool,channel=b.editor.paintChannel,color=b.editor.color,autoColor=b.editor.autoColor}
        data.buildTargets={}
        for _,part in ipairs(b.editor.bp:List()) do if #data.buildTargets<32 then
            local cell=part._cells[1];local unit=require('Config').CELL
            local point=c.camera:WorldToScreenPoint(Vector3(-cell[1]*unit,(cell[2]+.5)*unit,cell[3]*unit))
            data.buildTargets[#data.buildTargets+1]={id=part.id,type=part.type,x=point.x,y=point.y}
        end end
        local preview=b.editor.preview
        data.buildInput.preview=preview and preview.type and {type=preview.type,pos=preview.pos,rot=preview.rot,ok=preview.res.ok,reason=preview.res.reason} or false
        local stretch=b.editor.stretch
        data.buildStretch=stretch and {phase=stretch.phase,h=stretch.h,anchor=stretch.anchor,cur=stretch.cur,lo=stretch.lo,hi=stretch.hi,
            bad=stretch.bad,items=stretch.items and #stretch.items or #stretch.cells,mirror=stretch.mirrorCells and #stretch.mirrorCells or 0,
            version=stretch.planVersion,ghostModels=#b.ghost.pool} or false
        local ids={};for id in pairs(b.editor.selection) do ids[#ids+1]=id end;table.sort(ids)
        local drag=b.controls.dragSelection
        data.buildSelection={active=b.selecting==true,ids=ids,revision=b.editor.history.revision,
            hit=b.editor.hit and {id=b.editor.hit.partId,cell=b.editor.hit.cell} or false,
            drag=drag and {anchor=drag.anchor,lo=drag.lo,hi=drag.hi,pending=#drag.parts} or false,
            hover=b.hud.hover and b.hud.hover.info or false}
        data.buildSelection.pasting=b.editor.pasting==true
        data.buildSelection.clipboard=b.editor.clipboard and #b.editor.clipboard or 0
        local selectionBar=b.hud.selectionBar
        if selectionBar then
            local rect=selectionBar.root:GetAbsoluteLayoutForHitTest()
            data.buildSelection.bar={shown=selectionBar.shown,count=selectionBar.count,brush=selectionBar.brush,
                rect={rect.x,rect.y,rect.w,rect.h},layout=selectionBar.layout}
        end
        local joined=b.car.joined
        local groups={};for _,p in ipairs(b.editor.bp:List()) do if p.g>0 then groups[#groups+1]={id=p.id,g=p.g,type=p.type} end end
        data.buildGroups={joinNew=b.editor.joinNew,parts=groups,vertices=joined.vertices or 0,rebuilds=joined.rebuilds,xray=app.buildXray==true}
        local rotor=b.hud.rotor
        data.rotorHud={mode=rotor.mode,visible=rotor.info~=nil,bounds=rotor.bounds,load=rotor.info and rotor.info.count}
        if b.selecting then
            local parts={}
            for _,part in ipairs(b.editor.bp:List()) do parts[#parts+1]={id=part.id,type=part.type,pos=part.pos,rot=part.rot,_cells=part._cells,g=part.g,color=part.color,shellColor=part.shellColor} end
            data.buildSelection.parts=parts;data.buildSelection.mirror=b.editor.mirror
        end
        local badge=b.hud.modeBadge
        if badge then
            local vg=UI.GetNVGContext();require('ui.SourceDraw').Begin(vg);badge:Layout(vg)
            data.buildBadge={mode=badge.renderMode or '',active=badge.mode~=false,opacity=badge.fadeTween.value,
                offset=badge.offsetTween.value,popTime=badge.popTime,width=badge.badgeWidth or 0,color=badge.color,
                items=badge.parts,rect={(w-(badge.badgeWidth or 0))/2,72+badge.offsetTween.value,badge.badgeWidth or 0,38}}
        end
    end
    data.hangar={grid=app.hangar.grid,frame=app.hangar.frame,gridTarget=app.hangar.gridTarget,frameTarget=app.hangar.frameTarget,scan=app.hangar.scan.enabled,time=rawget(_G,'VOX_DEBUG') and VOX_DEBUG.time or app.hangar.time}
    data.hangar.lights={};data.hangar.shadows=renderer.drawShadows
    data.hangar.panelIsolation=app.hangar.qaPanelsOff or false
    data.hangar.materialUpdates={total=#app.hangar.materials,animated=#app.hangar.animatedMaterials}
    for _,light in ipairs(app.scene:GetComponents('Light',true)) do
        data.hangar.lights[#data.hangar.lights+1]={name=light.node.name,type=light.lightType,brightness=light.brightness,shadow=light.castShadows}
    end
    data.anchors={}
    for _,point in ipairs({{0,0,0},{0,3,0},{6,0,0},{-6,0,0},{0,0,6},{0,0,-6}}) do
        local q=c.camera:WorldToScreenPoint(Vector3(-point[1],point[2],point[3]))
        data.anchors[#data.anchors+1]={q.x,q.y}
    end
    if home then
        data.homeRects={}
        local widgets={nav=home.nav,info=home.info,loadout=home.loadout,cta=home.cta,edit=home.buttons.edit,battle=home.buttons.battle,trial=home.buttons.trial,mode=home.modeStrip,strip=home.bayScroll,card=home.cards[1],new=home.buttons.new,save=home.buttons.save,music=home.musicConsole}
        if home.newOpen then
            widgets.menu=home.menu;widgets.menuHeader=home.menu.children[1];widgets.menuEmpty=home.menu.children[2];widgets.menuImport=home.menu.children[3];widgets.menuWorkshop=home.menu.children[4]
            data.menuVisuals={}
            local vg=UI.GetNVGContext();require('ui.SourceDraw').Begin(vg)
            for i,key in ipairs({'empty','import','workshop'}) do
                local item=home.menu.children[i+1]
                data.menuVisuals[key]={layout=item:GetSourceLayout(vg),hovered=item.state.hovered or false,
                    hover=item.hoverMotion and item.hoverMotion.value or 0,bar=item.barMotion and item.barMotion.value or 0,arrow=item.arrowMotion and item.arrowMotion.value or 0}
            end
        end
        for name,widget in pairs(widgets) do
            if widget:IsVisible() then local r=widget:GetAbsoluteLayoutForHitTest();data.homeRects[name]={r.x,r.y,r.w,r.h} end
        end
    end
    if home and home.workshop then
        local ws=home.workshop;data.workshop={}
        data.workshop.tabMotions=ws.tabMotions
        for _,key in ipairs({'selected','pending','view','group','sort','elapsed','hold','from','slides','imagesReady'}) do
            data.workshop[key]=ws[key]
        end
        if ws.caption then
            data.workshop.caption={elapsed=ws.caption.elapsed,distance=ws.caption.distance,groups={}}
            for i=1,6 do
                local alpha,offset=require('ui.WorkshopCarousel').Caption(ws,i)
                data.workshop.caption.groups[i]={opacity=alpha,translateX=offset}
            end
        end
        if ws.shelf then
            data.workshop.shelf={elapsed=ws.shelf.elapsed,groups={}}
            for i=1,9 do
                local alpha,offset=require('ui.WorkshopCarousel').Shelf(ws,i)
                data.workshop.shelf.groups[i]={opacity=alpha,translateY=offset}
            end
        end
        if ws.entrance then
            data.workshop.entrance={kind=ws.entrance.kind,elapsed=ws.entrance.elapsed,groups={},fill=require('ui.WorkshopEntrance').Fill(ws)}
            local count=ws.view=='detail' and 7 or 21
            for i=1,count do
                local alpha,dx,dy=require('ui.WorkshopEntrance').Group(ws,i)
                data.workshop.entrance.groups[i]={opacity=alpha,translateX=dx,translateY=dy}
            end
        end
    end
    if home and home.musicBox then
        local mb=home.musicBox;local p=mb.player
        data.music={filter=mb.filter,query=mb.query,count=#mb.tracks,mode=p.playMode,paused=p.userPaused,volume=p.volume,status=p:Status(),pending=p.pending,
            track=p:Track() and p:Track().id,position=p:Position(),duration=p:Duration(),favorites=p.favorites,errors=p.errors,layout=mb.layout,
            menu=mb.modeMenu:IsVisible(),rects={}}
        for name,widget in pairs({search=mb.search,seek=mb.seek,volume=mb.volume,frame=mb.frame,list=mb.list}) do
            local r=widget:GetAbsoluteLayoutForHitTest();data.music.rects[name]={r.x,r.y,r.w,r.h}
        end
    end
    if home and home.livery then
        local lv=home.livery;local session=lv.session;local layer=app.car.livery
        data.livery={group=lv.group,selected=session.sel,pick=session.pick,list=session:List(),count=#session:List(),hi=session.hi,history=#session.history,
            propHeight=lv.propHeight,meshes=0,vertices=0,rects={},surfaces={},gizmo=lv.controls:Gizmo()}
        for _,mesh in pairs(layer.meshes) do data.livery.meshes=data.livery.meshes+1;data.livery.vertices=data.livery.vertices+#mesh.vertices end
        for name,widget in pairs({lib=lv.lib,props=lv.props,grid=lv.grid,layers=lv.layers,size=lv.sliders.size,rotation=lv.sliders.rotation}) do
            local r=widget:GetAbsoluteLayoutForHitTest();data.livery.rects[name]={r.x,r.y,r.w,r.h}
        end
        for _,visual in pairs(app.car.visuals) do if require('render.LiveryModel').Fixed(visual.part) then
            local p=visual.part;local screen=lv.controls:Screen({p.pos[1],p.pos[2]+1,p.pos[3]})
            if screen and screen.x>340 and screen.x<w-340 and screen.y>80 and screen.y<h-130 then
                local hit=lv.controls:Surface(screen.x,screen.y)
                if hit then data.livery.surfaces[#data.livery.surfaces+1]={screen.x,screen.y,hit};if #data.livery.surfaces>=8 then break end end
            end
        end end
    end
    data.modeChoice=home and home.modeChoice;data.storyLevel=home and home.storyLevel
    local help=home and home.dialog and home.dialog.helpContent
    if help then
        local modal=home.dialog;local _,offset=modal.scroll:GetScroll()
        local scroll=modal.scroll
        data.help={scrollY=offset,bodyHeight=help.bodyHeight,card=modal.modalLayout_,naturalHeight=scroll.props.sourceNaturalHeight,
            wheelTrace=wheelTrace,scrollLayout=scroll:GetAbsoluteLayoutForHitTest(),scrollState=scroll.state,scrollYEnabled=scroll.props.scrollY}
    end
    data.salvage=home and home.salvage;data.lobby=app.lobby or 'arena';data.mapPreview=app.mapPreview~=nil
    data.previewMap=app.mapPreview and app.mapPreview.map.id;data.sceneVisible=renderer:GetViewport(0)~=nil
    data.loading={state=app.loader.state,phase=app.loader.phase,progress=app.loader.progress,
        pending=app.pendingMap and app.pendingMap.id,downloads=app.loader.gate.total,completed=app.loader.gate.completed,
        prepareFrames=app.loader.prepareFrames,prepareStage=app.loader.prepareStage,
        maxPrepareMs=app.loader.maxPrepareMs,prepareStageMax=app.loader.prepareStageMax,phaseTimes=app.loader.phaseTimes}
    if observedCapture then
        local capture=observedCapture
        data.loading.mapCapture={disposed=capture.disposed==true,views=capture.views,
            captured=capture.captured==true,ready=capture.ready==true,progress=capture.progress,
            captureFrame=capture.captureFrame,currentFrame=GetTime().frameNumber,
            worker=capture.worker and coroutine.status(capture.worker)}
    end
    data.mode='hangar';data.loadingFlow=app.loadingFlow:Snapshot()
    data.loadingFlow.backRect=app.loadingFlow.page.backRect
    data.craterModelResident=cache:GetExistingResource('Model','Crater/mesh-0.bin')~=nil
    data.vehicleLoading={busy=app.vehicleSwitch and app.vehicleSwitch:IsBusy() or false,
        ready=app.vehicleSwitch and app.vehicleSwitch.pending and app.vehicleSwitch.pending.ready or false,
        state=app.vehicleSwitch and app.vehicleSwitch.gate.state or '',draft=app.vehicleGate.state,
        assembling=app.vehicleSwitch and app.vehicleSwitch:IsAssembling() or false,
        assemblyFrames=app.vehicleSwitch and app.vehicleSwitch.assemblyFrames or 0,
        maxAssemblyMs=app.vehicleSwitch and app.vehicleSwitch.maxAssemblyMs or 0,
        progress=app.vehicleSwitch and app.vehicleSwitch.pending and app.vehicleSwitch.pending.progress,
        lift=app.vehicleSwitch and app.vehicleSwitch.lift.anim}
    data.garage={used=home and home.usedCount or 0,active=app.bays.active}
    data.garage.cards={}
    for i,card in ipairs(home and home.cards or {}) do
        local r=card:GetAbsoluteLayoutForHitTest()
        data.garage.cards[i]={r.x,r.y,r.w,r.h}
    end
    data.garage.slots={}
    for i,slot in ipairs(app.bays:Slots()) do data.garage.slots[i]=slot and {name=slot.name,parts=#slot.parts} or false end
    data.carVisuals=0
    for _ in pairs(app.car.visuals) do data.carVisuals=data.carVisuals+1 end
    if app.build then
        local ghost=app.build.ghost
        data.ghost={ready=ghost.ready,state=ghost.gate.state,type=app.editor.type,warmKey=ghost.warmKey,pool=#ghost.pool}
    end
    if app.warehouse then data.warehouse={ready=app.warehouse.ready,cursor=app.warehouse.cursor,hallVisible=app.hangar.root.enabled,
        motion=app.warehouse.ready and app.warehouse.motion:Snapshot() or nil,
        effects=app.warehouse.effects and {time=app.warehouse.effects.time,uploads=app.warehouse.effects.uploads,particles=#app.warehouse.effectData.dust.positions}} end
    if app.warehouse and app.warehouse.ready then
        data.warehouse.cameraSafety=app.camera.safety and app.camera.safety.root==app.warehouse.root or false
        data.warehouse.surfaces={}
        for _,y in ipairs({.02,.05,.1,.15,.2}) do
            local hits=app.scene:GetComponent('Octree'):Raycast(app.camera.camera:GetScreenRay(.5,y),RAY_TRIANGLE,100,DRAWABLE_GEOMETRY)
            local hit=hits[1];local drawable=hit and hit.drawable
            data.warehouse.surfaces[#data.warehouse.surfaces+1]={y=y,node=drawable and drawable.node.name or '',
                parent=drawable and drawable.node.parent.name or '',model=drawable and drawable.model and drawable.model.name or '',distance=hit and hit.distance or -1}
        end
    end
    local scale=app.graphicsSettings.sceneScale
    if scale then data.render={scale.graph.width,scale.graph.height} end
    local preview=home and home.workshopPreview
    if home and home.storyHolo then data.story={ready=home.storyHolo.ready,cursor=home.storyHolo.cursor,gate=home.storyHolo.gate.state,completed=home.storyHolo.gate.completed,total=home.storyHolo.gate.total,level=home.storyHolo.level,az=home.storyHolo.view.az,el=home.storyHolo.view.el,zoom=home.storyHolo.view.zoom} end
    if preview then data.preview={ready=preview.ready,cursor=preview.cursor,total=#preview.parts,complete=preview.ready and preview.cursor>#preview.parts} end
    local mouse=input.mousePosition;local hit=UI.FindWidgetAt(mouse.x/UI.GetScale(),mouse.y/UI.GetScale())
    data.mouse={x=mouse.x,y=mouse.y,scale=UI.GetScale(),hit=hit and hit.props.text or 'other',overlay=UI.GetTopOverlay()~=nil}
    local function Walk(widget,shown)
        shown=shown and widget:IsVisible()
        if not shown then return end
        local p=widget.props
        if widget._className=='VoxSalvageQuantityRow' then
            local function QuantityBounds(control)
                local r=control:GetAbsoluteLayoutForHitTest()
                return {r.x,r.y,r.w,r.h}
            end
            local hold=widget.hold
            data.salvageQuantity={rect=QuantityBounds(widget),fieldRect=QuantityBounds(widget.field),
                minusRect=QuantityBounds(widget.children[1]),plusRect=QuantityBounds(widget.children[3]),
                maxRect=QuantityBounds(widget.children[4]),value=widget.field:GetValue(),
                focused=UI.GetFocus()==widget.field,qty=widget.owner.salvage.qty,
                maximum=widget.maximum(),disposed=widget.disposed==true,
                hold=hold and {pointerId=hold.pointerId,direction=hold.direction,ticks=hold.ticks} or false}
        end
        if p.onClick then
            local r=widget:GetAbsoluteLayoutForHitTest()
            if r.w>0 and r.h>0 then
                local motion=widget.cardMotion
                local inv=widget.inventoryMotion;local feedback=widget.inventoryFeedback
                data.widgets[#data.widgets+1]={text=p.text or '',icon=p.icon or '',part=p.partType,kind=p.sourceKind or p.kind,action=p.action,hex=p.hex,auto=p.auto,styleWidth=p.width,styleHeight=p.height,selected=p.selected,disabled=p.disabled,rect={r.x,r.y,r.w,r.h},
                    shop=type(p.shop)=='table' and {cost=p.shop.cost,wallet=p.shop.wallet,poor=p.shop.poor} or nil,
                    prefab=type(widget.item)=='table' and widget.item.id or nil,
                    entrance={opacity=p.opacity or 1,translateX=p.translateX or 0,translateY=p.translateY or 0},
                    card=motion and {hovered=widget.state.hovered or false,lift=motion.lift.value,image=motion.image.value,reveal=motion.reveal.value,opacity=motion.opacity.value},
                    heroTitleSize=widget.heroTitleSize,
                    sourceMotion=widget.sourceMotion,hovered=widget.state.hovered,pressed=widget.state.pressed,
                    inventoryMotion=inv and {entry=inv.entry,image={value=inv.image.value},budget={value=inv.budget.value},hover={value=inv.hover.value}},
                    inventoryFeedback=feedback and {y=feedback.y.value,hover=feedback.hover.value,active=feedback.active and feedback.active.value},dropTarget=p.dropTarget,
                    focused=UI.GetFocus()==widget,
                    tabContent=widget.GetTabContent and widget:GetTabContent(UI.GetNVGContext()),
                    shelfContent=widget.GetShelfContent and widget:GetShelfContent(UI.GetNVGContext())}
            end
        end
        for _,child in ipairs(widget.children or {}) do Walk(child,shown) end
    end
    local root=UI.GetRoot();if root then Walk(root,true) end
    local modal=app.build and app.build.dialog or home and home.dialog
    if modal then
        Walk(modal,true)
        if modal.contentContainer_ then Walk(modal.contentContainer_,true) end
        if modal.footerWidget_ then Walk(modal.footerWidget_,true) end
        if modal.salvageBody then
            data.purchase={rows={}}
            local function PurchaseRows(widget)
                local p=widget.props or {}
                if p.text~=nil or p.value~=nil then
                    data.purchase.rows[#data.purchase.rows+1]={text=p.text,value=p.value}
                end
                for _,child in ipairs(widget.children or {}) do PurchaseRows(child) end
            end
            PurchaseRows(modal.salvageBody)
        end
    end
    local inventory=app.build and app.build.inventoryPanel
    if inventory then
        local focus=UI.GetFocus()
        local fp=focus and focus.props or {}
        data.inventoryState={current=inventory.model:Current(),active=inventory.model.active,hotbar=inventory.model.hotbar,
            drag=inventory.dragType,dragPoint=inventory.dragPoint,
            shown=inventory.shown,query=inventory.model.query,scroll=inventory.list.scrollOffset_,pool=inventory.list:GetPoolStats(),
            last=inventory.results[#inventory.results] and inventory.results[#inventory.results].id,
            focus=focus and {part=fp.partType,kind=fp.kind,slot=fp.inventoryStyle and fp.index,
                search=focus==inventory.search,close=focus==inventory.closeButton} or false}
        local function Bounds(widget)
            local r=widget:GetAbsoluteLayoutForHitTest()
            return {r.x,r.y,r.w,r.h}
        end
        local detail=inventory.detail
        data.inventoryState.searchRect=Bounds(inventory.search)
        data.inventoryState.detail={rows=detail.rows,expanded=detail.expanded or false,
            rect=Bounds(detail),scrollRect=Bounds(inventory.detailScroll),height=detail.props.height,
            fontSize=detail.props.compact and 22 or math.min(32,math.max(24,detail.props.viewportWidth*.022)),
            rowLines=detail.rowLines,description=detail.description,moreRect=detail.more and Bounds(detail.more)}
        Walk(inventory.body,true)
        local close=inventory.closeButton
        local r=close:GetAbsoluteLayoutForHitTest()
        if r.w>0 and r.h>0 then data.widgets[#data.widgets+1]={text='关闭',rect={r.x,r.y,r.w,r.h}} end
    end
    data.frames=FrameStats()
    if VOX_QA_HOME_ROUTE then
        print('OUTGAME_STATE '..cjson.encode(VOX_QA_HOME_ROUTE.Project(data)))
        return
    end
    local shopWidgets={}
    for _,widget in ipairs(data.widgets) do
        shopWidgets[#shopWidgets+1]={text=widget.text,kind=widget.kind,rect=widget.rect,disabled=widget.disabled,
            shop=widget.shop,prefab=widget.prefab}
    end
    local shopState={width=data.width,height=data.height,tab=data.tab,sceneVisible=data.sceneVisible,
        loadingFlow={active=data.loadingFlow and data.loadingFlow.active,failed=data.loadingFlow and data.loadingFlow.failed,
            error=data.loadingFlow and data.loadingFlow.error},
        vehicleLoading={busy=data.vehicleLoading and data.vehicleLoading.busy},
        garage={used=data.garage and data.garage.used},salvage={tab=data.salvage and data.salvage.tab},
        salvageInventory=data.salvageInventory and {credits=data.salvageInventory.credits,items=data.salvageInventory.items},
        workshop=data.workshop and {view=data.workshop.view,selected=data.workshop.selected},preview=data.preview,dialog=data.dialog,
        purchase=data.purchase,widgets=shopWidgets}
    print('OUTGAME_SHOP_STATE '..cjson.encode(shopState))
    if VOX_QA_MISSILES then data.widgets=nil;data.homeRects=nil;data.hangar=nil;data.anchors=nil end
    print('OUTGAME_STATE '..cjson.encode(data))
end
Dump=TimedCall('probe.Dump',Dump)
function HandleUpdate(et,ed)
    local timingApp=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app or lastObservedApp
    if input:GetKeyPress(KEY_F15) then SetBattleTiming(not battleTiming.enabled) end
    EnsureBattleTiming(timingApp)
    EnsureUpdateTiming(timingApp)
    original(et,ed)
    local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app or lastObservedApp
    EnsureBattleTiming(app)
    if not app or app.stopped then return end
    lastObservedApp=app
    EnsureUpdateTiming(app)
    -- F13 reads the presentation ring once; ordinary F8/automatic dumps stay compact.
    if app.trial and app.trial.story and input:GetKeyPress(KEY_F13) then pendingPresentationHistory=true end
    frames=frames+1
    if not app.trial and (not app.scene or not app.camera or not app.hangar) then
        samples={};sampleMode='loading'
        if frames%30==0 or input:GetKeyPress(KEY_F8) then Dump(app) end
        return
    end
    if app.opening and app.opening.active then
        local I=app.opening;local w,h=UI.GetViewportSize()
        local openingTiming=MeasureOpening(I)
        if frames%30==0 or input:GetKeyPress(KEY_F8) then
            local session=I.host.state and I.host.state.session
            local sortieStatus=I.ready and session and session.combat and session.combat.player and session.combat.easy and I.host.SortieStatus and I.host.SortieStatus(I) or nil
            if sortieStatus and sortieStatus.target and session then
                local target=sortieStatus.target
                local point=session.camera:GetCamera():WorldToScreenPoint(require('core.Coord').Vec(target[1],target[2],target[3]))
                sortieStatus.targetScreen={point.x*w,point.y*h}
            end
            print('OUTGAME_STATE '..cjson.encode({mode='opening',width=w,height=h,stage=I.stage,shot=I.shot,age=I.age,time=I.time,
                ready=I.ready,failed=I.failed,error=I.error,sceneReady=I.sceneReady,downloaded=I.downloaded,
                playing=I.playing,signed=I.signed,voice=I.voiceDuration,line=I.line,lineAge=I.lineAge,
                finishing=I.finishing,fadeOutAt=I.fadeOutAt,fadeOutDuration=I.fadeOutDuration,
                exitAudioMaster=I.audio and I.audio:MasterLevel() or nil,
                openingRetirement={craterDetached=I.host.state.craterRetired==true and session==nil and I.host.state.scene==nil,
                    pending=I.host.state.assetReleasePending==true,jobs=app.openingRetirements and #app.openingRetirements or 0},
                sortie=I.sortie and {step=I.sortie.step,elapsed=I.sortie.elapsed,controlling=I.sortie.controlling,
                    tip=I.sortie.tip,pending=I.sortie.pending,left=I.sortie.left,mine=I.sortie.mine,reason=I.sortie.reason,done=I.sortie.done} or nil,
                sortieStatus=sortieStatus,
                sortieCombat=I.ready and session and session.weapons and session.combat and {enemyHealth=session.combat.easy:Health(),
                    stats=session.world.stats,firing=session.firing,group=session.weapons:Group() and session.weapons:Group().kind,
                    weaponAudio=session.weaponAudio.counts,feedbackAudio=session.feedbackAudio:Snapshot(),
                    feedbackBound=session.openingOverlay~=nil,
                    hit=session.openingOverlay and session.openingOverlay.vitals.hit,
                    pops=session.openingOverlay and session.openingOverlay.pops} or nil,
                audio=I.audio and I.audio.Snapshot and I.audio:Snapshot() or nil,
                audioContext=require('audio.AudioLevels').ContextSnapshot(),
                musicContext=app.music and {group=app.music.group,duck=app.music.duck,level=app.music.duckLevel,paused=app.music.contextPaused} or nil,
                page=I.page and I.page:Snapshot() or nil,performance=ResourceStats(app),openingTiming=openingTiming,
                openingLoad=OpeningLoadState(I),
                timingInstrumentation=openingTiming and 'QA instance method wrappers; Time:GetSystemTime milliseconds; includes wrapper overhead, not an uninstrumented performance baseline' or nil}))
        end
        return
    end
    local mode=app.trial and app.trial.map.id or app.build and 'build' or 'hangar'
    if mode~=sampleMode or app.loadingFlow.active then samples={};sampleMode=mode
    else local dt=ed:GetFloat('TimeStep');if dt>0 then samples[#samples+1]=dt end end
    if app.trial then
        if app.trial.endless and input:GetKeyPress(KEY_F2) then
            local e=app.trial.endless
            for i=2,#e.entries do local u=e.entries[i].unit;u.kill='QA focus UI wave clear';u.dirty=true;u:Flush() end
        end
        if app.trial.endless and input:GetKeyPress(KEY_F3) then
            local e=app.trial.endless
            local base=app.trial.world.layout.base.pos or app.trial.world.layout.spawn.pos
            e.player.vehicle:Place({base[1],base[2]+1,base[3]},0)
            e.player:SavePose();e.player.previous=e.player.current;app.trial.view:ResetPose();app.trial:ResetCamera()
        end
        if input:GetKeyPress(KEY_HOME) and not app.trial.combat then
            local s=app.trial;local pos=#s.view.wings>0 and {0,75,0} or {298,10,0}
            s.vehicle:Place(pos,0);s.view:ResetPose();s.yaw=90;s.pitch=0;s.follow=false;s:PostUpdate(.1)
        end
        if input:GetKeyPress(KEY_PAGEUP) and not app.trial.combat then
            local t=app.trial
            if t.qaDrillFrozen then
                t.Update=t.qaDrillFrozen.update;t.PostUpdate=t.qaDrillFrozen.post;t.qaDrillFrozen=nil
            else
                t.qaDrillFrozen={update=t.Update,post=t.PostUpdate}
                t.Update=function() end;t.PostUpdate=function() end
            end
        end
        if input:GetKeyPress(KEY_PAGEDOWN) and app.trial.qaDrillFrozen and app.trial.drillSpeed.mesh then
            local mesh=app.trial.drillSpeed.mesh;mesh.enabled=not mesh.enabled
        end
        if input:GetKeyPress(KEY_END) and not app.trial.combat then
            local t=app.trial;t.weapons.drill:Cancel()
            t.vehicle:Place({0,0,0},0);t.view:ResetPose();t.yaw=0;t.pitch=20
            t.world.units[1].vehicle:Place({0,0,30},math.pi);t.world.units[1]:SavePose()
            t.world.units[1].previous=t.world.units[1].current
            t:PostUpdate(.1)
        end
        local salvage=app.trial.salvage
        local battle=app.trial.battle
        if battle and input:GetKeyPress(KEY_F3) and battle.player.alive and battle.rules.state~='over' then
            local u=battle.player
            u:Damage(u.bp:CoreParts()[1].id,1e9,u:Position());u:Flush()
        end
        if battle and input:GetKeyPress(KEY_F2) and battle.rules.state~='over' then
            if app.trial.intro then app.trial.intro:Finish() end
            battle.stats[battle.player]={kills=12,assists=5,deaths=1,damage=28640}
            battle.rules.state='over';battle.rules.winner='blue';battle.rules.events={{type='matchOver',winner='blue'}}
            battle:AfterStep(0)
        end
        if salvage and not salvage.rules.finished then
            local session=app.trial
            if input:GetKeyPress(KEY_F3) and salvage.player.alive and salvage.landed then
                local u=salvage.player;u.struct=0;u:Damage(u.bp:CoreParts()[1].id,u.bodyHpMax*2,u:Position());u:Flush()
            end
            if input:GetKeyPress(KEY_F4) then
                for _,o in ipairs(salvage.rules.objects) do if o.ctype=='supply' and not salvage.rules.opened[o.id] then
                    salvage.qaCrate=o
                    session.vehicle:Place({o.g[1],o.g[2]+2,o.g[3]},0);session.view:ResetPose();session:PostUpdate(.1);break
                end end
            end
            if input:GetKeyPress(KEY_F11) and salvage.qaCrate then
                -- Deterministic rare reveal fixture; production SearchStep owns pickup.
                local id;for key,item in pairs(require('core.ResourceData').Read('UI/Outgame.json').items) do if item.rarity==4 then id=key;break end end
                salvage.rules:Open(salvage.qaCrate)
                local search=salvage.rules.search;search.items={{id=id,n=1,r=4,t=1,state='hidden'}};search.i=1;search.p=0;search.wait=0;search.held=false;search.done=false
            end
            if input:GetKeyPress(KEY_F7) then
                for _,e in ipairs(salvage.rules.extracts) do if not e.needs and not e.maxWidth and not e.loud then
                    salvage.rules.time=math.max(salvage.rules.time,(e.openAt or 0)+1)
                    session.vehicle:Place({e.g[1],e.g[2]+2,e.g[3]},0);session.view:ResetPose();session:PostUpdate(.1);break
                end end
            end
        end
        local story=app.trial.story
        if story then
            if story.qaEpilogue and story.qaEpilogue.active then story.qaEpilogue:Update(ed:GetFloat('TimeStep'),true) end
            if story.level.id=='s5' then
                if input:GetKeyPress(KEY_HOME) and not story.boss then
                    story.voice:Hide();story.rules:Go(2);story:Events();app.trial.combatView:Consume(story.world);story.boss.rules:Go('fight');story.boss.flow.stage='fight'
                    local target=story.boss.unit:Position();local pos=story.boss:OpenNode(target,40,80) or {target[1]+45,target[2],target[3]-40}
                    pos={pos[1],story.world:GroundAt(pos[1],pos[3])+2,pos[3]};local yaw=math.atan(target[1]-pos[1],target[3]-pos[3])
                    story:Place({pos=pos,yaw=yaw});app.trial.view:ResetPose();app.trial.yaw=-yaw*180/math.pi;app.trial.pitch=10;app.trial.follow=false;app.trial:PostUpdate(.1)
                end
                local boss=story.boss
                if boss and input:GetKeyPress(KEY_F9) then boss:Nodes();local n=boss.rules.nodes[1];boss:Hit(n.pos,n.hp) end
                if boss and input:GetKeyPress(KEY_F10) then boss.rules:Phase(2);boss:Events();boss:StartRaid() end
                if boss and input:GetKeyPress(KEY_F11) then boss.rules.state='kneel';boss.rules.kneelDealt=0;boss.rules.hp=1;boss:Hit(boss:Cockpit(),1) end
                if boss and input:GetKeyPress(KEY_F12) then
                    if story.qaEpilogue and story.qaEpilogue.active then story.qaEpilogue:Dispose()
                    else
                        local ep=require('ui.Epilogue').Attach(app.trial.scene,UI.GetRoot(),function() end);story.qaEpilogue=ep
                        ep.rules:Next();ep.rules:Next();ep.rules:Next();ep:Update(.01,true)
                    end
                end
            end
            if input:GetKeyPress(KEY_F3) and story.player.alive then
                local u=story.player;u.struct=0
                u:Damage(u.bp:CoreParts()[1].id,u.bodyHpMax*.2,u:Position());u:Flush()
            end
            if story.rules.cap and input:GetKeyPress(KEY_F10) then
                for i=2,#story.entries do local entry=story.entries[i];local u=entry.unit
                    if entry.flee then for _,p in ipairs(u.bp:List()) do if p.type~='core' and u:Integrity()>=.59 then u:Destroy(p.id) end end end
                end
            end
            if story.rules.hold and input:GetKeyPress(KEY_F9) then
                local r=story.rules
                r.stepT=r.stepT<8 and 8 or r.stepT<36 and 36 or r.stepT<56 and 56 or r.stepT<66 and 66 or r.stepT<84 and 84 or r.stepT<104 and 104 or 126
                r.hold.left=r.stepT>=126 and .001 or math.max(1,124-r.stepT)
                story:Place({pos={0,6,-234},yaw=0});app.trial.view:ResetPose();app.trial.view:Update(1)
            end
            if story.rules.hold and input:GetKeyPress(KEY_F10) then
                story.rules.hold.energy=.00001
                story:Spawn({enemies={{at={0,8,-234},role='assault',name='QA shield attacker'}}})
            end
            if story.convoy and input:GetKeyPress(KEY_F9) then
                local c=story.convoy;local p=c.d/c.total;local nextP=p<.15 and .16 or p<.5 and .51 or p<.76 and .77 or .99999
                c.d=c.total*nextP;c.pos=c:Along(c.d);story.rules.progress=nextP
                story:Place({pos=c.pos,yaw=c.yaw});app.trial.view:ResetPose();app.trial.view:Update(1)
            end
            if story.convoy and input:GetKeyPress(KEY_F10) then
                local c=story.convoy;c.hp=.00001
                story:Spawn({enemies={{at={c.pos[1],c.pos[2],c.pos[3]},role='assault',target='truck',name='QA transport attacker'}}})
            end
            if input:GetKeyPress(KEY_F4) and story.player.alive then
                local spec=story.rules:StepSpec();local target=story.rules.cap and spec and spec.pos or story.rules:Target()
                if target then story:Place({pos=target,yaw=0});app.trial.view:ResetPose();app.trial.view:Update(1);app.trial:PostUpdate(.1) end
            end
            if input:GetKeyPress(KEY_F2) then
                for i=2,#story.entries do local u=story.entries[i].unit;u.kill='QA combat destruction';u.dirty=true;u:Flush() end
            end
            if input:GetKeyPress(KEY_F6) and story.player.alive then
                local u=story.player;u.struct=0;u:Damage(u.bp:CoreParts()[1].id,1e9,u:Position());u:Flush()
            end
        end
        if input:GetKeyPress(KEY_F3) and not app.trial.combat then
            local s=app.trial;local target=s.world.targets[1]
            target.node.position=Vector3(-155,10.4,20);target.native.position=target.node.position;target.pos={155,12,20};target.hp=10000
            s.vehicle:Place({155,0,-140},0);s.view:ResetPose();s.yaw=0;s.pitch=0;s.follow=false;s:PostUpdate(1)
            for i,g in ipairs(s.weapons.groups) do if g.kind=='missile' then s.weapons:Select(i) end end
        end
        if input:GetKeyPress(KEY_F8) then pendingBattleObjects=true end
        if input:GetKeyPress(KEY_F14) then pendingBattleObjects=true;pendingSceneObjects=true end
        local key=app.loadingFlow.phase..':'..tostring(app.trial.pointer.captured)..':'..tostring(app.trial.pointer.pending)
        if frames%30==0 and not G0_StoryRouteState or input:GetKeyPress(KEY_F8) or pendingPresentationHistory or pendingSceneObjects then previous=key;pendingTrialDump=app end
        return
    end
    if input:GetKeyPress(KEY_F2) then
        if app:EnterTrial('trial') then app.loader.options.prepare=function() error('QA intentional preparation failure') end end
    end
    if input:GetKeyPress(KEY_F3) then
        _G.VOX_QA_MISSILES=true
        local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'miniHeavy'):ToTable()
        app:WithVehicle(bp,function() return app:LoadBlueprint(bp) end)
    end
    if input:GetKeyPress(KEY_F12) and app.tutorial and not app.build and require('ui.GarageHud').GetState().tab=='hangar' then app.tutorial:Start() end
    if input.mouseMoveWheel~=0 then print('OUTGAME_WHEEL '..cjson.encode({raw=input.mouseMoveWheel,dist=app.camera.dist,build=app.build~=nil})) end
    if input:GetKeyPress(KEY_F6) then app:PreviewMap(app.selectedMap or 'trial') end
    if input:GetKeyPress(KEY_F7) then app:PreviewMap('crater') end -- QA only: exercises the production map gate.
    if input:GetKeyPress(KEY_F9) then
        -- Fixed source station/time for scene comparison; this probe never ships.
        _G.VOX_DEBUG={time=10}
        local pose=require('controls.HomeStations').Get(app.blueprint:Stats(),'hangar',app.camera.maxDist)
        app:View(pose);app.hangar:SetGrid(false);app.hangar:UpdateGrid(1)
    end
    if input:GetKeyPress(KEY_F10) then renderer.drawShadows=not renderer.drawShadows end
    if input:GetKeyPress(KEY_F11) then
        app.hangar.qaPanelsOff=not app.hangar.qaPanelsOff
        for _,material in ipairs(app.hangar.materials) do
            local value=material:GetShaderParameter('panel_on')
            if value.type~=VAR_NONE then
                if material:GetShaderParameter('qa_original_panel').type==VAR_NONE then material:SetShaderParameter('qa_original_panel',value) end
                material:SetShaderParameter('panel_on',app.hangar.qaPanelsOff and Variant(0) or material:GetShaderParameter('qa_original_panel'))
            end
        end
    end
    local home=require('ui.GarageHud').GetState()
    if home and home.tab=='hangar' and not app.build and not app.loadingFlow.active then
        if input:GetKeyPress(KEY_F4) then app:EnterTrial('story5');return end
        if input:GetKeyPress(KEY_DELETE) then app:EnterTrial('crater');return end
        if input:GetKeyPress(KEY_END) then
            local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'feather')
            app.qaWingGate=require('app.ResourceGate').New();local scene=app.scene
            app.qaWingGate:Start(require('parts.Dependencies').For(bp:List()),function(ready,message)
                assert(ready,message);if app.scene~=scene or app.stopped then return end
                local ok,why=app:LoadBlueprint(bp:ToTable());assert(ok,why);print('[WingQA] Source pair ready')
            end)
        end
    end
    if home and home.tab=='hangar' and not app.build and not app.loadingFlow.active then
        if input:GetKeyPress(KEY_PAGEUP) then app:StartOpening();return end
        if input:GetKeyPress(KEY_PAGEDOWN) then app:SelectEndless() end
    end
    if input:GetKeyPress(KEY_HOME) and home and home.tab=='hangar' and not app.build then
        app.qaDrillVariant=app.qaDrillVariant=='tianyuan' and 'fuyuan' or 'tianyuan'
        local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),app.qaDrillVariant)
        app.qaDrillGate=require('app.ResourceGate').New();local scene=app.scene
        app.qaDrillGate:Start(require('parts.Dependencies').For(bp:List()),function(ready,message)
            assert(ready,message);if app.scene~=scene or app.stopped then return end
            local ok,why=app:LoadBlueprint(bp:ToTable());assert(ok,why);print('[DrillQA] Original prefab ready '..app.qaDrillVariant)
        end)
    end
    if input:GetKeyPress(KEY_INSERT) and home and home.tab=='hangar' and not app.build then
        local bp=require('construction.Blueprint').New();local id=require('core.Rotations').IDENTITY
        for _,p in ipairs({{type='core',pos={0,3,0},rot=id},{type='rotorStep',pos={0,4,0},rot=id},
            {type='cube',pos={0,5,0},rot=id,g=7},{type='cube',pos={1,5,0},rot=id,g=7},
            {type='cube',pos={2,5,0},rot=id,g=7},{type='laser1',pos={0,6,0},rot=id}}) do bp:Add(p) end
        app.qaRotorGate=require('app.ResourceGate').New()
        local scene=app.scene
        app.qaRotorGate:Start(require('parts.Dependencies').For(bp:List()),function(ready,message)
            if not ready then error(message) end
            if app.scene~=scene or app.stopped then return end
            local ok,why=app:LoadBlueprint(bp:ToTable());assert(ok,why)
            app:EnterBuild();app.build.editor.mirror=false
            local fly=app.build.buildCamera;local ry=(app.blueprint.parts[2].pos[2]+.5)*require('Config').CELL
            fly:FocusAt(Vector3(0,ry,0),5)
            if fly.mode=='fp' then
                fly.flight=require('controls.FreeFlight').New({4,ry,-5},require('core.Math3').Normalize({-4,0,5}),fly.flight.limit);fly:Apply()
            end
            print('[RotorQA] Authored fixture ready after model gate')
        end)
    end
    if input:GetKeyPress(KEY_F4) and home and home.tab=='workshop' then home.WorkshopOpen('megaMech') end
    if home and home.workshop and home.workshop.view=='feature' then
        local ws=home.workshop
        if input:GetKeyPress(KEY_F12) then
            ws.qaCaptionStep=(ws.qaCaptionStep or 0)%5+1
            ws.qaCaptionTime=({.08,.3,.46,.62,false})[ws.qaCaptionStep]
        end
        if ws.caption and ws.qaCaptionTime then
            ws.caption.elapsed=math.min(.46,ws.qaCaptionTime);ws.caption.distance=24
            ws.shelf.elapsed=ws.qaCaptionTime
            home.page:Update(0)
        end
    end
    if home and home.workshop and home.workshop.view~='feature' then
        local ws=home.workshop
        if input:GetKeyPress(KEY_F12) then
            ws.qaEntranceStep=(ws.qaEntranceStep or 0)%6+1
            ws.qaEntranceTime=({.08,.3,.5,.74,.9,false})[ws.qaEntranceStep]
        end
        if ws.entrance and ws.qaEntranceTime then
            ws.entrance.elapsed=math.min(ws.entrance.kind=='detail' and .9 or ws.entrance.kind=='grid' and .82 or .74,ws.qaEntranceTime)
            home.page:Update(0)
        end
    end
    local preview=home and home.workshopPreview
    local key=tostring(home and home.tab)..':'..tostring(home and home.workshop and home.workshop.view)..':'..tostring(home and home.salvage and home.salvage.tab)..':'..tostring(app.mapPreview~=nil)..':'..tostring(preview and preview.ready and preview.cursor>#preview.parts)..':'..tostring(app.build~=nil)..':'..tostring(app.build and app.build.inventoryPanel~=nil)..':'..graphics:GetWidth()..':'..graphics:GetHeight()
    local story=home and home.storyHolo
    key=key..':'..tostring(story and story.ready)..':'..tostring(story and story.gate.state)..':'..tostring(story and story.level)
    key=key..':'..tostring(app.warehouse and app.warehouse.ready)..':'..tostring(app.build and app.build.dialog~=nil)
    key=key..':'..app.loader.state..':'..app.loader.phase..':'..app.loader.gate.completed
    key=key..':'..app.loadingFlow.phase..':'..tostring(app.loadingFlow.failed)..':'..tostring(app.loadingFlow.match and app.loadingFlow.match.stage)
    key=key..':'..tostring(app.vehicleSwitch and app.vehicleSwitch.pending~=nil)..':'..app.blueprint.name..':'..app.bays.revision
    key=key..':'..app.vehicleGate.state
    if app.build then key=key..':'..app.editor.type..':'..app.build.ghost.gate.state end
    key=key..':'..tostring(home and home.workshop and home.workshop.selected)..':'..tostring(home and home.workshop and home.workshop.pending)..':'..tostring(home and home.musicBox~=nil)
    local mb=home and home.musicBox
    if mb then key=key..':'..tostring(mb.player.pending)..':'..tostring(mb.player:Track() and mb.player:Track().id)..':'..mb.filter..':'..mb.query..':'..tostring(mb.player.userPaused)..':'..mb.player.playMode..':'..tostring(mb.modeMenu:IsVisible())..':'..tostring(mb.player.volume) end
    if not VOX_QA_HOME_ROUTE and frames%30==0 and key~=previous or input:GetKeyPress(KEY_F8) then previous=key;Dump(app) end
end
local originalPostUpdate=HandlePostUpdate
function HandlePostUpdate(et,ed)
    originalPostUpdate(et,ed)
    local observedApp=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app or lastObservedApp
    ObserveStoryPresentation(observedApp and observedApp.trial and observedApp.trial.story)
    -- Animated weapon nodes are updated before the production camera hides them.
    -- Sample the state which will render, while preserving production event order.
    local app=pendingTrialDump;pendingTrialDump=false
    if app and app.trial and not app.trial.disposed then DumpTrial(app)
    else pendingBattleObjects=false;pendingSceneObjects=false end
end
