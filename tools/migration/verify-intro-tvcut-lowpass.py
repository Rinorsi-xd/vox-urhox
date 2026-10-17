"""Actual Lua selector/gains/envelope and shipped filter PCM, without native output."""
import array, hashlib, json, os, sys, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

data = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
dsp = json.loads((ROOT / 'docs/migration/evidence/intro-tvcut-lowpass-source.json').read_text())
asset = ROOT / 'assets' / data['audio']['sfx_tv_cut_lowpass1800']
with wave.open(str(asset), 'rb') as sound:
    pcm = array.array('h', sound.readframes(sound.getnframes()))
    wav = {'channels': sound.getnchannels(), 'sampleRate': sound.getframerate(),
           'frames': sound.getnframes(), 'sampleWidth': sound.getsampwidth()}
assert wav == {'channels': 2, 'sampleRate': 48000, 'frames': 71040, 'sampleWidth': 2}
assert max(abs(v) for v in pcm) < 32767
assert hashlib.sha256(asset.read_bytes()).hexdigest() == dsp['output']['sha256']
assert dsp['oracle']['referenceError'] == 0 and dsp['negativeControls']['originalUnfilteredRejected']
assert dsp['oracle']['trace'] == {'gains': [1], 'filters': [{'type': 'lowpass', 'frequency': 1800, 'Q': .5}], 'compressors': 0}

fixture = r'''
package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,label)checks=checks+1;assert(ok,label)end
local function Near(a,b,label)Check(math.abs(a-b)<1e-9,label)end
local wall=0;Time={GetSystemTime=function()return wall end}
local requested={}
cache={GetResource=function(_,kind,path)
 Check(kind=='Sound','actual loader requests Sound')
 requested[path]=(requested[path]or 0)+1
 return {name=path,length=1.48,GetFrequency=function()return 48000 end,SetLooped=function(self,v)self.looped=v end}
end}
Scene=function()
 local scene={}
 function scene:CreateChild()return {CreateComponent=function()
  local source={playing=false,gain=1}
  function source:SetSoundType(kind)self.kind=kind end
  function source:StopImmediate()self.sound=nil;self.playing=false end
  function source:Play(sound,frequency,gain)self.sound=sound;self.frequency=frequency;self.gain=gain;self.playing=true end
  function source:Seek()end
  function source:Remove()self.detached=true end
  function source:Dispose()Check(self.detached and not self.playing,'retained source explicitly released');self.disposed=true end
  return source
 end}end
 function scene:Dispose()end
 return scene
end
audio={PauseSoundType=function()end,ResumeSoundType=function()end}
local Levels=require'audio.AudioLevels';Levels.Init(nil);Levels.Set('sfx',.65)
local Audio=require'audio.IntroAudio'
local a=Audio.New(DATA)
while #a.queue>0 do local _,err=a:PrepareNext();Check(not err,'prepare succeeds')end
Check(requested[DATA.audio.sfx_tv_cut]==1,'original raw resource prepared once')
Check(requested[DATA.audio.sfx_tv_cut_lowpass1800]==1,'derived filter resource prepared once')
Near(a:Duration('sfx_tv_cut'),1.48,'raw duration retained')
Near(a:Duration('sfx_tv_cut_lowpass1800'),1.48,'derived duration retained')
local base=.5*10^((-12-(-8.6))/20)*.9
local src,token=a:Sfx('tv_cut',{vol=.5,lowpass=1800,stopAfter=.45,stopFade=.15})
Check(src.sound.name==DATA.audio.sfx_tv_cut_lowpass1800,'filtered cue chooses baked resource')
Near(src.gain,base*.65,'original cue normalization and volume applied once')
Near(src.frequency,48000,'filter does not alter playback rate')
Check(not src.sound.looped,'filtered cue is one shot')
local slot=a.sources[1]
Near(slot.fadeWallAt,450,'wall timer at 450ms');Near(slot.fadeDuration,.15,'150ms live fade')
Levels.Set('sfx',.3);Near(src.gain,base*.3,'user slider remains live')
wall=449;a:Update(.449,true);Check(not slot.stopFade,'no early fade')
wall=450;a:Update(.001,true);Near(slot.stopFade.start,.45,'fade starts at audio time');Near(src.gain,base*.3,'fade starts at full runtime gain')
Near(slot.stopAt,.62,'150ms fade plus 20ms disposal margin')
wall=525;a:Update(.075,true);Near(src.gain,base*.3*.5,'fade midpoint retained')
wall=600;a:Update(.075,true);Near(src.gain,0,'fade zero at 600ms');Check(src.playing,'20ms tail retained')
wall=621;a:Update(.021,true);Check(not src.playing,'source stops after tail')
local raw=a:Sfx('tv_cut',{vol=.8})
Check(raw.sound.name==DATA.audio.sfx_tv_cut,'unfiltered sortie cue keeps original MP3')
Near(raw.gain,.8*10^((-12-(-8.6))/20)*.9*.3,'sortie volume unmodified')
Check(a:StopSfx(raw,.1),'raw cue stoppable');a:Dispose()
wall=0;local suspended=Audio.New(DATA)
while #suspended.queue>0 do suspended:PrepareNext()end
local hidden=suspended:Sfx('tv_cut',{vol=.5,lowpass=1800,stopAfter=.45,stopFade=.15})
wall=450;suspended:Update(.45,false)
Near(suspended.time,0,'hidden focus suspends audio time')
Near(suspended.sources[1].stopFade.start,0,'wall timer still requests fade while suspended')
Near(hidden.gain,base*.3,'hidden timer does not bake fade into PCM')
wall=525;suspended:Update(.075,true);Near(hidden.gain,base*.3*.5,'resumed audio advances live fade')
suspended:BeginTail();wall=875;suspended:Update(.35,true)
Near(suspended:MasterLevel(),1-.35/1.2,'opening master remains runtime automation')
suspended:Dispose()
return checks
'''

