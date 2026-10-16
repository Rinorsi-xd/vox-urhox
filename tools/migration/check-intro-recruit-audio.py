"""Recruit title SFX versus executed frozen H5 acts and frozen 5487 negative."""
import argparse
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

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--session', type=Path, help='Optional candidate Session; default tests current production')
args = parser.parse_args()
production = ROOT / 'scripts/intro/IntroSession.lua'
before = hashlib.sha256(production.read_bytes()).hexdigest()
target = (args.session or production).resolve()
is_production = target == production.resolve()
target_bytes = target.read_bytes()
frozen = ROOT / '.tmp/outgame-cached-1792114575097/scripts/intro/IntroSession.lua'
frozen_bytes = frozen.read_bytes()
frozen_hash = hashlib.sha256(frozen_bytes).hexdigest()
assert frozen_hash == 'ee64cbda80f72353ddb880bb825f583dc4ea51846c7f3b5db5f2cfecc445f3b9', 'Frozen 5487 Session drift'
source = json.loads(subprocess.check_output(
    ['node', 'tools/migration/source-intro-timing.mjs'], encoding='utf-8'))
audio_runner = (ROOT / 'tools/migration/source-intro-audio.cjs').read_text(encoding='utf-8')
assert audio_runner.count('for(const relative of [.2,.5,1])') == 1
audio_source = json.loads(subprocess.check_output(
    ['node', '--experimental-vm-modules', '-e', audio_runner.replace(
        'for(const relative of [.2,.5,1])', 'for(const relative of [.75])')],
    encoding='utf-8', stderr=subprocess.PIPE))
data = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
fixture = (ROOT / 'tools/migration/check-intro-timing.lua').read_text(encoding='utf-8')
checks = 0


def check(ok, message):
    global checks
    checks += 1
    assert ok, message


def convert(lua, value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(lua, v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(lua, v) for v in value])
    return value


