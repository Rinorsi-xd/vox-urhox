-- Appended only by explicit --qa --loading-failure-test; never a production module.
local VOX_LOADING_FAILURE_MARKER='VOX_QA_CONTROLLED_POST_INSTALL_WARMUP_FAILURE'
local VOX_LOADING_FAILURE_TEST=(function()
    local cjson=require('cjson')
    local UI=require('urhox-libs/UI')
    local Warmup=require('render.CombatWarmup')
    local actualNew=Warmup.New
    local refs=setmetatable({},{__mode='v'})
    local state={enabled=true,armed=true,injected=false,events={},serial=0,constructors=0,
        warmupDisposes=0,trialDisposes=0,cancelCalls=0,reloadCalls=0}
    local bindings={}
    local function Event(kind)
        state.serial=state.serial+1
        state.events[#state.events+1]={kind=kind,wallMs=Time:GetSystemTime(),serial=state.serial}
        if #state.events>24 then table.remove(state.events,1)end
    end
    local function TrialState(trial)
        return {disposed=trial.disposed==true,scene=trial.scene~=nil,world=trial.world~=nil,
            effects=trial.effects~=nil,view=trial.view~=nil,hud=trial.hud~=nil,combatView=trial.combatView~=nil}
    end
    local function Wrap(object,name,before,after)
        local actual=object[name];local original=rawget(object,name)
        assert(type(actual)=='function','QA loading failure missing real method '..name)
        local binding={object=object,name=name,original=original}
        binding.wrapped=function(self,...)
            if before then before(self,...)end
            local results=table.pack(actual(self,...))
            if after then after(self,...)end
            return table.unpack(results,1,results.n)
        end
        object[name]=binding.wrapped;bindings[#bindings+1]=binding
    end
    local function RestoreBindings()
        for _,binding in ipairs(bindings)do
            if binding.object[binding.name]==binding.wrapped then binding.object[binding.name]=binding.original end
        end
        bindings={}
    end
    local function Hook(session,owner)
        local app=VOX_TRIAL and VOX_TRIAL.app
        if not app or app.trial~=session then return false end
        local flow=app.loadingFlow
        if not flow or not flow.active or not flow.finished or flow.failed then return false end
        state.armed=false;refs.app=app
        state.install={mode=app.mode,flowMap=flow.map and flow.map.id,finished=flow.finished,
            pendingMap=app.pendingMap~=nil,loaderState=app.loader.state,covered=flow.pageVisible,
            trialSame=app.trial==session,generation=flow.generation}
        Event('bound-real-installed-session')
        Wrap(app,'CancelMapLoad',function(_,fromFlow)
            state.cancelCalls=state.cancelCalls+1
            state.cancel={fromFlow=fromFlow==true,failed=flow.failed,finished=flow.finished,
                pendingMap=app.pendingMap~=nil,trialPresent=app.trial~=nil}
            Event('real-cancel-map-load')
        end)
        Wrap(app,'Reload',function()
            state.reloadCalls=state.reloadCalls+1;Event('real-reload')
        end,function()
            state.recovery={map=flow.map and flow.map.id,phase=flow.phase,failed=flow.failed,
                cancelled=flow.cancelled,active=flow.active,generation=flow.generation}
        end)
        Wrap(session,'Dispose',function()state.trialDisposes=state.trialDisposes+1;Event('real-trial-dispose')end,
            function(self)state.retiredTrial=TrialState(self)end)
        Wrap(owner,'Dispose',function()state.warmupDisposes=state.warmupDisposes+1;Event('real-warmup-dispose')end,
            function(self)state.warmupCleanup={disposed=self.disposed==true,proxyRoot=self.proxyRoot~=nil,
                flashOwner=self.flashWarmup~=nil,equipmentOwner=self.equipmentWarmup~=nil}end)
        local actualPresented=owner.Presented;local originalPresented=rawget(owner,'Presented')
        owner.Presented=function(self,...)
            self.Presented=originalPresented
            if state.injected then return actualPresented(self,...)end
            state.injected=true;state.injectionWallMs=Time:GetSystemTime()
            state.injection={flowActive=flow.active,finished=flow.finished,covered=flow.pageVisible,
                trialSame=app.trial==session,pendingMap=app.pendingMap~=nil,phase=self.phase}
            Event('single-controlled-presented-error')
            error(VOX_LOADING_FAILURE_MARKER,0)
        end
        return true
    end
    local replacement
    replacement=function(...)
        local owner=actualNew(...)
        state.constructors=state.constructors+1
        if state.armed and Hook(select(1,...),owner)then
            if Warmup.New==replacement then Warmup.New=actualNew end
            state.constructorRestored=Warmup.New==actualNew
        end
        return owner
    end
    Warmup.New=replacement
    local function Snapshot()
        local app=refs.app or VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
        local flow=app and app.loadingFlow
        local w,h=UI.GetViewportSize()
        local rect=flow and flow.page and flow.page.backRect
        return {enabled=state.enabled,armed=state.armed,injected=state.injected,failedObserved=state.failedObserved,
            returned=state.returned,serial=state.serial,events=state.events,
            constructors=state.constructors,constructorRestored=state.constructorRestored,
            warmupDisposes=state.warmupDisposes,trialDisposes=state.trialDisposes,cancelCalls=state.cancelCalls,
            reloadCalls=state.reloadCalls,install=state.install,injection=state.injection,cancel=state.cancel,
            recovery=state.recovery,retiredTrial=state.retiredTrial,warmupCleanup=state.warmupCleanup,
            mode=app and app.mode,tab=app and app.tab,loaderState=app and app.loader.state,
            trialPresent=app and app.trial~=nil or false,pendingMap=app and app.pendingMap~=nil or false,
            globalTrialPresent=VOX_TRIAL~=nil,globalHangarPresent=VOX_HANGAR~=nil,
            flow=flow and {active=flow.active,failed=flow.failed,error=flow.error,phase=flow.phase,
                map=flow.map and flow.map.id,visible=flow.pageVisible,finished=flow.finished,pageFrames=flow.pageFrames,
                generation=flow.generation,combatOwner=flow.combatWarmup~=nil},
            backRect=rect and {x=rect.x,y=rect.y,w=rect.w,h=rect.h},width=w,height=h,
            boundary='Explicit single Presented fault after real CombatWarmup.New; real flow/cancel/reload/dispose paths. This is fault recovery, not normal gameplay or performance acceptance.'}
    end
    local function Observe(force)
        local app=refs.app;local flow=app and app.loadingFlow
        if state.injected and flow and flow.failed and not state.failedObserved then
            state.failedObserved=true;Event('actual-flow-failed')
        end
        if state.injected and state.trialDisposes>0 and app and app.mode=='hangar' and not app.trial
            and flow and not flow.active and flow.map and flow.map.id=='hangar' and not state.returned then
            state.returned=true;Event('actual-hall-cover-closed');RestoreBindings()
        end
        if force or state.serial~=state.printedSerial then
            state.printedSerial=state.serial
            print('VOX_LOADING_FAILURE '..cjson.encode(Snapshot()))
        end
    end
    return {Snapshot=Snapshot,Observe=Observe,marker=VOX_LOADING_FAILURE_MARKER}
end)()
local VOX_LOADING_FAILURE_POST_UPDATE=HandlePostUpdate
function HandlePostUpdate(eventType,eventData)
    VOX_LOADING_FAILURE_POST_UPDATE(eventType,eventData)
    VOX_LOADING_FAILURE_TEST.Observe(input:GetKeyPress(KEY_F8))
end
