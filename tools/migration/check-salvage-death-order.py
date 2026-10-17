"""Frozen H5 death/remnant order against actual Lua consumers. No runtime/GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-salvage-death-order-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-salvage-death-order.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

files = ['scripts/salvage/Run.lua', 'scripts/salvage/Director.lua', 'scripts/salvage/RunRules.lua', 'scripts/salvage/Loot.lua', 'scripts/salvage/Drops.lua']
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}

def execute(replacement=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value
    lua.globals().fixtures = table(fixtures)
    lua.globals().resources = table({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                                    for name in ['UI/Outgame.json', 'Salvage/RunData.json']})
    if replacement:
        original = (root / 'scripts/salvage/Run.lua').read_text(encoding='utf-8')
        before, after = replacement
        assert before in original
        lua.globals().mutantCode = original.replace(before, after, 1)
        lua.execute("package.preload['salvage.Run']=assert(load(mutantCode))")
    return lua, lua.execute((root / 'tools/migration/check-salvage-death-order.lua').read_text(encoding='utf-8'))

lua, checks = execute()
negatives = []
for label, mutation in [
    ('prior reversed settlement', ('local i=2\n    while i<=#self.entries do', 'for i=#self.entries,2,-1 do')),
    ('delete skips next actor', ('else i=i+1 end\n    end\n    local u=self.player', 'end\n        i=i+1\n    end\n    local u=self.player')),
    ('drop type overwritten', ('loot=Drops[e.kind] or Drops.rat', 'loot=Drops.rat')),
]:
    try:
        execute(mutation)
    except Exception as error:
        assert 'case ' in str(error), str(error)
        negatives.append({'name': label, 'result': 'REJECTED', 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control not detected: ' + label)
assert hashes == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {'result': 'PASS', 'sourceCommit': fixtures['commit'], 'sourceHashes': fixtures['sourceHashes'],
          'productionHashes': hashes, 'runtime': lua.lua_implementation, 'cases': len(fixtures['cases']),
          'checks': [checks[i] for i in range(1, len(checks)+1)], 'negativeControls': negatives,
          'boundary': 'Unmodified frozen JS afterStep/_alert/_session/_reveal with real loot modules against actual Lua Run.BeforeStep/AfterStep, Director.Alert/Remove, RunRules.Open/SearchStep and Loot.FromTable/Drops. All six-car death masks, all 12 drop tables, interleaved living actors, repeated steps, empty/near-full cargo; target BeforeStep strict -300m fall cutoff with controlled vehicle positions. Vehicle motion/weapon updates, native disposal, FX/HUD/input are adapters. Source fall integration/target physics, natural combat, rendering, accounts and performance remain unverified.'}
out = root / 'docs/migration/evidence/salvage-death-order-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'cases': len(fixtures['cases']), 'checks': len(checks), 'negativeControls': len(negatives), 'evidence': str(out)}))
