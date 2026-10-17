"""Run actual aiming modules, bounded fallback behavior and production-state negatives."""
import hashlib
import json
import sys
import time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
def run(mutation=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([table(x) for x in v])
        return v
    lua.globals().resources=table({p:json.loads((ROOT/'assets'/p).read_text(encoding='utf-8')) for p in ['Combat/Weapons.json','Combat/Drills.json','Parts/Catalog.json','Parts/HoverMounts.json','Parts/BuildRules.json']})
    if mutation:
        file,old,new=mutation
        original=(ROOT/file).read_text(encoding='utf-8');assert original.count(old)==1
        lua.globals().mutatedSource=original.replace(old,new,1)
        module=file.removeprefix('scripts/').removesuffix('.lua').replace('/','.')
        lua.execute("package.preload[...]=assert(load(mutatedSource,'@fallback-negative'))",module)
    start=time.perf_counter()
    checks=lua.execute((ROOT/'tools/migration/check-aim-fallback.lua').read_text(encoding='utf-8'))
    return [checks[i] for i in range(1,len(checks)+1)],(time.perf_counter()-start)*1000
checks,elapsed=run()
negatives=[]
for mutation,expected in [
 (('scripts/combat/AimAssist.lua','if canReach and not canReach(h.point,candidate.unit) then','if false then'),'fallback selects reachable point'),
 (('scripts/combat/AimReach.lua','if V.Dot(V.Sub(point,muzzle.pos),muzzle.dir)>1e-4 then return true end','return true'),'target behind long barrel'),
 (('scripts/combat/AimAssist.lua','if enemy(ref) and V.Length(V.Sub(hit.point,from))<=range then','if false then'),'direct hit must not cast'),
 (('scripts/combat/AimFallback.lua','if rays==4 then break end','if false then break end'),'1000-part candidate list is limited'),
 (('scripts/controls/DriveAim.lua','if not s.aimReach or s.aimReachVehicle~=s.vehicle or s.aimReachSystem~=s.weapons then','if not s.aimReach then'),'READ_RETIRED_BODY'),
 (('scripts/controls/DriveAim.lua','if not s.aimReach or s.aimReachVehicle~=s.vehicle or s.aimReachSystem~=s.weapons then','if not s.aimReach or s.aimReachVehicle~=s.vehicle then'),'READ_RETIRED_WEAPON')]:
    try:run(mutation)
    except Exception as error:
        assert expected in str(error),str(error)
        negatives.append({'file':mutation[0],'rejected':True,'reason':str(error).splitlines()[0]})
    else:raise AssertionError('Negative passed: '+mutation[0])
paths=['scripts/combat/AimAssist.lua','scripts/combat/AimFallback.lua','scripts/combat/AimReach.lua','scripts/controls/DriveAim.lua']
result={'checks':checks,'negativeTests':negatives,'offlineSuiteElapsedMs':elapsed,
 'scope':'Actual Lua modules; no Native/Web/device FPS claim. Clock includes module loading and fixture assertions.',
 'hashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}}
(ROOT/'docs/migration/evidence/aim-fallback-2026-10-17.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
