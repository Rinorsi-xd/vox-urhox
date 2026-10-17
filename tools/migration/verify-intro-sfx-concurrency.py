"""Real frozen galaxy/audio calls versus real Lua session/audio ownership."""
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(['node', 'tools/migration/source-intro-sfx-concurrency.cjs'], encoding='utf-8'))
old = ast.parse((ROOT / 'tools/migration/verify-intro-audio-tail.py').read_text(encoding='utf-8'))
fixture = next(node.value.args[0].value for node in old.body if isinstance(node, ast.Assign)
               and any(isinstance(target, ast.Name) and target.id == 'checks' for target in node.targets))
setup = fixture.split('for _,case in ipairs(REFERENCE.masterTails)do')[0]

TEST = '''
local function Blank()
 wall=0;Levels.Set('sfx',.65)
 local value=Audio.New({audio={},durations={vo_n04=5}})
 for _,id in ipairs({'sfx_blip','sfx_alarm','sfx_scribble','sfx_tv_cut'})do value.sounds[id]=Sound(id)end
 return value
end
package.loaded['urhox-libs/UI']={};package.loaded['core.Coord']={}
for _,name in ipairs({'core.ResourceData','ui.IntroTypography','app.ResourceGate','ui.IntroPage','intro.IntroImpact','intro.IntroSortie'})do package.loaded[name]={}end
local Session=require 'intro.IntroSession'
local value=Blank();local cues={};local handles={};local original=value.Sfx
value.Sfx=function(self,id,opt)
 local source,token=original(self,id,opt);cues[#cues+1]={id=id,opt=opt,source=source,token=token};handles[source]=true
 return source,token
end
local owner=setmetatable({stage='ad',shot='galaxy',age=5,voiceDuration=5,audio=value,data=value.data},{__index=Session})
owner:UpdateAdCues()
Check(#cues==#REFERENCE.cues,'actual Lua galaxy emits same authored catch-up cue count')
local count=0;for _ in pairs(handles)do count=count+1 end
Check(count==REFERENCE.independentSources,'each original galaxy cue retains an independent live source')
for i,cue in ipairs(cues)do
 local want=REFERENCE.cues[i]
 Check(cue.id==want.id and cue.opt.vol==want.opt.vol and cue.opt.rate==want.opt.rate,'actual source galaxy cue parameters '..i)
 Near(cue.source.frequency,want.frequency,'unchanged absolute playback frequency '..i)
 Near(cue.source.gain,want.gain,'unchanged gain '..i)
 Check(cue.source.playing and cue.source.kind=='VoxIntroSfx','cue live on original SFX bus '..i)
end
Check(#value.sources==40,'pool grows only to actual forty-cue high water')
for _,slot in ipairs(value.sources)do slot.source:StopImmediate()end
for burst=1,4 do
 owner.cueState={};owner:UpdateAdCues();Check(#value.sources==40,'ended sources reused on repeated original burst '..burst)
 for _,slot in ipairs(value.sources)do slot.source:StopImmediate()end
end
value:Dispose()
local pressure=Blank()
local loop,loopToken=pressure:Sfx('alarm',{vol=.45,loop=true})
local fade,fadeToken=pressure:Sfx('scribble',{vol=.4,loop=true});pressure:StopSfx(fade,.2,fadeToken)
fade:StopImmediate();fade.fadingOut=true
local cut,cutToken=pressure:Sfx('tv_cut',{vol=.5,stopAfter=.45,stopFade=.15});cut:StopImmediate()
for i=1,40 do pressure:Sfx('blip',{vol=.25,rate=.8+i*.015})end
Check(loop.playing and pressure.sources[1].token==loopToken,'pool pressure preserves live original loop')
Check(pressure.sources[2].token==fadeToken,'non-playing native fading source remains reserved')
Check(pressure.sources[3].token==cutToken,'non-playing delayed wall fade remains reserved')
Check(#pressure.sources==43,'only occupied or scheduled sources cause growth')
Levels.Set('sfx',0);local n=#pressure.sources;pressure:Sfx('blip')
Check(loop.playing and loop.gain==0 and #pressure.sources==n+1,'mute preserves playback ownership')
Levels.Set('sfx',.65)
local frozen=pressure.time;pressure:Update(5,false)
Check(pressure.time==frozen and pressure.sources[2].stopAt~=nil,'focus suspension preserves scheduled stop')
Check(pressure:StopSfx(loop,.2,loopToken),'original loop handle still stops correct sound under pressure')
pressure:Update(.23,true);fade.fadingOut=false
Check(not loop.playing and not fade.playing,'pending original fade finishes after focus resumes')
local replacement,replacementToken=pressure:Sfx('blip')
Check(replacement==loop and replacementToken~=loopToken,'fully idle source reused with new ownership token')
Check(not pressure:StopSfx(loop,.1,loopToken),'stale handle cannot stop new sound after genuine reuse')
Check(replacement.playing,'late original callback cannot interrupt replacement')
local scene=pressure.scene;pressure:Dispose()
for _,slot in ipairs(pressure.sources)do Check(not slot.source.playing and slot.source.disposed,'Dispose stops every expanded slot')end
local size=#scene.sources
Check(pressure:Sfx('blip')==nil and #scene.sources==size,'disposed audio cannot recreate a source')
Check(not pressure:StopSfx(loop,.1,loopToken),'disposed audio rejects retained original handle')
return checks
'''


