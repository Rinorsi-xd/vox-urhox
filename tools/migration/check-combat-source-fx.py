"""Compare actual frozen H5 methods with actual migrated Lua methods."""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

runtime = LuaRuntime()


def convert(value):
    if isinstance(value, dict):
        return runtime.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return runtime.table_from([convert(item) for item in value])
    return False if value is None else value


records = json.loads(subprocess.check_output(
    ['node', str(ROOT / 'tools/migration/combat-source-golden.cjs')], cwd=ROOT, text=True))
runtime.execute((ROOT / 'tools/migration/check-combat-source-fx.lua').read_text(encoding='utf-8'), convert(records))
