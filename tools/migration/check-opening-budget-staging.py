"""Compare the applied opening budget with frozen 5487; no production edits/GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FILES = ['scripts/app/SceneLoader.lua', 'scripts/app/OpeningHost.lua',
         'scripts/intro/IntroWarmup.lua', 'scripts/render/SceneWarmup.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
fixture = (ROOT / 'tools/migration/check-opening-budget-staging.lua').read_text(encoding='utf-8')
source = (ROOT / FILES[0]).read_text(encoding='utf-8')
baseline_path = ROOT / '.tmp/outgame-cached-1792114575097/scripts/app/OpeningHost.lua'
baseline_bytes = baseline_path.read_bytes()
baseline_host = baseline_bytes.decode('utf-8')
production_host = (ROOT / FILES[1]).read_text(encoding='utf-8')
assert production_host == baseline_host.replace(
    " local host={state=state}",
    " state.loader.prepareBudgetMs=5\n local host={state=state}", 1).replace(
    "or id=='mechanic' or id=='motto') then",
    "or id=='mechanic' or id=='motto' or id=='disclaimer') then", 1), 'Host differs beyond the budget variable and verified disclaimer camera enumeration'


def run(candidate=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *args: None
    lua.globals().OPENING_BEFORE_SOURCE = baseline_host
    lua.globals().OPENING_AFTER_SOURCE = production_host
    if candidate is not None:
        lua.execute('package.preload["app.SceneLoader"]=assert(load(...))', candidate)
    return lua.execute(fixture)


result = run()
negatives = []
for label, candidate in [
    ('budget-ignored', source.replace('>=self.prepareBudgetMs', '>=3')),
    ('cleanup-omitted', source.replace('if options and options.cleanup then options.cleanup() end', '')),
]:
    assert candidate != source
    try:
        run(candidate)
    except Exception as error:
        negatives.append({'name': label, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + label)

rows = []
for row in result['rows'].values():
    rows.append({'scenario': row['scenario'], **{key: dict(row[key].items()) for key in ['before', 'after']}})
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
assert baseline_bytes == baseline_path.read_bytes()
report = {'result': 'PASS', 'checks': result['checks'], 'negativeControls': negatives,
          'productionHash': hashes[FILES[1]], 'productionHashes': hashes,
          'baseline': {'manifest': '54870f56', 'path': str(baseline_path.relative_to(ROOT)),
                       'sha256': hashlib.sha256(baseline_bytes).hexdigest(), 'budgetMs': 3},
          'productionBudgetMs': 5, 'cases': rows,
          'toolHashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
              'tools/migration/check-opening-budget-staging.py',
              'tools/migration/check-opening-budget-staging.lua',
              'tools/migration/experiments/opening-prepare-budget-5.patch']},
          'candidate': 'Applied OpeningHost private state.loader.prepareBudgetMs=5; actual Host.New compared with frozen 5487 Host.New budget 3; global default unchanged',
          'boundary': 'Actual Lua 5.4 OpeningHost.New and SceneLoader with controlled 31-operation workload, mocked file/scene/gate and host dependencies, and explicit semantic cancellation fence. Tests cooperative yields and ownership/callback ordering, not wall-clock-cancel identical progress, native construction cost, Web loading speed, pixels, shader coverage or performance. Production inputs unchanged during this test; production candidate already applied by root.'}
out = ROOT / 'docs/migration/evidence/opening-budget-staging-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': report['checks'], 'negativeControls': len(negatives),
                  'productionHash': report['productionHash'], 'complete': rows[0], 'evidence': str(out)}))
