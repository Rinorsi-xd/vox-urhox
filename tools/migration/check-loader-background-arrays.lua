package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local now,checks,loader,queueCalls,syncCalls,failures=0,0,nil,0,0,0
local existing,queued={},{ }
Time={GetSystemTime=function() return now end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return true end}
package.loaded['app.ResourceGate']={New=function() return {Cancel=function() end} end}
local Loader=assert(load(LOADER_SOURCE))()
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Resource() return {memoryUse=33554792,width=1024,height=1024} end
local function New()
    now=0;queueCalls=0;syncCalls=0;failures=0;existing={};queued={}
    cache={
        GetExistingResource=function(_,kind,name) Check(kind=='Texture2DArray','original resource type');return existing[name] end,
        BackgroundLoadResource=function(_,kind,name,sendFailure)
            Check(kind=='Texture2DArray' and sendFailure==true,'original queue type and failure reporting')
            queueCalls=queueCalls+1;queued[#queued+1]=name;return false
        end,
        GetResource=function() syncCalls=syncCalls+1;error('blocking fallback forbidden') end,
        GetTotalMemoryUse=function() return 67109584 end,
    }
    loader=Loader.New();loader.state='loading';loader.phase='resources'
    loader.options={webWarmup={{type='Texture2DArray',name='a.xml'},{type='Texture2DArray',name='n.xml'}}}
    loader.onError=function() failures=failures+1 end
    return loader
end
local function Tick() now=now+16;loader:Update(0) end
local function Fence()
    for i=1,3 do Tick();Check(loader.warmWait==3-i,'three original staging fence updates') end
end

New();Tick()
Check(queueCalls==1 and loader.warmIndex==1 and loader.warmPending.token==loader.generation,'cold array queues once with cancellation token')
for _=1,8 do Tick() end
Check(queueCalls==1 and loader.warmIndex==1,'queue false means already pending; repeated updates only poll')
existing['a.xml']={width=0,height=0}
Tick();Check(loader.warmIndex==1 and queueCalls==1,'incomplete cache object remains pending')
existing['a.xml']=Resource();Tick()
Check(loader.warmIndex==2 and loader.warmPending==nil and loader.warmWait==3,'ready array completes before next array queues')
Fence();Tick();Check(queueCalls==2 and queued[2]=='n.xml','second array queued only after first fence')
existing['n.xml']=Resource();Tick();Fence();Tick()
Check(loader.phase=='scene' and loader.readSceneToken==loader.generation and syncCalls==0,'both arrays ready before parser stage, without synchronous fallback')

New();existing['a.xml']=Resource();existing['n.xml']=Resource()
Tick();Fence();Tick();Fence();Tick()
Check(queueCalls==0 and loader.phase=='scene','warm cache reuses exact prepared resources')

New();Tick();now=20017;loader:Update(0)
Check(loader.state=='failed' and failures==1 and loader.warmPending==nil,'wall clock deadline fails without timestep progression')
loader:Update(100);Check(failures==1,'timeout callback occurs once')

New();Tick();local token=loader.generation;loader:Cancel()
Check(loader.generation~=token and loader.warmPending==nil,'cancel clears pending token')
existing['a.xml']=Resource();Tick()
Check(loader.state=='idle' and loader.warmIndex==1 and failures==0,'late cache completion cannot revive cancelled loader')

New();Tick();loader.generation=loader.generation+1;Tick()
Check(loader.warmPending==nil and loader.warmIndex==1,'stale poll token cannot advance replacement generation')

New();cache.GetExistingResource=function() error('cache inspection failed') end;Tick()
Check(loader.state=='failed' and failures==1,'inspection exception is observable')
New();cache.BackgroundLoadResource=function() error('native queue failed') end;Tick()
Check(loader.state=='failed' and failures==1 and loader.warmPending==nil,'queue exception cancels pending ownership')

New();Tick();loader:Cancel();existing['a.xml']=Resource()
loader.state='loading';loader.phase='resources';loader.options={webWarmup={{type='Texture2DArray',name='a.xml'}}}
Tick();Fence();Tick()
Check(loader.phase=='scene' and failures==0 and queueCalls==1,'retry may reuse completed shared cache object without stale callbacks')
return {checks=checks,result='PASS'}
