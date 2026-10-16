"""Run real opening/session constructors without native/GPU processes."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(root)
paths = ['scripts/app/OpeningHost.lua', 'scripts/app/TrialSession.lua',
         'scripts/intro/IntroBattle.lua', 'scripts/intro/IntroMontagePool.lua']
before = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
historical = root / '.tmp/outgame-cached-1792092083711/scripts'
old = LuaRuntime(unpack_returned_tuples=True)
old.globals().OLD_SESSION = (historical / 'app/TrialSession.lua').read_text(encoding='utf-8')
old.globals().OLD_HOST = (historical / 'app/OpeningHost.lua').read_text(encoding='utf-8')
old.execute("package.preload['app.TrialSession']=function()return assert(load(OLD_SESSION))()end;package.preload['app.OpeningHost']=function()return assert(load(OLD_HOST))()end")
fixture = (root / 'tools/migration/check-opening-construction.lua').read_text(encoding='utf-8')
try:
    old.execute(fixture)
except Exception as error:
    reproduced = str(error)
else:
    raise AssertionError('Historical duplicate construction did not fail regression')
assert 'opening never suppresses or invokes default SetUnits' in reproduced, reproduced
old_metrics = dict(old.globals().CONSTRUCTION_METRICS)
assert old_metrics == {'bodies': 11, 'views': 11, 'practice': 1, 'discardedBodies': 1, 'discardedViews': 1}, old_metrics
lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute(fixture)
assert before == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': result['count'], 'runtime': lua.lua_implementation,
          'productionHashes': before,
          'reproducedBeforeFix': {'manifest': 'manifest-5198310b.json', 'error': reproduced,
              'construction': old_metrics,
              'hashes': {p: hashlib.sha256((historical / p.removeprefix('scripts/')).read_bytes()).hexdigest()
                         for p in paths[:2]}},
          'cases': [result['checks'][i] for i in range(1, result['count'] + 1)],
          'construction': dict(lua.globals().CONSTRUCTION_METRICS),
          'boundary': 'Actual OpeningHost.Prepare, TrialSession.New/init/Dispose, IntroBattle.New and IntroMontagePool with engine boundaries stubbed. No rendering, physics accuracy, or elapsed-time performance acceptance.'}
out = root / 'docs/migration/evidence/opening-construction-offline.json'
out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': report['checks'], 'evidence': str(out)}))
