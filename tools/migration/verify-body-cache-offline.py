"""Compare Body and suspension arithmetic with immutable Lua modules, no window."""
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
        if items and all(isinstance(key, int) for key in items):
            return [plain(items[index]) for index in range(1, len(items) + 1)]
        return {key: plain(item) for key, item in items.items()}
    return value


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792063134142')
    os.chdir(ROOT)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().NAV_BEFORE_ROOT = baseline.as_posix()
    result = plain(lua.execute((ROOT / 'tools/migration/check-body-cache-offline.lua').read_text(encoding='utf-8')))
    result['lua'] = lua.eval('_VERSION')
    result['baseline'] = str(baseline)
    paths = ['scripts/physics/Body.lua', 'scripts/drive/Vehicle.lua', 'scripts/drive/RaySuspension.lua']
    result['production'] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths}
    result['before'] = {path: hashlib.sha256((baseline / path).read_bytes()).hexdigest() for path in paths}
    output = ROOT / 'docs/migration/evidence/body-cache-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in result.items() if key != 'suspensionCases'}, indent=2))
    print('Suspension cases:', len(result['suspensionCases']))


if __name__ == '__main__':
    main()
