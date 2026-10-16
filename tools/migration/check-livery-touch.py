"""Actual frozen H5 home/livery gestures against actual Lua, without GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', '--experimental-vm-modules', 'tools/migration/check-livery-touch-source.cjs'], check=True)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = json.loads((root / '.tmp/source-livery-touch-fixtures.json').read_text(encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value
lua.globals().goldens = table(source)
production = ['scripts/controls/LiveryControls.lua']
hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in production}
try:
    checks = list(lua.execute((root / 'tools/migration/check-livery-touch.lua').read_text(encoding='utf-8')).values())
    result, error = 'PASS', None
except Exception as exc:
    result, error, checks = 'FAIL', str(exc), []
assert hashes == {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in production}, 'Production drift'
report = {'result': result, 'error': error, 'checks': checks, 'sourceCommit': source['sourceCommit'],
          'sourceHashes': source['hashes'], 'sourceCases': len(source['rows']), 'productionHashes': hashes,
          'boundary': 'Actual frozen home pointer/CameraRig/shared math and LiveryStudio._down, actual Lua LiveryControls; native vectors/rotation/UI/hit testing/session doubles. No browser/GPU/visual acceptance; increment is not in immutable manifest-41e4025e.'}
name = 'livery-touch-before.json' if '--before' in sys.argv else 'livery-touch-offline.json'
out = root / 'docs/migration/evidence' / name
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': result, 'checks': len(checks), 'error': error, 'evidence': str(out)}))
sys.exit(0 if result == 'PASS' else 1)
