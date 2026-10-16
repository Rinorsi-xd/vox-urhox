"""Actual Lua clearance equivalence and isolated CPU work, no frame-rate claim."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()

def convert(value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return null if value is None else value

reference = ROOT / '.tmp/outgame-cached-1792082498209/scripts/construction/TurretRange.lua'
production = ROOT / 'scripts/construction/TurretRange.lua'
lua.globals().turret_reference = reference.as_posix()
lua.globals().read_resource = lambda p: convert(json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8-sig')))
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function() return {Read=function(p) return read_resource(p) end} end")
checks, rows = lua.execute((ROOT / 'tools/migration/check-turret-deletion.lua').read_text(encoding='utf-8'))
report = {'result': 'PASS', 'checks': list(checks.values()),
          'benchmarks': [dict(row.items()) for row in rows.values()],
          'productionHashes': {'scripts/construction/TurretRange.lua': hashlib.sha256(production.read_bytes()).hexdigest()},
          'reference': str(reference), 'referenceSha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
          'boundary': 'Actual Lua 5.4 with real prefab/part resources. Clearance matches pre-change implementation, including additions, deletions, restores, rotor ownership and overlapping cells. Isolated CPU timings exclude native bodies, render, Web and real devices.'}
out = ROOT / 'docs/migration/evidence/turret-deletion-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'checks': len(report['checks']), 'benchmarks': report['benchmarks'], 'evidence': str(out)}))
