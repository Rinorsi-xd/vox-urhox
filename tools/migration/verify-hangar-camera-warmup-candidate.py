"""Actual orbit, clearance and reflection logic; no engine/GPU timing claim."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

candidate = 'tools/migration/candidates/HangarCameraWarmup.lua'
source = (ROOT / candidate).read_text('utf8')
fixture = (ROOT / 'tools/migration/check-hangar-camera-warmup-candidate.lua').read_text('utf8')


def run(code):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    messages = []
    runtime.globals().CANDIDATE_SOURCE = code
    runtime.globals().print = lambda *args: messages.append(' '.join(map(str, args)))
    runtime.execute(fixture)
    return messages


messages = run(source)
negative_results = {}
for name, before, after, expected in [
    ('shared-cur', 'self.scratch.cur=Copy(c.cur)', 'self.scratch.cur=c.cur', 'live cur'),
    ('shared-flight', 'self.scratch.flight=Copy(f)', 'self.scratch.flight=f', 'live flight'),
    ('unpresented-restore', 'self:Restore();self.phase=3',
     'self:Restore();self.completed=true;self:Dispose()', 'restoration must await'),
]:
    negative = source.replace(before, after)
    assert negative != source
    try:
        run(negative)
    except Exception as error:
        assert expected in str(error), str(error)
        negative_results[name] = str(error).split('\n')[0]
    else:
        raise AssertionError(f'Negative control passed: {name}')

print(json.dumps({
    'result': 'PASS', 'messages': messages, 'negativeControls': negative_results,
    'sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
        candidate, 'scripts/controls/OrbitCamera.lua', 'scripts/controls/PreviewRoom.lua',
        'scripts/scene/HangarAtmosphere.lua']},
    'boundary': 'Actual OrbitCamera.Step/Apply, PreviewRoom.Resolve and HangarAtmosphere.Update; '
                'engine vector/node/octree doubles. Checks state/RNG preservation, midpoint/endpoint, '
                'restore presentation, cancellation, errors and invalid-scene guards. '
                'No production integration, GPU/shader-order or performance claim.',
}))
