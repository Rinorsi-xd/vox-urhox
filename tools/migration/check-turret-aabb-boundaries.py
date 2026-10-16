"""Compare production AABB paths with frozen 4227 Lua, including cached edits."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
null=lua.table()
def convert(value):
    if value is None:return null
    if isinstance(value,dict):return lua.table_from({k:convert(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([convert(v) for v in value])
    return value

reference=ROOT/'.tmp/outgame-cached-1792086673066/scripts/construction/TurretRange.lua'
production=ROOT/'scripts/construction/TurretRange.lua'
before=production.read_bytes()
assert hashlib.sha256(reference.read_bytes()).hexdigest()=='0a7b8bc2fcfa60752af174a0372d854637523b945610ad8108c10e11d6bbc388'
lua.globals().turret_reference=reference.as_posix()
lua.globals().read_resource=lambda p:convert(json.loads((ROOT/'assets'/p).read_text(encoding='utf-8-sig')))
lua.globals().cjson=lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function()return {Read=function(p)return read_resource(p)end}end")
checks,stats=lua.execute((ROOT/'tools/migration/check-turret-aabb-boundaries.lua').read_text(encoding='utf-8'))
assert production.read_bytes()==before,'Production drifted during verification'
report={'pass':True,'checks':len(checks),'stats':dict(stats.items()),
 'production':{str(production.relative_to(ROOT)):hashlib.sha256(before).hexdigest()},
 'reference':{'path':str(reference.relative_to(ROOT)),'sha256':hashlib.sha256(reference.read_bytes()).hexdigest()},
 'boundary':'Actual Lua 5.4 production Compute/For/Evaluate against frozen 4227 Lua; real part assets and rotations, synthetic preview blueprints/occupancy; every pruned actual ray checked against original sample hashes. Hash alias contexts directly exercise the actual private Evaluate/MissesBounds functions. No native/GPU/Web/device performance acceptance.',
 'labels':list(checks.values())}
out=ROOT/'docs/migration/evidence/turret-aabb-boundaries-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='labels'},indent=2))
