-- Standalone QA entry; original main.lua is replaced only in the isolated server response.
local config=assert(ARRAY_PROBE_CONFIG,'Missing array probe configuration')
local Gate=require 'app.ResourceGate'
local rows,frames,events,arrays={},{},{},{}
local phase,index,finished='boot',1,false
local started,lastFrame,downloaded,settled=0,0,false,0
local gate=nil ---@type table|nil
local material=nil ---@type Material|nil
local materialMs=0
local function Now() return Time:GetSystemTime() end
local function Cleanup()
    if gate then gate:Cancel() end
    material=nil;arrays={}
    collectgarbage('collect')
    cache:ReleaseResource('Material',config.material,false)
    for _,item in ipairs(config.arrays) do cache:ReleaseResource('Texture2DArray',item.name,false) end
end
local function Finish(ok,message)
    if finished then return end
    finished=true
    local pending=cache:GetNumBackgroundLoadResources()
    Cleanup()
    local residual={}
    for _,item in ipairs(config.arrays) do residual[item.name]=cache:GetExistingResource('Texture2DArray',item.name)~=nil end
    local result={result=ok and 'PASS' or 'FAIL',message=message or '',mode=config.mode,rows=rows,frames=frames,events=events,materialMs=materialMs,
        cleanup={pendingBackground=pending,residual=residual},api=graphics.apiName,
        boundary='Isolated real engine array queue/readiness/frame-gap experiment; original frozen bytes and material reference binding, no scene pixels, gameplay, audio continuity or mobile performance acceptance.'}
    print('ARRAY_PROBE_RESULT '..cjson.encode(result))
end
function Start()
    started=Now();lastFrame=started
    SubscribeToEvent('Update','ArrayProbeUpdate')
    SubscribeToEvent('EndFrame','ArrayProbeFrame')
    SubscribeToEvent('ResourceBackgroundLoaded','ArrayProbeLoaded')
    gate=Gate.New();phase='download'
    print('[ArrayProbe] Boot')
    gate:Start(config.downloads,function(ok,message)
        -- Never construct resources in a downloader completion callback.
        downloaded=ok==true
        if not ok then Finish(false,'Download failed: '..tostring(message)) end
    end)
end
function Stop()
    UnsubscribeFromEvent('Update');UnsubscribeFromEvent('EndFrame');UnsubscribeFromEvent('ResourceBackgroundLoaded')
    if not finished then Finish(false,'Runtime stopped before completion') end
end
function ArrayProbeLoaded(_,data)
    if finished then return end
    events[#events+1]={wall=Now(),name=data:GetString('ResourceName'),success=data:GetBool('Success')}
end
function ArrayProbeFrame()
    local now=Now()
    if not finished and phase~='download' and phase~='boot' then
        frames[#frames+1]={wall=now,ms=math.max(0,now-lastFrame),phase=phase,index=index}
    end
    lastFrame=now
    if phase=='settle' then settled=settled+1 end
end
local function Advance(dt)
    if finished then return end
    Gate.UpdatePending(dt)
    if Now()-started>180000 then Finish(false,'Overall 180-second timeout');return end
    if phase=='download' then
        if not downloaded then return end
        for _,path in ipairs(config.downloads) do assert(cache:Exists(path),'Missing downloaded bytes '..path) end
        phase='queue'
    end
    if phase=='settle' then
        if settled<3 then return end
        index=index+1;phase=index>#config.arrays and 'material' or 'queue'
    end
    if phase=='queue' then
        local item=config.arrays[index]
        assert(not cache:GetExistingResource('Texture2DArray',item.name),'Experiment requires a cold array: '..item.name)
        local row={name=item.name,queueWall=Now()};rows[index]=row
        if config.mode=='synchronous' then
            row.queued=cache:GetResource('Texture2DArray',item.name)~=nil
        else row.queued=cache:BackgroundLoadResource('Texture2DArray',item.name,true) end
        row.queueMs=Now()-row.queueWall;phase='pending'
        return
    end
    if phase=='pending' then
        local item=config.arrays[index];local row=rows[index]
        if Now()-row.queueWall>30000 then Finish(false,'Array readiness timeout: '..item.name);return end
        local resource=cache:GetExistingResource('Texture2DArray',item.name)
        if not resource or resource.width<=0 or resource.height<=0 then return end
        assert(resource.width==config.width and resource.height==config.height,'Original array dimensions changed')
        assert(resource.layers==6,'Original six layers changed')
        assert(resource.levels==config.levels,'Original mip levels changed')
        assert(resource.memoryUse==config.memoryBytes,'Original array memory/format footprint changed')
        arrays[index]=resource;row.readyWall=Now();row.readyMs=row.readyWall-row.queueWall
        row.width=resource.width;row.height=resource.height;row.layers=resource.layers;row.levels=resource.levels
        row.format=resource.format;row.memoryBytes=resource.memoryUse
        settled=0;phase='settle'
        print('[ArrayProbe] Ready '..item.name..' queueMs='..row.queueMs..' readyMs='..row.readyMs)
        return
    end
    if phase=='material' then
        local begin=Now();material=assert(cache:GetResource('Material',config.material),'Original material missing')
        for i,item in ipairs(config.arrays) do
            assert(material:GetSurfaceTexture(item.binding)==arrays[i],'Original material does not reference prepared cache object: '..item.binding)
            rows[i].referenceMatched=true
        end
        materialMs=Now()-begin
        assert(cache:GetNumBackgroundLoadResources()==0,'Background work remains after both arrays are ready')
        -- Record one more complete rendered frame including material binding.
        phase='finish';return
    end
    if phase=='finish' then Finish(true) end
end
function ArrayProbeUpdate(_,data)
    if finished then return end
    local ok,message=pcall(Advance,data:GetFloat('TimeStep'))
    if not ok then Finish(false,tostring(message)) end
end
