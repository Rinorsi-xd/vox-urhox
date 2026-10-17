"""Compare actual frozen ES-module target selection and mode goals to Lua."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

node = shutil.which('node')
assert node, 'Node.js runtime missing'
proc = subprocess.run([node, '--experimental-vm-modules', str(root / 'tools/migration/check-match-target-source.cjs')],
                      capture_output=True, encoding='utf-8', check=True)
golden = json.loads(proc.stdout)
paths = ['scripts/combat/MatchTarget.lua', 'scripts/combat/BattleObjectives.lua',
         'scripts/combat/EnemyDriverNav.lua', 'scripts/combat/EnemyDriverMath.lua',
         'scripts/combat/BattleController.lua', 'scripts/combat/ShieldQuery.lua',
         'scripts/core/Math3.lua']
before = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths}
lua = LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value
lua.globals().golden = convert(golden)
result = lua.execute((root / 'tools/migration/check-match-target.lua').read_text(encoding='utf-8'))
def plain(value):
    if hasattr(value, 'items'):
        pairs = dict(value.items())
        if pairs and set(pairs) == set(range(1, len(pairs) + 1)):
            return [plain(pairs[i]) for i in range(1, len(pairs) + 1)]
        return {key: plain(item) for key, item in pairs.items()}
    return value
checks = list(result['checks'].values())
failures = list(result['failures'].values())
after = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths}
assert before == after, 'Production changed during actual source comparison'
report = {'result': 'FAIL' if failures else 'PASS', 'sourceCommit': golden['sourceCommit'],
          'sourceHashes': golden['hashes'], 'productionHashes': before, 'runtime': lua.lua_implementation,
          'checks': checks, 'failures': [plain(row) for row in failures],
          'sourceExecution': 'vm.SourceTextModule evaluates unchanged imports plus appended mode-class exports. Actual frozen shared driver, match rules and shield-query modules; unrelated engine/audio/UI imports are SyntheticModule stubs.',
          'boundary': 'Actual Lua MatchTarget, EnemyDriverNav.Visible, ShieldQuery, BattleObjectives.Goal/At and source module methods. Controlled world ray hits and units; unused hoisted constructor dependencies are strict fail-on-access sentinels. No constructors, full BeforeStep, GPU, actual physics, browser, frame-rate, visual or natural-match acceptance.'}
out = root / 'docs/migration/evidence/match-target-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(checks), 'failures': len(failures), 'evidence': str(out)}))
for row in report['failures'][:6]:
    print(json.dumps(row, ensure_ascii=False))
sys.exit(bool(failures))
