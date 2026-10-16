"""Execute the real player against 14f behavior and asynchronous resource edges."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
baseline = ROOT / '.tmp/outgame-cached-1792095367698/scripts/audio/MusicPlayer.lua'
baseline_sha = hashlib.sha256(baseline.read_bytes()).hexdigest()
assert baseline_sha == 'fb103848fafa1abdc9388817978d13bee3be5febb17d6d30ca3cba2b191a2158'
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


lua.globals().MUSIC_CATALOG = table(json.loads((ROOT / 'assets/UI/Music/Catalog.json').read_text(encoding='utf-8')))
lua.globals().MUSIC_BEFORE_SOURCE = baseline.read_text(encoding='utf-8')
result = dict(lua.execute((ROOT / 'tools/migration/check-music-preparation.lua').read_text(encoding='utf-8')))
result['baseline'] = {'manifest': 'manifest-14f59378.json', 'MusicPlayer': baseline_sha}
result['productionHashes'] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in
                             ['scripts/audio/MusicPlayer.lua', 'scripts/audio/AudioLevels.lua', 'scripts/app/ResourceGate.lua', 'assets/UI/Music/Catalog.json']}
(ROOT / 'docs/migration/evidence/music-preparation-offline.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
