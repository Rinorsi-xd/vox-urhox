package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
package.preload['core.ResourceData']=function() return {Read=function() return RADIO_DATA end} end
local existing,download,decoded,background,cancelled,scenes,disposed,plays={},{},0,0,0,0,0,{}
local sources,feedback={},{ }
local inCallback,inStart=false,false
local logs={}
local function Outside(label)
 Check(not inCallback,label..' must not execute under download callback lock')
 Check(not inStart,label..' must wait for ordinary Update after synchronous gate completion')
end
print=function(message) Outside('failure logging');logs[#logs+1]=message end
local function Deliver(complete,...)
 inCallback=true;local ok,message=pcall(complete,...);inCallback=false;assert(ok,message)
end
local function Node()
 return {CreateChild=function() return Node() end,CreateComponent=function()
  Outside('sound source allocation')
  local source={playing=false,SetSoundType=function(self,bus) Outside('sound source bus change');self.bus=bus end,
   StopImmediate=function(self) Outside('sound source stop');self.playing=false end}
  sources[#sources+1]=source;return source
 end}
end
Scene=function() Outside('audio scene allocation');scenes=scenes+1;local scene=Node();scene.Dispose=function() Outside('audio scene disposal');disposed=disposed+1 end;return scene end
input={focus=true,minimized=false}
Time={GetSystemTime=function() return 0 end}
cache={Exists=function() return download.ready end,
 DownloadResources=function(_,paths,complete)
  download.paths=paths;download.complete=function(...) Deliver(complete,...) end
  if download.sync then download.ready=not download.fail;download.complete(not download.fail,download.fail and 1 or 0) end
  return 7
 end,
 CancelDownloadGroup=function(_,group) Check(group==7,'cancel only the owned resource group');cancelled=cancelled+1 end,
 GetExistingResource=function(_,_,path) Outside('cache resident query');return existing[path] end,
 BackgroundLoadResource=function(_,kind,path) Outside('background resource submission');Check(kind=='Sound','decode only original audio resources');background=background+1 end,
 GetResource=function(_,kind,path) Outside('cache resource lookup');Check(kind=='Sound' and existing[path]~=nil,'never decode synchronously before residency');decoded=decoded+1;return existing[path] end,
}
package.preload['audio.AudioLevels']=function() return {FeedbackFor=function(seconds) feedback[#feedback+1]=seconds end,Play=function(source,sound,_,gain)
 Outside('sound source play');source.playing=true;plays[#plays+1]={sound=sound,gain=gain,bus=source.bus}
end} end
local Cues=TEST_CODE and assert(load(TEST_CODE,'StoryCommsCues negative'))() or require 'audio.StoryCommsCues'
local function New()
 inStart=true;local ok,result=pcall(Cues.New);inStart=false;assert(ok,result);return result
end
local cueCount=0;for _ in pairs(RADIO_DATA.cues) do cueCount=cueCount+1 end
local c=New()
Check(#download.paths==cueCount+1,'download includes registry and all exact reused Radio dependencies')
Check(not c:Play('open') and decoded==0 and scenes==0 and background==0,'unavailable cue never blocks or constructs audio state')
download.ready=true;download.complete(true)
Check(background==0 and decoded==0 and scenes==0,'download callback records readiness without cache access or allocations')
c:Update(.1,true)
Check(background==cueCount and decoded==0 and scenes==0,'next ordinary update starts background decoding only')
local last
for name,cue in pairs(RADIO_DATA.cues) do last=cue.path;existing[cue.path]={length=.3,id=name} end
existing[last]=nil;c:Update(.1,true)
Check(scenes==0 and not c:Play('intercept'),'partial residency cannot enter eager Radio.New')
Check(background==cueCount,'partial residency does not resubmit background jobs every frame')
existing[last]={length=.3};c:Update(.1,true)
Check(scenes==1 and decoded==cueCount,'all resident assets construct one reused exact-gain Radio player')
Check(c:Play('open') and #plays==1,'ready cue plays immediately')
Check(#feedback==1 and feedback[1]==.3,'actual original flow cue registers decoded duration for shared feedback window')
local data=RADIO_DATA.cues.open
Check(math.abs(plays[1].gain-data.gain*data.strength*.6*RADIO_DATA.master.scale)<1e-12,'retains original open strength and mix trims')
Check(not c:Play('open') and #plays==1,'retains shared Radio repeat-gap suppression')
c:Update(.51,true);Check(c:Play('open') and #plays==2,'original repeat gap expires normally')
Check(not c:Play('unknown'),'unknown cue stays silent')
c:Update(.1,false);Check(not sources[1].playing and not c:Play('intercept'),'focus pause stops feedback and suppresses new cue')
c:Update(.1,true);Check(c:Play('intercept') and #plays==3,'focus return permits new feedback without replaying missed cues')
for name,cue in pairs(RADIO_DATA.cues) do
 c:Update(10,true);local before=#plays;Check(c:Play(name) and #plays==before+1,'all original ready cues play '..name)
 Check(math.abs(plays[#plays].gain-cue.gain*cue.strength*.6*RADIO_DATA.master.scale)<1e-12,'all original ready cue gains retained '..name)
 Check(plays[#plays].bus==(cue.bus=='weapons' and 'VoxWeapons' or 'VoxFeedback'),'all original ready cue buses retained '..name)
end
c:Dispose();c:Dispose();Check(disposed==1 and not c:Play('close'),'owned audio scene released once')
local before=#plays;c:Update(5,true);Check(#plays==before,'disposed player never drains stale feedback')
existing={};download={};local early=New();local late=download.complete
early:Dispose();late(true);early:Update(1,true)
Check(cancelled==1 and scenes==1 and background==cueCount,'cancelled late download cannot create a scene or decode')
download={ready=true};local pending=New()
Check(background==cueCount and scenes==1,'synchronous warm-file gate callback defers all cache work')
pending:Update(.1,true)
Check(background==cueCount*2 and scenes==1,'resident file without decoded audio remains asynchronous on Update')
pending:Dispose()
for _,cue in pairs(RADIO_DATA.cues) do existing[cue.path]={length=.3} end
pending:Update(1,true);Check(scenes==1,'dispose during background decode cannot resurrect player')
local ready=New()
Check(scenes==1 and decoded==cueCount,'fully warm resources do not construct a player in synchronous callback')
ready:Update(.1,true)
Check(scenes==2 and decoded==cueCount*2,'fully warm resources prepare on next Update without background decode')
Check(background==cueCount*2 and #plays==before,'no pending cue replays when new owner is ready')
ready:Dispose();Check(disposed==2,'every created audio scene released')
existing={};download={sync=true};local synchronous=New()
Check(scenes==2 and background==cueCount*2,'synchronous DownloadResources completion does not touch cache')
synchronous:Update(.1,true)
Check(background==cueCount*3 and scenes==2,'synchronous download is prepared by next ordinary Update')
synchronous:Dispose()
download={sync=true};local disposedReady=New();local beforeBackground=background
disposedReady:Dispose();disposedReady:Update(.1,true)
Check(background==beforeBackground and scenes==2,'dispose between synchronous completion and first Update discards ready marker')
for _,sync in ipairs({false,true}) do
 existing={};download={sync=sync,fail=true};local beforeBackground=background;local failed=New()
 if not sync then download.complete(false,1) end
 Check(#logs==0 and background==beforeBackground and scenes==2,'download failure callback only records error')
 failed:Update(.1,true)
 Check(#logs==1 and string.find(logs[1],'StoryCommsCues',1,true)~=nil,'failure logged once outside callback')
 failed:Update(.1,true);failed:Update(.1,true)
 Check(#logs==1 and background==beforeBackground and scenes==2,'failed download never decodes or retries silently')
 failed:Dispose();logs={}
end
download={};local silent=New();local beforeBackground=background;local lateFailure=download.complete
silent:Dispose();lateFailure(false,1);silent:Update(1,true)
Check(#logs==0 and background==beforeBackground and scenes==2,'disposed late failure performs no logging or resource work')
return {result='PASS',checks=checks,dependencyCount=cueCount+1,
 boundary='Actual StoryCommsCues, StoryRadio and ResourceGate. Sync/async gate completion guards forbid cache queries/submission, source/scene creation and logging inside callback or Start. Tests failure, cancellation, background residency, all seven original gains/buses/gaps, focus and disposal. No actual native lock, decoder, audible continuity or GPU acceptance.'}
