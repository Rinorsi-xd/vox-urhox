"""Run actual Lua render ownership paths with observed native-object adapters."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path")
checks = lua.execute((root / 'tools/migration/check-debris-visual-transfer.lua').read_text(encoding='utf-8'))
report = {'result': 'PASS', 'runtime': lua.lua_implementation,
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'sources': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in [
              'scripts/render/CombatView.lua', 'scripts/render/VehicleView.lua',
              'tools/migration/check-debris-visual-transfer.lua']},
          'boundary': 'Actual production Lua render ownership/control paths; Node/model adapters observe identities, lifetime, same-frame part counts, authored pose and cancellation. No native/Web timing or GPU acceptance.'}
out = root / 'docs/migration/evidence' / ('debris-visual-transfer-' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
out.mkdir(parents=True)
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'evidence': str(out)}))
