"""Compare frozen JS vault callbacks to actual Lua rules and event consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-salvage-vault-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-salvage-vault-fixtures.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

files = ['scripts/salvage/Run.lua', 'scripts/salvage/RunRules.lua']
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
lua.globals().resources = table({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                               for name in ['UI/Outgame.json', 'Salvage/RunData.json']})
lua.globals().fixtures = table(fixtures)
checks = lua.execute((root / 'tools/migration/check-salvage-vault.lua').read_text(encoding='utf-8'))
assert hashes == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {'result': 'PASS', 'checks': [checks[i] for i in range(1, len(checks)+1)],
          'runtime': lua.lua_implementation, 'sourceCommit': fixtures['commit'],
          'sourceHashes': fixtures['sourceHashes'], 'productionHashes': hashes,
          'sourceCases': len(fixtures['cases']), 'sourceFrames': sum(len(c['frames']) for c in fixtures['cases']),
          'sourceEntryFrames': len(fixtures['entry']),
          'boundary': 'Unchanged frozen JS _searchStep/update vs actual Lua RunRules.SearchStep, Run.Events and Run.AfterStep. Actual positions derive entry speed; physics/UI/FX/audio are adapters. Audio omitted, no GPU, browser, account, visual or performance acceptance.'}
out = root / 'docs/migration/evidence/salvage-vault-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'evidence': str(out)}))
