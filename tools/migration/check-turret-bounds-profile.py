"""Paired actual Lua clearance checks and isolated cold CPU measurements."""
import hashlib
import json
import os
import statistics
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return null if value is None else value


def plain(value):
    if not hasattr(value, 'items'):
        return value
    entries = list(value.items())
    if entries and all(isinstance(k, int) for k, _ in entries):
        return [plain(value[i]) for i in range(1, len(entries) + 1)]
    return {str(k): plain(v) for k, v in entries}


reference = root / '.tmp/outgame-cached-1792086673066/scripts/construction/TurretRange.lua'
lua.globals().turret_reference = reference.as_posix()
lua.globals().read_resource = lambda path: convert(json.loads((root / 'assets' / path).read_text(encoding='utf-8-sig')))
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
rows, checks = lua.execute((root / 'tools/migration/check-turret-bounds-profile.lua').read_text(encoding='utf-8'))
rows = plain(rows)
for row in rows:
    row['previousMedianMs'] = statistics.median(row['previousMs'])
    row['currentMedianMs'] = statistics.median(row['currentMs'])
sources = ['scripts/construction/TurretRange.lua', 'scripts/construction/Blueprint.lua', 'scripts/construction/Rotors.lua', 'assets/Combat/Arena.json']
report = dict(result='PASS', checks=checks, cases=rows,
              productionHashes={path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in sources},
              reference=str(reference), referenceSha256=hashlib.sha256(reference.read_bytes()).hexdigest(),
              boundary='Actual Lua 5.4 with real 80 arena prefabs and rotor owners, three alternating-order cold runs plus warm checks per prefab. Every returned numeric value compared as double bits. Isolated CPU excludes native physics/rendering, downloads, coroutine yields and Web/device frames.')
out = root / 'docs/migration/evidence/turret-bounds-profile-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(result='PASS', checks=checks, cases=len(rows),
                      previousMedianTotalMs=sum(r['previousMedianMs'] for r in rows),
                      currentMedianTotalMs=sum(r['currentMedianMs'] for r in rows),
                      slowerCases=[r['key'] for r in rows if r['currentMedianMs'] > r['previousMedianMs']],
                      evidence=str(out))))
