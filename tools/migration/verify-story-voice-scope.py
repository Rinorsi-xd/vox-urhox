"""Run real Mission/StoryComms dependency APIs and actual playback text lookup."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FIXTURE = ROOT / 'tools/migration/check-story-voice-scope.lua'
OLD = ROOT / '.tmp/outgame-cached-1792126166169'
COMMS = ROOT / 'scripts/audio/StoryComms.lua'
MISSION = ROOT / 'scripts/story/Mission.lua'
read = lambda name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))
base = read('Story/Mission/Level1.json')
registry = read('Story/Mission/ResultVoices.json')
voices = {**base['voices'], **registry['voices']}


def normalize(text):
    return re.sub(r'[^\u3400-\u9fffA-Za-z0-9]', '', re.sub(r'^【[^】]*】', '', text))


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


expected = []
for number in range(1, 6):
    level = read(f'Story/Mission/Level{number}.json')['level']
    quotes = {row['grade']: row['text'] for row in registry['quotes'] if row['level'] == level['id']}
    texts = list(strings(level)) + list(quotes.values())
    normalized = {normalize(text) for text in texts}
    paths = sorted({voice['path'] for voice in voices.values() if any(normalize(text) in normalized for text in voice['text'])})
    known = {normalize(text) for voice in voices.values() for text in voice['text']}
    matched = sorted({text for text in texts if normalize(text) in known})
    expected.append({'paths': paths, 'quotes': quotes, 'matchedTexts': matched})


def run(comms, mission):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({key: table(child) for key, child in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(child) for child in value])
        return value

    lua.globals().READ_JSON = lambda name: table(read(name))
    lua.globals().EXPECTED_ALL = table(sorted(voice['path'] for voice in voices.values()))
    lua.globals().EXPECTED_LEVELS = table(expected)
    lua.globals().COMMS_SOURCE = comms
    lua.globals().MISSION_SOURCE = mission
    lua.globals().print = lambda *args: None
    return lua.execute(FIXTURE.read_text(encoding='utf-8'))


comms, mission = COMMS.read_text(encoding='utf-8'), MISSION.read_text(encoding='utf-8')
result = run(comms, mission)
negatives = []
for name, old_comms, old_mission in [
    ('9e5d-actual-all-voices', (OLD / 'scripts/audio/StoryComms.lua').read_text(encoding='utf-8'), mission),
    ('9e5d-actual-unscoped-caller', comms, (OLD / 'scripts/story/Mission.lua').read_text(encoding='utf-8')),
]:
    try:
        run(old_comms, old_mission)
    except Exception as error:
        message = str(error).splitlines()[0]
        assert 'unexpected' in message or 'Mission excludes unrelated voice' in message, message
        negatives.append({'name': name, 'failure': message})
    else:
        raise AssertionError('Historical actual all-voice behavior unexpectedly passed: ' + name)

# Dependency work leaves playback intact; the separately validated fight seed fix
# changes this one call outside that scope.
old_comms = (OLD / 'scripts/audio/StoryComms.lua').read_text(encoding='utf-8')
old_mission = (OLD / 'scripts/story/Mission.lua').read_text(encoding='utf-8')
assert comms[:comms.index('function M.Dependencies')] == old_comms[:old_comms.index('function M.Dependencies')]
assert comms[comms.index('function M.New'):] == old_comms[old_comms.index('function M.New'):]
assert mission[:mission.index('function M.Dependencies')] == old_mission[:old_mission.index('function M.Dependencies')]
seed_call='self:Spawn({enemies=e.step.enemies,role=e.step.role,name=e.step.name,tag=e.step.id})'
assert mission.count(seed_call)==1
assert mission.replace(seed_call,'self:Spawn(e.step)',1)[mission.index('function M.New'):] == old_mission[old_mission.index('function M.New'):]

manifest = json.loads((OLD / 'dist/1.0.0/manifest-9e5d7ed6.json').read_text(encoding='utf-8'))
files = {row['fs_path']: row for row in manifest['files']}
size = lambda path: files[path].get('size@windows', files[path]['size'])
all_bytes = sum(size(voice['path']) for voice in voices.values())
rows = []
for number, data in enumerate(expected, 1):
    paths = data['paths']
    rows.append({'level': number, 'voices': len(paths), 'bytes': sum(map(size, paths)),
                 'outsideVoiceCount': len(voices) - len(paths), 'outsideVoiceBytes': all_bytes - sum(map(size, paths)), 'paths': paths})
assert rows[0]['voices'] == 30, 'S1 must retain runtime fallback result quotes'
assert rows[2]['voices'] == 41 and rows[2]['bytes'] == 1118284
assert rows[2]['outsideVoiceCount'] == 115 and rows[2]['outsideVoiceBytes'] == 3482486
paths = ['scripts/audio/StoryComms.lua', 'scripts/story/Mission.lua', 'scripts/story/MissionData.lua',
         'scripts/audio/StoryCommsCues.lua', 'scripts/audio/StoryRadio.lua',
         'assets/Story/Mission/ResultVoices.json'] + [f'assets/Story/Mission/Level{i}.json' for i in range(1, 6)]
report = {
    'result': 'PASS', 'checks': result['checks'], 'allVoices': len(voices), 'allVoiceBytes': all_bytes,
    'levels': rows, 'negativeControls': negatives,
    'productionHashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths},
    'testInputs': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in
                   ['tools/migration/check-story-voice-scope.lua', 'tools/migration/verify-story-voice-scope.py']},
    'unchangedOutsideDependenciesExcept': 'Single separately validated Mission.Events fight Spawn tag/seed call',
    'boundary': 'Actual Lua MissionData, Mission.Dependencies/Quote, StoryComms.Dependencies/Say/result lookup and StoryRadio dependency API. Native audio/model/Boss/Epilogue boundaries adapted. Complete authored text/choice/retry/respawn/result lookup, not real decoding, HTTP transport, audible output, full S5 rendering or load-time/mobile acceptance. Candidate not yet built; 9e5d natural gameplay does not validate this change.'
}
out = ROOT / 'docs/migration/evidence/story-voice-scope-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': report['checks'], 'levels': [{key: value for key, value in row.items() if key != 'paths'} for row in rows], 'negativeControls': negatives}))
