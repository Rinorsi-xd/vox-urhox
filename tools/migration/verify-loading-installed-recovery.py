"""Actual Lua loading return methods; no FPS or engine construction acceptance."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

APP = ROOT / 'scripts/app/HangarApp.lua'
FLOW = ROOT / 'scripts/app/LoadingFlow.lua'
FIXTURE = ROOT / 'tools/migration/check-loading-installed-recovery.lua'
BASELINE = ROOT / '.tmp/outgame-cached-1792164278829/scripts'


def run(app, flow):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().APP_SOURCE = app
    lua.globals().FLOW_SOURCE = flow
    lua.globals().print = lambda *args: None
    return lua.execute(FIXTURE.read_text(encoding='utf-8'))


app = APP.read_text(encoding='utf-8')
flow = FLOW.read_text(encoding='utf-8')
result = run(app, flow)
negatives = []
for name, old_app, old_flow, expected in [
    ('8d installed failure', (BASELINE / 'app/HangarApp.lua').read_text(encoding='utf-8'),
     (BASELINE / 'app/LoadingFlow.lua').read_text(encoding='utf-8'), 'post-install failure returns'),
    ('old callback ordering', app, (BASELINE / 'app/LoadingFlow.lua').read_text(encoding='utf-8'),
     'old Back must not overwrite replacement transition'),
]:
    try:
        run(old_app, old_flow)
    except Exception as error:
        failure = str(error).splitlines()[0]
        assert expected in failure, failure
        negatives.append({'case': name, 'failure': failure})
    else:
        raise AssertionError('Negative control passed: ' + name)

paths = [APP, FLOW, FIXTURE, Path(__file__).resolve()]
report = {'result': 'PASS', 'checks': result['checks'], 'scenarios': result['scenarios'],
          'negativeControls': negatives,
          'hashes': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
          'boundary': 'Actual LoadingFlow methods and actual HangarApp.CancelMapLoad/Reload. Resource, UI, scene installation, preview return, trial and renderer are controlled adapters. No browser return, native disposal, GPU or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/loading-installed-recovery-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
