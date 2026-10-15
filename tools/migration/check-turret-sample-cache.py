"""Run source damage equivalence with an isolated candidate, without production edits."""
import hashlib
import json
import pathlib
import sys
import argparse
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


def resource(path): return convert(json.loads((ROOT/'assets'/path).read_text(encoding='utf-8-sig')))


parser=argparse.ArgumentParser()
parser.add_argument('candidate',nargs='?',default='.tmp/TurretRange-sample-cache-candidate.lua')
parser.add_argument('--reference-turret')
args=parser.parse_args()
candidate=ROOT/args.candidate
lua.globals().read_resource=resource
lua.globals().cjson=lua.table(null=null)
lua.globals().turret_candidate=candidate.as_posix()
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end;package.preload['construction.TurretRange']=function() return assert(loadfile(turret_candidate))() end")
names=['construction/Blueprint','construction/TurretRange','drive/VehicleSpec','combat/CarUnit']
reference={name:(ROOT/'scripts'/(name+'.lua')).read_text(encoding='utf-8-sig') for name in names}
if args.reference_turret:
    reference['construction/TurretRange']=(ROOT/args.reference_turret).read_text(encoding='utf-8-sig')
lua.globals().damage_before=convert(reference)
lua.globals().fixture=convert(json.loads((ROOT/'tools/migration/source-vehicle-fixtures.json').read_text(encoding='utf-8')))
checks=lua.execute((ROOT/'tools/migration/check-damage-rebuild.lua').read_text(encoding='utf-8'))
report={'result':'PASS','scope':'Actual candidate/source rules against existing full damage-equivalence suite; native factories excluded',
        'candidate':candidate.as_posix(),'candidateSha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),
        'reference':'Current production modules read at test start; turret override='+str(args.reference_turret),
        'referenceSha256':{name:hashlib.sha256(text.encode()).hexdigest() for name,text in reference.items()},
        'checks':[checks[i] for i in range(1,len(checks)+1)]}
stamp=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ')
path=ROOT/('docs/migration/evidence/turret-sample-cache-'+stamp+'.json')
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(len(checks),'candidate damage/range checks PASS;',path)
