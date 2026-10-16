-- Real IntroSession/OpeningHost/SceneLoader/ResourceGate; native I/O is controlled.
package.path='scripts/?.lua;'..package.path
local checks={};local events={};local jobs={};local localFiles={};local mode='async';local nativeReads=0
local audioSteps=0;local dependencyReads=0;local prepares=0;local viewportWrites=0;local cancelled={}
local audioFailure=false;local synchronousCancel=false
local function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
local function Noop()end
local function Module(name,value)package.loaded[name]=value end
local function Count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function Reset(cached)
 events={};jobs={};localFiles={};mode=cached and 'cached' or 'async';nativeReads=0
 audioSteps=0;dependencyReads=0;prepares=0;viewportWrites=0;cancelled={}
 audioFailure=false;synchronousCancel=false
end
Time={GetSystemTime=function()return 0 end};input={};MM_ABSOLUTE=1
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
local UI={GetFocus=Noop,ClearFocus=Noop,SetRoot=Noop,PushOverlay=Noop,PopOverlay=Noop}
Module('urhox-libs/UI',UI)
Module('urhox-libs.Platform.PlatformUtils',{IsWebPlatform=function()return true end})
Module('core.Coord',{})
Module('core.ResourceData',{Read=function(path)
 if path=='Intro/Intro.json'then return PREFETCH_DATA end
 if path=='Crater/Resources.json'then return {'map-a','map-b','map-a'}end
 if path=='Combat/MissileView.json'then return PREFETCH_MISSILES end
 error('unexpected data '..path)
end})
Module('ui.IntroTypography',{Dependencies=function()return {'font-a'}end})
Module('ui.IntroPage',{New=function()return {imageWarmup={ready=true},Close=Noop}end})
Module('audio.IntroAudio',{New=function()
 local prepared=0
 return {Update=Noop,Dispose=Noop,PrepareNext=function()
  prepared=prepared+1;audioSteps=audioSteps+1;events[#events+1]='audio'
  if audioFailure and prepared==8 then return false,'injected audio decode failure' end
  return prepared==55
 end}
end})
Module('ui.GarageHud',{Dispose=Noop})
Module('scene.Crater',{Release=Noop})
local BP={};function BP.New()return setmetatable({},{__index=BP})end
function BP:Load(source)self.source=source;return self end
function BP:ToTable()return self.source or PREFETCH_DATA.actors.hero end
function BP:List()return self.source.parts end
Module('construction.Blueprint',BP)
Module('parts.Dependencies',{For=function()dependencyReads=dependencyReads+1;return {'part-a','part-a','part-b'}end})
Module('ui.WeaponIconResources',{For=function()return {'icon-a','part-a'}end})
for _,name in ipairs({'WeaponAudio','DrivingAudio','CombatFeedbackAudio'})do
 Module('audio.'..name,{Dependencies=function()return {'sound-'..name,'part-a'}end})
end
Module('app.DriveMaps',{crater={scene='Scenes/Crater.xml',resources='Crater/Resources.json',webWarmup={}}})
cache={}
function cache:Exists(path)return mode=='cached' or localFiles[path]==true end
function cache:DownloadResources(paths,done,progress)
 local copy={};for i,path in ipairs(paths)do copy[i]=path end
 local id=#jobs+1;jobs[id]={paths=copy,done=done,progress=progress};events[#events+1]='download'
 if mode=='sync' then for _,path in ipairs(copy)do localFiles[path]=true end;done(true,0) end
 return id
end
function cache:CancelDownloadGroup(id)
 cancelled[id]=(cancelled[id] or 0)+1
 if synchronousCancel and jobs[id].done then jobs[id].done(false,1) end
end
local modernDownload=cache.DownloadResources
DOWNLOAD_COMPLETED='complete';DOWNLOAD_FAILED='failed';DOWNLOAD_CANCELLED='cancelled'
local legacy={}
function legacy:DownloadResources(paths)
 local copy={};for i,path in ipairs(paths)do copy[i]=path end
 local id=#jobs+1;jobs[id]={paths=copy,states={}};return id
end
function legacy:GetResourceTaskState(path)
 for _,job in ipairs(jobs)do if job.states and job.states[path]then return job.states[path]end end
 return 'pending'
end
function legacy:CancelGroup(id)cancelled[id]=(cancelled[id]or 0)+1 end
GetDownloadManager=function()return legacy end
function cache:GetFile(path)
 Check(audioSteps>=55,'scene native read follows complete audio preparation')
 nativeReads=nativeReads+1;return {Dispose=Noop}
end
function Scene()
 return {asyncLoading=true,asyncProgress=0,LoadAsyncXML=function()return true end,StopAsyncLoading=Noop,Dispose=Noop}
end
LOAD_SCENE=1;LOAD_SCENE_AND_RESOURCES=2
local function Complete(id,ok)
 local job=assert(jobs[id]);if ok then for _,path in ipairs(job.paths)do localFiles[path]=true end end
 if job.done then job.done(ok,ok and 0 or 1)
 else for _,path in ipairs(job.paths)do job.states[path]=ok and DOWNLOAD_COMPLETED or DOWNLOAD_FAILED end end
end
local Host=require('app.OpeningHost');local Intro=require('intro.IntroSession')
local function App()
 return {scene={},blueprint=BP.New(),camera={node={position={},rotation={}},camera={fov=50}},car={root={enabled=true},SetVisible=Noop},
  graphicsSettings={Show=function()viewportWrites=viewportWrites+1 end},DeferAssetRelease=function(_,fn)fn()end}
end
local function New(app)
 app=app or App();local host=Host.New(app);local prepare=host.Prepare
 host.Prepare=function(...)prepares=prepares+1;return prepare(...)end
 local intro=Intro.New(app,host);app.opening=intro
 Check(intro:Start(),'fresh opening starts');return intro,host,app
end
local function Tick(intro,n)for _=1,n do intro:Update(1/60,true)end end
local function Unique(job)
 local names={};for _,p in ipairs(job.paths)do names[p]=(names[p]or 0)+1 end
 return Count(names)==#job.paths,names
end

Reset();local intro,host=New()
Check(#jobs==1 and not intro.scenePrefetching,'Start creates only the media group outside ordinary update')
Tick(intro,1)
Check(#jobs==2 and intro.scenePrefetching and audioSteps==0 and not intro.downloaded,'first ordinary boot update overlaps raw scene and pending media groups without audio decode')
Complete(1,true)
Check(#jobs==2 and intro.downloaded and audioSteps==0,'media completion does not create another group inside callback dispatch')
Tick(intro,1)
Check(#jobs==2 and intro.scenePrefetching and audioSteps==1 and events[2]=='download' and events[3]=='audio','first opening update starts raw request before its first audio preparation')
local unique,names=Unique(jobs[2]);Check(unique and names['Scenes/Crater.xml']==1 and names['part-a']==1,'real ResourceGate deduplicates scene and repeated part dependencies')
for _,name in ipairs({'WeaponAudio','DrivingAudio','CombatFeedbackAudio'})do Check(names['sound-'..name]==1,'shared '..name..' raw bytes join prefetch before audio decode')end
Check(names['Equipment/plasma-flow.png']==1,'actual equipment flow texture joins raw prefetch')
for _,path in ipairs(require('render.MissileView').Dependencies())do Check(names[path]==1,'actual missile view joins raw prefetch before audio/scene construction: '..path)end
Tick(intro,53)
Check(audioSteps==54 and prepares==0 and nativeReads==0 and viewportWrites==0 and not intro.ready,'pending raw download overlaps first 54 audio frames without native scene work or reveal')
Tick(intro,1)
Check(intro.audioReady and prepares==0 and not intro.ready,'audio completion waits for outstanding raw download')
Complete(2,true)
Check(prepares==1 and intro.scenePreparing and not intro.ready,'raw completion starts preparation once after audio readiness, without revealing')
Check(host.state.loader.options.resources==host.state.resources and dependencyReads==1,'prefetch and loader share one computed actor/map dependency list')
intro:PrefetchScene();host.Prefetch(intro,Noop,Noop)
Tick(intro,1)
Check(#jobs==2 and prepares==1,'loader and repeated prefetch calls do not start another download group for cached bytes')
Check(nativeReads==0 and viewportWrites==0,'local readiness check does not decode or change viewport')
Tick(intro,1)
Check(nativeReads==1 and not intro.ready,'normal asynchronous scene read remains behind both readiness gates')
intro:Dispose()
Check(intro.disposed and host.state.disposed,'disposal releases prefetch owner and normal loader')
Check(not intro:Start(),'disposed opening cannot reenter with stale callbacks')

Reset();intro,host=New();Complete(1,true);Tick(intro,1);Complete(2,true)
Tick(intro,53)
Check(intro.sceneDownloaded and prepares==0 and nativeReads==0 and viewportWrites==0,'early raw completion never starts scene work before audio')
Tick(intro,1)
Check(prepares==1 and audioSteps==55 and not intro.ready,'audio completion starts normal scene preparation after early download')
intro:Dispose()

Reset(true);intro,host=New()
Tick(intro,1)
Check(#jobs==0 and intro.sceneDownloaded and dependencyReads==1,'all-local resources complete prefetch synchronously on first update without a download group')
Tick(intro,54)
Check(prepares==1 and #jobs==0 and not intro.ready,'all-local path still prepares 55 audio frames and keeps scene reveal gated')
intro:Dispose()

Reset();intro,host=New();Complete(1,true);Tick(intro,1);Complete(2,false);Tick(intro,60)
Check(intro.failed and intro.error~='' and prepares==0 and nativeReads==0 and not intro.ready,'prefetch failure stops native preparation and scene reveal')
local failedError=intro.error;Complete(2,true)
Check(intro.error==failedError and not intro.sceneDownloaded,'late success cannot override a failed prefetch')
intro:Dispose()

Reset();intro,host=New();synchronousCancel=true;Tick(intro,1);Complete(1,false);Tick(intro,60)
local mediaError=intro.error
Check(#jobs==2 and intro.failed and prepares==0 and audioSteps==0 and nativeReads==0,'media download failure blocks audio and construction while raw bytes were pending')
Check(cancelled[2]==1 and host.state.prefetchGate==nil and host.state.prefetchIntro==nil,'media failure cancels concurrently pending raw group and releases its owner')
Complete(2,true);Complete(2,false);Complete(1,true)
Check(intro.error==mediaError and not intro.downloaded and not intro.sceneDownloaded and not intro.ready,'synchronous cancel and late raw/media callbacks preserve first media error')
intro:Dispose()
Check(cancelled[2]==1,'media failure followed by disposal does not recancel raw group')

Reset();intro,host=New();Tick(intro,1);Complete(2,false)
local sceneError=intro.error;Complete(1,false);Complete(1,true);Tick(intro,60)
Check(intro.error==sceneError and not intro.downloaded and audioSteps==0 and prepares==0,'late media failure and success preserve an earlier scene failure')
intro:Dispose()

Reset();intro,host=New();Tick(intro,1);Complete(2,true);Tick(intro,60)
Check(intro.sceneDownloaded and not intro.downloaded and not intro.audioReady and audioSteps==0 and prepares==0 and nativeReads==0,'raw group may finish before media without decoding audio or constructing scene')
Complete(1,true);Tick(intro,55)
Check(intro.audioReady and prepares==1,'media completion after early raw readiness still requires all 55 audio preparation frames')
intro:Dispose()

Reset();intro,host=New();Complete(1,true)
Tick(intro,1)
local raw=jobs[2];local oldError=intro.error;intro:Dispose()
Check(cancelled[2]==1,'closing during raw prefetch cancels its own download group exactly once')
raw.done(true,0);raw.done(false,1)
Check(not intro.sceneDownloaded and intro.error==oldError and prepares==0,'stale completion and failure do not write disposed session')
local newer,newHost=New();Tick(newer,1)
Check(#jobs==3 and not newer.sceneDownloaded,'new opening reuses local media and owns a separate current raw request')
raw.done(true,0);raw.done(false,1)
Check(not newer.sceneDownloaded and not newer.failed and not cancelled[3],'old callbacks cannot finish, fail, or cancel new opening')
Complete(3,true);Tick(newer,54)
Check(prepares==1 and newer.scenePreparing,'new opening still prepares after its own successful prerequisites')
newer:Dispose()

Reset();intro,host=New();local oldMedia=jobs[1];intro:Dispose();oldMedia.done(true,0)
Check(#jobs==1 and not intro.scenePrefetching,'media completion after disposal cannot create prefetch')

Reset();intro,host=New();Tick(intro,1)
local pendingMedia,pendingRaw=jobs[1],jobs[2];intro:Dispose()
Check(cancelled[1]==1 and cancelled[2]==1,'disposal while both raw groups are pending cancels each owned group once')
pendingMedia.done(true,0);pendingRaw.done(true,0);pendingMedia.done(false,1);pendingRaw.done(false,1)
Check(not intro.downloaded and not intro.sceneDownloaded and not intro.failed and prepares==0,'late concurrent group callbacks cannot mutate disposed opening')

Reset();local app=App();host=Host.New(app)
local owner={data=PREFETCH_DATA};local replacement={data=PREFETCH_DATA};local firstDone=0;local secondDone=0
host.Prefetch(owner,function()firstDone=firstDone+1 end,Noop)
host.Prefetch(owner,function()error('duplicate owner callback')end,Noop)
Check(#jobs==1 and dependencyReads==1,'same host owner does not recompute dependencies or duplicate raw download')
host.Prefetch(replacement,function()secondDone=secondDone+1 end,Noop)
Check(#jobs==2 and cancelled[1]==1 and dependencyReads==2,'replacement host owner cancels previous group and computes its own dependencies once')
Complete(1,true);Check(firstDone==0 and secondDone==0,'replaced host owner ignores old completion')
host.CancelPrefetch(owner)
Check(not cancelled[2],'stale owner cancellation cannot cancel replacement group')
Complete(2,true);Check(secondDone==1,'replacement host owner completes independently')
host.Dispose()

Reset(true);local prepared=0
local oldHost={Begin=Noop,Prepare=function()prepared=prepared+1 end,Dispose=Noop}
intro=Intro.New(App(),oldHost);intro:Start();Tick(intro,54)
Check(prepared==0,'host without optional hook preserves audio-before-scene ordering')
Tick(intro,1);Check(prepared==1 and not intro.ready,'host without optional hook remains compatible and does not reveal early');intro:Dispose()

Reset(true);local thrown={Begin=Noop,Prefetch=function()error('prefetch injected failure')end,Prepare=function()error('unexpected prepare')end,Dispose=Noop}
intro=Intro.New(App(),thrown);intro:Start();Tick(intro,55)
Check(intro.failed and intro.error:find('prefetch injected failure',1,true) and not intro.ready,'optional hook exception becomes controlled loading failure');intro:Dispose()

Reset();mode='sync';intro,host=New();Tick(intro,1)
Check(#jobs==2 and intro.sceneDownloaded and not intro.audioReady and prepares==0,'DownloadResources can synchronously complete media and raw requests without early native work')
Check(intro.gate.group==nil and host.state.prefetchGate.group==nil,'synchronous completion before returned group ID does not restore completed groups')
Tick(intro,54)
Check(prepares==1 and not intro.ready and #jobs==2,'synchronously downloaded bytes still wait for audio and normal scene preparation')
intro:Dispose();Check(next(cancelled)==nil,'disposing completed synchronous groups does not cancel stale returned IDs')

Reset();audioFailure=true;synchronousCancel=true;intro,host=New();Complete(1,true);Tick(intro,8)
Check(intro.failed and intro.error=='injected audio decode failure' and prepares==0,'audio failure preserves its own first error and blocks construction')
Check(cancelled[2]==1 and host.state.prefetchGate==nil and host.state.prefetchIntro==nil,'audio failure immediately cancels and releases pending raw prefetch owner')
Complete(2,true);Complete(2,false);Tick(intro,55)
Check(not intro.sceneDownloaded and not intro.ready and prepares==0 and intro.error=='injected audio decode failure','late completion or synchronous cancellation callback cannot override audio failure')
host.CancelPrefetch(intro);intro:Dispose()
Check(cancelled[2]==1,'repeated cancellation and disposal do not recancel retired raw group')

Reset();cache.DownloadResources=nil;intro,host=New();Tick(intro,1)
local function Pump(gate)
 for _=1,100 do if gate.state~='loading'then return end;require('app.ResourceGate').UpdatePending(.1)end
 error('legacy gate failed to drain')
end
Check(#jobs==2 and intro.scenePrefetching and not intro.downloaded and audioSteps==0,'legacy manager owns two concurrent groups before media completes')
Complete(1,true);Pump(intro.gate)
Check(#jobs==2 and intro.downloaded and prepares==0,'legacy media completion drains pending scan without starting another group or native work')
Tick(intro,1)
Check(#jobs==2 and intro.scenePrefetching and audioSteps==1,'shipped legacy manager starts raw prefetch before first audio preparation')
Tick(intro,53);Complete(2,true);Pump(host.state.prefetchGate)
Check(intro.sceneDownloaded and prepares==0 and nativeReads==0,'legacy raw completion preserves audio-before-native gate')
Tick(intro,1);Tick(intro,1)
Check(prepares==1 and #jobs==2 and not intro.ready,'legacy branch reuses all downloaded bytes during normal loader readiness')
intro:Dispose()

Reset();intro,host=New();Tick(intro,1);Complete(2,true);Pump(host.state.prefetchGate);Tick(intro,55)
Check(intro.sceneDownloaded and not intro.downloaded and audioSteps==0 and prepares==0,'legacy raw-first completion keeps media and audio prerequisites intact')
Complete(1,true);Pump(intro.gate);Tick(intro,55)
Check(prepares==1 and audioSteps==55,'legacy raw-first path prepares only after media and all audio are ready');intro:Dispose()

Reset();intro,host=New();Tick(intro,1);Complete(1,false);Pump(intro.gate)
local legacyMediaError=intro.error
Check(intro.failed and cancelled[2]==1 and host.state.prefetchGate==nil and audioSteps==0,'legacy media failure cancels concurrently pending raw group')
Complete(2,true);require('app.ResourceGate').UpdatePending(.1);Tick(intro,55)
Check(intro.error==legacyMediaError and not intro.sceneDownloaded and prepares==0,'legacy cancelled raw polling cannot replace media failure')
intro:Dispose();Check(cancelled[2]==1,'legacy failure disposal cancels raw group only once')

Reset();intro,host=New();Tick(intro,1);intro:Dispose()
Check(cancelled[1]==1 and cancelled[2]==1,'legacy disposal cancels both concurrently pending groups')
Complete(1,true);Complete(2,true);require('app.ResourceGate').UpdatePending(.1)
Check(not intro.downloaded and not intro.sceneDownloaded and prepares==0,'legacy late task completion after disposal cannot revive either group')
cache.DownloadResources=modernDownload

do
 local read=package.loaded['core.ResourceData'].Read
 package.loaded['core.ResourceData'].Read=function(path)return PREFETCH_SOUNDS[path] or read(path)end
 local expected={['Equipment/plasma-flow.png']=true}
 for _,path in ipairs(require('render.MissileView').Dependencies())do expected[path]=true end
 for _,name in ipairs({'WeaponAudio','DrivingAudio','CombatFeedbackAudio'})do
  package.loaded['audio.'..name]=nil
  for _,path in ipairs(require('audio.'..name).Dependencies())do expected[path]=true end
 end
 local actual={};for _,path in ipairs(Host.Dependencies(App(),PREFETCH_DATA))do actual[path]=true end
 for path in pairs(expected)do Check(actual[path],'real shared audio/equipment dependency is prefetched: '..path)end
 for _,path in ipairs(PREFETCH_LATE)do if expected[path]then Check(actual[path],'historical constructor late resource still consumed is covered: '..path)end end
end

return {checks=checks,count=#checks}
