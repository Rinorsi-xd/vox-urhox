"""Offline Lua CPU attribution only; native bodies and debris are excluded."""
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
null=lua.table()


def convert(value):
    if isinstance(value,dict): return lua.table_from({k:convert(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([convert(v) for v in value])
    return null if value is None else value


def resource(path):
    return convert(json.loads((ROOT/'assets'/path).read_text(encoding='utf-8-sig')))


lua.globals().read_resource=resource
lua.globals().cjson=lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
candidate=next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--candidate=')),None)
if candidate:
    lua.globals().turret_candidate=candidate
    lua.execute("package.preload['construction.TurretRange']=function() return assert(loadfile(turret_candidate))() end")
rows=lua.execute((ROOT/'tools/migration/profile-damage-flush.lua').read_text(encoding='utf-8'))


def plain(value):
    if hasattr(value,'items'): return {str(k):plain(v) for k,v in value.items()}
    return value


report={'scope':'Attribution of actual production Lua only; native vehicle/debris factories excluded; not frame-time acceptance',
        'candidate':candidate,
        'samples':[plain(rows[i]) for i in range(1,len(rows)+1)],
        'hashes':{p:hashlib.sha256((ROOT/'scripts'/p).read_bytes()).hexdigest() for p in [
            'combat/CarUnit.lua','construction/Blueprint.lua','construction/TurretRange.lua','construction/Rotors.lua','drive/VehicleSpec.lua']}}
stamp=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ')
path=ROOT/('docs/migration/evidence/damage-flush-profile-'+stamp+'.json')
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(path)
for sample in report['samples']:
    print(sample['name'],sample['step'],round(sample['totalMs'],3),
          sorted([(key,round(value['exclusiveMs'],3)) for key,value in sample['segments'].items()],key=lambda p:-p[1]))
