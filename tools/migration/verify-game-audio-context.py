"""Run frozen JS state/mixer and actual Lua adapters against the same cases."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
os.chdir(ROOT)
source = json.loads(subprocess.check_output(['node', '--experimental-vm-modules', 'tools/migration/source-game-audio.cjs'], text=True))
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


lua.globals().SOURCE = table(source)
configs = {name: json.loads((ROOT / path).read_text(encoding='utf-8')) for name, path in {
    'Combat/WeaponSounds.json': 'assets/Combat/WeaponSounds.json',
    'Combat/DrivingSounds.json': 'assets/Combat/DrivingSounds.json',
    'Combat/FeedbackSounds.json': 'assets/Combat/FeedbackSounds.json',
    'Combat/FlowSounds.json': 'assets/Combat/FlowSounds.json',
    'Story/Radio/Radio.json': 'assets/Story/Radio/Radio.json',
    'UI/Music/Catalog.json': 'assets/UI/Music/Catalog.json',
}.items()}
lua.globals().CONFIGS = table(configs)
result = dict(lua.execute((ROOT / 'tools/migration/check-game-audio-context.lua').read_text(encoding='utf-8')))
result['cueCounts'] = dict(result['cueCounts'])
result['sourceCommit'] = source['commit']
result['sourceHashes'] = source['hashes']
paths = ['scripts/audio/' + name + '.lua' for name in ['GameMusicState', 'AudioLevels', 'MusicPlayer', 'WeaponAudio', 'DrivingAudio', 'CombatFeedbackAudio', 'BattleFlow', 'UiSound', 'StoryRadio']]
paths += ['scripts/app/HangarApp.lua', 'assets/Combat/FeedbackSounds.json', 'tools/migration/source-game-audio.cjs', 'tools/migration/check-game-audio-context.lua']
result['productionHashes'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
(ROOT / 'docs/migration/evidence/game-audio-context-offline.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
