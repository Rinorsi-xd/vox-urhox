"""Offline probe equivalence only; fake clock is not a performance benchmark."""
import importlib.util
import json
import hashlib
from pathlib import Path
from lupa.lua54 import LuaRuntime

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('drive_sections', HERE / 'perf-drive-sections.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
gait = (ROOT / 'scripts/drive/LegGait.lua').read_text(encoding='utf-8')
contact = (ROOT / 'scripts/drive/ContactControl.lua').read_text(encoding='utf-8')
scope = (HERE / 'perf-drive-sections-scope.lua').read_text(encoding='utf-8')
fixture = (HERE / 'check-drive-sections.lua').read_text(encoding='utf-8')
gait_probe, contact_probe = tool.instrument_gait(gait), tool.instrument_contact(contact)


def run(g=gait_probe, c=contact_probe):
    lua = LuaRuntime(unpack_returned_tuples=True)
    for key, value in {'GAIT_BASE': gait, 'GAIT_PROBE': g, 'CONTACT_BASE': contact, 'CONTACT_PROBE': c, 'SCOPE_SOURCE': scope}.items():
        lua.globals()[key] = value
    return lua.execute(fixture)


result = run()
syntax = LuaRuntime()
for name in ('perf-drive-sections-native.lua', 'perf-drive-sections-scope.lua'):
    syntax.execute('assert(load(...))', (HERE / name).read_text(encoding='utf-8'))
negative = []
for name, g, c, expected in [
    ('changed swing cadence', gait_probe.replace('c.phaseAcc+fc*dt', 'c.phaseAcc+fc*dt*.9'), contact_probe, 'gait'),
    ('changed wheel force', gait_probe, contact_probe.replace('force*Share(i)', 'force*Share(i)*.9'), 'contact'),
    ('missing scope Leave', gait_probe.replace('Probe.Leave();Probe.Leave();return', 'Probe.Leave();return'), contact_probe, 'Leaked drive probe scopes'),
]:
    assert g != gait_probe or c != contact_probe
    try:
        run(g, c)
    except Exception as error:
        assert expected in str(error), str(error)
        negative.append({'name': name, 'rejected': True})
    else:
        raise AssertionError('Surviving negative control: ' + name)
paths = ['scripts/drive/LegGait.lua', 'scripts/drive/ContactControl.lua', 'scripts/drive/LegControl.lua', 'scripts/core/Math3.lua']
report = {'status': 'PASS', 'checks': result['checks'], 'negativeControls': negative,
          'luaSyntaxChecks': 2,
          'sectionsCovered': sorted(result['sections'].keys()),
          'sourceSha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'boundary': 'Actual Gait/Contact/Math3; 720 synthetic gait steps and 448 contact steps, exact state/call/force ordering. Ray/body boundaries and clock are doubles. Does not validate real Bullet trajectories, timing, shader, Web FPS or Snapdragon845.'}
out = ROOT / 'docs/migration/evidence/drive-sections-offline.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
