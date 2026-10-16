"""Source WebAudio oracle, exported PCM, and actual Lua scheduling/lifecycle."""
import hashlib,json,os,sys,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT);sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
data=json.loads((ROOT/'assets/Combat/MatchRadioDSP.json').read_text())
calls=json.loads((ROOT/'assets/Combat/Radio.json').read_text(encoding='utf8'))
oracle=json.loads((ROOT/'docs/migration/evidence/match-radio-source.json').read_text())
checks=0
def check(ok,label):
 global checks
 checks+=1
 assert ok,label
def tab(lua,v):
 if isinstance(v,dict):return lua.table_from({k:tab(lua,x) for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([tab(lua,x) for x in v])
 return v
check(data['sourceSha256']==oracle['sourceSha256'],'source graph hash')
check(set(data['lines'])==set(calls['lines']),'all 116 source lines')
files={s['path']:s for l in data['lines'].values() for s in l['stems'].values()}
for p,s in files.items():
 raw=(ROOT/'assets'/p).read_bytes();check(hashlib.sha256(raw).hexdigest()==s['sha256'],'exported PCM hash '+p)
 with wave.open(str(ROOT/'assets'/p)) as w:
  check((w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,48000),'PCM format '+p)
  check(abs(w.getnframes()/48000-s['seconds'])<1e-10,'PCM duration '+p)
for row in oracle['oracle']:
 check(row['reconstructionMaxError']<=2/32767,'actual source float stem reconstruction '+row['id'])
 check(row['exportedPcmMaxError']<=4/32767,'actual source exported PCM reconstruction '+row['id'])
for p,expected in data['inputs'].items():
 base=json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text(encoding='utf8'))
 check(hashlib.sha256((Path(base['snapshot'])/p).read_bytes()).hexdigest()==expected,'frozen voice/hiss input '+p)
voice=(ROOT/'scripts/audio/MatchVoice.lua').read_text();radio=(ROOT/'scripts/audio/MatchRadioDSP.lua').read_text()
def run(v=voice,r=radio):
 lua=LuaRuntime(unpack_returned_tuples=True);g=lua.globals();g.DATA=tab(lua,data);g.CALLS=tab(lua,calls);g.VOICE=v;g.RADIO=r;g.check=check
 return dict(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
Time={GetSystemTime=function()return 0 end};input={focus=true,minimized=false}
local loaded,background,sources,receivers,gates={}, {}, {}, {}, {};local downloadAuto=true;local bgCount=0;local syncCount=0
local lengths={};for _,l in pairs(DATA.lines)do for _,s in pairs(l.stems)do lengths[s.path]=s.seconds end end
local function node()
 local n={dead=false}
 function n:CreateChild()return node()end
 function n:CreateComponent()
  local s={playing=false,disposed=false}
  function s:SetSoundType(t)self.soundType=t end
  function s:Play(sound,frequency,gain)self.sound=sound;self.playing=true;self.gain=gain;self.frequency=frequency end
  function s:Seek(at)self.seek=at end
  function s:StopImmediate()self.playing=false end
  function s:Dispose()self:StopImmediate();self.disposed=true;self.sound=nil end
  sources[#sources+1]=s;return s
 end
 function n:CreateScriptObject()
  local r={node=n,handlers={}};receivers[#receivers+1]=r
  function r:SubscribeToEvent(name,fn)self.handlers[name]=fn end
  return r
 end
 function n:Dispose()self.dead=true end
 return n
end
Node=node
local function emit(path,success)
 local event={GetString=function()return path end,GetBool=function()return success end}
 for _,r in ipairs(receivers)do if not r.node.dead and r.handlers.ResourceBackgroundLoaded then r.handlers.ResourceBackgroundLoaded(r,'ResourceBackgroundLoaded',event)end end
end
local function finish(path,success)
 if success then loaded[path]={length=assert(lengths[path]),path=path}end;background[path]=nil;emit(path,success)
end
local function finishAll(success)local paths={};for p in pairs(background)do paths[#paths+1]=p end;for _,p in ipairs(paths)do finish(p,success)end end
local function cleanup()for _,r in ipairs(receivers)do if not r.node.dead and r.handlers.Update then r.handlers.Update()end end end
cache={GetResource=function()syncCount=syncCount+1;error('synchronous audio load forbidden')end,
 GetExistingResource=function(_,_,p)return loaded[p]end,
 GetNumBackgroundLoadResources=function()local n=0;for _ in pairs(background)do n=n+1 end;return n end,
 BackgroundLoadResource=function(_,_,p)bgCount=bgCount+1;background[p]=true;return true end,
 ReleaseResource=function(_,_,p,force)
  check(force==false,'shared resource release never forced')
  for _,s in ipairs(sources)do if s.playing and s.sound and s.sound.path==p then return end end
  loaded[p]=nil
 end}
package.loaded['core.ResourceData']={Read=function(p)return p=='Combat/Radio.json' and CALLS or DATA end}
package.loaded['app.ResourceGate']={New=function()
 local gate={generation=0};gates[#gates+1]=gate
 function gate:Cancel()self.generation=self.generation+1;self.cancelled=true end
 function gate:Start(paths,fn)
  self:Cancel();self.cancelled=false;self.paths=paths;local token=self.generation
  check(#paths==4,'downloads exactly selected four stems')
  self.complete=function(ok)if token==self.generation then fn(ok)end end
  if downloadAuto then self.complete(true)end
 end
 return gate
end}
local Levels=require 'audio.AudioLevels';Levels.Init()
local Radio=assert(load(RADIO))();package.loaded['audio.MatchRadioDSP']=Radio
local Voice=assert(load(VOICE))()
local function battle()return {session={scene=node()},rules={state='prep'}}end
local function prepare(v,key)
 v:Say(key);for i=1,8 do local before=bgCount;v:Next();check(bgCount-before<=1,'at most one background decode submitted per frame');finishAll(true);v.radio:Collect();if v.card then return end end
 error('voice did not prepare')
end
local v=Voice.New(battle());check(#gates==1 and gates[1].paths==nil and bgCount==0,'construct does not preload entire Radio library')
downloadAuto=false;v:Say('titleElimination');v:Next();v:Update(8)
check(#v.queue==1 and not v.ready and not Levels.Speaking(),'cold download preserves source initial queue TTL without starting speaking')
gates[1].complete(true);downloadAuto=true
for i=1,8 do v:Next();finishAll(true);v.radio:Collect();if v.card then break end end
check(v.card~=nil and v.card.at==8,'clock starts only after downloaded and decoded')
local line=DATA.lines[v.card.id];check(math.abs(v.busyUntil-(8+line.total+.35))<1e-10,'source total plus queue gap')
check(math.abs(v.speakingUntil-(8+line.speaking))<1e-10,'source speaking clock')
check(math.abs(v.card.untilAt-(8+line.total+.5))<1e-10 and v.card.lead==.26,'source card timing')
v:Update(.019);check(#sources==0,'no immediate dry voice')
v:Update(.002);check(#sources==1 and sources[1].sound.path:match('lead.wav$'),'source initial key/static stem')
v:Update(.038);check(#sources==1,'hiss does not start early')
v:Update(.002);check(#sources==2 and sources[2].sound.path:match('hiss.wav$'),'source hiss onset')
v:Update(.198);local count=#sources;check(count==2,'voice does not start before .26')
v:Update(.041);check(#sources==3 and sources[3].sound.path:match('voice.wav$'),'processed voice delayed onset')
check(math.abs(sources[3].seek-.04)<1e-9,'late frame seeks to source clock')
for _,s in ipairs(sources)do if s.playing then check(s.soundType=='VoxMatchVoice' and math.abs(s.gain-.28)<1e-12,'one radio master on voice bus')end end
Levels.Set('sfx',0);Levels.Set('voice',.3);check(math.abs(sources[3].gain-.14)<1e-12,'active voice settings update independently of SFX')
v:Fade(.35);check(not Levels.Speaking() and #v.radio.jobs==0 and #v.radio.fading==2,'fade cancels transients and releases speaking immediately')
v:Update(.175);check(math.abs(sources[3].gain-.07)<1e-10,'fade multiplies dynamic setting once')
prepare(v,'go');local fading=#v.radio.fading;check(fading>0,'replacement does not hard cut detached voice/hiss fade')
v:Update(.2);check(#v.radio.fading==0,'old fade naturally retires')
v:Reset();check(#v.radio.jobs==0 and #v.radio.fading==0 and v.radio.pending==nil and not Levels.Speaking(),'reset cancels every owned track and pending prepare')
prepare(v,'go');v:Update(v.speakingUntil-v.time+.000001);check(not Levels.Speaking(),'natural source speaking release')
v:Reset();prepare(v,'go');local other={};Levels.SetSpeaking(other,true);input.focus=false;v:Update(.1)
check(#v.radio.jobs==0 and Levels.Speaking(),'focus cancels own audio and preserves another speaking owner');Levels.SetSpeaking(other,false);input.focus=true
prepare(v,'go');input.minimized=true;v:Update(0);check(#v.radio.jobs==0 and not Levels.Speaking(),'minimize stops pending/transient/voice');input.minimized=false
v:Reset();v:Say('go');v:Next();local before=#v.queue;v:Update(10);check(#v.queue==0 and v.radio.pending==nil,'later expired real-time call is dropped and preparation cancelled')
v:Reset();v:Say('go');v:Next();local oldPaths=gates[1].paths;v:Say('win');v:Next();local current=v.radio.pending
local currentPaths={};for _,s in pairs(DATA.lines[current.id].stems)do currentPaths[s.path]=true end
for _,p in ipairs(oldPaths)do if background[p] and not currentPaths[p]then finish(p,false)end end
v.radio:Collect();check(v.radio.pending==current and not current.failed,'cancelled old decode failure cannot fail current candidate')
v:Reset();v:Say('go');v:Next();local pending={};for p in pairs(background)do pending[#pending+1]=p end
v:Dispose();check(not Levels.Speaking(),'dispose clears speaking')
for _,p in ipairs(pending)do finish(p,true)end;cleanup();check(v.radio.cleanupNode==nil,'late successful decode released after disposal')
for _,s in ipairs(sources)do check(not s.playing,'disposed source silent')end
local failed=Voice.New(battle());failed:Say('go');failed:Next();finishAll(false);failed.radio:Collect();failed:Next();check(failed.radio.pending==nil,'decode failure retires candidate')
failed:Say('win');failed:Next();failed:Dispose();finishAll(false);cleanup();check(failed.radio.cleanupNode==nil,'failed background decode does not leak cleanup receiver')
check(syncCount==0,'all audio playback uses existing decoded resources')
local already=Radio.New(node());local originalBackground=cache.BackgroundLoadResource
cache.BackgroundLoadResource=function(_,_,path)bgCount=bgCount+1;background[path]=true;return false end
already:Prepare('a02');already:Collect();check(not already.pending.failed,'false background return can mean already queued')
cache.BackgroundLoadResource=originalBackground
for i=1,8 do finishAll(true);already:Collect();if already:Prepare('a02')then break end end
check(already:Prepare('a02')==true,'already queued resource completes via existing cache without sync fallback');already:Dispose()
Levels.Init();local each=Radio.New(node());local lineCases=0
for id,line in pairs(DATA.lines)do
 for _,s in pairs(line.stems)do loaded[s.path]={length=s.seconds,path=s.path}end
 local clock=1000+lineCases*10;local total,speaking=each:Play(id,clock)
 check(math.abs(total-(line.duration+.52))<1e-9 and math.abs(speaking-(line.duration+.5))<1e-9,'actual metadata source clocks '..id)
 each:Update(clock+.26);local found=false
 for _,job in ipairs(each.jobs)do if job.path==line.stems.voice.path then found=job.source~=nil;check(job.source and math.abs(job.source.gain-.28)<1e-12,'actual processed voice source gain '..id)end end
 check(found,'all source lines have delayed processed voice '..id)
 each:Update(clock+line.stems.tail.at+.021);local tail=false
 for _,job in ipairs(each.jobs)do if job.path==line.stems.tail.path then tail=job.source~=nil end end
 check(tail,'all source lines schedule original return track '..id)
 each:Halt();for _,s in pairs(line.stems)do loaded[s.path]=nil end;lineCases=lineCases+1
end
each:Dispose()
return {backgroundLoads=bgCount,sources=#sources,lineCases=lineCases}
'''))
result=run();negatives=[]
for name,v,r in [
 ('synchronous decode',voice,radio.replace("cache:GetExistingResource('Sound',job.path)","cache:GetResource('Sound',job.path)")),
 ('missing source master',voice,radio.replace('Data.runtimeGain*envelope','1*envelope')),
 ('stale failure poisons new candidate',voice,radio.replace('self.pending and pendingPaths[path]','self.pending')),
 ('immediate voice onset',voice,radio.replace('at=now+stem.at','at=now')),
 ('TTL starts before cold preparation',voice.replace('if self.ready then for i=','if true then for i='),radio),
 ('fade kills detached old source',voice,radio.replace('self:Stop();self.time=now','self:Stop();for _,job in ipairs(self.fading)do Release(job)end;self.fading={};self.time=now'))]:
 check(v!=voice or r!=radio,'negative changes production '+name)
 try:run(v,r)
 except Exception as e:negatives.append({'case':name,'rejected':str(e).splitlines()[0]})
 else:raise AssertionError('negative escaped '+name)
paths=['scripts/audio/MatchVoice.lua','scripts/audio/MatchRadioDSP.lua','assets/Combat/MatchRadioDSP.json','tools/migration/import-match-radio.cjs','tools/migration/check-match-radio-dsp.py']
report={'result':'PASS','checks':checks,'cases':result,'negativeControls':negatives,'uniqueStems':len(files),'diskPcmBytes':sum(s['bytes'] for s in files.values()),
 'largestSingleLinePcmBytes':max(sum(s['bytes']-44 for s in l['stems'].values()) for l in data['lines'].values()),
 'sourceMaxError':max(x['reconstructionMaxError'] for x in oracle['oracle']),'exportedPcmMaxError':max(x['exportedPcmMaxError'] for x in oracle['oracle']),
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
 'boundary':'Actual frozen source WebAudio graph and actual Lua methods with async adapters. No engine audible listening acceptance or sample-accurate native mixer assertion.'}
(ROOT/'docs/migration/evidence/match-radio-dsp-offline.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
