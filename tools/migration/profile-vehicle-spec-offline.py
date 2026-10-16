"""Attribute real Lua spec construction; isolated CPU, not Web frame evidence."""
import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()


def convert(value):
    if value is None:
        return null
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return value


def plain(value):
    if hasattr(value, 'items'):
        return {str(k): plain(v) for k, v in value.items()}
    return value


lua.globals().read_resource = lambda path: convert(json.loads((root / 'assets' / path).read_text(encoding='utf-8-sig')))
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path; package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
result = lua.execute((root / 'tools/migration/profile-vehicle-spec-offline.lua').read_text(encoding='utf-8'))
sources = ['drive/VehicleSpec', 'construction/Blueprint', 'construction/Rotors', 'construction/TurretRange']
report = {
    'boundary': 'Actual production Lua construction with os.clock inclusive CPU wrappers, JSON resource adapter, no native physics/rendering/yields. Nested times cannot be added. Not Web loading or FPS acceptance.',
    'production': {name: hashlib.sha256((root / 'scripts' / (name + '.lua')).read_bytes()).hexdigest() for name in sources},
    'cases': plain(result),
}
out = root / 'docs/migration/evidence/vehicle-spec-profile-offline.json'
out.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
