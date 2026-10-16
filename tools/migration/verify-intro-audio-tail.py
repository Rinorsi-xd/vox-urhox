"""Exact frozen IntroAudio master automation versus actual Lua audio/tail owner."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
source=json.loads(subprocess.check_output(['node','--experimental-vm-modules','tools/migration/source-intro-audio.cjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
 if isinstance(value,dict):return lua.table_from({k:table(v)for k,v in value.items()})
 if isinstance(value,list):return lua.table_from([table(v)for v in value])
 return value
lua.globals().REFERENCE=table(source)
checks=lua.execute('''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,label)checks=checks+1;assert(ok,label)end
local function Near(actual,want,label)Check(math.abs(actual-want)<1e-9,label..' actual='..actual..' expected='..want)end
local wall=0;Time={GetSystemTime=function()return wall end}
local scenes={};local resources={}
local function Sound(name)
 local value={name=name,length=60,SetLooped=function()end,GetFrequency=function()return 48000 end,owners=0}
 resources[name]=value;return value
end
Scene=function()
 local scene={sources={},disposed=false}
 function scene:CreateChild()return {CreateComponent=function()
  local source={playing=false,frequency=0,gain=1,disposed=false}
  function source:SetSoundType(kind)self.kind=kind end
  function source:StopImmediate()if self.sound then self.sound.owners=self.sound.owners-1;self.sound=nil end;self.playing=false end
  function source:Play(sound,frequency,gain)
   self:StopImmediate();Check(not sound.released,'playing resource still owned');self.sound=sound;sound.owners=sound.owners+1
   self.frequency=frequency==0 and sound:GetFrequency()or frequency;self.gain=gain;self.playing=true
  end
  function source:Seek()end
  scene.sources[#scene.sources+1]=source;return source
 end}end
 function scene:Dispose()
  Check(not self.disposed,'dedicated scene disposed once');self.disposed=true
  for _,source in ipairs(self.sources)do Check(not source.playing,'playing source stopped before owning scene disposal');source.disposed=true end
 end
 scenes[#scenes+1]=scene;return scene
end
audio={PauseSoundType=function()end,ResumeSoundType=function()end}
cache={ReleaseAllResources=function(_,force)
 Check(force==false,'shared cache release never forces tail resources')
 for _,sound in pairs(resources)do if sound.owners==0 then sound.released=true end end
end}
local Levels=require 'audio.AudioLevels';Levels.Init(nil)
local Audio=require 'audio.IntroAudio';local Tail=require 'audio.IntroAudioTail'
local function New()
 Levels.Set('voice',.6);Levels.Set('sfx',.65);Levels.Set('music',.75)
 local value=Audio.New({audio={},durations={}})
 value.sounds.vo_test=Sound('voice');value.sounds.bgm_test=Sound('music');value.sounds.sfx_alarm=Sound('sfx')
 value:Music('bgm_test',{vol=.5,fade=0});value:Voice('vo_test');local sfx=value:Sfx('alarm',{vol=.32,rate=.7,loop=true})
 return value,sfx
end
for _,case in ipairs(REFERENCE.masterTails)do
 wall=0;local value,sfx=New();local scene=value.scene
 Check(value:BeginTail(),'first fade begins');local deadline=value.tail.deadline
 local previous=0;local adopted=false
 for _,row in ipairs(case.samples)do
  wall=row.elapsed*1000
  if adopted then Tail.Update(row.elapsed-previous,row.focused)else value:Update(row.elapsed-previous,row.focused)end
  previous=row.elapsed
  if case.name=='volume'and row.elapsed==.7 then Levels.Set('voice',.3);Levels.Set('sfx',.2);Levels.Set('music',.25)end
  if row.elapsed==.7 then
   Check(Tail.Adopt(value),'handoff accepts independent audio at visual end');adopted=true
   Check(Tail.Adopt(value),'duplicate handoff idempotent')
   local snapshot=Tail.Snapshot()
   Check(snapshot.active and snapshot.voicePlaying==1 and snapshot.sfxPlaying==1 and snapshot.musicPlaying==1,'tail query reports playing channel counts')
   Near(snapshot.master,value:MasterLevel(),'tail query master is current')
   Near(snapshot.remainingWallMs,700,'tail query absolute remaining deadline')
   for _,v in pairs(snapshot)do Check(type(v)=='number'or type(v)=='boolean','tail query exposes no native object or owner reference')end
   cache:ReleaseAllResources(false)
   for _,sound in pairs(value.sounds)do Check(not sound.released,'playing source protects resource across non-force cache sweep')end
  end
  Check(value.active==not row.closed,'source delayed close boundary')
  Check(scene.disposed==row.closed,'dedicated sound scene lifetime matches source')
  if not row.closed then
   Near(value.time,row.audioTime,'focus suspension keeps source audio clock')
   Near(value:MasterLevel(),row.master,'entire opening master envelope')
   Near(value.voice.gain,row.voice,'voice follows master and original slider')
   Near(sfx.gain,row.sfx,'sfx follows master and original normalization/rate')
   Near(value.music[value.musicIndex].source.gain,row.music,'music follows master/duck/log slider')
   Check(sfx.frequency==48000*.7,'master does not alter playback frequency')
  else
   Check(#value.unwatch==0,'close removes all volume subscriptions')
   Check(not value:Snapshot().active,'inactive snapshot never queries disposed native sources')
   local snapshot=Tail.Snapshot();Check(not snapshot.active and snapshot.remainingWallMs==0 and snapshot.master==0,'tail query inactive after deadline')
  end
  if row.elapsed<1.4 then
   Check(not value:BeginTail(),'repeat finish cannot restart tail');Check(value.tail.deadline==deadline,'repeat exit keeps original wall deadline')
  end
 end
 Near(case.closeDeadline,1400,'actual JS deferred close deadline')
 Tail.Update(10,true);value:Dispose();Tail.CancelAll()
end
wall=0;local stopped=New();stopped:BeginTail();Tail.Adopt(stopped);Tail.CancelAll()
Check(not stopped.active and stopped.scene.disposed,'Stop immediately disposes live tail');Tail.CancelAll()
Check(not Tail.Snapshot().active,'Stop clears query state immediately')
wall=0;local old=New();old:BeginTail();Tail.Adopt(old)
local replacement=Audio.New({audio={},durations={}})
Check(not old.active and old.scene.disposed,'new opening immediately cancels previous tail');replacement:Dispose()
wall=0;local jumped=New();jumped:BeginTail();Tail.Adopt(jumped);wall=5000;Tail.Update(.016,false)
Check(not jumped.active,'wall-clock jump closes tail despite clamped dt and suspended audio')
wall=0;local clamped,sfx=New();clamped:BeginTail();Tail.Adopt(clamped)
for _,row in ipairs(REFERENCE.masterTails[1].samples)do
 wall=row.elapsed*1000;Tail.Update(.001,true)
 if not row.closed then
  Near(clamped:MasterLevel(),row.master,'master follows source wall elapsed despite clamped frame dt')
  if row.elapsed>=1.2 then
   Near(clamped.voice.gain,0,'voice reaches zero at 1200ms despite clamped dt')
   Near(sfx.gain,0,'sfx reaches zero at 1200ms despite clamped dt')
   Near(clamped.music[clamped.musicIndex].source.gain,0,'music reaches zero at 1200ms despite clamped dt')
  end
 else Check(not clamped.active,'clamped dt retains 1400ms wall close')end
end
wall=0;local resumed=New();resumed:BeginTail();Tail.Adopt(resumed)
wall=300;Tail.Update(.001,true);Near(resumed:MasterLevel(),.75,'focused wall elapsed advances tail')
wall=400;Tail.Update(.001,false);wall=500;Tail.Update(.001,false)
Near(resumed:MasterLevel(),.75,'hidden intervals do not advance tail')
Tail.Update(.001,true);Near(resumed:MasterLevel(),.75,'resume does not charge suspended interval')
wall=800;Tail.Update(.001,true);Near(resumed:MasterLevel(),.5,'resumed focused wall elapsed advances tail')
wall=1400;Tail.Update(.001,false);Check(not resumed.active,'wall close still wins over paused master')
wall=0;local first=New();local second=New();first:BeginTail();second:BeginTail();Tail.Adopt(first);Tail.Adopt(second)
Check(not first.active and second.active,'adopting a different audio object releases old owner');Tail.CancelAll()
return checks
''')
paths=['scripts/audio/IntroAudio.lua','scripts/audio/IntroAudioTail.lua','scripts/audio/AudioLevels.lua','scripts/app/HangarApp.lua']
report={'result':'PASS','checks':checks,'sourceCommit':source['commit'],'sourceHashes':source['sourceHashes'],'sourceMasterTails':source['masterTails'],
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Actual frozen IntroAudio.js and actual Lua IntroAudio/IntroAudioTail/AudioLevels; controlled SoundSource/Scene/cache ownership adapters. Compares all three buses and source master at 0/350/700/1200/1399/1400ms, source hidden-context suspend versus wall close, slider changes, duplicate finish/adoption, non-force cache reference model, replacement/Stop and large wall-clock jump. Focused wall intervals approximate the source AudioContext clock independently of clamped frame dt; uncertain focus-transition intervals are discarded, not claimed as exact audio-clock equivalence. Actual HangarApp Update/Stop hooks await Web integration. No native cache-reference, mixing/output, GPU, frame continuity or target-device acceptance.'}
out=ROOT/'docs/migration/evidence/intro-audio-tail-offline.json';out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items()if k!='sourceMasterTails'},indent=2))
