"""Production Lua warmup sequencing/mask ownership; no GPU compile acceptance."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FILES = ['scripts/intro/IntroWarmup.lua', 'scripts/render/SceneWarmup.lua',
         'tools/migration/check-intro-idyll-warmup.lua',
         'tools/migration/check-intro-idyll-warmup.py',
         'tools/migration/check-intro-warmup.lua',
         'assets/Hangar/Models/OrbitalHangar-Architecture2-glass.bin']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
data = (ROOT / FILES[-1]).read_bytes()
assert data[:4] == b'UMDL'
buffers, count, mask, morph_start, morph_count = struct.unpack_from('<5I', data, 4)
assert (buffers, mask, morph_start, morph_count) == (1, 11, 0, 0)
points = [struct.unpack_from('<fff', data, 24 + i * 32) for i in range(count)]
bounds = {'min': [min(p[i] for p in points) for i in range(3)],
          'max': [max(p[i] for p in points) for i in range(3)]}
fixture = (ROOT / FILES[2]).read_text(encoding='utf-8')


def run(historical=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().GLASS_BOUNDS = lua.table_from({k: lua.table_from(v) for k, v in bounds.items()})
    lua.execute('print=function()end')
    if historical is not None:
        lua.execute('package.preload["intro.IntroWarmup"]=assert(load(...))', historical)
    return lua.execute(fixture)


old = ROOT / '.tmp/outgame-cached-1792104485199/scripts/intro/IntroWarmup.lua'
try:
    run(old.read_text(encoding='utf-8'))
except Exception as error:
    assert 'first original camera subpass stays within idyll phase' in str(error), str(error)
    negative = {'manifest': 'manifest-cb9f15ca.json', 'sha256': hashlib.sha256(old.read_bytes()).hexdigest(),
                'failure': str(error).splitlines()[0]}
else:
    raise AssertionError('Historical omitted first camera unexpectedly passed')
result = run()
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
report = {'result': 'PASS', 'checks': result['checks'], 'originalPhases': result['originalPhases'],
          'samples': list(result['samples'].values()), 'cancellationCases': result['cancellationCases'],
          'leaveCaptureCases': result['leaveCaptureCases'],
          'glass': {'vertices': count, 'worldBounds': bounds},
          'productionHashes': {p: value for p, value in hashes.items() if p.startswith('scripts/')},
          'inputs': {p: value for p, value in hashes.items() if not p.startswith('scripts/')},
          'historicalNegativeControl': negative,
          'boundary': 'Actual production IntroWarmup and SceneWarmup execute under Lua 5.4 with controlled camera/scene/effect/capture adapters and real model vertex bounds. Verifies additional first camera admission, unchanged seven phases/terminal prop times, independent deduplication, four/single-copy quotas, two presented rest frames, three-frame leave capture hooks and exact cancel/complete restoration. No GPU, shader compile, captured pixels, audio continuity, Web/native or mobile performance PASS.'}
out = ROOT / 'docs/migration/evidence/intro-idyll-warmup-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': report['checks'], 'evidence': str(out)}))
