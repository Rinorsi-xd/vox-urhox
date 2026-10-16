"""Exact d011 suspension golden for the scoped point-arm candidate."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def plain(value):
    if hasattr(value, 'items'):
        items = dict(value.items())
        if items and all(isinstance(k, int) for k in items):
            return [plain(items[i]) for i in range(1, len(items) + 1)]
        return {k: plain(v) for k, v in items.items()}
    return value


def main():
    os.chdir(ROOT)
    baseline = ROOT / '.tmp/outgame-cached-1792108710605'
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    assert sha(baseline / 'scripts/physics/Body.lua') == '877530eb78b720d4b07fd53399a7c015641120def2d0e7d14710fada36592f72'
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().NAV_BEFORE_ROOT = baseline.as_posix()
    golden = plain(lua.execute((ROOT / 'tools/migration/check-body-cache-offline.lua').read_text(encoding='utf-8')))
    ray_lua = LuaRuntime(unpack_returned_tuples=True)
    ray_lua.globals().NAV_BEFORE_ROOT = baseline.as_posix()
    ray = plain(ray_lua.execute((ROOT / 'tools/migration/check-space-ray-offline.lua').read_text(encoding='utf-8')))
    production = ['scripts/physics/Space.lua', 'scripts/physics/Body.lua',
                  'scripts/drive/RaySuspension.lua', 'scripts/core/Math3.lua']
    inputs = ['tools/migration/verify-body-arm-offline.py',
              'tools/migration/check-space-ray-offline.lua',
              'tools/migration/check-body-cache-offline.lua']
    result = {'result': 'PASSED', 'baseline': 'manifest-d01102e0',
              'baselineRoot': str(baseline), 'bodySha256': sha(ROOT / 'scripts/physics/Body.lua'),
              'suspensionSha256': sha(ROOT / 'scripts/drive/RaySuspension.lua'),
              'spaceSha256': sha(ROOT / 'scripts/physics/Space.lua'),
              'production': {p: sha(ROOT / p) for p in production},
              'inputs': {p: sha(ROOT / p) for p in inputs},
              'golden': golden, 'ray': ray, 'scope': 'Exact Lua arithmetic, wheel states and native-call ordering; no native timing claim.'}
    output = ROOT / 'docs/migration/evidence/body-arm-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'result': result['result'], 'assertions': golden['assertions'],
                      'suspensionCases': len(golden['suspensionCases']), 'rayAssertions': ray['assertions'],
                      'rayCases': len(ray['cases']), 'output': str(output)}, indent=2))


if __name__ == '__main__':
    main()
