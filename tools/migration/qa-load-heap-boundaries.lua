-- QA suffix only. Methods emit boundaries; JavaScript samples after WASM returns.
local M={}
function M.Install(App)
    assert(not rawget(_G,'VOX_QA_LOAD_HEAP_BOUNDARIES'),'Duplicate load heap boundaries')
    local state={seen={},sequence=0,active=false,returning=false}
    _G.VOX_QA_LOAD_HEAP_BOUNDARIES=state
    local function Mark(tag,app)
        if state.seen[tag] then return end
        assert(state.sequence<6,'Load heap boundary limit')
        state.seen[tag]=true;state.sequence=state.sequence+1
        print('VOX_LOAD_HEAP_BOUNDARY '..cjson.encode({tag=tag,sequence=state.sequence,frame=GetTime().frameNumber,
            engineWallMs=Time:GetSystemTime(),mode=app.mode,loaderPhase=app.loader.phase,
            loadingPhase=app.loadingFlow.phase,resourceBytes=cache:GetTotalMemoryUse(),luaKiB=collectgarbage('count'),
            backgroundLoads=cache:GetNumBackgroundLoadResources(),pendingAssetRelease=app.pendingAssetRelease~=nil,
            diagnostic=true,atomicAllocatorSnapshot=false}))
    end
    local function Returned(app)
        if state.returning and state.returnFence and app.hangar and not app.trial and not app.loadingFlow.active then Mark('returned-cleanup',app) end
    end
    local originalStart=App.Start
    App.Start=function(app,...)
        local result=table.pack(originalStart(app,...))
        local loader=app.loader;local flow=app.loadingFlow
        local close=flow.Close
        flow.Close=function(owner,...)
            local wasActive=owner.active
            local result=table.pack(close(owner,...))
            if wasActive then
                if state.active and not state.returning and app.trial and not owner.failed and not owner.cancelled then Mark('activation-closed',app)
                elseif not state.active and app.hangar and not app.trial then Mark('hall-stable',app) end
                Returned(app)
            end
            return table.unpack(result,1,result.n)
        end
        local read=loader.ReadScene
        loader.ReadScene=function(owner,...)
            if state.active and not state.returning then Mark('resources-ready',app) end
            return read(owner,...)
        end
        local load=loader.Load
        loader.Load=function(owner,path,onReady,onError,options)
            if state.active and not state.returning and options and options.prepare then
                local prepare=options.prepare
                options.prepare=function(scene,checkpoint)
                    return prepare(scene,function(progress,stage)
                        if progress==.6 and stage=='session' then Mark('physics-prepared',app) end
                        return checkpoint(progress,stage)
                    end)
                end
            end
            return load(owner,path,onReady,onError,options)
        end
        return table.unpack(result,1,result.n)
    end
    local enter=App.EnterTrial
    App.EnterTrial=function(app,mapId,battleMode,...)
        local chosen=mapId=='salvage' or battleMode~=nil
        if chosen then assert(not state.active,'Load heap diagnostic permits one deployment');state.active=true end
        local result=table.pack(enter(app,mapId,battleMode,...))
        if chosen and result[1]==false then state.active=false end
        return table.unpack(result,1,result.n)
    end
    local reload=App.Reload
    App.Reload=function(app,...)
        if state.active and app.trial then state.returning=true end
        return reload(app,...)
    end
    local release=App.ReleaseSettledAssets
    App.ReleaseSettledAssets=function(app,...)
        local result=table.pack(release(app,...))
        if result[1]==true and state.active then
            if state.returning and app.hangar and not app.trial then state.returnFence=true;Returned(app)
            elseif not state.returning and not app.hangar and not app.trial then
                local token=app.mapTransition.current
                if token and token.released then Mark('old-hall-cleaned',app) end
            end
        end
        return table.unpack(result,1,result.n)
    end
end
return M
