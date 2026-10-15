"""Exercise actual shell/xray/vehicle Lua ownership without claiming GPU evidence."""
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

sources = ['scripts/render/ShellMaterials.lua', 'scripts/render/VehicleView.lua',
           'scripts/render/BuildXray.lua', 'scripts/parts/Materials.lua',
           'tools/migration/check-shell-materials.lua']
before = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path")
checks = lua.execute((root / 'tools/migration/check-shell-materials.lua').read_text(encoding='utf-8'))
assert before == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources}
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'sources': before,
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'boundary': 'Production ShellMaterials/BuildXray/VehicleView with native object adapters; verifies identity, exact parameter retention, repaint, transfer, cancellation, exception rollback and disposal. No native/Web rendering or performance acceptance.'}
out = root / 'docs/migration/evidence' / ('shell-materials-' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
out.mkdir(parents=True)
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'evidence': str(out)}))
