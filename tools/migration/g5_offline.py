"""Shared method-level Lua runner; no production file is modified by negatives."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime, LuaError


def hashes(paths):
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}


def execute(fixtures, data=None, mutation=None):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    resources = {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))
                 for name in ['UI/Outgame.json', 'Salvage/RunData.json']}
    lua.globals().resources = table(resources)
    for key, value in (data or {}).items():
        lua.globals()[key] = table(value)
    if mutation:
        filename, old, new, _ = mutation
        original = (ROOT / filename).read_text(encoding='utf-8')
        assert original.count(old) == 1, 'Mutation anchor must be unique: ' + filename
        lua.globals().mutationSource = original.replace(old, new, 1)
        module = filename.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
        lua.execute("package.preload[...]=assert(load(mutationSource,'@behavior-negative'))", module)
    checks = []
    for fixture in fixtures:
        result = lua.execute((ROOT / fixture).read_text(encoding='utf-8'))
        checks.extend(result[i] for i in range(1, len(result) + 1))
    return checks


def negatives(fixtures, mutations, data=None):
    rejected = []
    for mutation in mutations:
        try:
            execute(fixtures, data, mutation)
        except LuaError as error:
            reason = str(error).splitlines()[0]
            assert mutation[3] in reason, 'Negative failed outside intended assertion: ' + reason
            rejected.append({'file': mutation[0], 'before': mutation[1], 'after': mutation[2],
                             'rejected': True, 'assertion': mutation[3], 'reason': reason})
        else:
            raise AssertionError('Behavioral negative passed: ' + mutation[0])
    return rejected
