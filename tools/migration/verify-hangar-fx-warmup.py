"""Execute actual weapon Glow batch; behavior and ordering, not GPU timing."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = (ROOT / 'scripts/render/HangarFxWarmup.lua').read_text('utf8')
fixture = (ROOT / 'tools/migration/check-hangar-fx-warmup.lua').read_text('utf8')


def run(code):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    messages = []
    runtime.globals().WARMUP_SOURCE = code
    runtime.globals().print = lambda *args: messages.append(' '.join(map(str, args)))
    runtime.execute(fixture)
    return messages


messages = run(source)
negative = source.replace('    self.batch:Finish()', '    self.batch.mesh.enabled=false')
assert negative != source
try:
    run(negative)
except Exception as error:
    assert 'draw is submitted, not allocation-only' in str(error), str(error)
    negative_result = str(error).split('\n')[0]
else:
    raise AssertionError('Allocation-only negative control passed without a rendered probe')

print(json.dumps({
    'result': 'PASS', 'messages': messages, 'negativeControl': negative_result,
    'sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
        'scripts/render/HangarFxWarmup.lua', 'scripts/render/EffectBatch.lua', 'scripts/core/Coord.lua']},
    'boundary': 'Real HangarFxWarmup, EffectBatch and Coord; engine-facing draw doubles. '
                'Checks exact shader/layout, actual camera placement, no RNG, presented/cancel '
                'cleanup, missing resource, construction error, invalid range and foreign camera. '
                'Web compilation, first-use timing, visuals and long-session performance remain unmeasured.',
}))
