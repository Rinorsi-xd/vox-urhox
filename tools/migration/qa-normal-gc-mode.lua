-- QA-only automatic collector mode comparison; no numeric collector tuning.
local rawGc = collectgarbage
local Cycle = require 'core.CollectionCycle'
local Lifetime = require 'render.RenderTargetLifetime'
local target = __VOX_GC_TARGET__
local controller = {target=target,phase='idle',contaminated=false,mutations=0,events={}}
local wrapper
local function App()
    return VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
end
local function Guard()
    local app=App()
    local cycle=Cycle.State()
    local pending=Lifetime.PendingCount()
    local background=cache:GetNumBackgroundLoadResources()
    local result={appPresent=app~=nil,live=app~=nil and app.trial~=nil and app.trial.battle~=nil
        and app.trial.battle.rules.state=='live',stopped=app~=nil and app.stopped==true,
        pendingAssetRelease=app~=nil and app.pendingAssetRelease~=nil,
        incrementalRelease=app~=nil and app.assetReleaseIncremental==true,
        retirementQueue=app~=nil and app.openingRetirements~=nil,
        loaderState=app and app.loader and app.loader.state or false,
        pendingTargets=pending,background=background,cycle=cycle,
        loading=app~=nil and app.loadingFlow.active==true,
        preview=app~=nil and app.mapPreview~=nil,
        switchPending=app~=nil and app.vehicleSwitch~=nil and app.vehicleSwitch.pending~=nil,
        focused=input.focus==true,minimized=input.minimized==true,
        captured=app~=nil and app.trial~=nil and app.trial.pointer.captured==true,
        dialog=app~=nil and app.trial~=nil and app.trial.dialog~=nil,
        intro=app~=nil and app.trial~=nil and app.trial.intro~=nil and not app.trial.intro.done}
    result.clear=result.live and not result.stopped and not result.pendingAssetRelease
        and not result.incrementalRelease and not result.retirementQueue
        and result.loaderState~='loading' and pending==0 and background==0
        and not cycle.active and not cycle.stepping and not cycle.restoreRequested
        and not result.loading and not result.preview and not result.switchPending
        and result.focused and not result.minimized and result.captured and not result.dialog and not result.intro
    return result
end
local function Assembly()
    local app=App()
    local battle=app and app.trial and app.trial.battle
    if not battle then return false end
    local result={}
    for i,entry in ipairs(battle.entries) do
        local unit=entry.unit
        local rows={}
        for _,part in ipairs(unit.bp:List()) do
            rows[#rows+1]={part.id,part.type,part.pos[1],part.pos[2],part.pos[3],part.rot,
                part.color or false,part.shellColor or false,part.g or 0}
        end
        table.sort(rows,function(a,b)return a[1]<b[1]end)
        local text=cjson.encode(rows)
        local hash=2166136261
        for k=1,#text do hash=((hash~text:byte(k))*16777619)&0xffffffff end
        result[i]={team=unit.team,slot=entry.slot,player=entry.member.player==true,
            role=entry.member.role or false,variant=entry.member.variant or false,
            count=#rows,bytes=#text,fnv1a32=string.format('%08x',hash)}
    end
    return result
end
local function Emit(kind)
    print('VOX_NORMAL_GC_ACK '..cjson.encode({kind=kind,target=target,phase=controller.phase,
        previous=controller.previous or false,restored=controller.restored==true,
        contaminated=controller.contaminated,mutations=controller.mutations,
        error=controller.error or false,running=rawGc('isrunning')}))
end
wrapper=function(operation,...)
    if controller.phase=='selected' and operation~='count' and operation~='isrunning' then
        controller.contaminated=true
        controller.mutations=controller.mutations+1
        if #controller.events<32 then
            controller.events[#controller.events+1]={operation=tostring(operation),timeMs=Time:GetSystemTime()}
        end
    end
    return rawGc(operation,...)
end
function controller.Snapshot()
    return {target=target,phase=controller.phase,previous=controller.previous or false,
        selectedAtMs=controller.selectedAtMs or false,restored=controller.restored==true,
        contaminated=controller.contaminated,mutations=controller.mutations,events=controller.events,
        wrapperOwned=collectgarbage==wrapper,error=controller.error or false,
        running=rawGc('isrunning'),luaKiB=rawGc('count'),guard=Guard(),assembly=controller.assembly or false,
        assemblyBoundary='Selected endpoint only; FNV1a32 of canonical id/type/xyz/rotation/colors/g rows, not a cryptographic digest; includes weapon types through part.type.'}
end
function controller.Select()
    if controller.phase~='idle' then controller.error='selection-already-attempted';Emit('select');return end
    if not Guard().clear or not rawGc('isrunning') or collectgarbage~=rawGc then
        controller.error='selection-gate';controller.phase='rejected';Emit('select');return
    end
    controller.assembly=Assembly()
    if #controller.assembly~=8 then controller.error='eight-vehicle-gate';controller.phase='rejected';Emit('select');return end
    local ok,previous=pcall(rawGc,target)
    if not ok then controller.error=tostring(previous);controller.phase='rejected';Emit('select');return end
    controller.previous=previous
    controller.selectedAtMs=Time:GetSystemTime()
    controller.phase='selected'
    collectgarbage=wrapper
    if previous~='generational' and previous~='incremental' then
        controller.error='unexpected-original-mode';controller.contaminated=true
    end
    Emit('select')
end
function controller.Restore()
    if controller.restored then Emit('restore');return end
    if controller.phase~='selected' then Emit('restore');return end
    local owned=collectgarbage==wrapper
    if not owned then controller.error='wrapper-ownership-lost';controller.contaminated=true end
    local ok,message=pcall(rawGc,controller.previous)
    if owned then collectgarbage=rawGc end
    controller.restored=ok and rawGc('isrunning')==true
    controller.phase=controller.restored and 'restored' or 'restore-failed'
    if not ok then controller.error=tostring(message) end
    if not controller.restored and not controller.error then controller.error='collector-not-running' end
    Emit('restore')
end
VOX_QA_NORMAL_GC_MODE=controller
local previousUpdate=HandleUpdate
function HandleUpdate(eventType,eventData)
    previousUpdate(eventType,eventData)
    if input:GetKeyPress(KEY_F10) then controller.Select() end
    if input:GetKeyPress(KEY_F11) then controller.Restore() end
end
local previousStop=Stop
function Stop()
    controller.Restore()
    if previousStop then previousStop() end
end
