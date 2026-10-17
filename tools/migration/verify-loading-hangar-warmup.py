"""Verify actual scene/grid/reflection lifecycle; no GPU/performance claims."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASELINE_COMMIT = 'f94827b26fc12b707e6d6904d093e16358caaf41'
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FLOW = ROOT / 'scripts/app/LoadingFlow.lua'
FIXTURE = ROOT / 'tools/migration/check-loading-hangar-warmup.lua'


def run(source):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    messages = []
    runtime.globals().print = lambda *args: messages.append(' '.join(map(str, args)))
    runtime.globals().FLOW_SOURCE = source
    runtime.execute(FIXTURE.read_text('utf8'))
    return messages


messages = run(FLOW.read_text('utf8'))
baseline = subprocess.check_output(
    ['git', 'show', f'{BASELINE_COMMIT}:scripts/app/LoadingFlow.lua'], cwd=ROOT, text=True, encoding='utf8',
)
try:
    run(baseline)
except Exception as error:
    assert 'first-frame boundary and guide participate in warmup' in str(error), str(error)
    negative = str(error).split('\n')[0]
else:
    raise AssertionError('Fixed baseline unexpectedly prepared hidden first-frame guide shaders')

print(json.dumps({
    'result': 'PASS', 'messages': [line for line in messages if 'checks PASS' in line],
    'baselineCommit': BASELINE_COMMIT,
    'baselineNegativeControl': negative,
    'loadingFlowSha256': hashlib.sha256(FLOW.read_bytes()).hexdigest(),
    'boundary': 'Real LoadingFlow, SceneWarmup, Hangar.UpdateGrid and HangarAtmosphere modules; '
                'engine-facing doubles verify mask restoration, actual reflected camera, zero-dt state, '
                'two covered frames, cancellation, return, native and invalid/unrelated hangar guards. '
                'No shader compilation or runtime speed claim.',
}))
