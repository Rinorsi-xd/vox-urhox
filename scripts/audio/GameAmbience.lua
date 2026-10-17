-- Original H5 environmental loops, prepared on demand without startup decoding.
local Data=require('core.ResourceData').Read('Combat/AmbienceSounds.json')
local Gate=require 'app.ResourceGate'
local Levels=require 'audio.AudioLevels'
local HANGAR_GAIN_SCALE=.5
local M={};M.__index=M
function M.Resolve(state)
    local drive=state.drive or {};local shell=state.shell or {};local controller=drive.modeController or {}
    if state.disabled or state.introActive or drive.busy or drive.matchStarting or shell.busy or shell.transition and shell.transition.playing
        or controller.intro or controller.paused or drive.active and not (drive.input and drive.input.locked) and not controller.script then return nil end
    if drive.pausedDrive then return 'amb_hangar' end
    if drive.active then return drive.mapId=='salvage' and 'amb_mine' or 'amb_crater' end
    return (shell.screen=='salvage' or shell.stage=='warehouse') and 'amb_warehouse' or 'amb_hangar'
end
-- Download-only dependency of one ambience cue, for loading masks that know the map.
function M.Dependencies(id) local cue=Data.cues[id];return cue and {cue.path} or {} end
function M.FromApp(app,home)
    local session=app.mode=='trial' and app.trial
    local editing=session and session.endless and session.endless.run.state=='editing'
    local finished=session and ((session.story or session.salvage) and session.combat.rules.finished
        or session.endless and session.endless.run.state=='over')
    local flow=app.loadingFlow
    return {disabled=app.stopped or not app.scene or not app.music.unlocked,
        introActive=app.opening and app.opening.active,
        drive={active=session and not editing,pausedDrive=editing,mapId=session and session.map.id,
            busy=app.loader.state=='loading' or app.pendingMap~=nil,
            input={locked=session and session.pointer and session.pointer.captured},firing=session and session.firing,
            modeController={intro=session and session.intro and not session.intro.done,paused=finished}},
        shell={screen=app.lobby=='salvage' and 'salvage' or home and home.tab,
            busy=flow and flow.active,stage=app.warehouse and app.warehouse.ready and 'warehouse'}}
end
function M.New(backend)
    local self=setmetatable({},M);self:init(backend or cache);return self
end
function M:init(backend)
    self.backend=backend;self.gate=Gate.New(backend);self.scene=Scene();self.root=self.scene:CreateChild('GameAmbience')
    self.slots={};self.serial=0;self.time=0;self.retryAt=0
end
function M:Clear(index)
    local slot=self.slots[index];if not slot then return end
    slot.source:StopImmediate();slot.source:Dispose();slot.source=nil;slot.sound=nil
    table.remove(self.slots,index)
    local path=Data.cues[slot.id].path
    for _,other in ipairs(self.slots) do if other.id==slot.id then return end end
    if not self.pending or self.pending.id~=slot.id then self.backend:ReleaseResource('Sound',path,false) end
end
function M:CancelPending()
    self.serial=self.serial+1;self.gate:Cancel()
    local pending=self.pending;self.pending=nil
    if pending then
        local used=false;for _,slot in ipairs(self.slots) do if slot.id==pending.id then used=true;break end end
        if not used then self.backend:ReleaseResource('Sound',Data.cues[pending.id].path,false) end
    end
end
function M:ReleaseCurrent()
    if not self.current then return end
    self.current.releaseAge=0;self.current=nil
end
function M:Select(id)
    if self.chosen==id then return end
    self.chosen=id;self.retryAt=0;self:CancelPending();self:ReleaseCurrent()
end
function M:Prepare(id,dt)
    local cue=Data.cues[id]
    if not self.pending then
        if self.time<self.retryAt then return end
        local pending={id=id,token=self.serial,elapsed=0};self.pending=pending
        self.gate:Start({cue.path},function(ok,err)
            if self.disposed or self.pending~=pending or self.serial~=pending.token then return end
            -- Native completion callbacks only publish readiness; never decode under the download lock.
            pending.downloaded=ok==true;pending.error=not ok and (err or 'Ambience download failed') or nil
        end)
    end
    local pending=self.pending
    if pending.error then
        print('[GameAmbience] '..id..': '..tostring(pending.error));self:CancelPending();self.retryAt=self.time+5;return
    end
    if not pending.downloaded then return end
    local sound=self.backend:GetExistingResource('Sound',cue.path)
    if not sound or sound.length<=0 then
        -- A decoded but unreferenced Sound can be evicted by ReleaseAllResources
        -- before this poll; once no background load remains, queue it again.
        local requeue=pending.queued and (pending.requeues or 0)<3 and self.backend.GetNumBackgroundLoadResources~=nil
            and self.backend:GetNumBackgroundLoadResources()==0
        if not pending.queued or requeue then
            if requeue then pending.requeues=(pending.requeues or 0)+1 end
            pending.queued=true
            local ok,err=pcall(self.backend.BackgroundLoadResource,self.backend,'Sound',cue.path,true)
            if not ok then pending.error=tostring(err) end
        end
        pending.elapsed=pending.elapsed+math.max(0,dt)
        if pending.elapsed>=20 then pending.error='Ambience background preparation timeout' end
        return
    end
    -- At most one active voice plus bounded release tails during rapid scene changes.
    if #self.slots>=8 then self:Clear(1) end
    sound.looped=cue.loop
    local source=self.root:CreateComponent('SoundSource');source.soundType='VoxAmbience'
    Levels.Play(source,sound,0,0,0,'sfx',cue.bus)
    local slot={id=id,sound=sound,source=source,amount=0}
    self.slots[#self.slots+1]=slot;self.current=slot;self.pending=nil
end
function M:Update(dt,state,focused)
    if self.disposed then return end
    local step=math.max(0,dt);self.time=self.time+step
    local id=focused and M.Resolve(state) or nil
    self:Select(id)
    if not focused then
        for i=#self.slots,1,-1 do self:Clear(i) end
        return
    end
    if id and not self.current then self:Prepare(id,step) end
    for i=#self.slots,1,-1 do local slot=self.slots[i];local cue=Data.cues[slot.id]
        if slot==self.current then
            local target=cue.gain*(slot.id=='amb_hangar' and HANGAR_GAIN_SCALE or 1)*(state.drive.firing and .6 or 1)
            slot.amount=slot.amount+(target-slot.amount)*(1-math.exp(-step/cue.attack))
        else
            slot.releaseAge=slot.releaseAge+step;slot.amount=slot.amount*math.exp(-step/cue.release)
        end
        Levels.SetGain(slot.source,slot.amount,'sfx')
        if slot.releaseAge and slot.releaseAge>=cue.release*5 then self:Clear(i) end
    end
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;self:CancelPending();self.current=nil
    for i=#self.slots,1,-1 do self:Clear(i) end
    self.scene:Dispose()
end
return M
