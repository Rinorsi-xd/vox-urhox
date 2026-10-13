-- A candidate scene loads off-screen. The active scene survives load/validation failure.
---@class SceneLoader
local function Now() return os.clock()*1000 end
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
    self.warmIndex=1;self.warmWait=0;self.warmPath='';self.sceneProgressStart=.35
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
    self.gate:Start(options and options.resources or {path},function(ok,message)
        if self.generation~=token then return end
        if not ok then self:Fail(message);return end
        if Platform.IsWebPlatform() and options and options.webWarmup and #options.webWarmup>0 then
            self.phase='resources';self.elapsed=0;self.warmPath=path;self.sceneProgressStart=.45
            return
        end
        self.phase='scene';self.elapsed=0
        self:ReadScene(path,token)
    end)
end
function Loader:ReadScene(path,token)
    -- Open through ResourceCache so packaged resources and remote manifests work too.
    local function ready(resource)
        if self.generation~=token then return end
        if not resource then self:Fail("Scene resource unavailable: "..path);return end
        local file=cache:GetFile(path)
        if not file then self:Fail("Cannot open scene: "..path);return end
        self.pending=Scene()
        if self.prepare then self.prepare(self.pending) end
        self.pending.asyncLoadingMs=3
        -- WASM cannot wait for background resource completion. Load the scene
        -- in slices, resolving its already-downloaded resources on the main
        -- thread to avoid incomplete materials and overlapping image decodes.
        local mode=Platform.IsWebPlatform() and LOAD_SCENE or LOAD_SCENE_AND_RESOURCES
        local ok=self.pending:LoadAsyncXML(file,mode)
        self.sourceFile=file
        if not ok then self:Fail("Cannot parse scene: "..path) end
    end
    if cache.GetResourceAsync then cache:GetResourceAsync("XMLFile",path,ready)
    else
        -- Older WASM builds lack the async binding. XML is render-blocking and
        -- ResourceGate has already completed its download before ReadScene.
        ready(cache:GetResource("XMLFile",path))
    end
end
function Loader:Fail(message)
    local failed=self.onError
    self:Cancel()
    self.state="failed"
    if failed then failed(message) end
end
function Loader:Update(dt)
    if self.state~="loading" then return end
    self.elapsed=self.elapsed+dt
    -- Download size is not a deadline. Only stalled downloads use the idle
    -- timeout; scene decoding and preparation retain their bounded phase time.
    if self.phase=='download' and (self.gate.completed>self.downloadCompleted or self.gate.bytes>self.downloadBytes) then
        self.elapsed=0;self.downloadCompleted=self.gate.completed;self.downloadBytes=self.gate.bytes
    end
    if self.elapsed>90 then self:Fail("Scene loading timed out");return end
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
            self:ReadScene(self.warmPath,self.generation);return
        end
        local ok,resource=pcall(cache.GetResource,cache,item.type,item.name)
        if not ok or not resource then self:Fail('Cannot prepare texture: '..item.name);return end
        print('[SceneLoader] Prepared '..item.name..' bytes='..resource.memoryUse..' cache='..cache:GetTotalMemoryUse())
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
                self.progress=.75+.24*progress
                if Now()-self.sliceStart>=self.prepareBudgetMs then coroutine.yield() end
            end)
        end)
        return
    end
    self:Commit()
end
function Loader:Commit()
    local candidate=self.pending
    -- A cache miss after an old scene was released must not expose default
    -- lighting for the first visible frames. Keep the previous scene active
    -- while the native asynchronous baker prepares the candidate's SH/IBL.
    if not self:EnvironmentReady(candidate) then
        self.phase='environment';self.progress=.99;return
    end
    local ok,err=pcall(self.onReady,candidate)
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