def run(text, mapping=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def convert(v):
        if isinstance(v, dict): return lua.table_from({k: convert(x) for k, x in v.items()})
        if isinstance(v, list): return lua.table_from([convert(x) for x in v])
        return v
    lua.globals().DATA = convert(mapping or data)
    return lua.execute(text)

checks = run(fixture)
mutations = {
    'missing-filter-selection': fixture.replace('lowpass=1800,stopAfter', 'lowpass=0,stopAfter'),
    'double-volume-expectation': fixture.replace('Near(src.gain,base*.65,', 'Near(src.gain,base*.65*.5,'),
    'early-envelope-expectation': fixture.replace('Near(slot.fadeWallAt,450,', 'Near(slot.fadeWallAt,400,'),
}
rejected = {}
for label, text in mutations.items():
    try:
        run(text)
    except Exception as error:
        rejected[label] = str(error).split('\n')[0]
    else:
        raise AssertionError('Negative control unexpectedly passed: ' + label)
paths = ['scripts/audio/IntroAudio.lua', 'scripts/audio/AudioLevels.lua', 'assets/Intro/Intro.json',
         'assets/Intro/Audio/sfx_tv_cut.mp3', 'assets/Intro/Audio/sfx_tv_cut_lowpass1800.wav',
         'tools/migration/verify-intro-tvcut-lowpass.py', 'tools/migration/import-intro-tvcut-lowpass.cjs']
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': dsp['baseline'], 'sourceHashes': dsp['provenance'],
          'productionHashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'evidenceReportHashes': {'docs/migration/evidence/intro-tvcut-lowpass-source.json': hashlib.sha256((ROOT / 'docs/migration/evidence/intro-tvcut-lowpass-source.json').read_bytes()).hexdigest()},
          'wav': wav, 'negativeControls': rejected, 'approvedSourceAssets': [str(asset.relative_to(ROOT)).replace('\\', '/')],
          'boundary': 'Actual IntroAudio/AudioLevels and actual Intro.json execute in Lua54 with controlled SoundSource/Scene/cache. Verifies raw and derived preparation/selection, unchanged original-id normalization, one volume application, slider/master, playback rate, duration, 450ms wall trigger, 150ms focus-aware runtime fade and 20ms disposal margin. PCM and source-render evidence are hash-bound. Negative controls deliberately change cue options or expected gain/envelope; they are not native playback tests. No native decoder, audible mixing/compressor parity, rendered continuity or device performance acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-tvcut-lowpass-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
