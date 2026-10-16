"""Compare G5 natural-flow entry points with SHA-verified executed H5 methods."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, LuaError, lua_type

PRODUCTION = ['scripts/app/SalvageLobby.lua', 'scripts/ui/SalvagePage.lua', 'scripts/salvage/Director.lua',
              'scripts/app/EndlessSession.lua', 'scripts/app/TrialSession.lua', 'scripts/storage/BlueprintStore.lua',
              'scripts/salvage/StashRules.lua', 'scripts/storage/RecordNumbers.lua']
TESTS = ['tools/migration/check-g5-natural-parity.py', 'tools/migration/check-g5-natural-parity.lua',
         'tools/migration/check-g5-natural-source.cjs', 'tools/migration/g5-offline-imports.lua',
         'tools/migration/check-salvage-director.lua']
sha = lambda name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
before = {name: sha(name) for name in PRODUCTION}
golden = json.loads(subprocess.check_output(['node', 'tools/migration/check-g5-natural-source.cjs'], encoding='utf-8'))
actual = {name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.') for name in PRODUCTION}
actual.add('endless.Data')
excluded = set()
for name in PRODUCTION:
    excluded.update(re.findall(r'''require\s*\(?\s*['"]([^'"]+)['"]''', (ROOT / name).read_text(encoding='utf-8')))
excluded -= actual
resources = ['UI/Outgame.json', 'UI/SalvageRules.json', 'Salvage/RunData.json', 'Endless/Rules.json']


def execute(mutation=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value
    def plain(value):
        if lua_type(value) != 'table':
            return value
        keys = list(value.keys())
        if keys and all(isinstance(k, int) and k > 0 for k in keys) and max(keys) == len(keys):
            return [plain(value[i]) for i in range(1, len(keys) + 1)]
        return {str(k): plain(v) for k, v in value.items()}
    lua.globals().ReadResource = lambda name: table(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8')))
    lua.globals().cjson = lua.table_from({'encode': lambda v: json.dumps(plain(v), ensure_ascii=False),
                                      'decode': lambda text: table(json.loads(text))})
    lua.globals().golden = table(golden)
    lua.globals().excluded = table(sorted(excluded))
    input_defs = (ROOT / '.emmylua/InputEvents.d.lua').read_text(encoding='utf-8')
    for key, value in re.findall(r'^(KEY_[A-Z0-9_]+)\s*=\s*(\d+)', input_defs, re.MULTILINE):
        lua.globals()[key] = int(value)
    if mutation:
        filename, old, new, _ = mutation
        source = (ROOT / filename).read_text(encoding='utf-8')
        assert source.count(old) == 1, 'Mutation anchor must be unique: ' + filename
        lua.globals().mutationSource = source.replace(old, new, 1)
        module = filename.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.execute('package.preload[...]=assert(load(mutationSource,"@behavior-negative"))', module)
    checks = list(lua.execute((ROOT / TESTS[1]).read_text(encoding='utf-8')).values())
    legacy = (ROOT / TESTS[4]).read_text(encoding='utf-8')
    marker = "    local scene=Scene();scene:CreateComponent('Octree')"
    assert legacy.count(marker) == 1, 'Legacy CPU boundary must be unique'
    lua.execute('''legacyChecks={};V={atFrame=function(frame,fn) assert(frame==10);fn() end,
        assert=function(ok,name) assert(ok,name);legacyChecks[#legacyChecks+1]=name end,finish=function() end}''')
    lua.execute(legacy.split(marker, 1)[0] + '\n    V.finish()\nend)')
    checks.extend('legacy CPU: ' + name for name in lua.globals().legacyChecks.values())
    return checks


checks = execute()
mutations = [
    (PRODUCTION[0], "if item.cat=='cargo' and n>0 then", "if n>0 then", 'source dump quote mixed'),
    (PRODUCTION[0], 'local item=Data.items[id];local n=self:Loose(id,usage)', 'local item=Data.items[id];local n=self:Owned(id)', 'source dump visibility all-installed'),
    (PRODUCTION[0], 'self.data=previous;return false,called and err or tostring(ok),0,0', 'return false,called and err or tostring(ok),0,0', 'dump file-open failure rolls back whole state'),
    (PRODUCTION[1], "elseif sv.market=='sell' then\n            local sale=lobby:CargoSale()", "elseif false then\n            local sale=lobby:CargoSale()", 'source dump visibility mixed'),
    (PRODUCTION[2], "self:Spawn(e);if e.kind=='ambush' then self:Alert(e) end", "if #self.entries-1+#e.left<=14 then self:Spawn(e);if e.kind=='ambush' then self:Alert(e) end end", 'source encounter partial-budget frame 1 activation'),
    (PRODUCTION[2], 'if alive>=14 or not at then return nil end', 'if #self.entries>=15 or not at then return nil end', 'source encounter dead-does-not-consume-budget frame 1 partial alive budget'),
    (PRODUCTION[2], "enc.state='active';enc.left={}", "if #enc.units>0 then enc.state='active';enc.left={} end", 'source encounter full-budget frame 1 activation'),
    (PRODUCTION[3], 'elseif key==KEY_RETURN or key==KEY_KP_ENTER then', 'elseif key==KEY_RETURN then', 'real PollKeys to Endless.NextWave NumpadEnter repeat false'),
    (PRODUCTION[4], 'KEY_V,KEY_RETURN,KEY_KP_ENTER,KEY_SPACE', 'KEY_V,KEY_RETURN,KEY_SPACE', 'real PollKeys to Endless.NextWave NumpadEnter repeat false'),
]
negative = []
for mutation in mutations:
    try:
        execute(mutation)
    except LuaError as error:
        reason = str(error).splitlines()[0]
        assert mutation[3] in reason, 'Negative failed outside intended assertion: ' + reason
        negative.append({'file': mutation[0], 'mutation': mutation[2], 'rejected': True, 'assertion': mutation[3], 'reason': reason})
    else:
        raise AssertionError('Behavior negative passed: ' + mutation[0])
assert before == {name: sha(name) for name in PRODUCTION}, 'Production drift during test'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'],
          'sourceCases': {'sales': len(golden['sales']), 'encounters': len(golden['encounters']), 'keys': len(golden['keys'])},
          'productionHashes': before, 'testInputs': {name: sha(name) for name in TESTS},
          'resources': {'assets/' + name: sha('assets/' + name) for name in resources},
          'negativeControls': negative,
          'boundaries': ['Executed unchanged H5 _deal/_dump, SalvageStash loose/take/sell and items sellPrice.',
                         'Executed unchanged H5 _alive/_addUnit/_spawnEncounter/_encounters/_alert/_cleared; native unit, driver, mesh and raycast boundaries adapted.',
                         'Executed unchanged H5 key; actual Lua PollKeys/HandleKey/Endless.NextWave with enum values from current engine definitions.',
                         'Actual Lua page construction/callback, Lobby CargoSale/SellCargo/Usage, BlueprintStore.Write/Read executed against controlled file and JSON bridge.',
                         'Existing check-salvage-director.lua executes unchanged through its unique Scene boundary; subsequent native rendering checks remain unrun.',
                         'H5 saves each cargo kind; target deliberately commits one atomic save with rollback on returned/thrown failure.',
                         'Historical H5 Map order is absent from target stash schema. Target uses frozen item catalogue order; reversed source acquisition order yields identical all-cargo settlement.',
                         'No Runtime/GPU, browser natural run, user account, remote persistence, audio playback, pixel or mobile performance acceptance.']}
output = ROOT / 'docs/migration/evidence/g5-natural-parity-2026-10-16.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases'], 'negatives': len(negative), 'evidence': str(output)}))
