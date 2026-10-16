"""Run the production SceneLoader state machine with controlled native boundaries."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = (ROOT / 'scripts/app/SceneLoader.lua').read_text(encoding='utf-8')
fixture = (ROOT / 'tools/migration/check-loader-background-arrays.lua').read_text(encoding='utf-8')


def run(candidate):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().LOADER_SOURCE = candidate
    return lua.execute(fixture)


result = run(source)
mutations = {
    'blocking-fallback': ('pcall(cache.GetExistingResource,cache,item.type,item.name)', 'pcall(cache.GetResource,cache,item.type,item.name)'),
    'duplicate-queue': ('if not pending then', 'if true then'),
    'no-wall-timeout': ('Now()-pending.started>20000', 'Now()-pending.started>2000000'),
    'no-generation-fence': ('pending.token~=self.generation', 'false'),
}
rejected = []
for name, (before, after) in mutations.items():
    assert before in source, name
    try:
        run(source.replace(before, after, 1))
    except Exception:
        rejected.append(name)
    else:
        raise AssertionError('Negative control escaped: ' + name)

production = ['scripts/app/SceneLoader.lua']
inputs = ['tools/migration/check-loader-background-arrays.lua', 'tools/migration/check-loader-background-arrays.py']
hashes = lambda paths: {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': result['checks'], 'negativeControls': rejected,
          'productionHashes': hashes(production), 'inputs': hashes(inputs),
          'boundary': 'Actual Lua 5.4 production loader with controlled cache and wall clock. Verifies queue once, cache polling, staging fence, cancellation, retries and timeout; no native background cancellation, Web frame time, pixels, shaders or whole-map loading acceptance.'}
output = ROOT / 'docs/migration/evidence/loader-background-arrays-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
