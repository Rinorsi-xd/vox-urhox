"""Exact real-module validation of deletion-only sampled-hit reuse."""
import hashlib
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
FROZEN=ROOT/'.tmp/perf-damage-flush-c935-1017'
BASE=FROZEN/'scripts/construction/TurretRange.lua'
CANDIDATE=ROOT/'tools/migration/candidates/TurretRangeSampledDeletion.lua'
OUT=ROOT/'docs/migration/evidence/turret-sampled-deletion-offline-2026-10-17.json'
assert not OUT.exists(),'Preserve prior evidence'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(BASE)=='cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc'
source=CANDIDATE.read_text(encoding='utf-8');resources={}
roster=json.loads((FROZEN/'damage-roster.json').read_text(encoding='utf-8'))['roster']
def setup(candidate):
    lua=LuaRuntime(unpack_returned_tuples=True);null=lua.table()
    def convert(v):
        if v is None:return null
        if isinstance(v,dict):return lua.table_from({k:convert(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([convert(x) for x in v])
        return v
    def read_resource(name):
        p=ROOT/'.tmp/outgame-cached-1792198527902/assets'/name;resources[name]=sha(p)
        return convert(json.loads(p.read_text(encoding='utf-8-sig')))
    lua.globals().read_resource=read_resource;lua.globals().cjson=lua.table(null=null)
    lua.globals().candidate_source=candidate;lua.globals().turret_reference=BASE.as_posix()
    lua.globals().scalar_roster=convert(roster)
    lua.globals().frozen_path=(FROZEN/'scripts').as_posix()+'/?.lua;'+(FROZEN/'scripts').as_posix()+'/?/init.lua;'
    lua.execute("package.path=frozen_path..package.path;package.preload['core.ResourceData']=function()return {Read=function(p)return read_resource(p)end}end;package.preload['construction.TurretRange']=function()return assert(load(candidate_source,'sampled-deletion-candidate'))()end")
    return lua
suite=(ROOT/'tools/migration/check-turret-sampled-deletion.lua').read_text(encoding='utf-8')
production=ROOT/'scripts/construction/TurretRange.lua';production_sha=sha(production)
checks,transitions=setup(source).execute(suite)
labels=list(checks.values());rows=[dict(row.items()) for row in transitions.values()]
negative=[]
broken=source.replace('if b.occ[hash]~=id and a.sampledHits[id] then return false end','if false then return false end',1)
assert broken!=source
try:
    setup(broken).execute(suite)
except Exception as error:
    negative.append(dict(name='ignore-removed-hit-dependency',rejected=True,error=str(error).splitlines()[0]))
assert negative,'Negative control failed to detect unsound hit reuse'
assert sha(production)==production_sha
summary=dict(candidateEvaluations=sum(r['candidateEvaluations'] for r in rows),baselineEvaluations=sum(r['baselineEvaluations'] for r in rows),savedCheckpoints=sum(r['baselineCheckpoints']-r['candidateCheckpoints'] for r in rows),transitionsWithSkippedEvaluation=sum(r['candidateEvaluations']<r['baselineEvaluations'] for r in rows))
damage=[r for r in rows if r['label'].startswith('K ') and ' damage ' in r['label'] and ' hot ' not in r['label']]
report=dict(status='PASS',checks=len(labels),labels=labels,transitions=rows,summary=summary,actualKDamage=damage,negativeControls=negative,baselineSha256=sha(BASE),candidateSha256=sha(CANDIDATE),productionSha256=production_sha,fixtureSha256=sha(FROZEN/'damage-roster.json'),resourceHashes=resources,boundary='Real frozen c935 Lua5.4 algorithms and K eight blueprints plus authored weapon samples across24rotations. Exact double ranges/order/occupancy/rays ignoring only additive candidate sampledHits metadata. Query checkpoint reduction expected when deterministic Evaluate is skipped; no scheduling removed from Prepare. No hardware performance or FPS claim. Cold computation is unchanged except hit metadata overhead and may regress; requires measured Native/Web A/B before production.')
OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['labels','transitions','resourceHashes','actualKDamage']},ensure_ascii=True))
