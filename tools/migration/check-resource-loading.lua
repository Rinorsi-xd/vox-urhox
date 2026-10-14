-- Real scene/physics lifetime checks plus deterministic native-download callback replay.
local Gate=require 'app.ResourceGate'
local Loader=require 'app.SceneLoader'
local app,oldScene,loader
local cancelledGround
local preparedWorld,restoreNew
local cancelCount=0
local timings={}
local function Measure(label,fn,...)
    local start=os.clock();local value=fn(...);local elapsed=(os.clock()-start)*1000
    local t=timings[label] or {calls=0,total_ms=0,max_ms=0};timings[label]=t
    t.calls=t.calls+1;t.total_ms=t.total_ms+elapsed;t.max_ms=math.max(t.max_ms,elapsed)
    return value
end
local data=require('core.ResourceData');local read=data.Read
data.Read=function(path) return Measure(path,read,path) end
local Height=require('core.HeightField');local heightNew=Height.New
Height.New=function(path) return Measure(path,heightNew,path) end
local stage='boot';local ticks=0;local cleanup=0;local failed=0;local activated=0;local gateChecked=false
engine.maxInactiveFps=120
V.atFrame(20,function()
    local backend={requests={},cancelled={},localFiles={['cached.png']=true}}
    function backend:Exists(path) return self.localFiles[path]==true end
    function backend:DownloadResources(paths,done,progress)
        self.requests[#self.requests+1]={paths=paths,done=done,progress=progress};return #self.requests
    end
    function backend:CancelDownloadGroup(id) self.cancelled[#self.cancelled+1]=id end
    local gate=Gate.New(backend);local calls=0
    local function Complete() calls=calls+1 end
    gate:Start({'cached.png','next.png','next.png'},Complete)
    local first=backend.requests[1]
    V.assert(#first.paths==1 and first.paths[1]=='next.png','readiness skips local files and deduplicates missing media')
    first.progress(0,1,40,100);V.assert(gate.bytes==40 and gate.totalBytes==100,'download byte progress survives native callback')
    gate:Cancel();V.assert(backend.cancelled[1]==1 and gate.group==nil,'cancel only the owned native group')
    first.done(true,0);first.progress(1,1,100,100)
    V.assert(calls==0 and gate.state=='idle','late completion cannot revive cancelled request')
    gate:Start({'second.png'},Complete);local second=backend.requests[2]
    first.done(false,1);V.assert(gate.state=='loading','older generation cannot fail replacement request')
    second.done(false,1);V.assert(gate.state=='failed' and calls==1 and gate.group==nil,'download failure remains observable and releases callback')
    gate:Start({'second.png'},Complete);backend.requests[3].done(true,0)
    V.assert(gate.state=='ready' and calls==2,'explicit retry can complete after failure')
    function backend:DownloadResources(paths,done) done(true,0);return 99 end
    gate:Start({'sync.png'},Complete);gate:Cancel()
    V.assert(calls==3 and #backend.cancelled==1,'synchronous completion does not leave stale group to cancel')
    gate:Start({'cached.png'},Complete);V.assert(calls==4 and gate.total==0,'local readiness completes without download request')

    local slow=Loader.New();slow.state='loading';slow.phase='download';slow.gate.total=4
    for i=1,3 do slow.gate.completed=i;slow:Update(40) end
    V.assert(slow.state=='loading','downloads progressing over 90 seconds are not failed by total duration')
    slow:Update(91);V.assert(slow.state=='failed','download with no further progress retains 90 second timeout')
    slow=Loader.New();slow.state='loading';slow.phase='download';slow.gate.total=1
    for i=1,3 do slow.gate.bytes=i*100;slow:Update(40) end
    V.assert(slow.state=='loading','modern byte progress keeps large individual download alive');slow:Cancel()
    slow=Loader.New();slow.state='loading';slow.phase='resources';slow:Update(91)
    V.assert(slow.state=='failed','native preparation phases retain original timeout')

    local originalManager=GetDownloadManager;local completed=0;local legacyCalls=0
    local manager={}
    function manager:DownloadResources() return 7 end
    function manager:CancelGroup() end
    function manager:GetResourceTaskState(path) return tonumber(path)<=completed and DOWNLOAD_COMPLETED or DOWNLOAD_DOWNLOADING end
    local legacyBackend={}
    function legacyBackend:Exists(path) return tonumber(path)<=completed end
    GetDownloadManager=function() return manager end
    local legacy=Gate.New(legacyBackend)
    legacy:Start({'1','2','3','4'},function() legacyCalls=legacyCalls+1 end)
    for i=1,3 do completed=i;Gate.UpdatePending(40) end
    V.assert(legacy.state=='loading' and legacy.completed==3,'legacy WASM polling uses idle time across progressing downloads')
    completed=4;Gate.UpdatePending(40)
    V.assert(legacy.state=='ready' and legacyCalls==1,'legacy WASM batch can complete after 160 seconds')
    completed=0;legacy:Start({'1','2','3','4'},function() legacyCalls=legacyCalls+1 end);Gate.UpdatePending(91)
    V.assert(legacy.state=='failed' and legacyCalls==2,'legacy stalled batch still fails exactly once')
    local requests=0;local many={}
    for i=1,80 do many[i]=tostring(i) end
    completed=80
    -- Keep the fake files absent until the manager reports completion.
    legacyBackend.Exists=function() return false end
    local oldState=manager.GetResourceTaskState
    manager.GetResourceTaskState=function(_,path) requests=requests+1;return DOWNLOAD_DOWNLOADING end
    legacy:Start(many,function() legacyCalls=legacyCalls+1 end);Gate.UpdatePending(.1)
    V.assert(requests<=8 and legacy.state=='loading','large legacy batch polls at most eight resources per update')
    manager.GetResourceTaskState=function(_,path) requests=requests+1;return oldState(manager,path) end
    legacyBackend.Exists=function() return true end
    for i=1,80 do Gate.UpdatePending(.1) end
    V.assert(legacy.state=='ready' and legacy.completed==80 and legacyCalls==3,'bounded legacy scan eventually completes all resources once')
    GetDownloadManager=originalManager
    gateChecked=true
end)
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;oldScene=app.scene
        V.assert(cache:GetExistingResource('Model','Crater/mesh-0.bin')==nil,'boot does not load unselected crater models')
        local worldModule=require('drive.CraterWorld');local new=worldModule.New
        restoreNew=function() worldModule.New=new end
        worldModule.New=function(...)
            local world=new(...);cancelledGround=world.visualGround;preparedWorld=world;return world
        end
        app:EnterTrial('crater');stage='cancel'
    elseif stage=='cancel' then
        local ready=app.loader.phase=='prepare' and preparedWorld and
            ((cancelCount==0 and app.loader.prepareFrames>=2) or (cancelCount==1 and next(preparedWorld.space.bodies)~=nil))
        if ready then
            V.assert(app.scene==oldScene and not app.trial,'old scene stays active while collision builds')
            V.assert(app.loader.pending:GetChild('CraterPhysics')~=nil,'cancel exercises a partially created native world')
            if cancelCount==0 then V.assert(not preparedWorld.layout.dataReady,'first cancellation interrupts partial data decode')
            else V.assert(preparedWorld.layout.dataReady,'second cancellation interrupts native collision preparation') end
            V.assert(app:CancelMapLoad(),'map preparation accepts cancellation')
            V.assert(cancelledGround and cancelledGround.disposed and cancelledGround.buffer.size==0,'cancel immediately releases visual ground buffer')
            V.assert(preparedWorld.layout==nil,'cancel drops partial or completed layout arrays')
            V.assert(app.loader.pending==nil and app.loader.job==nil and app.loader.options==nil,'cancel clears native scene and coroutine owners')
            V.assert(app.pendingMap==nil and app.scene==oldScene,'cancellation retains active garage and clears loading notice')
            cancelCount=cancelCount+1;stage='settle';ticks=0
        end
    elseif stage=='settle' then
        ticks=ticks+1
        if ticks==5 then
            collectgarbage('collect');cache:ReleaseAllResources(false)
            V.assert(cache:GetExistingResource('Model','Crater/mesh-0.bin')==nil,'cancelled map model no longer retained')
            V.assert(cache:GetExistingResource('Texture2D','Crater/Sky.hdr')==nil,'cancelled map sky bake no longer retained')
            preparedWorld=nil;app:EnterTrial('crater');stage=cancelCount<2 and 'cancel' or 'retry'
        end
    elseif stage=='retry' and app.trial then
        restoreNew()
        local expected=0
        for _,rock in ipairs(data.Read('Crater/Boulders.json')) do if rock.r>=.9 then expected=expected+1 end end
        V.assert(app.trial.world.boulderCount==expected,'retry installs every qualifying boulder from the current exported data')
        local layout=app.trial.world.layout
        V.assert(#layout.blocks==layout.dataParts.blocks and #layout.terrain.heights==layout.dataParts.heights,'partitioned layout restores every collider and height declared in the current manifest')
        V.assert(cache:GetExistingResource('JSONFile','Crater/Layout.json')==nil,'map metadata does not retain duplicate native JSON DOM')
        V.assert(app.loader.prepareFrames>2,'physics preparation is spread over multiple frames')
        V.assert(app.trial.environment.effects.layout==app.trial.world.layout,'physics and rendering share one decoded terrain layout')
        local report={prepare_frames=app.loader.prepareFrames,max_prepare_slice_ms=app.loader.maxPrepareMs,prepare_budget_ms=app.loader.prepareBudgetMs,remote_transport_verified=false,data_timings=timings,prepare_total_ms=app.loader.prepareTotalMs,stage_max_ms=app.loader.prepareStageMax}
        print('[ResourceLoadingMetrics] '..cjson.encode(report))
        app:Reload();stage='return'
    elseif stage=='return' and app.mode=='hangar' then
        oldScene=app.scene;loader=Loader.New()
        loader:Load('Scenes/TrialTrack.xml',function() activated=activated+1 end,function() failed=failed+1 end,{
            prepare=function(scene,checkpoint) scene:CreateChild('PartialCandidate');checkpoint(.5);error('intentional preparation failure') end,
            cleanup=function() cleanup=cleanup+1 end})
        stage='fail'
    elseif stage=='fail' then
        loader:Update(1/60)
        if loader.state=='failed' then
            V.assert(failed==1 and activated==0 and cleanup==1,'preparation failure invokes cleanup and never activates candidate')
            V.assert(loader.pending==nil and loader.job==nil and app.scene==oldScene,'failure preserves active native scene')
            loader:Load('Scenes/TrialTrack.xml',function(scene) activated=activated+1;scene:Dispose() end,function() failed=failed+1 end)
            stage='retry-loader'
        end
    elseif stage=='retry-loader' then
        loader:Update(1/60)
        if loader.state=='ready' then
            V.assert(activated==1 and failed==1,'same loader can retry after preparation failure')
            V.assert(gateChecked,'native callback replay ran before lifecycle completion')
            loader:Cancel()
            loader.EnvironmentReady=function() return false end
            loader:Load('Scenes/OrbitalHangar.xml',function() activated=activated+1 end,function() failed=failed+1 end)
            stage='bake-wait'
        end
    elseif stage=='bake-wait' then
        loader:Update(1/60)
        if loader.phase=='environment' then
            V.assert(loader.pending~=nil and activated==1 and app.scene==oldScene,'environment wait keeps candidate off-screen and active scene intact')
            loader:Cancel()
            V.assert(loader.pending==nil and loader.state=='idle','environment preparation can be cancelled without activation')
            loader.EnvironmentReady=nil -- restore native baker implementation
            loader:Load('Scenes/OrbitalHangar.xml',function(scene)
                local zone=scene:GetComponent('Zone',true)
                V.assert(zone.sourceTexture and environmentBakeCache:RequestBake(zone.sourceTexture),'native environment ready before scene activation')
                activated=activated+1;scene:Dispose()
            end,function() failed=failed+1 end)
            stage='bake-retry'
        end
    elseif stage=='bake-retry' then
        loader:Update(1/60)
        if loader.state=='ready' then
            V.assert(activated==2 and failed==1,'environment preparation retry commits once')
            loader:Cancel();stage='done';V.finish()
        end
    end
end
for frame=30,1230 do V.atFrame(frame,Poll) end
V.atFrame(1240,function() V.assert(stage=='done','loading cancellation failure retry lifecycle completed');V.finish() end)
