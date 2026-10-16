"""Execute frozen source CarVisual/WingRig and actual production Lua Bind/Update."""
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/source-wing-rig.mjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
make=lua.execute((ROOT/'tools/migration/check-wing-rig-offline.lua').read_text())
def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x) for x in v])
    return v
checks=0
failures=[]
affected=set()
for case in reference['scenarios']:
    instance=make(table(case['segs']),table(case['wing']))
    for index,frame in enumerate(case['frames']):
        rig=instance.step(instance,table(frame['state']),frame['dt'])
        for name,q in frame['nodes'].items():
            actual=rig['nodes'][name]['node']['rotation']
            expected=[q[0],-q[1],-q[2],q[3]]
            for axis,value in zip(['x','y','z','w'],expected):
                checks+=1
                if not math.isclose(actual[axis],value,rel_tol=2e-11,abs_tol=2e-11):
                    affected.add((case['type'],case['rot']))
                    if len(failures)<12:failures.append({'type':case['type'],'rot':case['rot'],'frame':index,'phase':frame['state']['phase'] if frame['state'] else None,'node':name,'axis':axis,'actual':actual[axis],'expected':value})
        checks+=1
        value=instance['vis']['emissionModels'][1]['instanceCustomData']['x']
        assert math.isclose(value,frame['glow'],rel_tol=2e-11,abs_tol=2e-11),(case['type'],index,'glow')
files=['scripts/render/DriveView.lua','scripts/render/WingRig.lua']
report={'result':'FAIL' if failures else 'PASS','checks':checks,'scenarios':len(reference['scenarios']),
        'affectedScenarios':len(affected),'firstFailures':failures,'baseline':reference['baseline'],
        'sourceHashes':reference['sourceHashes'],'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files},
        'boundary':'Actual source CarVisual.update/WingRig.update and actual Lua DriveView.Bind/Update/WingRig.Build/Update; native nodes/resources are doubles. All 24 rotations and eight phases. No GPU, native physics, rendered pixels, flight feel or real-device performance acceptance.'}
output=ROOT/'docs/migration/evidence/wing-rig-offline.json'
if '--before' in sys.argv:output=output.with_name('wing-rig-offline-before.json')
output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
assert not failures,'Source/Lua articulation differs'
