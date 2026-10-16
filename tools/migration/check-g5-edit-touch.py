"""Run G5 production Lua adapters without a GPU or native game instance."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

baseline = json.loads((root / 'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json').read_text(encoding='utf-8'))
source_names = ['three/src/battle/endlessEdit.js', 'three/src/salvage/salvageRun.js']
source_hashes = {}
for name in source_names:
    digest = hashlib.sha256((Path(baseline['snapshot']) / name).read_bytes()).hexdigest()
    assert digest == baseline['files'][name]['sha256'], f'Frozen source changed: {name}'
    source_hashes[name] = digest
production = ['scripts/endless/Edit.lua', 'scripts/ui/EndlessEditBar.lua', 'scripts/salvage/Run.lua',
              'scripts/salvage/RunRules.lua', 'scripts/salvage/Loot.lua', 'scripts/ui/SalvageLootMotion.lua']
before = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in production}
lua = LuaRuntime(unpack_returned_tuples=True)
checks = lua.execute((root / 'tools/migration/check-g5-edit-touch.lua').read_text(encoding='utf-8'))
check_names = [checks[i] for i in range(1, len(checks) + 1)]
pickup_lua = LuaRuntime(unpack_returned_tuples=True)
def lua_table(value):
    if isinstance(value, dict):
        return pickup_lua.table_from({key: lua_table(item) for key, item in value.items()})
    if isinstance(value, list):
        return pickup_lua.table_from([lua_table(item) for item in value])
    return value
pickup_lua.globals().resources = lua_table({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                                          for name in ['UI/Outgame.json', 'Salvage/RunData.json']})
pickup_checks = pickup_lua.execute((root / 'tools/migration/check-g5-pickup.lua').read_text(encoding='utf-8'))
check_names.extend(pickup_checks[i] for i in range(1, len(pickup_checks) + 1))
after = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in production}
assert before == after, 'Production inputs changed during check'
report = {'result': 'PASS', 'checks': check_names,
          'runtime': lua.lua_implementation, 'sourceCommit': baseline['commit'],
          'sourceHashes': source_hashes, 'productionHashes': before,
          'boundary': 'Production Lua methods and actual shop callbacks; UI/native dependencies stubbed. No GPU, browser, account, rendering, or performance acceptance.'}
out = root / 'docs/migration/evidence/g5-edit-touch-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'evidence': str(out)}))
