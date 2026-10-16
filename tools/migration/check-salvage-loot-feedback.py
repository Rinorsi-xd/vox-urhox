"""Frozen H5 loot feedback versus actual Lua rules/consumer; no graphics runtime."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-salvage-loot-feedback-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-salvage-loot-feedback.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def execute(mutant=None, frozen=None):
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
    if mutant:
        name, before, after = mutant
        original = (root / name).read_text(encoding='utf-8')
        assert before in original
        lua.globals().mutantCode = original.replace(before, after, 1)
        module = name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.execute("package.preload['" + module + "']=assert(load(mutantCode))")
    if frozen:
        for name in files:
            lua.globals().frozenCode = (frozen / name).read_text(encoding='utf-8')
            module = name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
            lua.execute("package.preload['" + module + "']=assert(load(frozenCode))")
    return lua, lua.execute((root / 'tools/migration/check-salvage-loot-feedback.lua').read_text(encoding='utf-8'))

files = ['scripts/salvage/Run.lua', 'scripts/salvage/RunRules.lua', 'scripts/salvage/Cinematics.lua']
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
lua, checks = execute()
negative = []
frozen = root / '.tmp/outgame-cached-1792115578618'
try:
    execute(frozen=frozen)
except Exception as error:
    negative.append({'name': 'frozen manifest-49c15ba7 production', 'result': 'REJECTED',
                     'failure': str(error).splitlines()[0],
                     'productionHashes': {name: hashlib.sha256((frozen / name).read_bytes()).hexdigest() for name in files}})
else:
    raise AssertionError('Frozen 49c15ba7 must expose the pre-fix omission')
for label, mutation in [
    ('red shake missing', ('scripts/salvage/Run.lua', 'e.item.r>=5 and .55 or .32', 'e.item.r>=5 and .32 or .32')),
    ('broadcast too early', ('scripts/salvage/Run.lua', 'Time:GetSystemTime()+1200', 'Time:GetSystemTime()+1199')),
    ('broadcast depends on simulation', ('scripts/salvage/Run.lua', 'local now=Time:GetSystemTime()', 'local now=self.rules.time*1000')),
    ('wreck leftover missing', ('scripts/salvage/RunRules.lua', 'left[#left+1]={it.id,it.n-taken}', 'left[#left+1]=nil')),
    ('wreck feed reports full roll', ('scripts/salvage/RunRules.lua', 'picked[#picked+1]={it.id,taken}', 'picked[#picked+1]={it.id,it.n}')),
    ('wreck keeps container rarity order', ('scripts/salvage/RunRules.lua', 'table.sort(rolled,function(a,b) return a.order<b.order end)', '')),
    ('cinematic frame drops wall-clock update', ('scripts/salvage/Cinematics.lua', 'if self.run.UpdateFeedback then self.run:UpdateFeedback() end', '')),
]:
    try:
        execute(mutation)
    except Exception as error:
        negative.append({'name': label, 'result': 'REJECTED', 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Undetected negative control: '+label)
assert hashes == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {'result': 'PASS', 'runtime': lua.lua_implementation, 'sourceCommit': fixtures['commit'],
          'sourceHashes': fixtures['sourceHashes'], 'productionHashes': hashes,
          'sourceCases': len(fixtures['rare'])+len(fixtures['wrecks']),
          'checks': [checks[i] for i in range(1, len(checks)+1)], 'negativeControls': negative,
          'boundary': 'Actual frozen JS _reveal/_open and actual Lua SearchStep/Step/Events/UpdateFeedback/Dispose. Real loot tables, prices, cargo capacity and wall-clock boundaries; UI/FX/physics are adapters. Cinematics.Update calls the wall-clock consumer but no GPU/browser/pixel/listening/account/performance acceptance.'}
out = root / 'docs/migration/evidence/salvage-loot-feedback-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'negativeControls': len(negative), 'evidence': str(out)}))
