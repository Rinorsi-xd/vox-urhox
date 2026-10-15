package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function Check(ok,message)checks=checks+1;assert(ok,message)end
local now,download,metadata,reason=100,nil,nil,nil
local created,allocated,disposed,subscribed=0,0,0,0
Time={GetSystemTime=function()return now end}
function SubscribeToEvent()subscribed=subscribed+1 end
function UnsubscribeFromEvent()subscribed=subscribed-1 end
function Vector3(...)return {...}end;Vector3={RIGHT={},__call=function(_,...)return {...}end};setmetatable(Vector3,Vector3)
function Quaternion(...)return {...}end
Graphics={GetRGBAFormat=function()return 1 end};TEXTURE_RENDERTARGET=1;SURFACE_MANUALUPDATE=1;FILTER_BILINEAR=1
local surface={SetViewport=function()end,QueueUpdate=function()end,SetNumViewports=function()end}
Texture2D={new=function()allocated=allocated+1;return{SetNumLevels=function()end,SetSRGB=function()end,
    SetSize=function(_,w,h)Check(w==1024 and h==1024,'capture dimensions');return true end,
    SetData=function()return true end,SetFilterMode=function()end,GetRenderSurface=function()return surface end,
    Dispose=function()disposed=disposed+1 end}end}
function Viewport()end;Viewport={new=function()return{SetRenderPath=function()end}end}
renderer={GetDefaultRenderPath=function()return{Clone=function()return{}end}end}
local scene={CreateChild=function()created=created+1;return{CreateComponent=function()return{}end,Dispose=function()end}end}
local image={width=1024,height=1024,compressed=false}
cache={DownloadResources=function(_,paths,callback)Check(#paths==2,'only optional map resources');download=callback end,
    GetFile=function(_,path)Check(path=='Scenes/Crater.xml','checked expected input');return{size=50,GetChecksum=function()return reason=='checksum' and 11 or 10 end,Dispose=function()end}end,
    GetResource=function()return image end}
package.loaded['render.RenderTargetLifetime']={Retire=function()end}
package.loaded['core.ResourceData']={Read=function()if reason=='missing'then error('Missing')end;return metadata end}
local Map=require'render.MatchMapShot'
local function Meta()return{version=1,revision='crater-static-v1',scene='Scenes/Crater.xml',size=1024,half=320,image='Crater/Minimap.bin',runtimeChecks={['Scenes/Crater.xml']={bytes=50,checksum=10}}}end
Map.Initialize();Map.Initialize();Check(subscribed==2,'main-thread subscription is idempotent')
metadata=Meta();local map={scene='Scenes/Crater.xml'}
local job=Map.New(scene,map);Check(job.bakePending and created==0,'optional download creates no camera');job:Update();Check(not job.ready,'waits real download callback')
download(true,0);job:Update();Check(job.ready and job.baked and job.progress==1,'valid lossless base completes without capture');Check(created==0 and allocated==1,'no runtime RT or geometry for baked route')
local texture,half=job:Take();Check(texture and half==320,'original texture ownership transfer');job:Dispose();Check(disposed==0,'disposed job cannot free transferred texture');texture:Dispose();Check(disposed==1,'receiver releases texture once')
for _,failure in ipairs({'checksum','missing','contract','dimensions','download'})do
    reason=failure;metadata=Meta();if failure=='contract'then metadata.half=321 end;image.width=failure=='dimensions'and 100 or 1024
    local before=created;job=Map.New(scene,map);download(failure~='download',failure=='download'and 1 or 0);job:Update()
    Check(not job.baked and not job.ready and created==before+1,'real capture fallback '..failure);Check(job.texture~=nil,'fallback owns capture RT '..failure);job:Dispose()
end
reason=nil;image.width=1024;metadata=Meta()
job=Map.New(scene,map);local callback=download;local before=created;job:Dispose();callback(true,0);Check(created==before and not job.result,'late optional download after cancellation is ignored')
job=Map.New(scene,map);now=10101;job:Update();Check(job.texture~=nil and not job.baked,'stalled optional download falls back after bounded wait');job:Dispose()
before=created;job=Map.New(scene,{scene='Scenes/EnginePit.xml'});Check(created==before+1 and not job.bakePending,'other maps retain original capture');job:Dispose()
Map.Shutdown();Check(subscribed==0,'shutdown unregisters callbacks');Map.Initialize();Check(subscribed==2,'reload registers again');Map.Shutdown()
return{assertions=checks}
