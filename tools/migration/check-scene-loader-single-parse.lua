package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local current={}
local checks=0
local scenarios={}
local function Check(value,message)
    checks=checks+1;assert(value,message)
end
package.preload['urhox-libs.Platform.PlatformUtils']=function()
    return {IsWebPlatform=function() return current.web end}
end
LOAD_SCENE=1;LOAD_SCENE_AND_RESOURCES=2
DOWNLOAD_COMPLETED=3;DOWNLOAD_DOWNLOADING=2
DOWNLOAD_FAILED=4;DOWNLOAD_CANCELLED=5
Time={GetSystemTime=function() return current.now end}
environmentBakeCache={RequestBake=function() return current.bakeReady end}
local Loader=require 'app.SceneLoader'
local Gate=require 'app.ResourceGate'
local function New(name,config)
    current={name=name,web=true,now=0,localFiles={},tasks={},cancelled={},files={},scenes={},
        xmlLoads=0,opens=0,parses=0,cleanup=0,cancel=0,activated=0,failures={},bakeReady=true}
    for key,value in pairs(config or {}) do current[key]=value end
    scenarios[#scenarios+1]=name
    cache={}
    function cache:Exists(path) return current.localFiles[path]==true end
    function cache:GetFile(path)
        current.opens=current.opens+1
        Check(current.localFiles[path]==true,'raw scene must be downloaded before opening')
        if current.openError then error('native open exception') end
        if current.missing then return nil end
        local file={path=path,disposed=0}
        function file:Dispose() self.disposed=self.disposed+1 end
        current.files[#current.files+1]=file;return file
    end
    function cache:GetResource(kind,path)
        if kind=='XMLFile' then current.xmlLoads=current.xmlLoads+1;error('duplicate scene XML DOM') end
        return {memoryUse=8}
    end
    function cache:GetExistingResource() return {memoryUse=8,width=1024,height=1024} end
    function cache:GetResourceAsync() current.xmlLoads=current.xmlLoads+1;error('duplicate async scene XML DOM') end
    function cache:GetTotalMemoryUse() return 8 end
    function cache:DownloadResources(paths,done,progress)
        local task={paths=paths,done=done,progress=progress};current.tasks[#current.tasks+1]=task
        return #current.tasks
    end
    function cache:CancelDownloadGroup(group) current.cancelled[#current.cancelled+1]=group end
    Scene=function()
        if current.sceneError then error('native scene exception') end
        local scene={asyncLoading=true,asyncProgress=0,disposed=0,stopped=0}
        function scene:LoadAsyncXML(file,mode)
            current.parses=current.parses+1;self.file=file;self.mode=mode
            Check(file.disposed==0,'File remains alive when native async loader starts')
            if current.parseError then error('native parse exception') end
            return not current.parseFalse
        end
        function scene:StopAsyncLoading() self.stopped=self.stopped+1;self.asyncLoading=false end
        function scene:Dispose() self.disposed=self.disposed+1 end
        function scene:GetComponents() return current.zones or {} end
        current.scenes[#current.scenes+1]=scene;return scene
    end
    local loader=Loader.New(current.prepare)
    loader.canStart=function() return true end
    return loader
end
local function Load(loader,options,path)
    options=options or {};options.cleanup=function() current.cleanup=current.cleanup+1 end
    options.cancel=function() current.cancel=current.cancel+1 end
    loader:Load(path or 'Scenes/Test.xml',function(scene)
        if current.activateError then error('activation exception') end
        current.activated=current.activated+1;current.active=scene
    end,function(message) current.failures[#current.failures+1]=message end,options)
end
local function Tick(loader,dt)
    loader:FramePresented();loader:FramePresented();loader:Update(dt or 1/60)
end
local function Download(task,ok)
    if ok then for _,path in ipairs(task.paths) do current.localFiles[path]=true end end
    task.done(ok,ok and 0 or 1)
end
local function Start(loader)
    loader:Update(0)
    if #current.tasks>0 then Download(current.tasks[#current.tasks],true) end
    Tick(loader)
end
local function Finish(loader)
    loader.pending.asyncLoading=false;loader.pending.asyncProgress=1
    for _=1,8 do if loader.state~='loading' then break end;Tick(loader) end
end
local function Released(loader)
    Check(loader.pending==nil and loader.sourceFile==nil and loader.job==nil,'failed/cancelled loader releases owners')
    for _,file in ipairs(current.files) do Check(file.disposed==1,'source file disposed exactly once') end
    for _,scene in ipairs(current.scenes) do Check(scene.disposed==1 and scene.stopped==1,'candidate stopped and disposed exactly once') end
end

do
    local loader=New('cached-web-single-parse',{localFiles={['Scenes/Test.xml']=true}})
    Load(loader);Start(loader)
    Check(#current.tasks==0 and current.opens==1 and current.parses==1 and current.xmlLoads==0,'cached Web uses only native scene XML parser')
    Check(loader.pending.mode==LOAD_SCENE and loader.pending.asyncLoadingMs==3,'Web keeps main-thread resource resolution and 3ms node budget')
    Check(current.files[1].disposed==0,'source retained throughout native asynchronous load')
    Finish(loader)
    Check(loader.state=='ready' and current.activated==1 and current.files[1].disposed==1,'successful scene commits once after file release')
    Check(current.active.disposed==0 and current.cleanup==0,'committed scene ownership transfers without cleanup')
    loader:Cancel();Check(current.active.disposed==0,'later loader cancel cannot dispose committed scene')
end
do
    local dependencies={'media.bin','media.bin'}
    local loader=New('remote-scene-missing-from-custom-list')
    Load(loader,{resources=dependencies});loader:Update(0)
    Check(#dependencies==2 and dependencies[1]=='media.bin','caller resource list remains unchanged')
    local task=current.tasks[1]
    Check(#task.paths==2 and task.paths[1]=='Scenes/Test.xml' and task.paths[2]=='media.bin','actual gate includes scene and deduplicates media')
    Tick(loader);Check(current.opens==0 and loader.phase=='download','remote scene cannot open before download callback')
    Download(task,true);loader:Update(0)
    Check(current.opens==0,'scene parser waits for its own presented frames')
    loader:FramePresented();loader:Update(0);Check(current.opens==0,'one scene presentation cannot start parse')
    loader:FramePresented();loader:Update(0);Check(current.parses==1 and current.xmlLoads==0,'two scene presentations start only one parser')
    loader:Cancel();Released(loader)
end
do
    local loader=New('cancel-download-late-callback');Load(loader);loader:Update(0)
    local task=current.tasks[1];loader:Cancel();Download(task,true);Tick(loader)
    Check(loader.state=='idle' and current.opens==0 and #current.failures==0,'late download callback cannot resurrect cancelled scene')
    Check(#current.cancelled==1,'cancel releases only owned download group')
end
do
    local loader=New('replace-download-stale-callback');Load(loader);loader:Update(0)
    local first=current.tasks[1];Load(loader,nil,'Scenes/Next.xml');loader:Update(0)
    Download(first,false);Download(current.tasks[2],true);Tick(loader)
    Check(loader.pending.file.path=='Scenes/Next.xml' and #current.failures==0,'old download failure cannot affect replacement load')
    local opens=current.opens;loader:ReadScene('Scenes/Test.xml',loader.generation-1)
    Check(current.opens==opens,'stale direct read token cannot open a file')
    loader:Cancel();Released(loader)
end
do
    local loader=New('download-failure-retry');Load(loader);loader:Update(0);Download(current.tasks[1],false)
    Check(loader.state=='failed' and #current.failures==1 and current.opens==0,'download failure reports once without parsing')
    Load(loader);Start(loader);Finish(loader)
    Check(loader.state=='ready' and current.activated==1 and #current.failures==1,'same loader retries after download failure')
end
do
    local loader=New('native-load-mode',{web=false});Load(loader);Start(loader)
    Check(loader.pending.mode==LOAD_SCENE_AND_RESOURCES and current.xmlLoads==0,'native retains resource-aware async mode without cache XML DOM')
    loader:Cancel();Released(loader)
end
for _,variant in ipairs({'missing','openError','sceneError','parseFalse','parseError'}) do
    local loader=New('error-'..variant,{[variant]=true});Load(loader);Start(loader);Tick(loader)
    Check(loader.state=='failed' and #current.failures==1 and current.activated==0,'native failure surfaces once: '..variant)
    Check(current.cleanup==1 and current.cancel==1,'native failure invokes cleanup/cancel once: '..variant)
    Released(loader)
    current[variant]=false;Load(loader);Start(loader);Finish(loader)
    Check(loader.state=='ready' and current.activated==1,'retry succeeds after native failure: '..variant)
end
do
    local loader=New('candidate-prepare-error',{prepare=function() error('candidate prepare exception') end})
    Load(loader);Start(loader)
    Check(loader.state=='failed' and current.parses==0 and #current.failures==1,'candidate prepare exception cannot start parse')
    Released(loader)
end
do
    local loader=New('candidate-prepare-cancel')
    loader.prepare=function() loader:Cancel() end
    Load(loader);Start(loader)
    Check(loader.state=='idle' and current.parses==0 and #current.failures==0,'reentrant candidate cancellation stops before parser')
    Released(loader)
end
do
    local loader=New('cancel-inflight-parse');Load(loader);Start(loader);loader:Cancel();Tick(loader)
    Check(current.activated==0 and #current.failures==0,'cancelled in-flight parse never activates')
    Released(loader)
end
do
    local loader=New('activation-failure',{activateError=true});Load(loader);Start(loader);Finish(loader)
    Check(loader.state=='failed' and #current.failures==1,'activation error stays observable')
    Released(loader)
end
do
    local prepared=0
    local loader=New('frame-sliced-prepare')
    Load(loader,{prepare=function(scene,checkpoint)
        for i=1,4 do current.now=current.now+4;prepared=i;checkpoint(i/4,'parts') end
    end});Start(loader);loader.pending.asyncLoading=false;loader.pending.asyncProgress=1
    Tick(loader);Tick(loader)
    Check(prepared==1 and loader.job~=nil and loader.state=='loading','prepare checkpoints still yield at 3ms budget')
    for _=1,8 do Tick(loader) end
    Check(prepared==4 and loader.state=='ready' and loader.prepareFrames==5,'all prepare slices finish before activation')
end
do
    local loader=New('cancel-partial-prepare')
    Load(loader,{prepare=function(_,checkpoint) current.now=current.now+4;checkpoint(.5,'parts');error('must be cancelled') end})
    Start(loader);loader.pending.asyncLoading=false;Tick(loader);Tick(loader);loader:Cancel()
    Check(#current.failures==0 and current.activated==0,'partial prepare cancellation closes coroutine before remaining work')
    Released(loader)
end
do
    local loader=New('web-array-warmup-order')
    Load(loader,{webWarmup={{type='Texture2DArray',name='array-a.xml'},{type='Texture2DArray',name='array-b.xml'}}})
    loader:Update(0);Download(current.tasks[1],true)
    Check(loader.phase=='resources' and current.opens==0,'Web retains texture staging before scene')
    for _=1,11 do Tick(loader) end
    Check(loader.phase=='scene' and current.parses==1 and loader.sceneProgressStart==.45,'array warmup retires staging frames then starts direct scene load')
    loader:Cancel();Released(loader)
end
do
    local loader=New('legacy-web-download-binding');cache.DownloadResources=nil;cache.GetResourceAsync=nil
    local paths={};local complete=false
    local manager={DownloadResources=function(_,resources) paths=resources;return 73 end,CancelGroup=function()end,
        GetResourceTaskState=function() return complete and DOWNLOAD_COMPLETED or DOWNLOAD_DOWNLOADING end}
    GetDownloadManager=function() return manager end
    Load(loader,{resources={'media.bin'}});loader:Update(0);Gate.UpdatePending(.1)
    Check(current.opens==0 and #paths==2,'legacy gate downloads raw scene without async resource binding')
    complete=true;for _,path in ipairs(paths) do current.localFiles[path]=true end
    Gate.UpdatePending(.1);Tick(loader)
    Check(current.parses==1 and current.xmlLoads==0,'legacy Web direct parse works after actual gate completes')
    loader:Cancel();Released(loader)
end
do
    local loader=New('environment-wait-cancel',{zones={{sourceTexture={}}},bakeReady=false})
    Load(loader);Start(loader);loader.pending.asyncLoading=false;Tick(loader)
    Check(loader.phase=='environment' and current.activated==0,'environment bake remains an activation gate')
    loader:Cancel();Released(loader)
end
return {pass=true,checks=checks,scenarios=scenarios}
