-- Explicit opt-in QA suffix. No subscriptions or production/library edits.
local M={enabled=false,prepared=false,epoch=0,frames={},dropped=0,capacity=4096,observed={}}
local clock=function() return Time:GetSystemTime() end
local current=nil
local stack={}
local bindings={}
local identity=rawget(_G,'VOX_QA_PIPELINE_IDENTITY') or {}
local boundary='Integer wall milliseconds, including wrapper/clock/allocation/GC/preemption costs; not exact CPU or GPU time. Engine frame IDs align all callbacks. Inclusive scopes overlap; sum selfMs only. Unscoped wall includes engine work, waits and pacing, and has no assigned owner. First/last capture frames may be partial.'
local function Elapsed(after,before) return (after-before)&0xffffffff end
local function FrameNumber() return GetTime().frameNumber end
local function Finish(nextWall,partial)
    if not current then return end
    assert(#stack==0,'Cannot close a QA frame inside a callback')
    local measured=0
    for _,row in pairs(current.scopes) do measured=measured+row.selfMs end
    current.endWall=nextWall
    current.wallMs=Elapsed(nextWall,current.startWall)
    current.measuredWallMs=measured
    current.unscopedWallMs=current.wallMs-measured
    current.partialEnd=partial or false
    if #M.frames<M.capacity then M.frames[#M.frames+1]=current else M.dropped=M.dropped+1 end
    current=nil
end
local function Frame()
    local id=FrameNumber()
    if current and current.frame~=id then Finish(clock(),false) end
    if not current then
        current={frame=id,epoch=M.epoch,startWall=clock(),scopes={},events={},droppedEvents=0,
            partialStart=M.firstFrame,framePresentedCalls=0,callsAfterFramePresented=0}
        M.firstFrame=false
    end
    return current
end
local function Event(frame,name,phase,at)
    if #frame.events<64 then
        frame.events[#frame.events+1]={name,phase,Elapsed(at,frame.startWall)}
    else frame.droppedEvents=frame.droppedEvents+1 end
end
local function Wrap(owner,key,name,presented)
    local original=owner[key]
    local function Wrapped(...)
        local observed=M.observed[name]
        if not observed then observed={calls=0};M.observed[name]=observed end
        observed.calls=observed.calls+1;observed.frame=FrameNumber()
        if not M.enabled then return original(...) end
        local frame=Frame()
        if frame.framePresentedCalls>0 then frame.callsAfterFramePresented=frame.callsAfterFramePresented+1 end
        local started=clock()
        Event(frame,name,'enter',started)
        local scope={frame=frame,name=name,start=started,children=0}
        stack[#stack+1]=scope
        local result=table.pack(pcall(original,...))
        local ended=clock()
        assert(stack[#stack]==scope,'QA callback nesting corrupted')
        stack[#stack]=nil
        assert(FrameNumber()==frame.frame,'Engine frame changed inside a QA callback')
        local elapsed=Elapsed(ended,started)
        local row=frame.scopes[name]
        if not row then row={calls=0,inclusiveMs=0,selfMs=0,maxMs=0,errors=0};frame.scopes[name]=row end
        row.calls=row.calls+1;row.inclusiveMs=row.inclusiveMs+elapsed
        row.selfMs=row.selfMs+elapsed-scope.children;row.maxMs=math.max(row.maxMs,elapsed)
        if not result[1] then row.errors=row.errors+1 end
        local parent=stack[#stack]
        if parent then parent.children=parent.children+elapsed end
        Event(frame,name,'leave',ended)
        if presented then frame.framePresentedCalls=frame.framePresentedCalls+1 end
        if not result[1] then error(result[2],0) end
        return table.unpack(result,2,result.n)
    end
    owner[key]=Wrapped
    bindings[#bindings+1]={owner=owner,key=key,original=original,wrapped=Wrapped,name=name}
end
function M.Prepare(callbacks,fixedSteps)
    if M.prepared then return end
    assert(type(callbacks)=='table','Prepare requires the actual lexical entry callback owner')
    local UI=require 'urhox-libs/UI'
    local wanted={
        {UI,'Update','ui.Update'},{UI,'Layout','ui.Layout'},{UI,'Render','ui.Render'},
        {UI,'UpdateInspector','ui.UpdateInspector'},
        {callbacks,'HandleUpdate','main.Update'},{callbacks,'HandlePostUpdate','main.PostUpdate'},
        {callbacks,'HandleFramePresented','main.FramePresented',true},
    }
    if fixedSteps then
        assert(identity.fixedSteps==true,'Fixed-step module identity required')
        local battle=require 'combat.BattleController'
        local world=require 'drive.TrackWorld'
        wanted[#wanted+1]={battle,'BeforeStep','fixed.BeforeStep'}
        wanted[#wanted+1]={world,'Step','fixed.WorldStep'}
        wanted[#wanted+1]={battle,'AfterStep','fixed.AfterStep'}
    end
    -- Validate every boundary before changing any function reference.
    for _,item in ipairs(wanted) do assert(type(item[1][item[2]])=='function','Missing QA boundary '..item[3]) end
    for _,item in ipairs(wanted) do Wrap(item[1],item[2],item[3],item[4]) end
    M.prepared=true
end
function M.Enable(enabled)
    assert(#stack==0,'Toggle QA only between callbacks')
    enabled=enabled~=false
    if enabled==M.enabled then return end
    if enabled then
        M.epoch=M.epoch+1;M.firstFrame=true
        assert(M.prepared,'Prepare before Start subscribes callbacks');M.enabled=true
    else
        Finish(clock(),true);M.enabled=false
    end
end
function M.Snapshot()
    return {available=true,enabled=M.enabled,prepared=M.prepared,epoch=M.epoch,pending=#M.frames,currentFrame=current and current.frame,
        dropped=M.dropped,bindings=#bindings,dormantWrappers=M.prepared and not M.enabled,
        observed=M.observed,control=M.control,identity=identity,boundary=boundary}
end
function M.Take()
    assert(not M.enabled,'Stop capture before taking frame records')
    local frames=M.frames;M.frames={}
    return {frames=frames,dropped=M.dropped,identity=identity,boundary=boundary}
end
function M.Emit()
    local report=M.Take()
    -- Never serialize or print in a measured callback.
    for _,frame in ipairs(report.frames) do
        print('VOX_FRAME_PIPELINE '..cjson.encode({frame=frame,dropped=report.dropped,identity=identity,boundary=boundary}))
    end
    return #report.frames
end
return M
