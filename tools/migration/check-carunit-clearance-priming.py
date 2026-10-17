"""Offline real-module cache identity and constructor cancellation checks."""
import hashlib
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
FROZEN=ROOT/'.tmp/perf-damage-flush-c935-1017'
BASE=FROZEN/'scripts/combat/CarUnit.lua'
CANDIDATE=ROOT/'tools/migration/candidates/CarUnitClearancePriming.lua'
OUT=ROOT/'docs/migration/evidence/carunit-clearance-priming-offline-2026-10-17.json'
assert not OUT.exists(),'Preserve previous evidence'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(BASE)=='ec07f2c50496b7ce70b86116b6425bf6499d1914141686832818a79f04d8dba7'
old=BASE.read_text(encoding='utf-8');new=CANDIDATE.read_text(encoding='utf-8')
expected=old.replace('local Spec=require "drive.VehicleSpec"','local Spec=require "drive.VehicleSpec"\nlocal TurretRange=require \'construction.TurretRange\'',1)
needle='    local spec=self.spawnSpecCache and self.spawnSpecCache:Get(self.source)'
expected=expected.replace(needle,needle+'\n    if spec and spec.ok and checkpoint then\n        TurretRange.For(self.bp,spec.rotorOf,function() checkpoint(.75) end)\n    end',1)
assert new==expected,'Candidate changed more than cached load priming'
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
lua.globals().baseline_unit_source=old;lua.globals().candidate_unit_source=new
lua.globals().priming_roster=convert(json.loads((FROZEN/'damage-roster.json').read_text(encoding='utf-8'))['roster'])
lua.globals().frozen_path=(FROZEN/'scripts').as_posix()+'/?.lua;'+(FROZEN/'scripts').as_posix()+'/?/init.lua;'
lua.execute("package.path=frozen_path..package.path;package.preload['core.ResourceData']=function() return {Read=function(p)return read_resource(p)end}end")
production=ROOT/'scripts/combat/CarUnit.lua';before=sha(production)
labels=list(lua.execute((ROOT/'tools/migration/check-carunit-clearance-priming.lua').read_text(encoding='utf-8')).values())
assert sha(production)==before
report=dict(status='PASS',checks=len(labels),labels=labels,baselineSha256=sha(BASE),candidateSha256=sha(CANDIDATE),productionSha256=before,fixtureSha256=sha(FROZEN/'damage-roster.json'),resourceHashes=resources,boundary='Real frozen c935 modules and eight actual K sources. Native construction never executed; constructor stopped immediately before native boundary, no fake vehicle returned. Real cache miss/hit, pure blueprint/hp/range/cache exact, numeric checkpoints, synchronous no-checkpoint exclusion, coroutine cancellation/retain cleanup. No performance or complete native lifecycle claim.')
OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['labels','resourceHashes']},ensure_ascii=True))
