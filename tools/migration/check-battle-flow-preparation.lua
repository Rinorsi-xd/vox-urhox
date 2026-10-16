package.path='scripts/?.lua;'..package.path
local checks=0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function equal(a,b,label)check(type(a)=='number' and type(b)=='number' and math.abs(a-b)<1e-9 or a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function scenario(kind)
 for _,id in ipairs({'audio.BattleFlow','app.ResourceGate','audio.AudioLevels','core.ResourceData'})do package.loaded[id]=nil end
 local disk,existing,background,plays={},{},{},{}
 local callback,inside,decodeAllowed,cacheCalls,syncCalls=false,false,false,0,0
 local function sound(path)return {path=path,length=.6}end
 local backend={}
 function backend:Exists(path)return disk[path]or false end
 function backend:GetExistingResource(_,path)
  check(not inside,'no cache lookup from download completion');cacheCalls=cacheCalls+1;return existing[path]
 end
 function backend:GetResource(_,path)
  check(not inside,'no decode from download completion')
  check(decodeAllowed,'no synchronous Sound decode in event/update');syncCalls=syncCalls+1
  check(disk[path],'checkpoint decodes only downloaded sound');existing[path]=sound(path);return existing[path]
 end
 function backend:BackgroundLoadResource(_,path)
  check(not inside,'no background queue from download completion');background[#background+1]=path;return false
 end
 function backend:DownloadResources(paths,done)callback={paths=paths,done=done};return 1 end
 function backend:CancelDownloadGroup()callback=false end
 cache=backend;input={focus=true,minimized=false};Time={GetSystemTime=function()return 1000 end}
 local Gate=assert(loadfile('scripts/app/ResourceGate.lua'))()
 package.loaded['app.ResourceGate']={New=function()
  local g=Gate.New(backend);local start=g.Start
  function g:Start(paths,done)return start(self,paths,function(...)
   inside=true;local result={pcall(done,...)};inside=false;if not result[1]then error(result[2])end
  end)end
  return g
 end}
 package.loaded['core.ResourceData']={Read=function()return DATA end}
 local Levels=require 'audio.AudioLevels'
 function Scene()
  local root={}
  function root:CreateChild()return self end
  function root:CreateComponent()
   return {playing=false,SetSoundType=function(self,x)self.soundType=x end,
    StopImmediate=function(self)self.playing=false end,
    Play=function(self,s,f,g)self.playing=true;plays[#plays+1]={path=s.path,gain=g}end}
  end
  function root:Dispose()self.disposed=true end
  return root
 end
 local Flow=assert(load(FLOW_SOURCE))()
 local paths=Flow.Dependencies(true)
 for _,path in ipairs(paths)do
  if kind~='download'then disk[path]=true end
  if kind=='resident'then existing[path]=sound(path)end
 end
 local f=Flow.New();f:Prepare(true)
 if kind=='resident'then
  check(f.ready,'resident Prepare is ready synchronously')
  check(f:Play('battle_enter'),'resident first event plays without decode')
 else
  check(not f.ready,'raw downloads do not mean decoded ready')
  if kind=='download'then
   f:Update(.01);check(not f.ready,'pending download does not decode')
   for _,p in ipairs(callback.paths)do disk[p]=true end
   local before=cacheCalls;callback.done(true,0)
   equal(cacheCalls,before,'download callback only marks readiness')
  end
  for _=1,#paths+2 do
   for _,p in ipairs(background)do existing[p]=sound(p)end
   local queued=#background;local before=cacheCalls;f:Update(.01)
   check(#background-queued<=1,'one background preparation per frame')
   check(cacheCalls-before<=5,'one preparation plus four cache polls per frame')
  end
  check(f.ready,'all original flow and found voices become resident')
 end
 equal(syncCalls,0,'asynchronous preparation never uses GetResource')
 local counts=0;for _ in pairs(f.sounds)do counts=counts+1 end
 equal(counts,#paths,'ready includes complete original dependency closure')
 local byPath={};for id,cue in pairs(DATA.cues)do byPath[cue.path]=id end
 local function cueMatches(path,id)
  local cue=DATA.cues[id]
  if cue.pool then for _,alt in ipairs(cue.pool)do if DATA.cues[alt].path==path then return true end end end
  return cue.path==path
 end
 for _,sample in ipairs(SOURCE.events)do
  f.time=f.time+2;local before=#plays;f:Event(sample.event)
  equal(#plays-before,#sample.played,'frozen source event count '..sample.event.type)
  if #sample.played>0 then check(cueMatches(plays[#plays].path,sample.played[1]),'frozen source event sound '..sample.event.type)end
 end
 f.tick=nil
 for _,sample in ipairs(SOURCE.countdown)do
  f.time=f.time+2;local before=#plays;f:Countdown(sample.remaining,sample.active)
  equal(#plays-before,#sample.played,'frozen source countdown')
 end
 local before=cacheCalls;f:Queue(true);check(f.loop.playing,'prepared queue loop starts')
 local base=f.time;f:Found();check(not f.loop.playing,'found stops queue loop')
 equal(f.voiceAt-base,SOURCE.lobby.delayMs/1000,'original radio delay preserved')
 f:Update(.379);check(not f.voice,'radio waits full original delay')
 f:Update(.002);check(f.voice and f.voice.playing,'prepared found radio plays')
 equal(cacheCalls,before,'event/loop/radio play never enters resource cache')
 equal(syncCalls,0,'all runtime playback avoids synchronous decode')
 f:Dispose();check(f.disposed and next(f.sounds)==nil,'disposed owner clears retained samples')
 -- The battle constructor uses the existing coroutine checkpoint before Activate.
 for _,path in ipairs(paths)do existing[path]=nil end
 local b=Flow.New();decodeAllowed=true;local checkpoints=0
 b:Prepare(false,function(progress,stage)
  checkpoints=checkpoints+1;equal(stage,'battle-audio','loader checkpoint label')
  check(progress>0 and progress<=1,'loader checkpoint fraction')
 end)
 decodeAllowed=false
 check(b.ready,'loader checkpoint prepares complete battle closure synchronously')
 equal(checkpoints,#Flow.Dependencies(false),'one checkpoint per original battle sound')
 check(b:Play('battle_enter'),'Activate battle_enter is ready without first Update')
 -- Execute the actual matching clock with readiness delayed past the wait.
 local Loading=assert(load(LOADING_SOURCE))()
 local nowReady=false;local found,entered=0,0
 local flow={active=true,phase='loading',time=0,elapsed=0,finished=false,failed=false,
  match={stage='queue',age=0,wait=.1,cfg={id='elimination'},roster={}},
  sounds={ready=false,Update=function(self)self.ready=nowReady end,Found=function()found=found+1 end},
  app={EnterTrial=function()entered=entered+1;return true end},Fail=function(self,e)self.failed=e end}
 Loading.Advance(flow,.2);equal(found,0,'unprepared found event is not swallowed')
 equal(flow.match.stage,'queue','unprepared matching keeps cancellable queue')
 nowReady=true;Loading.Advance(flow,.01);equal(found,1,'ready matching announces found exactly once')
 Loading.Advance(flow,1.099);equal(entered,0,'original found presentation still visible')
 Loading.Advance(flow,.002);equal(entered,1,'original found presentation ends at 1100ms')
 flow.sounds.failure='decode failed';Loading.Advance(flow,.01);equal(flow.failed,'decode failed','preparation failure reaches loading error')
 -- A cancelled owner cannot revive from a late native completion.
 for _,path in ipairs(paths)do existing[path]=nil;disk[path]=nil end
 local cancelled=Flow.New();cancelled:Prepare(true);local late=callback.done;cancelled:Dispose();late(true,0)
 check(not cancelled.ready and next(cancelled.sounds)==nil,'late cancelled download cannot revive owner')
 -- A decode that never becomes resident fails explicitly, without a sync fallback.
 for _,path in ipairs(paths)do existing[path]=nil;disk[path]=true end
 local stuck=Flow.New();stuck:Prepare(true);stuck:Update(.01);stuck:Update(20.01)
 check(stuck.failure and stuck.failure:find('timed out',1,true),'decode timeout becomes explicit failure')
 check(not stuck.ready,'failed decode cannot announce ready');stuck:Dispose()
end
package.loaded['urhox-libs/UI']={}
for _,kind in ipairs({'resident','cached','download'})do scenario(kind)end
return {result='PASS',checks=checks,scenarios=3}