def run(module_text=None):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(item) for item in value])
        return value

    lua.globals().REFERENCE = table(reference)
    if module_text:
        lua.globals().TEST_AUDIO_MODULE = module_text
        preload = "package.preload['audio.IntroAudio']=assert(load(TEST_AUDIO_MODULE,'@scripts/audio/IntroAudio.lua'))\n"
    else:
        preload = ''
    return lua.execute(preload + setup + TEST)


current = (ROOT / 'scripts/audio/IntroAudio.lua').read_text(encoding='utf-8')
if '--baseline' in sys.argv:
    try:
        run()
    except Exception as error:
        if 'each original galaxy cue retains an independent live source' not in str(error):
            raise
        result = {'result': 'EXPECTED_BASELINE_FAILURE', 'error': str(error), 'source': reference,
                  'productionSha256': hashlib.sha256(current.encode()).hexdigest()}
        out = ROOT / 'docs/migration/evidence/intro-sfx-concurrency-before.json'
        out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'result': result['result'], 'error': result['error']}, indent=2))
        sys.exit(0)
    raise AssertionError('Expected current source stealing to fail before fix')

checks = run()
missing_guard = current.replace(' and not candidate.source.fadingOut and not candidate.stopAt and not candidate.fadeWallAt', '')
if missing_guard == current:
    raise AssertionError('Missing-guard negative control could not be constructed')
try:
    run(missing_guard)
except Exception as error:
    rejected = str(error)
else:
    raise AssertionError('Missing-reservation negative control unexpectedly passed')
missing_release = current.replace('slot.source:Remove();slot.source:Dispose()', '')
if missing_release == current:
    raise AssertionError('Missing-release negative control could not be constructed')
try:
    run(missing_release)
except Exception as error:
    release_rejected = str(error)
else:
    raise AssertionError('Scene-only release negative control unexpectedly passed')
result = {'result': 'PASS', 'checks': checks, 'source': reference, 'negativeControl': rejected,
          'missingReleaseNegativeControl': release_rejected,
          'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in
                               ['scripts/audio/IntroAudio.lua', 'scripts/intro/IntroSession.lua']},
          'boundary': 'Executes actual frozen Intro.actGalaxy task and IntroAudio.sfx/_play, actual Lua IntroSession.UpdateAdCues and IntroAudio, with controlled source/scene adapters. Delayed-frame catch-up is an ownership stress case, not a frame-time benchmark. No native decoding/mixing/listening, Web performance, audible compressor equivalence or mobile acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-sfx-concurrency-offline.json'
out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in result.items() if key != 'source'}, indent=2))
