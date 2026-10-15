"""Run actual Lua 5.4 ownership/iteration checks without an engine window."""
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
        return {key: plain(item) for key, item in value.items()}
    return value


def main():
    baseline = ROOT / (sys.argv[1] if len(sys.argv) > 1 else '.tmp/outgame-cached-1792074566364')
    os.chdir(ROOT)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SPACE_BASELINE_ROOT = baseline.as_posix()
    result = plain(lua.execute((ROOT / 'tools/migration/check-space-owner-guard.lua').read_text(encoding='utf-8')))
    result['lua'] = lua.eval('_VERSION')
    result['baseline'] = str(baseline)
    paths = ['scripts/physics/Space.lua', 'scripts/drive/TrackWorld.lua']
    result['production'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}
    result['before'] = {name: hashlib.sha256((baseline / name).read_bytes()).hexdigest() for name in paths}
    output = ROOT / 'docs/migration/evidence/space-owner-guard-offline.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
