"""Read-only production review: retired-node traps around actual session teardown."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

paths = ['scripts/endless/SpawnPresentation.lua', 'scripts/app/EndlessSession.lua', 'scripts/app/TrialSession.lua',
         'scripts/endless/Edit.lua', 'scripts/render/RestoreFlash.lua', 'scripts/render/VehicleView.lua']
before = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
source = json.loads((root / '.tmp/source-endless-spawn-fixtures.json').read_text(encoding='utf-8'))
lua.globals().goldens = lua.table_from([lua.table_from(row) for row in source['rows']])
result = lua.execute((root / 'tools/migration/check-endless-spawn-lifetime.lua').read_text(encoding='utf-8'))
checks = list(result['checks'].values())
assert before == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}, 'Production changed during review'
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'productionHashes': before,
          'setupChecks': result['setupChecks'], 'checks': checks,
          'boundary': 'Actual TrialSession.Dispose/PostUpdate and EndlessSession.Dispose plus actual Edit.Leave, with strict read/write traps after mocked native Node.Dispose. Existing 497 production/golden setup also executed. No production edits, native renderer, browser, account, heap or performance acceptance.'}
out = root / 'docs/migration/evidence/endless-spawn-lifetime-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'setupChecks': result['setupChecks'], 'evidence': str(out)}))
