"""Compare real frozen JS audio control/envelopes with the real Lua module."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
source = json.loads(subprocess.run(['node', '--experimental-vm-modules', 'tools/migration/source-intro-audio.cjs'], check=True, capture_output=True, text=True, encoding='utf-8').stdout)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


lua.globals().SOURCE_AUDIO = table(source)
checks = lua.execute('''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,message) checks=checks+1;assert(ok,message) end
local disposed=0
Scene=function() return {CreateChild=function() return {CreateComponent=function() return {
 SetSoundType=function() end,StopImmediate=function(self) self.playing=false end,
 Remove=function(self) self.detached=true end,Dispose=function(self) assert(self.detached and not self.playing);self.disposed=true end,
 Play=function(self,sound,frequency,gain) self.sound=sound;self.frequency=frequency;self.gain=gain;self.playing=true end,
 Seek=function() end,
} end} end,Dispose=function() disposed=disposed+1 end} end
audio={PauseSoundType=function() end,ResumeSoundType=function() end}
local Levels=require 'audio.AudioLevels';Levels.Init(nil)
local Intro=require 'audio.IntroAudio'
local data={audio={},durations={}}
local p=Intro.New(data)
local function Sound(length) return {length=length,GetFrequency=function() return 48000 end,SetLooped=function() end} end
p.sounds.vo_test=Sound(2);p.sounds.bgm_test=Sound(40);p:Music('bgm_test',{vol=.5,fade=0})
for _,row in ipairs(SOURCE_AUDIO.trace) do
 if row.action=='end' then p.voice:StopImmediate() end
 p:Update(row.time-p.time,true)
 if row.action=='voice' then p:Voice('vo_test') elseif row.action=='stop' then p:StopVoice() end
 p:UpdateGains()
 local actual=p.music[p.musicIndex].source.gain
 Check(math.abs(actual-row.gain)<1e-10,'frozen JS duck envelope differs at '..row.time..': '..actual..' versus '..row.gain)
end
local clock=p.time;local gain=p.music[p.musicIndex].source.gain
p:Update(5,false);Check(p.time==clock and p.music[p.musicIndex].source.gain==gain,'focus pause freezes original audio clock/envelope')
for _,row in ipairs(SOURCE_AUDIO.cues) do
 p.sounds[row.id]=p.sounds[row.id] or Sound(1)
 Levels.Set('sfx',row.volume)
 local source=p:Sfx(row.id:sub(5),{vol=row.relative,rate=row.rate})
 Check(math.abs(source.gain-row.gain)<1e-10,'frozen source normalized SFX/master/volume differs: '..row.id)
 Check(source.frequency==48000*row.rate,'cue keeps source-relative absolute playback frequency: '..row.id)
end
for _,case in ipairs(SOURCE_AUDIO.stops) do
 Levels.Set('sfx',.65);local source,token=p:Sfx('alarm',{vol=.32,loop=true});local start=p.time
 local fade=type(case.fade)=='number' and case.fade or nil
 Check(p:StopSfx(source,fade,token),'owned SFX fade is accepted')
 for _,row in ipairs(case.samples) do
  p:Update(start+row.elapsed-p.time,true)
  Check(math.abs(source.gain-row.gain)<1e-10,'frozen original SFX stop gain differs at '..row.elapsed)
  Check((not source.playing)==row.stopped,'frozen SFX stop preserves the source .02 second scheduling tail')
 end
end
Levels.Set('sfx',.65);local repeated,repeatToken=p:Sfx('alarm',{vol=.32,loop=true});local started=p.time
p:StopSfx(repeated,.6,repeatToken)
for _,row in ipairs(SOURCE_AUDIO.repeatedStops) do
 p:Update(started+row.elapsed-p.time,true)
 if row.action=='stop' then p:StopSfx(repeated,.2,repeatToken) end
 if row.action=='volume' then Levels.Set('sfx',row.volume) end
 Check(math.abs(repeated.gain-row.gain)<1e-10,'repeated stop or volume slider must keep the source current fade level')
 Check((not repeated.playing)==row.stopped,'repeated stop schedules the final tail correctly')
end
for _,slot in ipairs(p.sources) do slot.source.playing=false;slot.stopAt=nil;slot.fadeWallAt=nil end
local stale,staleToken=p:Sfx('alarm',{loop=true});p:StopSfx(stale,.2,staleToken)
local capacity=#p.sources
for i=1,capacity do p:Sfx('blip',{loop=true}) end
Check(stale.playing and p.sources[1].token==staleToken,'pool pressure preserves the owned fading source')
p:Update(.23,true);Check(not stale.playing,'owned fade completes before its source can be reused')
local replacement,newToken=p:Sfx('blip',{loop=true})
Check(replacement==stale and newToken~=staleToken,'fully idle source is reused with a fresh token')
Check(not p:StopSfx(stale,.1,staleToken),'stale handle token cannot fade a replaced sound')
local replacedGain=stale.gain;p:Update(.3,true)
Check(stale.playing and stale.gain==replacedGain,'old scheduled fade cannot stop a replacement in the reused slot')
local frozen=p.time;p:StopSfx(stale,.2);p:Update(5,false)
Check(p.time==frozen and stale.playing,'hidden focus freezes SFX stop scheduling')
p:Update(.23,true);Check(not stale.playing,'focused audio resumes and completes pending SFX stop')
p:Dispose();Check(disposed==1 and #p.unwatch==0,'disposing audio releases retained scene and all bus subscriptions')
Check(not p:StopSfx(stale,.2),'disposed audio rejects retained SFX handles')
return checks
''')
result = {'result': 'PASS', 'checks': checks, 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'envelopeSamples': len(source['trace']), 'sfxParameterCases': len(source['cues']),
          'sfxStopCases': len(source['stops']), 'sfxRepeatedStopSamples': len(source['repeatedStops']),
          'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in
                               ['scripts/audio/IntroAudio.lua', 'scripts/audio/IntroAudioTail.lua', 'scripts/audio/AudioLevels.lua']},
          'boundary': 'Actual frozen IntroAudio.js module executed through vm.SourceTextModule; WebAudio graph/control automation adapted. Actual Lua IntroAudio and AudioLevels executed. Compares original .15/.6 duck ramps, all SFX normalization/gain/rate combinations, stop fades/default/zero/.02 tail, repeated stop, slider during fade, reuse token and focus/disposal. Does not measure native mixing, audible peaks/compressor/lowpass, mouth waveform, GPU, Web frame timing or mobile performance.'}
(ROOT / 'docs/migration/evidence/intro-audio-envelope-offline.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
