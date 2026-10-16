"""Compare production Lua presentation against executed frozen H5 goldens."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', '--experimental-vm-modules', 'tools/migration/check-endless-spawn-source.cjs'], check=True)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

paths = ['scripts/endless/SpawnPresentation.lua', 'scripts/app/EndlessSession.lua',
         'scripts/app/TrialSession.lua', 'scripts/render/NodeVisibility.lua']
hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
source = json.loads((root / '.tmp/source-endless-spawn-fixtures.json').read_text(encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().goldens = lua.table_from([lua.table_from(row) for row in source['rows']])
result = lua.execute((root / 'tools/migration/check-endless-spawn.lua').read_text(encoding='utf-8'))
checks = list(result['checks'].values())
assert hashes == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}, 'Production drift during check'
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'sourceCommit': source['sourceCommit'],
          'sourceFile': source['sourceFile'], 'sourceHash': source['sourceHash'], 'sourceCases': len(source['rows']),
          'productionHashes': hashes, 'checks': checks,
          'boundary': 'Actual frozen H5 EndlessView.rise/update, production Lua SpawnPresentation and NodeVisibility; actual EndlessSession constructor/respawn/edit return/Present/Dispose and TrialSession Update/PostUpdate. Native vector/node/render/physics/resource and unrelated session subsystems use controlled stubs. Not part of immutable b932b9cd. No browser, rendered, OOM or performance acceptance.'}
out = root / 'docs/migration/evidence/endless-spawn-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': len(source['rows']), 'evidence': str(out)}))
