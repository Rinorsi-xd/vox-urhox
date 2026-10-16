package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,message) checks=checks+1;assert(ok,message) end
package.preload['core.ResourceData']=function() return {Read=function() return MUSIC_CATALOG end} end
local Levels=require 'audio.AudioLevels'
local active={}
Scene=function()
 local metric=active
 return {CreateChild=function() return {CreateComponent=function()
  metric.created=metric.created+1;metric.live=metric.live+1;metric.maxLive=math.max(metric.maxLive,metric.live)
  return {playing=false,timePosition=0,gain=0,
   Play=function(self,sound,frequency,gain)
    Check(frequency==0,'Play keeps the original sample frequency');Check(not metric.callback,'download callbacks never construct/play new audio')
    self.playing=true;self.timePosition=0;self.gain=gain;metric.plays[#metric.plays+1]=sound.file
   end,
   StopImmediate=function(self) self.playing=false end,
   Dispose=function(self) Check(not self.disposed,'source disposed once');self.disposed=true;metric.live=metric.live-1 end,
   Seek=function(self,seconds) self.timePosition=seconds end,
  }
 end} end,Dispose=function() metric.sceneDisposed=metric.sceneDisposed+1 end}
end
audio={PauseSoundType=function() end,ResumeSoundType=function() end}
Time={GetSystemTime=function() return 0 end}
local Current=require 'audio.MusicPlayer'
local Before=assert(load(MUSIC_BEFORE_SOURCE,'@frozen-14f-MusicPlayer'))()
local first=MUSIC_CATALOG.tracks[1].id
local second=MUSIC_CATALOG.tracks[2].id
local third=MUSIC_CATALOG.tracks[3].id
local function New(module,options)
 options=options or {};Levels.Init(nil)
 local metric={created=0,live=0,maxLive=0,sceneDisposed=0,plays={},sync=0,reads=0,background=0,writes=0,callback=false}
 active=metric
 local backend={jobs={},existing={},queued={},cancelled={},throwQueue=options.throwQueue,rejectQueue=options.rejectQueue}
 function backend:Exists() return options.downloaded==true end
 function backend:DownloadResources(paths,done)
  self.jobs[#self.jobs+1]={file=paths[1],done=done};return #self.jobs
 end
 function backend:CancelDownloadGroup(id) self.cancelled[id]=true end
 function backend:Ready(file,length)
  self.existing[file]={file=file,length=length or 180,compressed=true,dataSize=3122198};return self.existing[file]
 end
 function backend:GetResource(kind,file)
  metric.sync=metric.sync+1
  if module==Current then error('MusicPlayer synchronously loads audio') end
  return self.existing[file] or self:Ready(file)
 end
 function backend:GetExistingResource(kind,file)
  Check(kind=='Sound','only selected music Sound is inspected');Check(not metric.callback,'download callback does not query native resource cache')
  metric.reads=metric.reads+1;return self.existing[file]
 end
 function backend:BackgroundLoadResource(kind,file,sendFailure)
  Check(kind=='Sound' and sendFailure==true,'background request uses documented audio API')
  Check(not metric.callback,'background preparation is deferred out of the download callback')
  metric.background=metric.background+1;self.queued[file]=true
  if self.throwQueue then error('decoder unavailable') end
  return not self.rejectQueue
 end
 function backend:ReleaseResource(kind,file,force)
  Check(kind=='Sound' and force==false,'retired slot only releases unused shared audio')
  self.existing[file]=nil
 end
 function backend:Complete(index,ok)
  metric.callback=module==Current;self.jobs[index].done(ok,ok and '' or 'download failed');metric.callback=false
 end
 local store={Read=function() end,Write=function(_,key,value,valid)
  Check(key=='music' and valid(value),'real player validates persisted music payload');metric.writes=metric.writes+1;return true
 end}
 local player=module.New(store,backend)
 return player,backend,metric
end
local function PendingFile(p) return p.slots[p.pending].track.file end
local function Loaded(p,b)
 if #b.jobs>0 then b:Complete(#b.jobs,true) end
 p:Update(0,'hangar',false)
 if p.pending then b:Ready(PendingFile(p));p:Update(0,'hangar',false) end
end
local function Library()
 local p,b,m=New(Current);p:SetLibraryMode(true);p:Update(0,'hangar',false);return p,b,m
end

-- The original queue and shared RNG must produce identical ordered choices.
local function Trace(module)
 math.randomseed(17653)
 local p,b,m=New(module);p:Update(0,'hangar',false)
 Check(#b.jobs==0 and not p.pending,'locked initial player never chooses or downloads')
 p:Unlock();local trace={}
 for i=1,12 do
  if i==1 then p:Update(0,'hangar',false) else p:Next() end
  local chosen=p.slots[p.pending].track.id;trace[#trace+1]=chosen
  if module==Current then
   Check(#p.history==i-1,'queue is not committed before audio readiness')
   local beforeReads,beforeBg=m.reads,m.background;b:Complete(#b.jobs,true)
   Check(m.reads==beforeReads and m.background==beforeBg,'successful download records only readiness')
   p:Update(0,'hangar',false);b:Ready(PendingFile(p));p:Update(0,'hangar',false)
  else b:Complete(#b.jobs,true) end
  Check(p:Track().id==chosen and #p.history==i,'only the selected track commits once')
  local slot=p.slots[p.current];Check(slot.fade.start==p.time and slot.target==1,'original fade starts at successful playback')
  p:Update(1.2,'hangar',false);Check(math.abs(p:Level(slot)-.5)<1e-12,'original 2.4-second smooth fade midpoint')
  p:Update(1.2,'hangar',false);Check(math.abs(p:Level(slot)-1)<1e-12,'original fade reaches full level at 2.4 seconds')
  trace[#trace+1]=string.format('%.12f',math.random())
 end
 Check(m.maxLive<=2,'current/fading player never owns more than two sources')
 p:Dispose();Check(m.live==0 and m.sceneDisposed==1,'all music sources and retained audio scene are disposed')
 return table.concat(trace,'|'),m.sync
end
local beforeTrace,beforeSync=Trace(Before)
local afterTrace,afterSync=Trace(Current)
Check(beforeTrace==afterTrace,'12 shuffled selections and interleaved shared RNG results match frozen 14f exactly')
Check(beforeSync==12 and afterSync==0,'same playback sequence removes all 12 synchronous audio GetResource calls')

-- Pause, focus, lock and volume changes while bytes/decode finish never play.
for _,blocked in ipairs({'pause','hidden','locked','mute','disabled'}) do
 local p,b,m=Library();p:PlayTrack(first);local file=PendingFile(p)
 if blocked=='pause' then p:SetPaused(true)
 elseif blocked=='locked' then p.unlocked=false
 elseif blocked=='mute' then p:SetVolume(0)
 elseif blocked=='disabled' then p:SetEnabled(false) end
 b:Complete(1,true);local hidden=blocked=='hidden'
 p:Update(0,'hangar',hidden);Check(m.background==1,'byte-ready blocked player still prepares selected Sound')
 b:Ready(file);local written=m.writes;p:Update(0,'hangar',hidden)
 Check(#m.plays==0 and #p.history==0 and p.current==nil,'blocked completion cannot play or commit history: '..blocked)
 Check(m.writes==written,'blocked decoded completion cannot persist Played: '..blocked)
 local clock=p.time;p:Update(99,'hangar',hidden);Check(p.time==clock and p.pending~=nil,'blocked preparation never times out or advances music clock: '..blocked)
 p:Resume();p:Update(0,'hangar',false)
 Check(p:Track().id==first and #p.history==1 and #m.plays==1,'unblock starts the same prepared song exactly once: '..blocked)
 p:Update(.3,'hangar',false);Check(#m.plays==1,'ready completion is consumed only once')
 p:Dispose()
end

do
 local p,b,m=Library();p:PlayTrack(first);local a=b.jobs[1]
 p:PlayTrack(second);Check(b.cancelled[1],'rapid manual choice cancels old owned download')
 local reads,bg=m.reads,m.background;b:Complete(1,true)
 Check(m.reads==reads and m.background==bg and #m.plays==0,'late old download cannot prepare/play selected replacement')
 Loaded(p,b);Check(p:Track().id==second and #p.history==1,'replacement commits once through actual player methods')
 p:Update(2.4,'hangar',false);p:PlayTrack(third);local file=PendingFile(p);b:Complete(#b.jobs,true);p:Update(0,'hangar',false)
 local started=m.background;p:Dispose();b:Ready(file);a.done(true);p:Update(1,'hangar',false)
 Check(m.background==started and m.live==0 and #m.plays==1,'disposed player ignores late download/decode and cannot create sources')
end
do
 local p,b,m=New(Current);p:Unlock();p:Update(0,'hangar',false);local obsolete=b.jobs[1]
 p:Update(0,'training',false);Check(b.cancelled[1] and p.slots[p.pending].track.group=='training','scene change cancels incompatible pending song before preparing it')
 local n=m.background;obsolete.done(true);Check(m.background==n,'old scene download completion is inert')
 b:Complete(2,true);p:Update(0,'training',false);b:Ready(PendingFile(p));p:Update(0,'training',false)
 Check(p:Track().group=='training' and #p.history==1,'only new scene song is committed');p:Dispose()
end
do
 local p,b,m=Library();p:PlayTrack(first);p:SetLibraryMode(false)
 Check(p.continuationId==first,'closing library retains its pending continuation')
 Loaded(p,b);Check(p:Track().id==first,'pending library song survives return to original hall group');p:Dispose()
end
do
 local p,b,m=Library();p:PlayTrack(first);b:Complete(1,false)
 Check(#p.errors==0 and m.background==0,'failed byte callback records result without audio work')
 p:Update(0,'hangar',false)
 Check(p.failed[first] and #p.errors==1 and p.pending==nil and p.retryAt==p.time+.5,'download error retains failed-song marking and half-second retry')
 p:Update(.49,'hangar',false);Check(#b.jobs==1,'failure cannot retry before original cooldown')
 p:Update(.02,'hangar',false);Check(#b.jobs==2 and p.slots[p.pending].track.id~=first,'retry chooses another allowed song through original queue');p:Dispose()
end
for _,mode in ipairs({'rejected','invalid','exception'}) do
 local p,b,m=New(Current,{rejectQueue=mode=='rejected',throwQueue=mode=='exception'})
 p:SetLibraryMode(true);p:Update(0,'hangar',false);p:PlayTrack(first);local file=PendingFile(p)
 b:Complete(1,true);p:Update(0,'hangar',false)
 if mode=='exception' then Check(p.pending==nil and p.failed[first],'background API exception follows existing failure/retry flow')
 else
  if mode=='invalid' then b:Ready(file,0) end
  p:Update(19.9,'hangar',false);Check(p.pending~=nil and m.background==1,'unfinished/invalid resource uses one bounded queued request')
  p:Update(.11,'hangar',false);Check(p.pending==nil and p.failed[first] and #m.plays==0,'background timeout releases pending and never plays invalid audio')
 end
 p:Dispose()
end
do
 local p,b,m=New(Current,{rejectQueue=true});p:SetLibraryMode(true);p:Update(0,'hangar',false);p:PlayTrack(first)
 local file=PendingFile(p);b:Complete(1,true);p:Update(0,'hangar',false);b:Ready(file);p:Update(.1,'hangar',false)
 Check(p:Track().id==first and #p.errors==0,'already queued resource false return can still resolve shared Sound');p:Dispose()
end
do
 local p,b,m=Library();p:PlayTrack(first);local file=PendingFile(p);b:Ready(file);b:Complete(1,true);p:Update(0,'hangar',false)
 Check(m.background==0 and p:Track().id==first,'resident Sound is reused without a new background request')
 p:SetPlayMode('repeat');p.slots[p.current].source.playing=false;p:Update(0,'hangar',false)
 Check(#m.plays==2 and #p.history==1,'single-track repeat reuses original sound without another history commit')
 Check(p:Seek(8),'original seek remains available');p:Previous();Check(p:Position()==0,'previous after 3 seconds restarts current');p:Dispose()
end

-- Exercise the actual shipped legacy download-manager gate as well.
do
 local p,b,m=New(Current);p:Unlock();b.DownloadResources=nil
 DOWNLOAD_COMPLETED=1;DOWNLOAD_FAILED=2;DOWNLOAD_CANCELLED=3
 local ready=false;local cancelled=0
 b.Exists=function() return ready end
 GetDownloadManager=function() return {
  DownloadResources=function() return 75 end,GetResourceTaskState=function() return ready and DOWNLOAD_COMPLETED or 0 end,
  CancelGroup=function(_,id) Check(id==75,'legacy cancellation keeps owned group');cancelled=cancelled+1 end,
 } end
 p:Update(0,'hangar',false);require('app.ResourceGate').UpdatePending(.1)
 Check(m.background==0,'legacy unfinished group does not prepare Sound')
 ready=true;require('app.ResourceGate').UpdatePending(.1)
 Check(m.background==0 and m.reads==0,'legacy native completion only records music readiness')
 p:Update(0,'hangar',false);b:Ready(PendingFile(p));p:Update(0,'hangar',false)
 Check(#m.plays==1 and m.sync==0,'legacy manager and actual player complete asynchronous selected song')
 p:Dispose();ready=false;p,b,m=New(Current);b.DownloadResources=nil;b.Exists=function() return false end;p:Unlock();p:Update(0,'hangar',false);p:Dispose()
 Check(cancelled==1,'disposing pending legacy player cancels its owned download group')
end
return {result='PASS',checks=checks,baselineSyncLoads=beforeSync,currentSyncLoads=afterSync,comparedShuffledTracks=12,
 boundary='Actual MusicPlayer, AudioLevels and ResourceGate executed with controlled resource/scene adapters. Frozen 14f player is executed for ordered choices, shared RNG and fade comparison. Current GetResource is a fail-fast trap. Tests cover readiness, cancellation, pause/hidden/mute/unlock, retry, invalid/late decode, continuation, repeat, disposal and legacy download manager. No native MP3 decoder, audible continuity, Web frame timing, GPU or mobile acceptance.'}
