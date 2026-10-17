"""Frozen source addPart/_rotors vs actual Lua model consumers; no rendering."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/source-rotor-disc.mjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(v) for v in value])
    return value

lua.globals().ASSETS=table({name:json.loads((ROOT/'assets'/name).read_text(encoding='utf-8'))
    for name in ['Parts/Catalog.json','Parts/Rigs/rotor.json','Parts/Rigs/rotorSpin.json','Parts/Rigs/rotorStep.json']})
adapter=(ROOT/'tools/migration/check-rotor-disc-offline.lua').read_text(encoding='utf-8')
factory=lua.execute(adapter)
checks=0
def compare(actual,expected,label):
    global checks
    for index,point in enumerate(expected,1):
        for axis,value in enumerate(point,1):
            checks+=1
            assert math.isclose(actual[index][axis],value,rel_tol=2e-12,abs_tol=2e-12),(label,index,axis,actual[index][axis],value)

for case in reference['cases']:
    part=case['part']
    instance=factory(table(part),table(reference['points']))
    compare(instance.initial,case['initial'],('initial',part))
    for frame in case['frames']:
        compare(instance.Step(instance,frame['prev'],frame['angle'],frame['alpha']),frame['points'],('update',part,frame))
    # Reconstructed physics supplies a surviving rotor angle to the same visual.
    expected=next(f['points'] for f in case['frames'] if f['alpha']==1 and f['angle']==.8)
    instance.Step(instance,.8,.8,1)
    compare(instance.Rebind(instance),expected,('rebind',part))
    compare(instance.Repaint(instance),expected,('repaint keeps live angle',part))
    instance.ResetAngle(instance)
    next_part={**part,'pos':[-part['pos'][0] if part['pos'][0] else -4,3,1]}
    refit_reference=next(row for row in reference['cases'] if row['part']['type']==part['type']
                         and row['part']['rot']==part['rot'] and row['part']['pos']==next_part['pos'])
    compare(instance.Refit(instance,table(next_part)),refit_reference['initial'],('refit',part))

production=ROOT/'scripts/render/RotorDisc.lua'
text=production.read_text(encoding='utf-8')
accepted_checks=checks
negative=[]
for name,old,new in [('no-mirror','Vector3(sign,1,1)','Vector3(1,1,1)'),
                     ('wrong-side','part.pos[1]<0','part.pos[1]>0'),
                     ('wrong-composition','angle*sign+(vis.rotorOffset or 0)','angle*sign-(vis.rotorOffset or 0)'),
                     ('repaint-resets-live-angle','vis.rotorAngle or 0','0')]:
    assert old in text
    lua.execute("package.loaded['render.RotorDisc']=nil;package.loaded['render.RotorView']=nil;package.loaded['render.PartRig']=nil;package.loaded['render.VehicleView']=nil")
    lua.globals().MUTANT=text.replace(old,new)
    lua.execute("package.preload['render.RotorDisc']=assert(load(MUTANT))")
    mutant=lua.execute(adapter)
    rejected=False
    for case in reference['cases']:
        instance=mutant(table(case['part']),table(reference['points']))
        try:
            compare(instance.initial,case['initial'],name)
            instance.Step(instance,.8,.8,1)
            expected=next(f['points'] for f in case['frames'] if f['alpha']==1 and f['angle']==.8)
            compare(instance.Repaint(instance),expected,name)
        except AssertionError:rejected=True;break
    assert rejected,('Mutant survived',name)
    negative.append(name)

view_text=(ROOT/'scripts/render/VehicleView.lua').read_text(encoding='utf-8')
assert view_text.count('    RotorDisc.Bind(vis,part)')==1
lua.execute("package.loaded['render.RotorDisc']=nil;package.loaded['render.RotorView']=nil;package.loaded['render.PartRig']=nil;package.loaded['render.VehicleView']=nil")
lua.globals().MUTANT=text
lua.execute("package.preload['render.RotorDisc']=assert(load(MUTANT))")
lua.globals().MUTANT=view_text.replace('    RotorDisc.Bind(vis,part)','')
lua.execute("package.preload['render.VehicleView']=assert(load(MUTANT))")
mutant=lua.execute(adapter)
case=next(row for row in reference['cases'] if row['part']['type']=='rotor' and row['part']['pos'][0]==4)
part=case['part'];instance=mutant(table(part),table(reference['points']))
next_part={**part,'pos':[-4,3,1]}
opposite=next(row for row in reference['cases'] if row['part']['type']==part['type'] and row['part']['rot']==part['rot'] and row['part']['pos']==next_part['pos'])
try:compare(instance.Refit(instance,table(next_part)),opposite['initial'],'missing refit repaint binding')
except AssertionError:negative.append('missing-refit-repaint-binding')
else:raise AssertionError('Missing refit wiring mutant survived')

files=['scripts/render/RotorDisc.lua','scripts/render/PartRig.lua','scripts/render/RotorView.lua','scripts/render/VehicleView.lua']
report={'status':'PASS','cases':len(reference['cases']),'checks':accepted_checks,'negativeControls':negative,
        'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
        'productionHashes':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files},
        'boundary':'Actual frozen source addPart/_rotors and actual Lua PartRig.Build, VehicleView.AddPart/ApplyEdits/Repaint, RotorView.New/Update. Native resources/transforms are controlled adapters. No rendered culling, pixels, flight physics or performance acceptance.'}
destination=ROOT/'docs/migration/evidence/rotor-disc-offline.json'
destination.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
