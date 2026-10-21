"""Exact surface/rebind and static-query regression checks; no game window."""
import json
import os
import pathlib
import subprocess
import sys

from lupa.lua54 import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parents[3]
os.chdir(ROOT)
BASELINE = '8eb7822c'
lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()
lua.globals().cjson = lua.table_from({'null': null})


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return null if value is None else value


lua.globals().readData = lambda path: table(json.loads((ROOT / 'assets' / path).read_text()))
lua.globals().oldSource = lambda path: subprocess.check_output(
    ['git', 'show', f'{BASELINE}:scripts/{path}.lua'], cwd=ROOT, text=True)
script = 'p0-benchmark.lua' if '--benchmark' in sys.argv else 'p0-incremental.lua'
lua.execute((pathlib.Path(__file__).parent / script).read_text())
