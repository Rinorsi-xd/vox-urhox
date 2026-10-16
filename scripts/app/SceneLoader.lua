-- A candidate scene loads off-screen. The active scene survives load/validation failure.
---@class SceneLoader
-- CPU time and engine TimeStep do not measure a blocked Web main thread.
local function Now() return Time:GetSystemTime() end
local Platform=require('urhox-libs.Platform.PlatformUtils')
local Loader={}
Loader.__index=Loader
function Loader.New(prepare)
    local self=setmetatable({},Loader)
    self:init()
    self.prepare=prepare
    return self
end
function Loader:init()
    self.generation=0
    self.pending=nil ---@type Scene|nil
    self.sourceFile=nil ---@type File|nil
    self.state="idle"
    self.progress=0
    self.elapsed=0
    self.downloadCompleted=0;self.downloadBytes=0
    self.phase='idle';self.job=nil;self.options=nil
    self.gate=require('app.ResourceGate').New()
    self.prepareFrames=0;self.maxPrepareMs=0;self.prepareBudgetMs=3
    self.warmIndex=1;self.warmWait=0;self.warmPath='';self.sceneProgressStart=.35
    self.warmPending=nil ---@type table|nil
    self.presentedPhase='';self.phaseFrames=0
    self.sceneLoadedProgress=0;self.prepareProgress={}
end
function Loader:Cancel()
    self.generation=self.generation+1
    self.gate:Cancel()
    if self.job then coroutine.close(self.job);self.job=nil end
    local options=self.options;self.options=nil
    if options and options.cleanup then options.cleanup() end
    if self.pending then self.pending:StopAsyncLoading(); self.pending:Dispose(); self.pending=nil end
    if self.sourceFile then self.sourceFile:Dispose();self.sourceFile=nil end
    self.state="idle";self.phase='idle';self.onReady=nil;self.onError=nil
    self.beginDownload=nil
    self.readSceneToken=nil
    self.warmIndex=1;self.warmWait=0;self.warmPath='';self.sceneProgressStart=.35
    self.warmPending=nil
    if options and options.cancel then options.cancel() end
