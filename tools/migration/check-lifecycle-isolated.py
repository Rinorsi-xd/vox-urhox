"""Execute production Lua lifecycle code without starting the game engine."""
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

sources = ['scripts/app/HangarApp.lua', 'scripts/app/OpeningHost.lua']
before = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}
lua = LuaRuntime(unpack_returned_tuples=True)
checks = lua.execute((root / 'tools/migration/check-lifecycle-isolated.lua').read_text(encoding='utf-8'))
after = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}
assert before == after, 'Production changed during isolated run'
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'sources': before,
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'boundary': 'Production Lua with engine dependencies stubbed. No Runtime/browser, no rendering/performance acceptance.'}
out = root / 'docs/migration/evidence' / ('lifecycle-isolated-' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
out.mkdir(parents=True)
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'evidence': str(out)}))
