"""Execute retained settlement and result UI contracts with actual resource data."""
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
sources = {}
for name in ['three/src/salvage/salvageRun.js', 'shared/ui/salvageRunHud.js']:
    digest = hashlib.sha256((Path(baseline['snapshot']) / name).read_bytes()).hexdigest()
    assert digest == baseline['files'][name]['sha256'], name
    sources[name] = digest
paths = ['scripts/salvage/Run.lua', 'scripts/salvage/RunRules.lua', 'scripts/salvage/Loot.lua',
         'scripts/app/SalvageLobby.lua', 'scripts/salvage/StashRules.lua', 'scripts/ui/SalvageRunHud.lua']
before = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value
lua.globals().resources = convert({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                                 for name in ['UI/Outgame.json', 'Salvage/RunData.json', 'UI/SalvageRules.json']})
checks = lua.execute((root / 'tools/migration/check-g5-result.lua').read_text(encoding='utf-8'))
assert before == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths}
report = {'result': 'PASS', 'sourceCommit': baseline['commit'], 'sourceHashes': sources,
          'runtime': lua.lua_implementation, 'productionHashes': before,
          'checks': [checks[i] for i in range(1, len(checks) + 1)],
          'boundary': 'Actual production Run.Finish/Commit, Lobby.CommitRun, stash validator and UI Result callbacks. Resource data real; storage and UI widgets stubbed. No account, browser, native rendering or mobile performance acceptance.'}
out = root / 'docs/migration/evidence/g5-result-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(report['checks']), 'evidence': str(out)}))
