-- Isolated QA entry: no scene, UI, audio player, bootstrap or shader warmup.
local config=assert(SOUND_CALLBACK_PROBE_CONFIG)
local Gate=require 'app.ResourceGate'
local rows,frames,loaded={},{},{}
local phase,finished,frame,settled='boot',false,0,0
local started,lastFrame=0,0
local gate=Gate.New()
local active={}
local sounds={}
local function Now() return Time:GetSystemTime() end
local function Finish(ok,message)
    if finished then return end
    finished=true
    gate:Cancel()
    print('SOUND_CALLBACK_RESULT '..cjson.encode({result=ok and 'PASS' or 'FAIL',message=message or '',
        mode=config.mode,rows=rows,frames=frames,loaded=loaded,api=graphics.apiName,
        boundary='Isolated exact two sound files and production ResourceGate. SystemTime is native millisecond clock; ready is observer upper bound, not native EndLoad. No playback, scene, production improvement or mobile acceptance.'}))
end
local function Request(label)
    local row={label=label,requestWall=Now(),requestFrame=frame,resources={}}
    rows[#rows+1]=row;active=row;phase='download'
    for _,name in ipairs(config.paths) do
        row.resources[#row.resources+1]={name=name,existsBefore=cache:Exists(name)}
    end
    -- The callback does only scalar state/timing writes. Cache preparation is
    -- deliberately performed from a later Update, after this stack unwinds.
    gate:Start(config.paths,function(ok,message)
        row.callbackEnterWall=Now();row.callbackFrame=frame
        row.downloadOK=ok==true;row.error=message;row.completed=true
        row.callbackExitWall=Now()
    end)
    row.requestReturnWall=Now();row.synchronous=row.completed==true
end
function Start()
    started=Now();lastFrame=started
    SubscribeToEvent('Update','SoundCallbackUpdate')
    SubscribeToEvent('EndFrame','SoundCallbackFrame')
    SubscribeToEvent('ResourceBackgroundLoaded','SoundCallbackLoaded')
    print('[SoundCallbackProbe] boot mode='..config.mode)
end
function Stop()
    UnsubscribeFromEvent('Update');UnsubscribeFromEvent('EndFrame');UnsubscribeFromEvent('ResourceBackgroundLoaded')
    if not finished then Finish(false,'Stopped before completion') end
end
function SoundCallbackLoaded(_,data)
    if not finished then loaded[#loaded+1]={wall=Now(),name=data:GetString('ResourceName'),success=data:GetBool('Success')} end
end
function SoundCallbackFrame()
    local now=Now()
    if not finished then frames[#frames+1]={wall=now,ms=math.max(0,now-lastFrame),phase=phase,frame=frame} end
    lastFrame=now
end
local function Advance(dt)
    frame=frame+1
    Gate.UpdatePending(dt)
    if Now()-started>90000 then Finish(false,'90-second runtime deadline');return end
    if phase=='boot' then
        if frame>=15 then Request('initial') end
        return
    end
    if phase=='download' then
        if not active.completed then return end
        if not active.downloadOK then Finish(false,'Download failed: '..tostring(active.error));return end
        active.nextUpdateWall=Now();active.nextUpdateFrame=frame
        assert(frame>active.callbackFrame,'Prepare must occur in a later Update')
        active.nextIndex=1;phase=config.mode=='prepare' and 'queue' or 'settle';settled=0
        return
    end
    if phase=='queue' then
        local row=active.resources[active.nextIndex]
        if not row then phase='pending';return end
        row.checkWall=Now();local existing=cache:GetExistingResource('Sound',row.name)
        row.checkReturnWall=Now();row.residentBefore=existing~=nil
        if existing then sounds[row.name]=existing;row.readyWall=Now();row.readyFrame=frame
        else
            row.queueWall=Now();row.queueFrame=frame
            row.queued=cache:BackgroundLoadResource('Sound',row.name,true)
            row.queueReturnWall=Now()
            assert(row.queued,'Background queue rejected '..row.name)
        end
        active.nextIndex=active.nextIndex+1
        return
    end
    if phase=='pending' then
        local all=true
        for _,row in ipairs(active.resources) do
            if not row.readyWall then
                local sound=cache:GetExistingResource('Sound',row.name)
                if sound then
                    sounds[row.name]=sound;row.readyWall=Now();row.readyFrame=frame
                    row.compressed=sound.compressed;row.dataSize=sound.dataSize
                else all=false end
            end
        end
        if all then phase='settle';settled=0 end
        return
    end
    if phase=='settle' then
        settled=settled+1
        if settled<15 then return end
        if #rows==1 then Request('warm') else Finish(true) end
    end
end
function SoundCallbackUpdate(_,data)
    if finished then return end
    local ok,message=pcall(Advance,data:GetFloat('TimeStep'))
    if not ok then Finish(false,tostring(message)) end
end