end
function Loader:Load(path,onReady,onError,options)
    self:Cancel()
    local token=self.generation
    self.state="loading";self.progress=0;self.elapsed=0
    self.downloadCompleted=0;self.downloadBytes=0
    self.onReady,self.onError=onReady,onError
    self.options=options;self.phase='download';self.prepareFrames=0;self.maxPrepareMs=0
    self.prepareStage='world';self.prepareStageMax={};self.prepareTotalMs=0
    self.sceneLoadedProgress=0;self.prepareProgress={}
    self.phaseStarted=Now();self.phaseTimes={};self.observedPhase=self.phase
    self.presentedPhase='';self.phaseFrames=0
    self.beginDownload=function()
    local resources=options and options.resources or {path}
    if type(resources)=='function' then
        local ok,result=pcall(resources)
        if not ok then self:Fail(tostring(result));return end
        resources=result
    end
    -- Scene XML must be local before GetFile, even when a caller supplies only
    -- media dependencies. Download bytes without constructing a cached XML DOM.
    local requested={path}
    for _,resource in ipairs(resources) do requested[#requested+1]=resource end
    self.gate:Start(requested,function(ok,message)
        if self.generation~=token then return end
        if not ok then self:Fail(message);return end
        if Platform.IsWebPlatform() and options and options.webWarmup and #options.webWarmup>0 then
            self.phase='resources';self.elapsed=0;self.warmPath=path;self.sceneProgressStart=.45
            return
        end
        self.phase='scene';self.elapsed=0
        self.warmPath=path;self.readSceneToken=token
    end)
    end
end
function Loader:ReadScene(path,token)
    if self.generation~=token or self.state~='loading' then return end
    -- ResourceGate already downloaded the raw file. Loading an XMLFile first
    -- retained a second full DOM beside LoadAsyncXML's own parser on WASM.
    local opened,file=pcall(cache.GetFile,cache,path)
    if not opened or not file then self:Fail("Cannot open scene: "..path..(opened and '' or ': '..tostring(file)));return end
    self.sourceFile=file
    local ok,parsed=pcall(function()
        self.pending=Scene()
        if self.prepare then self.prepare(self.pending) end
        if self.generation~=token then return true end
        self.pending.asyncLoadingMs=3
        -- Arrays are already prepared before this parser starts. Keep scene
        -- parsing sliced without a blocking wait for background resources.
        local mode=Platform.IsWebPlatform() and LOAD_SCENE or LOAD_SCENE_AND_RESOURCES
        return self.pending:LoadAsyncXML(file,mode)
    end)
    if self.generation~=token then return end
    if not ok then self:Fail("Cannot load scene: "..path..': '..tostring(parsed))
    elseif not parsed then self:Fail("Cannot parse scene: "..path) end
end
function Loader:Fail(message)
    local failed=self.onError
    self:Cancel()
    self.state="failed"
    if failed then failed(message) end
end
function Loader:Update(dt)
    if self.state~="loading" then return end
    if self.beginDownload then
        if self.canStart and not self.canStart() then return end
        local begin=self.beginDownload;self.beginDownload=nil;begin()
        return
    end
    self:MeasurePhase()
    -- Source LoadingPage.run yields two presented frames before each stage.
    if self.canStart and (self.presentedPhase~=self.phase or self.phaseFrames<2) then return end
    self.elapsed=self.elapsed+dt
    -- The watchdog measures stalled work, not the total size of a map or car.
    if self.phase=='download' and (self.gate.completed>self.downloadCompleted or self.gate.bytes>self.downloadBytes) then
        self.elapsed=0;self.downloadCompleted=self.gate.completed;self.downloadBytes=self.gate.bytes
    end
    if self.phase=='scene' and self.pending and self.pending.asyncProgress>self.sceneLoadedProgress then
        self.elapsed=0;self.sceneLoadedProgress=self.pending.asyncProgress
    end
    if self.elapsed>90 then self:Fail("Scene loading timed out");return end
    if self.phase=='scene' and self.readSceneToken then
        local token=self.readSceneToken;self.readSceneToken=nil
        self:ReadScene(self.warmPath,token);return
    end
    if self.phase=='activate' then self:Commit();return end
    if self.phase=='download' then
        self.progress=self.gate.total>0 and .35*self.gate.completed/self.gate.total or 0;return
    end
    if self.phase=='resources' then
        -- An array decodes all six full-resolution layers and queues GPU uploads.
        -- Let the renderer retire those staging buffers before the next array
        -- or scene material loads. WASM has a fixed heap; GC cannot free uploads.
        if self.warmWait>0 then self.warmWait=self.warmWait-1;return end
        local resources=self.options.webWarmup
        local item=resources[self.warmIndex]
        if not item then
            self.phase='scene';self.elapsed=0
            self.readSceneToken=self.generation;return
        end
        local pending=self.warmPending
        if pending and pending.token~=self.generation then self.warmPending=nil;return end
        if pending and Now()-pending.started>20000 then
            self:Fail('Texture preparation timed out: '..item.name);return
        end
        local ok,resource=pcall(cache.GetExistingResource,cache,item.type,item.name)
        if not ok then self:Fail('Cannot inspect texture: '..item.name..': '..tostring(resource));return end
        local ready=resource and (item.type~='Texture2DArray' or (resource.width>0 and resource.height>0))
        if not ready then
            if not pending then
                self.warmPending={token=self.generation,started=Now()}
                local queued,result=pcall(cache.BackgroundLoadResource,cache,item.type,item.name,true)
                -- false can mean another owner already queued this resource.
                -- Poll the cache until ready; never fall back to blocking GetResource.
                if not queued then self:Fail('Cannot queue texture: '..item.name..': '..tostring(result));return end
            end
            return
        end
        self.warmPending=nil
        print('[SceneLoader] Prepared '..item.name..' bytes='..resource.memoryUse..' cache='..cache:GetTotalMemoryUse())
        self.elapsed=0
        self.warmIndex=self.warmIndex+1;self.warmWait=3
        self.progress=.35+.1*(self.warmIndex-1)/#resources
        return
    end
    if not self.pending then return end
    if self.phase=='environment' then self:Commit();return end
    if self.job then
        self.sliceStart=Now();self.prepareFrames=self.prepareFrames+1
        local ok,err=coroutine.resume(self.job)
        local elapsed=Now()-self.sliceStart
        self.maxPrepareMs=math.max(self.maxPrepareMs,elapsed);self.prepareTotalMs=self.prepareTotalMs+elapsed
        self.prepareStageMax[self.prepareStage]=math.max(self.prepareStageMax[self.prepareStage] or 0,elapsed)
        if not ok then self:Fail(tostring(err));return end
        if coroutine.status(self.job)~='dead' then return end
        self.job=nil;self:Commit();return
    end
    self.progress=self.sceneProgressStart+self.pending.asyncProgress*(.75-self.sceneProgressStart)
    if self.pending.asyncLoading then return end
    if self.sourceFile then self.sourceFile:Dispose();self.sourceFile=nil end
    if self.options and self.options.prepare then
        self.phase='prepare';self.elapsed=0
        self.job=coroutine.create(function()
            self.options.prepare(self.pending,function(progress,stage)
                self.prepareStage=stage or self.prepareStage
                local previous=self.prepareProgress[self.prepareStage]
                if previous==nil or progress>previous then
                    self.elapsed=0;self.prepareProgress[self.prepareStage]=progress
                end
                self.progress=.75+.24*progress
                if Now()-self.sliceStart>=self.prepareBudgetMs then coroutine.yield() end
            end)
        end)
        return
    end
    self:Commit()
end
function Loader:FramePresented()
    if self.state~='loading' then return end
    if self.presentedPhase~=self.phase then
        self.presentedPhase=self.phase;self.phaseFrames=1
    else self.phaseFrames=self.phaseFrames+1 end
end
function Loader:MeasurePhase()
    if not self.phaseStarted then return end
    if self.observedPhase~=self.phase then self.elapsed=0 end
    local now=Now()
    self.phaseTimes[self.observedPhase]=(self.phaseTimes[self.observedPhase] or 0)+math.max(0,now-self.phaseStarted)/1000
    self.phaseStarted=now;self.observedPhase=self.phase
end
function Loader:Commit()
    local candidate=self.pending
    -- A cache miss after an old scene was released must not expose default
    -- lighting for the first visible frames. Keep the previous scene active
    -- while the native asynchronous baker prepares the candidate's SH/IBL.
    if not self:EnvironmentReady(candidate) then
        self.phase='environment';self.progress=.99;return
    end
    if self.phase~='activate' then
        self:MeasurePhase();self.phase='activate';return
    end
    self:MeasurePhase()
    local ok,err=pcall(self.onReady,candidate)
    self:MeasurePhase()
    if ok then
        self.pending=nil;self.options=nil;self.state='ready';self.phase='ready';self.progress=1
        self.onReady=nil;self.onError=nil
    else self:Fail(tostring(err)) end
end
function Loader:EnvironmentReady(scene)
    local zones=scene:GetComponents('Zone',true)
    for _,zone in ipairs(zones) do
        local source=zone.sourceTexture
        if source and not environmentBakeCache:RequestBake(source) then return false end
    end
    -- Attach the completed result before installing the candidate, including
    -- Zones that were loaded off-screen and have not been rendered yet.
    for _,zone in ipairs(zones) do
        local source=zone.sourceTexture
        if source then zone.sourceTexture=nil;zone.sourceTexture=source end
    end
    return true
end
return Loader
