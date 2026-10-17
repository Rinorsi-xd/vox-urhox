-- QA suffix: append after ads-source-observer.lua. Counts real gameplay Update calls.
do
local Motion=require 'render.WeaponMotion'
local original=Motion.Update
local seen=setmetatable({},{__mode='k'})
local frame,active,pending=0,false,false
local currentTrial=false
local state={observedFrames=0,updateCallbacks=0,eligibleCallbacks=0,weaponCalls=0,duplicateCalls=0,maxPerFrame=0,
    uniqueWeapons=0,outsideUpdateCalls=0,filteredCalls=0,maxWeaponCallsInFrame=0,updateErrors=0,sequence=0}
local callsThisFrame=0
local wrapped
wrapped=function(self,...)
    local eligible=app and app.trial==currentTrial and not (app.loadingFlow and app.loadingFlow.active)
    if active and eligible then
        local entry=seen[self]
        if not entry then entry={frame=0,count=0};seen[self]=entry;state.uniqueWeapons=state.uniqueWeapons+1 end
        if entry.frame~=frame then entry.frame=frame;entry.count=0 end
        entry.count=entry.count+1
        state.weaponCalls=state.weaponCalls+1;callsThisFrame=callsThisFrame+1
        if entry.count>1 then state.duplicateCalls=state.duplicateCalls+1 end
        state.maxPerFrame=math.max(state.maxPerFrame,entry.count)
    elseif active then state.filteredCalls=state.filteredCalls+1
    else state.outsideUpdateCalls=state.outsideUpdateCalls+1 end
    return original(self,...)
end
Motion.Update=wrapped
local function Snapshot()
    state.sequence=state.sequence+1
    state.boundary='QA counts actual WeaponMotion.Update self identities per real HandleUpdate invocation, only with an existing same app.trial and loadingFlow.active false at entry and call. maxPerFrame is maximum calls for one weapon in one eligible callback. observedFrames counts eligible callbacks containing weapon calls; uniqueWeapons is cumulative observed identities. PostUpdate and excluded loading calls are outsideUpdateCalls; not timing/FPS or mobile evidence.'
    print('WEAPON_ONCE_STATE '..cjson.encode(state))
end
local update=HandleUpdate
function HandleUpdate(...)
    frame=frame+1;state.updateCallbacks=state.updateCallbacks+1;callsThisFrame=0
    currentTrial=app and app.trial or false
    active=currentTrial~=false and not (app.loadingFlow and app.loadingFlow.active)
    if active then state.eligibleCallbacks=state.eligibleCallbacks+1 end
    local result=table.pack(pcall(update,...));active=false;currentTrial=false
    if callsThisFrame>0 then state.observedFrames=state.observedFrames+1 end
    state.maxWeaponCallsInFrame=math.max(state.maxWeaponCallsInFrame,callsThisFrame)
    if not result[1]then state.updateErrors=state.updateErrors+1;Snapshot();error(result[2],0)end
    if input:GetKeyPress(KEY_F9)then pending=true end
    return table.unpack(result,2,result.n)
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
    local result=table.pack(post(...))
    if pending then pending=false;Snapshot()end
    return table.unpack(result,1,result.n)
end
local stop=Stop
function Stop(...)
    if Motion.Update==wrapped then Motion.Update=original end
    return stop(...)
end
print('WEAPON_ONCE_READY actual gameplay Update/WeaponMotion identity counter installed')
end
