"""Actual Lua SceneLoader/ResourceGate contract replay without renderer or GPU."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
result = LuaRuntime(unpack_returned_tuples=True).execute(
    (ROOT / 'tools/migration/check-scene-loader-single-parse.lua').read_text(encoding='utf-8'))
report = dict(result)
report['scenarios'] = list(result['scenarios'].values())
report['production'] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in
                        ['scripts/app/SceneLoader.lua', 'scripts/app/ResourceGate.lua']}
report['boundary'] = ('Actual Lua 5.4 production modules with native API doubles; verifies download, '
                      'single parser entry, ownership, cancellation, retries and frame gates. '
                      'No engine XML parser, Web heap measurement, GPU or OOM resolution acceptance.')
output = ROOT / 'docs/migration/evidence/scene-loader-single-parse-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