def runner(raw=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    if raw is not None:
        lua.globals().STAGED_SESSION = raw
        lua.execute("package.preload['intro.IntroSession']=function()return assert(load(STAGED_SESSION))()end")
    lua.globals().TIMING_DATA = convert(lua, data)
    return lua.execute(fixture)


def actual_cues(run, definition):
    result = run(definition['held'], definition['n06'], definition['n10'], None)
    start = next(v['t'] for _, v in result['voices'].items() if v['id'] == 'vo_n12')
    sounds = [dict(v.items()) for _, v in result['sounds'].items()
              if v['shot'] in ['recruit', 'peacekeeper', 'master', 'mechanic'] and v['id'] == 'slam']
    return start, sounds


def compare(run, definitions):
    rows = []
    for definition in definitions:
        source_start = next(v['t'] for v in definition['events'] if v['type'] == 'voice' and v['id'] == 'vo_n12')
        expected = [v for v in definition['events']
                    if v['type'] == 'sfx' and v['id'] == 'slam' and v['t'] >= source_start]
        check(len(expected) == 6, 'Actual frozen actRecruit/words emits six title slams')
        actual_start, sounds = actual_cues(run, definition)
        check(len(sounds) == len(expected), 'Recruit title SFX count matches actual frozen source')
        ages = []
        for actual, wanted in zip(sounds, expected):
            age, wanted_age = actual['t'] - actual_start, wanted['t'] - source_start
            check(abs(age - wanted_age) < .035, 'Title slam follows frozen word cue time')
            check(actual['opt']['vol'] == wanted['opt']['vol'] == .75, 'Title uses actual source .75 gain')
            check(actual['opt']['rate'] is None and actual['opt']['loop'] is None, 'Title preserves source default rate and one-shot')
            ages.append({'sourceAge': wanted_age, 'candidateAge': age})
        rows.append({'held': definition['held'], 'n06': definition['n06'], 'n10': definition['n10'], 'cues': ages})
    return rows


old = runner(frozen_bytes.decode('utf-8'))
try:
    compare(old, source['cases'][:1])
except AssertionError as error:
    negative = str(error)
    check(negative == 'Recruit title SFX count matches actual frozen source', 'Frozen 5487 fails for the intended missing cue')
else:
    raise AssertionError('Frozen 5487 unexpectedly has all recruit title slams')

rows = compare(runner(None if is_production else target_bytes.decode('utf-8')), source['cases'])
mutated = target_bytes.decode('utf-8').replace("self.audio:Sfx('slam',{vol=.75})", "self.audio:Sfx('slam',{vol=.5})")
try:
    compare(runner(mutated), source['cases'][:1])
except AssertionError as error:
    mutation = str(error)
    check(mutation == 'Title uses actual source .75 gain', 'Wrong title volume mutation is rejected')
else:
    raise AssertionError('Wrong title volume escaped regression')

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
package.path='scripts/?.lua;'..package.path
Scene=function()return {CreateChild=function()return {CreateComponent=function()return {
 SetSoundType=function()end,StopImmediate=function(self)self.playing=false end,
 Play=function(self,sound,frequency,gain)self.sound=sound;self.frequency=frequency;self.gain=gain;self.playing=true end,
 Seek=function()end}end}end,Dispose=function()end}end
local Levels=require 'audio.AudioLevels';Levels.Init(nil)
local Audio=require 'audio.IntroAudio';A=Audio.New({audio={},durations={}})
local sound={length=1,GetFrequency=function()return 48000 end,SetLooped=function(self,value)self.looped=value end}
A.sounds.sfx_slam=sound
function PlayTitle(volume)
 Levels.Set('sfx',volume)
 local source=A:Sfx('slam',{vol=.75})
 return source.gain,source.frequency,source.sound.looped
end
""")
gains = []
for row in audio_source['cues']:
    if row['id'] != 'sfx_slam' or row['rate'] != 1:
        continue
    gain, frequency, looped = lua.globals().PlayTitle(row['volume'])
    check(abs(gain - row['gain']) < 1e-12, 'Actual Lua IntroAudio matches frozen normalized title gain')
    check(frequency == 48000, 'Default title rate uses actual sound sample rate')
    check(looped is False, 'Default title is one-shot')
    gains.append({'sfxVolume': row['volume'], 'sourceGain': row['gain'], 'candidateGain': gain})

check(before == hashlib.sha256(production.read_bytes()).hexdigest(), 'Frozen production remains unchanged')
check(target_bytes == target.read_bytes(), 'Tested Session remains unchanged during execution')
paths = [production, ROOT / 'scripts/audio/IntroAudio.lua', ROOT / 'scripts/audio/AudioLevels.lua']
report = {
    'result': 'PASS' if is_production else 'STAGED_PASS', 'checks': checks, 'baseline': source['baseline'],
    'sourceHashes': {**source['sourceHashes'], **audio_source['sourceHashes']},
    'productionHashes': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in paths},
    'testedSession': str(target), 'testedSessionIsProduction': is_production,
    'testedSessionSha256': hashlib.sha256(target_bytes).hexdigest(),
    'frozenNegativeControl': {'manifest': 'manifest-54870f56.json', 'file': str(frozen),
                              'sha256': frozen_hash, 'observedFailure': negative},
    'wrongVolumeMutation': mutation, 'cases': rows, 'gains': gains,
    'boundary': 'Actual frozen actRecruit/words and IntroAudio execute via existing source runners; only the audio sample relative-volume matrix is narrowed in memory to .75. Full actual tested Lua Ad coroutine runs with recorded audio/native/UI boundaries. Its six calls are separately routed through actual current IntroAudio and AudioLevels with SoundSource adapters to compare gain, default frequency and loop. STAGED_PASS tests the explicit candidate only; productionHashes record current bytes and do not grant production acceptance. No production edits, build, GPU, decoded output or audible acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-recruit-audio-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': checks, 'cases': len(rows), 'evidence': str(out), 'testedSessionSha256': report['testedSessionSha256']}))
