package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function Check(ok,message)checks=checks+1;assert(ok,message)end
local now,download,metadata,reason=100,nil,nil,nil
local created,allocated,disposed,subscribed=0,0,0,0
local cancels,legacyCancels,downloads=0,0,0
local cached,legacyReady,legacyState=false,false,0
local uploadFailure,filterFailure=false,false
Time={GetSystemTime=function()return now end}
function GetTime()return{frameNumber=10}end
function SubscribeToEvent()subscribed=subscribed+1 end
function UnsubscribeFromEvent()subscribed=subscribed-1 end
Vector3={RIGHT={},__call=function(_,...)return {...}end};setmetatable(Vector3,Vector3)
function Quaternion(...)return {...}end
function Color(r,g,b,a)return{ToUInt=function()return(math.floor(r*255))|(math.floor(g*255)<<8)|(math.floor(b*255)<<16)|(math.floor(a*255)<<24)end}end
Graphics={GetRGBAFormat=function()return 1 end};TEXTURE_RENDERTARGET=1;SURFACE_MANUALUPDATE=1;FILTER_BILINEAR=1
DOWNLOAD_COMPLETED=1;DOWNLOAD_FAILED=2;DOWNLOAD_CANCELLED=3
local surface={SetViewport=function()end,QueueUpdate=function()end,SetNumViewports=function()end}
Texture2D={new=function()
    allocated=allocated+1;local released=false
    return{SetNumLevels=function()end,SetSRGB=function()end,
        SetSize=function(_,w,h)Check(w==1024 and h==1024,'capture dimensions');return true end,
        SetData=function()return not uploadFailure end,
        SetFilterMode=function()if filterFailure then error('Filter setup failed')end end,
        GetRenderSurface=function()return surface end,
        Dispose=function()Check(not released,'texture released exactly once');released=true;disposed=disposed+1 end}
end}
Viewport={new=function()return{SetRenderPath=function()end}end}
renderer={GetDefaultRenderPath=function()return{Clone=function()return{}end}end}
local scene={CreateChild=function()created=created+1;return{CreateComponent=function()return{}end,Dispose=function()end}end}
local image={width=1024,height=1024,compressed=false}
cache={Exists=function()return cached or legacyReady end,
    CancelDownloadGroup=function(_,group)Check(group==91,'cancel owns modern download group');cancels=cancels+1 end,
    GetFile=function(_,path)Check(path=='Scenes/Crater.xml','checked expected input');return{size=50,GetChecksum=function()return reason=='checksum'and 11 or 10 end,Dispose=function()end}end,
    GetResource=function()return image end}
