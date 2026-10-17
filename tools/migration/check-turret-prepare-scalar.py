"""Exact Lua 5.4 equivalence for one isolated Prepare allocation candidate."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

FROZEN = ROOT / '.tmp/perf-damage-flush-c935-1017'
BASELINE = FROZEN / 'scripts/construction/TurretRange.lua'
CANDIDATE = ROOT / 'tools/migration/candidates/TurretRangePrepareScalar.lua'
OUT = ROOT / 'docs/migration/evidence/turret-prepare-scalar-offline-2026-10-17.json'
assert not OUT.exists(), 'Preserve prior correctness evidence'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(BASELINE) == 'cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc'
old = BASELINE.read_text(encoding='utf-8')
new = CANDIDATE.read_text(encoding='utf-8')
before = '                if V.Length(V.Sub({c[1],c[2]+.5,c[3]},pv))<reach then'
after = '                local x,y,z=c[1]-pv[1],c[2]+.5-pv[2],c[3]-pv[3]\n                if math.sqrt(x*x+y*y+z*z)<reach then'
assert old.count(before) == 1 and old.replace(before, after) == new, 'Candidate changed more than the two temporary table expression'
production = ROOT / 'scripts/construction/TurretRange.lua'
production_sha = sha(production)
roster = json.loads((FROZEN / 'damage-roster.json').read_text(encoding='utf-8'))['roster']
resource_hashes = {}

def setup(source, mode='complete'):
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
    def read_resource(name):
        path = ROOT / '.tmp/outgame-cached-1792198527902/assets' / name
        resource_hashes[name] = sha(path)
        return convert(json.loads(path.read_text(encoding='utf-8-sig')))
    lua.globals().read_resource = read_resource
    lua.globals().cjson = lua.table(null=null)
    lua.globals().candidate_source = source
    lua.globals().turret_reference = BASELINE.as_posix()
    lua.globals().scalar_roster = convert(roster)
    lua.globals().scalar_test_mode = mode
    prefix = (FROZEN / 'scripts').as_posix()
    lua.globals().frozen_lua_path = prefix + '/?.lua;' + prefix + '/?/init.lua;'
    lua.execute("package.path=frozen_lua_path..package.path; package.preload['core.ResourceData']=function() return {Read=function(p)return read_resource(p)end}end; package.preload['construction.TurretRange']=function()return assert(load(candidate_source,'scalar-candidate'))()end")
    return lua

suite = (ROOT / 'tools/migration/check-turret-prepare-scalar.lua').read_text(encoding='utf-8')
lua = setup(new)
checks = lua.execute(suite)
main_labels = list(checks.values())
# Existing dense/ray-boundary suite compares real sample traces and hash aliases.
boundary_lua = setup(new)
boundary_checks, boundary_stats = boundary_lua.execute((ROOT / 'tools/migration/check-turret-aabb-boundaries.lua').read_text(encoding='utf-8'))
negative = []
for label, broken in [
    ('dy-offset', new.replace('c[2]+.5-pv[2],c[3]-pv[3]', 'c[2]+.5001-pv[2],c[3]-pv[3]', 1)),
    ('inclusive-threshold', new.replace('math.sqrt(x*x+y*y+z*z)<reach', 'math.sqrt(x*x+y*y+z*z)<=reach', 1)),
]:
    rejected = False
    try:
        setup(broken, 'thresholdOnly').execute(suite)
    except Exception:
        rejected = True
    assert rejected, 'Negative control was not detected: ' + label
    negative.append(dict(name=label, rejected=True))
assert sha(production) == production_sha, 'Production changed during read-only validation'
report = dict(status='PASS', exactCandidateReplacement=True, checks=len(main_labels), boundaryChecks=len(boundary_checks),
              boundaryStats=dict(boundary_stats.items()), negativeControls=negative,
              baselineSha256=sha(BASELINE), candidateSha256=sha(CANDIDATE), productionSha256=production_sha,
              fixtureSha256=sha(FROZEN / 'damage-roster.json'), resourceHashes=resource_hashes,
              labels=main_labels, boundaryLabels=list(boundary_checks.values()),
              boundary='Real frozen c935 Lua 5.4 modules, real K eight blueprints, authored weapon sample rigs and rotations. Bit-exact doubles for ranges/private occupancy/ray caches; checkpoint counts compared. Dense AABB/hash-alias tests use synthetic occupancy with real sample assets. Actual pure Spec/SpawnSpecCache paths verify bp cache warmth without native substitutes. No CPU benefit, native/Web/frame-time or target-device performance claim.')
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k not in ['labels', 'boundaryLabels', 'resourceHashes']}, ensure_ascii=True))
