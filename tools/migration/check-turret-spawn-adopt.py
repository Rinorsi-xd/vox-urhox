"""Offline exact real-module tests; no Runtime, browser or production writes."""
import hashlib
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
FROZEN=ROOT/'.tmp/perf-damage-flush-c935-1017'
CANDIDATE=ROOT/'tools/migration/candidates'
OUT=ROOT/(sys.argv[1] if len(sys.argv)>1 else 'docs/migration/evidence/turret-spawn-adopt-offline-2026-10-17.json')
assert not OUT.exists(),'Preserve previous evidence'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files={'scripts/construction/TurretRange.lua':'TurretRangeSpawnAdopt.lua','scripts/drive/SpawnSpecCache.lua':'SpawnSpecCacheTurretAdopt.lua','scripts/combat/CarUnit.lua':'CarUnitTurretAdopt.lua'}
baseline_hashes={p:sha(FROZEN/p) for p in files}
candidate_hashes={p:sha(CANDIDATE/n) for p,n in files.items()}
production_hashes={p:sha(ROOT/p) for p in files}
identity=json.loads((FROZEN/'source-identity.json').read_text(encoding='utf-8'))
for p,h in baseline_hashes.items():assert h==identity['sourceHashes'][p],p
baseline_range=(FROZEN/'scripts/construction/TurretRange.lua').read_text(encoding='utf-8')
candidate_range=(CANDIDATE/'TurretRangeSpawnAdopt.lua').read_text(encoding='utf-8')
suffix=(CANDIDATE/'TurretRangeSpawnAdoptApi.lua').read_text(encoding='utf-8')
assert candidate_range==baseline_range.replace('return M',suffix+'\nreturn M',1),'Existing clearance algorithm changed'
baseline_unit=(FROZEN/'scripts/combat/CarUnit.lua').read_text(encoding='utf-8')
assert (CANDIDATE/'CarUnitTurretAdopt.lua').read_text(encoding='utf-8')==baseline_unit.replace('self.spawnSpecCache:Get(self.source)','self.spawnSpecCache:Get(self.source,self.bp)',1),'Unexpected CarUnit change'
lua=LuaRuntime(unpack_returned_tuples=True);null=lua.table();resources={}
def convert(v):
    if v is None:return null
    if isinstance(v,dict):return lua.table_from({k:convert(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([convert(x) for x in v])
    return v
def read_resource(name):
    p=ROOT/'.tmp/outgame-cached-1792198527902/assets'/name;resources[name]=sha(p)
    return convert(json.loads(p.read_text(encoding='utf-8-sig')))
lua.globals().read_resource=read_resource;lua.globals().cjson=lua.table(null=null)
lua.globals().baseline_unit_source=(FROZEN/'scripts/combat/CarUnit.lua').read_text(encoding='utf-8')
for key,name in [('candidate_unit_source','CarUnitTurretAdopt.lua'),('candidate_range_source','TurretRangeSpawnAdopt.lua'),('candidate_cache_source','SpawnSpecCacheTurretAdopt.lua')]:
    lua.globals()[key]=(CANDIDATE/name).read_text(encoding='utf-8')
lua.globals().adopt_roster=convert(json.loads((FROZEN/'damage-roster.json').read_text(encoding='utf-8'))['roster'])
lua.globals().frozen_path=(FROZEN/'scripts').as_posix()+'/?.lua;'+(FROZEN/'scripts').as_posix()+'/?/init.lua;'
lua.execute("package.path=frozen_path..package.path;package.preload['core.ResourceData']=function() return {Read=function(p)return read_resource(p)end}end")
labels=list(lua.execute((ROOT/'tools/migration/check-turret-spawn-adopt.lua').read_text(encoding='utf-8')).values())
assert production_hashes=={p:sha(ROOT/p) for p in files},'Production changed'
footprints=[dict(row.items()) for row in lua.globals().adopt_footprints.values()]
report=dict(status='PASS',checks=len(labels),labels=labels,cacheFootprints=footprints,baselineHashes=baseline_hashes,candidateHashes=candidate_hashes,productionHashes=production_hashes,resourceHashes=resources,boundary='Frozen actual eight K sources, actual Lua54 Blueprint/VehicleSpec/CarUnit before native boundary; exact cache/spec comparison and mutation isolation. Footprint counts are reachable tables and logical packed string payload, not actual allocator bytes. No native/runtime/browser performance claim; normal GC.')
OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['labels','resourceHashes']},ensure_ascii=True))