local manager={DownloadResources=function(_,paths)Check(#paths==2,'legacy optional resources only');downloads=downloads+1;return 92 end,
    GetResourceTaskState=function()return legacyState end,
    CancelGroup=function(_,group)Check(group==92,'cancel owns legacy group');legacyCancels=legacyCancels+1 end}
function GetDownloadManager()return manager end
local function Backend(mode)
    cached=false;legacyReady=false;legacyState=0;download=nil
    if mode=='legacy'then cache.DownloadResources=nil;return end
    cache.DownloadResources=function(_,paths,callback)
        Check(#paths==2,'only optional map resources');downloads=downloads+1;download=callback
        if mode=='throw'then error('Download binding failure')end
        if mode=='sync'then callback(true,0)end
        return 91
    end
end
package.loaded['render.RenderTargetLifetime']={Retire=function()end}
package.loaded['core.ResourceData']={Read=function()if reason=='missing'then error('Missing')end;return metadata end}
local Gate=require'app.ResourceGate'
local Map=require'render.MatchMapShot'
local function Meta()return{version=1,revision='crater-static-v1',scene='Scenes/Crater.xml',size=1024,half=320,image='Crater/Minimap.bin',runtimeChecks={['Scenes/Crater.xml']={bytes=50,checksum=10}}}end
Map.Initialize();Map.Initialize();Check(subscribed==2,'main-thread subscription is idempotent')
metadata=Meta();local map={scene='Scenes/Crater.xml'};Backend('async')
local job=Map.New(scene,map);Check(job.bakePending and created==0,'optional download creates no camera');job:Update();Check(not job.ready,'waits real download callback')
download(true,0);job:Update();Check(job.ready and job.baked and job.progress==1,'valid lossless base completes without capture');Check(created==0 and allocated==1,'no runtime RT or geometry for baked route')
local texture,half=job:Take();Check(texture and half==320,'original texture ownership transfer');job:Dispose();Check(disposed==0,'disposed job cannot free transferred texture');texture:Dispose();Check(disposed==1,'receiver releases texture once')
for _,mode in ipairs({'sync','cached'})do
    Backend(mode);cached=mode=='cached';local before=downloads
    job=Map.New(scene,map);job:Update();Check(job.baked and not job.bakeGate,'synchronous completion '..mode)
    Check(downloads==before+(mode=='cached'and 0 or 1),'cached readiness avoids download '..mode);job:Dispose()
end
for _,failure in ipairs({'checksum','missing','contract','dimensions','download','upload','filter'})do
    Backend('async');reason=failure;metadata=Meta();if failure=='contract'then metadata.half=321 end
    image.width=failure=='dimensions'and 100 or 1024
    uploadFailure=failure=='upload';filterFailure=failure=='filter'
    local before=created;local beforeDisposed=disposed
    job=Map.New(scene,map);download(failure~='download',failure=='download'and 1 or 0);job:Update()
    Check(not job.baked and not job.ready and created==before+1,'real capture fallback '..failure)
    Check(job.texture~=nil and job.uploadTexture==nil,'fallback retains only capture RT '..failure)
    Check(disposed==beforeDisposed+((uploadFailure or filterFailure)and 1 or 0),'failed baked upload released '..failure)
    job:Dispose()
end
reason=nil;image.width=1024;metadata=Meta();uploadFailure=false;filterFailure=false
Backend('async');job=Map.New(scene,map);local callback=download;local before=created;local beforeCancels=cancels
job:Dispose();job:Dispose();callback(true,0)
Check(cancels==beforeCancels+1,'Dispose cancels pending modern group once')
Check(created==before and not job.result and not job.bakePending,'late cancelled callback cannot activate baked map')
Backend('async');job=Map.New(scene,map);callback=download;beforeCancels=cancels;now=now+9999;job:Update()
Check(not job.texture and job.bakePending,'timeout does not fire early');now=now+1;job:Update()
Check(cancels==beforeCancels+1 and not job.bakeGate,'10 second timeout cancels modern group')
Check(job.texture~=nil and not job.baked,'timeout preserves live fallback');callback(true,0);job:Update()
Check(not job.baked and not job.bakeFinished,'late timeout callback stays ignored');job:Dispose()
Backend('throw');job=Map.New(scene,map);job:Update();Check(job.texture~=nil and not job.bakeGate,'download exceptions fall back safely');job:Dispose()
Backend('legacy');job=Map.New(scene,map);legacyReady=true;legacyState=DOWNLOAD_COMPLETED;Gate.UpdatePending(.1);job:Update()
Check(job.baked and not job.bakeGate,'legacy task polling loads real baked map');job:Dispose()
Backend('legacy');job=Map.New(scene,map);local beforeLegacy=legacyCancels;job:Dispose();legacyReady=true;legacyState=DOWNLOAD_COMPLETED;Gate.UpdatePending(.1)
Check(legacyCancels==beforeLegacy+1 and not job.result,'legacy Dispose terminates and removes polling job')
Backend('legacy');job=Map.New(scene,map);beforeLegacy=legacyCancels;now=now+10000;job:Update()
Check(legacyCancels==beforeLegacy+1 and job.texture~=nil,'legacy timeout terminates own group and captures');job:Dispose()
Backend('legacy');job=Map.New(scene,map);legacyState=DOWNLOAD_FAILED;Gate.UpdatePending(.1);job:Update()
Check(job.texture~=nil and not job.baked,'legacy failed download preserves fallback');job:Dispose()
local originalManager=manager;manager=nil;Backend('legacy');job=Map.New(scene,map);job:Update()
Check(job.texture~=nil,'missing legacy manager preserves fallback');job:Dispose();manager=originalManager
for _,failure in ipairs({'upload','filter'})do
    local imageDisposed=0;local beforeDisposed=disposed
    job=setmetatable({size=1,captured=true,image={GetPixelInt=function()return 0xff808080 end,SetPixelInt=function()end,Dispose=function()imageDisposed=imageDisposed+1 end}},Map)
    job.worker=coroutine.create(function()job:Process()end)
    uploadFailure=failure=='upload';filterFailure=failure=='filter'
    local ok,message=pcall(job.Update,job)
    Check(not ok and tostring(message):find(failure=='upload'and'Cannot upload minimap base'or'Filter setup failed',1,true),'Process reports original '..failure..' failure')
    Check(job.disposed and disposed==beforeDisposed+1 and imageDisposed==1,'Process releases texture and image '..failure)
    job:Dispose();Check(disposed==beforeDisposed+1 and imageDisposed==1,'Process failure cleanup is idempotent '..failure)
end
uploadFailure=false;filterFailure=false;Backend('async')
before=created;job=Map.New(scene,{scene='Scenes/EnginePit.xml'});Check(created==before+1 and not job.bakePending,'other maps retain original capture');job:Dispose()
Map.Shutdown();Check(subscribed==0,'shutdown unregisters callbacks');Map.Initialize();Check(subscribed==2,'reload registers again');Map.Shutdown()
return{assertions=checks}
