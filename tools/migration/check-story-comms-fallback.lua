package.path='scripts/?.lua;'..package.path
local checks,plays,background,lookups,cancelled,sceneDisposals=0,0,0,0,0,0
local existing,downloads,requested={}, {}, {}
local inCallback=false
local function Complete(job,ok)
 inCallback=true;job.complete(ok);inCallback=false
end
local function Check(value,message) checks=checks+1;assert(value,message) end
Scene=function() return {CreateChild=function() return {CreateComponent=function() return {
 SetSoundType=function() end,StopImmediate=function(self) self.playing=false end,
} end} end,Dispose=function() sceneDisposals=sceneDisposals+1 end} end
input={focus=true,minimized=false}
audio={PauseSoundType=function() end,ResumeSoundType=function() end}
cache={Exists=function() return false end,
 DownloadResources=function(_,paths,complete)
  local id=#downloads+1;downloads[id]={path=paths[1],complete=complete};return id
 end,
 CancelDownloadGroup=function() cancelled=cancelled+1 end,
 GetResource=function() error('legacy fallback synchronously decoded a Sound') end,
 GetExistingResource=function(_,kind,path) Check(not inCallback,'download completion never queries Sound cache');Check(kind=='Sound','legacy readiness only inspects audio cache');lookups=lookups+1;return existing[path] end,
 BackgroundLoadResource=function(_,kind,path) Check(not inCallback,'download completion never submits Sound decoding');Check(kind=='Sound','legacy fallback requests background Sound decoding');background=background+1;requested[path]=true end,
}
package.preload['audio.AudioLevels']=function() return {
 Play=function(source) source.playing=true;plays=plays+1 end,RawGain=function() return .4 end,
 SetGain=function() end,SetSpeaking=function() end,
} end
package.preload['ui.CommsCard']=function() return {Tick=function() end,Dispose=function() end} end
package.preload['audio.StoryCommsCues']=function() return {New=function() return {
 Play=function() end,Update=function() end,Dispose=function() end,
} end} end
local C=TEST_CODE and assert(load(TEST_CODE,'StoryComms negative'))() or require 'audio.StoryComms'
local data={voices={}}
for i=1,9 do data.voices['v'..i]={path='v'..i..'.ogg',text={'line'..i}} end
local function New() C.Shutdown();return C.New(nil,data) end
local v=New();local lines={}
for i=1,9 do lines[i]={'nono','line'..i} end
v:Say(lines)
Check(#downloads==9 and background==0 and lookups==0,'Say only starts nine independent downloads without decoding')
for _,job in ipairs(downloads) do Complete(job,true) end
Check(background==0 and lookups==0,'download callbacks only enqueue markers')
for i=1,9 do local before=background;C.Tick(.1);Check(background==before+1,'Update submits at most one voice preparation') end
Check(background==9,'each completed file starts exactly one background decode on later frames')
for path in pairs(requested) do existing[path]={length=1} end
lookups=0;C.Tick(.1);Check(lookups==4,'first frame inspects at most four decoded sounds')
lookups=0;C.Tick(.1);Check(lookups==4,'second frame retains fixed decoding budget')
lookups=0;C.Tick(.1);Check(lookups==1,'last frame drains final decoded sound')
lookups=0;C.Tick(.1);Check(lookups==0,'completed decodes leave no idle polling work')
v:Update(.3,true);Check(plays==1 and #v.log==1,'loaded original dialogue starts once through existing lead clock')
v:Say({{'nono','line1'}},true);Check(#downloads==9,'same path never downloads or decodes twice')
for _,action in ipairs({'hide','owner','expired','shutdown'}) do
 existing={};requested={};local first=#downloads+1;v=New();v:Say({{'nono','line1'}})
 local job=downloads[first];Complete(job,true);local before=plays
 if action=='hide' then v:Hide()
 elseif action=='owner' then C.New(nil,data)
 elseif action=='expired' then v:Update(2.1,true);v:Update(5,true)
 else C.Shutdown() end
 existing['v1.ogg']={length=1};C.Tick(.1)
 for _=1,5 do v:Update(1,true) end
 Check(plays==before,'background decode cannot play obsolete speech after '..action)
end
existing={};local first=#downloads+1;v=New();v:Say({{'nono','line2'}})
local late=downloads[first].complete;local beforeBackground=background;local beforeCancelled=cancelled
C.Shutdown();Check(cancelled==beforeCancelled+1,'Shutdown cancels the owned unfinished download group')
Complete({complete=late},true);C.Tick(.1)
Check(background==beforeBackground,'late download after Shutdown never starts background decode')
v=C.New(nil,data);v:Say({{'nono','line2'}});local nextJob=downloads[#downloads]
Complete({complete=late},true);Check(background==beforeBackground,'old shared-state callback cannot affect newly created communications')
Complete(nextJob,false);C.Tick(.1);Check(background==beforeBackground,'failed download never attempts decode')
C.Shutdown()
-- Fully resident audio takes the cache-only fast path; the modern API is intact.
existing['v3.ogg']={length=1};v=C.New(nil,data);v:Say({{'nono','line3'}})
local before=background;Complete(downloads[#downloads],true);C.Tick(.1);v:Update(.3,true)
Check(background==before and v.source.playing,'resident Sound is reused without background or synchronous load')
C.Shutdown();cache.Exists=function() return true end
v=C.New(nil,data);before=lookups;local beforeSyncDownloads=#downloads
inCallback=true;v:Say({{'nono','line3'}});inCallback=false
Check(lookups==before and #downloads==beforeSyncDownloads,'resident file synchronous Gate completion only enqueues preparation')
C.Tick(.1);before=plays;v:Update(.3,true)
Check(plays==before+1,'resident file synchronous Gate path prepares and plays on Update')
cache.Exists=function() return false end
C.Shutdown();local nativeReady
cache.GetResourceAsync=function(_,kind,path,callback) Check(kind=='Sound' and path=='v4.ogg','modern branch retains exact async API');nativeReady=callback end
local beforeDownloads=#downloads;v=C.New(nil,data);v:Say({{'nono','line4'}})
Check(#downloads==beforeDownloads and nativeReady~=nil,'modern branch never enters legacy download fallback')
nativeReady({length=1});before=plays;v:Update(.3,true);Check(plays==before+1,'modern async callback still resolves and plays authored line')
C.Shutdown();nativeReady({length=1});C.Tick(.1)
-- The shipped older Web binding also lacks DownloadResources callbacks.
cache.GetResourceAsync=nil;cache.DownloadResources=nil
DOWNLOAD_COMPLETED=1;DOWNLOAD_FAILED=2;DOWNLOAD_CANCELLED=3
Time={GetSystemTime=function() return 0 end}
local legacyReady=false;local legacyCancelled=0
cache.Exists=function() return legacyReady end
GetDownloadManager=function() return {
 DownloadResources=function(_,paths) Check(paths[1]=='v5.ogg','legacy manager receives exact recording');return 42 end,
 GetResourceTaskState=function() return legacyReady and DOWNLOAD_COMPLETED or 0 end,
 CancelGroup=function(_,group) Check(group==42,'legacy cancellation retains resource-group identity');legacyCancelled=legacyCancelled+1 end,
} end
existing['v5.ogg']=nil;v=C.New(nil,data);v:Say({{'nono','line5'}})
before=background;require('app.ResourceGate').UpdatePending(.1)
Check(background==before,'legacy download polling does not decode an unfinished file')
legacyReady=true;inCallback=true;require('app.ResourceGate').UpdatePending(.1);inCallback=false
Check(background==before,'actual old manager completion only marks readiness')
C.Tick(.1);Check(background==before+1,'next Tick prepares actual old-manager download')
existing['v5.ogg']={length=1};C.Tick(.1);before=plays;v:Update(.3,true)
Check(plays==before+1,'actual old Web manager and decoder fallback resolves the authored voice')
C.Shutdown();legacyReady=false;v=C.New(nil,data);v:Say({{'nono','line5'}});C.Shutdown()
Check(legacyCancelled==1,'Shutdown cancels old-manager pending group')
legacyReady=true;before=background;require('app.ResourceGate').UpdatePending(1)
Check(background==before,'old-manager pending registry cannot resurrect a shutdown preload')
Check(sceneDisposals>0,'test explicitly releases all retained audio scenes')
return {result='PASS',checks=checks,perFrameBudget=4,
 boundary='Actual StoryComms and ResourceGate: completion callbacks forbid Sound cache reentry, Tick prepares one voice and polls at most four decodes; ownership, cancellation, resident and modern async paths. No native lock, OGG decoder, frame timing, audible continuity, Web, or mobile acceptance.'}
