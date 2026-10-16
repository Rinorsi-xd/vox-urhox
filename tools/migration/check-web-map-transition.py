"""Execute production transition, app lifecycle and loader with Lua 5.4."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

paths = ['scripts/app/WebMapTransition.lua', 'scripts/app/HangarApp.lua', 'scripts/app/SceneLoader.lua', 'scripts/core/CollectionCycle.lua']
before = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute((root / 'tools/migration/check-web-map-transition.lua').read_text(encoding='utf-8'))
checks = list(result['checks'].values())
after = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
assert before == after, 'Production files changed during fixture'
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'checks': checks, 'productionHashes': before,
          'boundary': 'Actual WebMapTransition state machine; actual HangarApp EnterTrial, hall disposal, shared deferred sweep, Update, Reload, Stop and PostUpdate; actual SceneLoader Cancel, Fail and Commit. Native scene/resource/UI/renderer boundaries are controlled stubs. Recovery Install remains a stub. No GPU, WASM heap, browser, OOM recovery or performance acceptance.'}
out = root / 'docs/migration/evidence/web-map-transition-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(checks), 'evidence': str(out)}))
