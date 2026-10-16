"""Verify raw-byte prefetch ordering with real Lua session/gate implementations."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(root)
paths = ['scripts/intro/IntroSession.lua', 'scripts/app/OpeningHost.lua',
         'scripts/app/SceneLoader.lua', 'scripts/app/ResourceGate.lua',
         'scripts/render/MissileView.lua', 'assets/Combat/MissileView.json']
hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value
lua.globals().PREFETCH_DATA = table(json.loads((root / 'assets/Intro/Intro.json').read_text(encoding='utf-8')))
lua.globals().PREFETCH_MISSILES = table(json.loads((root / 'assets/Combat/MissileView.json').read_text(encoding='utf-8')))
lua.globals().PREFETCH_SOUNDS = table({f'Combat/{name}Sounds.json': json.loads((root / f'assets/Combat/{name}Sounds.json').read_text(encoding='utf-8')) for name in ['Weapon', 'Driving', 'Feedback']})
import re
historical_log=(root/'docs/migration/evidence/intro-natural-web-1600x900-manifest-8581d52a.log').read_text(encoding='utf-8').split('Loaded Lua script intro/IntroSession.lua',1)[1].split('[IntroWarmup] idyll ',1)[0]
lua.globals().PREFETCH_LATE=table(sorted(set(re.findall(r"DownloadWhilePlaying: downloaded '([^']+)'",historical_log))))
result = lua.execute((root / 'tools/migration/check-opening-prefetch.lua').read_text(encoding='utf-8'))
assert hashes == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': result['count'], 'productionHashes': hashes,
          'cases': [result['checks'][i] for i in range(1, result['count'] + 1)],
          'boundary': 'Actual IntroSession, OpeningHost, SceneLoader and ResourceGate; controlled native download/file/scene boundaries and 55-frame audio preparation double. No GPU, voice continuity, memory, network throughput or elapsed-time performance acceptance.'}
out = root / 'docs/migration/evidence/opening-prefetch-offline.json'
out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'evidence': str(out)}))
