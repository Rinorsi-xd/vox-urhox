-- Real audio modules and ResourceGate; cache calls are forbidden in completion.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks,scenarios=0,0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function case(kind,transport,timing,resident,action)
 scenarios=scenarios+1
 for _,name in ipairs({'audio.UiSound','audio.StoryPageVoice','audio.AudioLevels','app.ResourceGate','urhox-libs/UI','core.ResourceData'})do package.loaded[name]=nil end
 local Gate=assert(loadfile('scripts/app/ResourceGate.lua'))()
 local inCompletion=false;local cacheCalls,background,downloads,cancelled=0,{},{},{}
 local existing,disk={},{};local ms=1000;local sources,scenes={},{}
 local paths={}
 if kind=='ui'then for _,cue in pairs(SOUND_DATA.cues)do paths[#paths+1]=cue.path end
 else paths={'Story/Page/C-01.mp3','Story/Page/C-02.mp3'}end
 table.sort(paths)
 local function sound(path)return {name=path,length=2}end
 for _,path in ipairs(paths)do if timing=='cached'or resident then disk[path]=true end;if resident then existing[path]=sound(path)end end
 input={focus=true,minimized=false};Time={GetSystemTime=function()return ms end}
 DOWNLOAD_COMPLETED=3;DOWNLOAD_FAILED=4;DOWNLOAD_CANCELLED=5
 local backend={}
 function backend:Exists(path)return disk[path]==true end
 function backend:GetExistingResource(kind,path)
  check(not inCompletion,'cache operation inside download completion');eq(kind,'Sound','sound lookup only')
  cacheCalls=cacheCalls+1;return existing[path]
 end
 function backend:GetResource(kind,path)
  check(not inCompletion,'cache operation inside download completion')
  error('Synchronous Sound preparation is forbidden')
 end
 function backend:BackgroundLoadResource(kind,path)
  check(not inCompletion,'cache operation inside download completion');eq(kind,'Sound','background sound only')
  cacheCalls=cacheCalls+1;background[#background+1]=path;return action~='already-queued'
 end
 function backend:CancelDownloadGroup(group)cancelled[group]=true end
 local function complete(job,ok)
  if ok then for _,path in ipairs(job.paths)do disk[path]=true end end
  job.done=ok;job.finished=true
  if job.voiceReady then inCompletion=true;job.voiceReady(ok and sound(job.paths[1])or nil);inCompletion=false
  elseif job.callback then job.callback(ok,ok and 0 or 1)end
 end
 if transport=='modern'then
  function backend:DownloadResources(needed,done)
   local job={paths=needed,callback=done};downloads[#downloads+1]=job
   if timing=='sync'then complete(job,true)end
   return #downloads
  end
 else
  local manager={}
  function manager:DownloadResources(needed)
   local job={paths=needed};downloads[#downloads+1]=job
   if timing=='sync'then complete(job,true)end
   return #downloads
  end
  function manager:GetResourceTaskState(path)
   for _,job in ipairs(downloads)do for _,p in ipairs(job.paths)do if p==path and job.finished then return job.done and DOWNLOAD_COMPLETED or DOWNLOAD_FAILED end end end
   return 1
  end
  function manager:CancelGroup(group)cancelled[group]=true end
  GetDownloadManager=function()return manager end
 end
 if action=='native-async'or action=='native-async-cancel'then
  function backend:GetResourceAsync(kind,path,ready)
   eq(kind,'Sound','native async sound type')
   local job={paths={path},voiceReady=ready};downloads[#downloads+1]=job
   if timing=='sync'then complete(job,true)end
  end
 end
 cache=backend
 package.loaded['app.ResourceGate']={New=function()
  local gate=Gate.New(backend);local Start=gate.Start
  function gate:Start(needed,done)
   return Start(self,needed,function(...)
    inCompletion=true;local result={pcall(done,...)};inCompletion=false
    if not result[1]then error(result[2])end
   end)
  end
  return gate
 end}
 local UI={Input={On=function()return 1 end,Off=function()end},Button={_className='Button'}}
 package.loaded['urhox-libs/UI']=UI
 package.loaded['core.ResourceData']={Read=function()return SOUND_DATA end}
 function Scene()
  local scene={disposed=false};scenes[#scenes+1]=scene
  function scene:CreateChild()
   local node={}
   function node:CreateComponent()
    local source={playing=false,plays=0};sources[#sources+1]=source
    function source:SetSoundType(bus)self.soundType=bus end
    function source:StopImmediate()self.playing=false end
    function source:Play(s,f,g)self.sound=s;self.frequency=f;self.gain=g;self.playing=true;self.plays=self.plays+1 end
    return source
   end
   return node
  end
  function scene:Dispose()self.disposed=true end
  return scene
 end
 local Module=assert(load(kind=='ui'and UI_SOURCE or PAGE_SOURCE))()
 local owner=kind=='ui'and Module.Start()or Module.New()
 local pageState={storyVoice=kind=='page'and owner or nil}
 local pageHost=assert(load('local M,F=...;\n'..PAGE_HOST_SOURCE..'\nreturn M'))({},{SetTime=function()end})
 if kind=='page'then owner:Play(1,'test source page line')end
 local function update(dt,focus)
  local prior=#background;local calls=cacheCalls
  if kind=='ui'then Module.Update()
  else
   local wasFocused=input.focus;input.focus=focus~=false
   pageHost.Update(pageState,dt or .01);input.focus=wasFocused
  end
  check(#background-prior<=1,'at most one preparation queued per update')
  check(cacheCalls-calls<=6,'bounded cache inspection per update')
 end
 local function dispose()if kind=='ui'then Module.Dispose()else pageHost.Leave(pageState)end end
 local function finish(ok)
  for _,job in ipairs(downloads)do if not job.finished then complete(job,ok)end end
  if transport=='legacy'then for _=1,#paths+1 do Gate.UpdatePending(.1)end end
 end
 local function plays()local n=0;for _,s in ipairs(sources)do n=n+s.plays end;return n end
 if action=='cancel'or action=='native-async-cancel'then
  dispose();local before=cacheCalls;finish(true);update();eq(cacheCalls,before,'late cancelled completion cannot enter cache')
  eq(#background,0,'cancelled resources not queued');check(scenes[1].disposed,'cancelled scene disposed');return
 end
 if action=='replace'and kind=='ui'then
  local oldScene=scenes[1];Module.Start();check(oldScene.disposed,'restart releases old owner')
  finish(true)
  for _=1,#paths+1 do update()end
  eq(#background,#paths,'old completion cannot duplicate preparation for replacement')
  Module.Dispose();return
 end
 if action=='failed'then
  finish(false);for _=1,3 do update()end
  eq(#background,0,'failed download cannot prepare sounds')
  if kind=='ui'then eq(#Module.Snapshot().errors,1,'download failure reported once after update')end
  dispose();return
 end
 if resident then
  eq(#downloads,0,'resident sound requires no network')
  if kind=='ui'then eq(Module.Snapshot().ready,#paths,'resident cues ready before first update');check(Module.Play('press'),'resident cue immediately playable')
  else check(owner.loaded['C-01']and owner.loaded['C-02'],'resident page voices immediately available')end
 else
  eq(#background,0,'completion callback never queues cache work')
  finish(true);eq(#background,0,'delivered download callback only records readiness')
  local before=cacheCalls
  if kind=='ui'then check(not Module.Play('press'),'unready input does not block or decode')end
  eq(cacheCalls,before,'play path cannot enter cache')
  if action=='native-async'then
   eq(#background,0,'native async readiness needs no legacy preparation queue')
   check(owner.loaded['C-01']and owner.loaded['C-02'],'native async callback records both original voices')
  else
   for _=1,#paths do update(.01,false)end
   eq(#background,#paths,'all original sounds queued without reducing content')
   for _,path in ipairs(paths)do existing[path]=sound(path)end
   for _=1,#paths do update()end
  end
 end
 if kind=='ui'then
  eq(Module.Snapshot().ready,#paths,'all original cues reach ready')
  ms=ms+1000;check(Module.Play('press'),'prepared cue plays')
  check(not Module.Play('press'),'original input gap retained')
  local found=false
  for _,source in ipairs(sources)do if source.playing then eq(source.frequency,0,'original sample frequency restored');found=true end end
  check(found,'real source playback invoked')
  input.focus=false;update();for _,source in ipairs(sources)do check(not source.playing,'focus stops all UI sources')end
  input.focus=true
 else
  update(.27);check(plays()>=1,'first original voice starts after lead')
  local first=sources[1].playing and sources[1]or sources[2]
  eq(first.sound.name,'Story/Page/C-01.mp3','nono voice identity retained');eq(first.frequency,0,'nono original frequency');eq(first.gain,.4,'nono original gain')
  update(3);update(.27);check(plays()>=2,'second original voice starts')
  local second=sources[1].sound and sources[1].sound.name=='Story/Page/C-02.mp3'and sources[1]or sources[2]
  eq(second.sound.name,'Story/Page/C-02.mp3','huhu voice identity retained');eq(second.gain,.4,'huhu original gain')
  owner:Play(1,'replay original line');update(.27);check(plays()>=3,'replay uses prepared sounds')
 end
 local before=cacheCalls;dispose();dispose();finish(true);update();eq(cacheCalls,before,'disposed owner cannot prepare or poll')
 check(scenes[#scenes].disposed,'scene released');for _,source in ipairs(sources)do check(not source.playing,'all owned sources stopped')end
end
for _,kind in ipairs({'ui','page'})do
 for _,transport in ipairs({'modern','legacy'})do
  for _,timing in ipairs({'async','sync','cached'})do case(kind,transport,timing,false,'normal')end
  case(kind,transport,'async',true,'normal')
  case(kind,transport,'async',false,'cancel')
  case(kind,transport,'async',false,'failed')
  case(kind,transport,'async',false,'already-queued')
 end
end
case('ui','modern','async',false,'replace')
case('ui','legacy','async',false,'replace')
case('page','modern','async',false,'native-async')
case('page','modern','sync',false,'native-async')
case('page','modern','async',false,'native-async-cancel')
return {result='PASS',checks=checks,scenarios=scenarios,
 boundary='Actual current/frozen audio modules and actual ResourceGate with modern/legacy download, cache and native sound-source adapters. Strict no-cache-in-completion and bounded-update assertions; no GPU, native lock attribution, audible continuity or Web response-time acceptance.'}
