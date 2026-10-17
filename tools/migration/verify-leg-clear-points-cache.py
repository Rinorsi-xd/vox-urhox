"""Isolated Clear world-point reuse against actual frozen modules; no engine."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

BASELINE = ROOT / '.tmp/outgame-cached-1792187441376'
OUT = ROOT / 'docs/migration/evidence/leg-clear-points-cache-offline-1017'
PATHS = ['scripts/drive/LegControl.lua', 'scripts/drive/LegGait.lua', 'scripts/parts/LegIK.lua', 'scripts/core/Math3.lua']
digest = lambda data: hashlib.sha256(data).hexdigest()
original = (BASELINE / PATHS[0]).read_text(encoding='utf-8-sig')
for path in PATHS:
    assert digest((BASELINE / path).read_bytes()) == digest((ROOT / path).read_bytes()), 'Frozen controller drift: ' + path

anchor = """    local points={};for _,name in ipairs({'shoulderJoint','elbow','knee','toe'}) do
        points[#points+1]=add(p,rotate(q,add(s.leg.origin,mul(Rot.ApplyRot(s.leg.rot,ik.points[name]),CELL))))
    end"""
replacement = """    local origin=s.leg.origin;local points=value.clearPoints
    local function Same(a,b) return a==b and (a~=0 or 1/a==1/b) end
    if points and Same(value.clearQx,q.x) and Same(value.clearQy,q.y) and Same(value.clearQz,q.z) and Same(value.clearQw,q.w)
        and Same(value.clearPx,p[1]) and Same(value.clearPy,p[2]) and Same(value.clearPz,p[3])
        and Same(value.clearOx,origin[1]) and Same(value.clearOy,origin[2]) and Same(value.clearOz,origin[3]) and value.clearRot==s.leg.rot then
        -- Matching pose and transform reuse the same points within this Step.
    else
        points={};for _,name in ipairs({'shoulderJoint','elbow','knee','toe'}) do
            points[#points+1]=add(p,rotate(q,add(s.leg.origin,mul(Rot.ApplyRot(s.leg.rot,ik.points[name]),CELL))))
        end
        value.clearPoints=points
        value.clearQx,value.clearQy,value.clearQz,value.clearQw=q.x,q.y,q.z,q.w
        value.clearPx,value.clearPy,value.clearPz=p[1],p[2],p[3]
        value.clearOx,value.clearOy,value.clearOz=origin[1],origin[2],origin[3]
        value.clearRot=s.leg.rot
    end"""
assert original.count(anchor) == 1
candidate = original.replace(anchor, replacement)
diagnostic = candidate.replace('        -- Matching pose and transform reuse the same points within this Step.',
                               '        LEG_POINT_COUNTS.hits=LEG_POINT_COUNTS.hits+1')
diagnostic = diagnostic.replace('        points={};for _,name', '        LEG_POINT_COUNTS.builds=LEG_POINT_COUNTS.builds+1\n        points={};for _,name')
fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
fixture = json.loads(fixture_path.read_text(encoding='utf-8-sig'))
types = sorted({leg['type'] for case in fixture['cases'] for leg in case['spec']['legs']})
os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value


def plain(value):
    if not hasattr(value, 'items'):
        return value
    entries = list(value.items())
    if entries and all(isinstance(key, int) for key, _ in entries):
        return [plain(value[index]) for index in range(1, len(value) + 1)]
    return {key: plain(item) for key, item in entries}


lua.globals().LEG_BEFORE_ROOT = BASELINE.as_posix()
lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
lua.globals().LEG_RIGS = convert({kind: json.loads((ROOT / f'assets/Parts/Rigs/{kind}.json').read_text(encoding='utf-8-sig')) for kind in types})
lua.globals().LEG_POINTS_CANDIDATE = diagnostic
lua.globals().LEG_POINTS_CLEAN = candidate
lua.globals().LEG_POINT_COUNTS = lua.table_from({'hits': 0, 'builds': 0})
suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')


def replace_once(old, new):
    global suite
    assert suite.count(old) == 1, old
    suite = suite.replace(old, new)


replace_once("local legs=assert(loadfile(root..'/scripts/drive/LegControl.lua'))()", "local legs=root=='.' and assert(load(LEG_POINTS_CANDIDATE,'isolated-clear-points'))() or assert(loadfile(root..'/scripts/drive/LegControl.lua'))()")
replace_once("local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.')", "local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.');LEG_MODULE_PAIR={old=old,new=new}")
replace_once("elseif type(a)=='number' then", """elseif type(a)=='number' then
        if not tolerance then assert(string.pack('d',a)==string.pack('d',b),label..' double bits')end""")
suite += """
function LEG_POINT_BOUNDARIES(case)
    local outputs={}
    for _,name in ipairs({'old','new'})do
        local c=Analytic(LEG_MODULE_PAIR[name],case);local s=c.list[1]
        local q={x=0,y=0,z=0,w=1};local p={0,0,0};local foot=Copy(s.leg.toe)
        local scope <close> = c.ikScope;c.ikCache={}
        local rays={};local blockFirst=true
        c.Cast=function(_,point,direction,distance)
            rays[#rays+1]={point=Copy(point),direction=Copy(direction),distance=distance}
            if blockFirst then blockFirst=false;return {distance=.01}end
        end
        local results={c:Clear(s,foot,q,p)}
        assert(results[1]==false and #rays==1,'real first-segment failure')
        results[#results+1]=c:Clear(s,foot,q,p,3)
        assert(results[2]==true and #rays==2,'real from=3 fallback')
        results[#results+1]=c:Clear(s,foot,q,p,3)
        for _,mutate in ipairs({
            function()foot[1]=foot[1]+.125 end,
            function()p[2]=p[2]+.125;foot[2]=foot[2]+.125 end,
            function()q.y=math.sin(.03);q.w=math.cos(.03)end,
            function()q.x=-q.x;q.y=-q.y;q.z=-q.z;q.w=-q.w end,
            function()s.leg.origin[3]=s.leg.origin[3]+.125 end,
            function()s.leg.rot=(s.leg.rot+1)%24 end,
            function()q.x=-0.;p[1]=-0. end,
        })do mutate();results[#results+1]=c:Clear(s,foot,q,p,3)end
        outputs[#outputs+1]={results=results,rays=rays}
    end
    Compare(outputs[1],outputs[2],'Clear failure fallback and invalidation')
    return {firstSegmentFailure=true,from3Fallback=true,repeatedClear=true,
        inPlaceFootPositionQuaternionOriginRotation=true,signedZeroAndQuaternionSign=true}
end
function LEG_POINT_BENCH(case,steps)
    -- Remove the solve-count wrapper from both timing paths.
    local function Clean(source)
        local ik=assert(loadfile(LEG_BEFORE_ROOT..'/scripts/parts/LegIK.lua'))()
        package.loaded['parts.LegIK']=ik
        package.loaded['drive.LegGait']=assert(loadfile(LEG_BEFORE_ROOT..'/scripts/drive/LegGait.lua'))()
        return {ik=ik,legs=assert(load(source,'clean-controller-timing'))(),count={solve=0}}
    end
    local modules={old=Clean(LEG_POINTS_ORIGINAL),new=Clean(LEG_POINTS_CLEAN)}
    local times={}
    for _,name in ipairs({'old','new','new','old','old','new','new','old'})do
        local c,e=Analytic(modules[name],case)
        e.state.lv.z=4;local cmd={throttle=1,steer=.2,strafe=.1}
        for i=1,120 do e.forces={};e.rays={};c:Step(cmd,1/60,0)end
        collectgarbage('collect');local start=os.clock()
        for i=1,steps do e.forces={};e.rays={};c:Step(cmd,1/60,0)end
        times[#times+1]={name=name,seconds=os.clock()-start}
    end
    return {steps=steps,times=times}
end
"""
lua.globals().LEG_POINTS_ORIGINAL = original
lua.execute(suite)
rows = [plain(lua.globals().LEG_RUN_CASE(convert(case))) for case in fixture['cases']]
rows.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
boundaries = plain(lua.globals().LEG_RUN_BOUNDARIES(convert(fixture['cases'][0])))
clear_boundaries = plain(lua.globals().LEG_POINT_BOUNDARIES(convert(fixture['cases'][0])))
counts = plain(lua.globals().LEG_POINT_COUNTS)
benchmarks = []
if '--timing' in sys.argv:
    for kind in types:
        case = next(case for case in fixture['cases'] if case['spec']['legs'][0]['type'] == kind)
        row = plain(lua.globals().LEG_POINT_BENCH(convert(case), 2400))
        row['type'] = kind
        totals = {name: sum(item['seconds'] for item in row['times'] if item['name'] == name) for name in ['old', 'new']}
        row['candidateGainPct'] = (1 - totals['new'] / totals['old']) * 100
        benchmarks.append(row)
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'candidate-LegControl.lua').write_text(candidate, encoding='utf-8')
candidate_path = ROOT / '.tmp/leg-clear-points-candidate-1017/scripts/drive/LegControl.lua'
candidate_path.parent.mkdir(parents=True, exist_ok=True)
candidate_path.write_text(candidate, encoding='utf-8')
report = {
    'result': ('REJECTED_NO_REPEATABLE_CPU_GAIN' if any(row['candidateGainPct'] <= 0 for row in benchmarks) else 'NUMERIC_PASS_TIMING_REQUIRES_REVIEW') if benchmarks else 'NUMERIC_PASS',
    'productionChanged': False, 'runtime': lua.lua_implementation,
    'baseline': str(BASELINE), 'manifest': 'manifest-935ac922.json',
    'checks': lua.globals().LEG_ASSERTIONS(), 'cases': rows, 'boundaries': boundaries, 'clearBoundaries': clear_boundaries,
    'cacheCounts': counts, 'cacheHitPct': counts['hits'] / max(1, counts['hits'] + counts['builds']) * 100,
    'candidateSha256': digest(candidate.encode()), 'fixtureSha256': digest(fixture_path.read_bytes()),
    'candidatePath': str(candidate_path),
    'sourceSha256': {path: digest((BASELINE / path).read_bytes()) for path in PATHS},
    'isolatedBenchmarks': benchmarks,
    'decision': 'No production application is authorized by this offline test. A numerical pass alone is insufficient; absent repeatable whole-Step CPU gain, reject this candidate.',
    'boundary': 'Actual frozen LegControl/Gait/IK and Math3 with source ray/body fixtures plus synthetic mixed terrain. Complete controller/telemetry/force/ray outputs compared by packed double bits between variants; H5 fixture tolerance remains 2e-5. Benchmarks, when requested, time whole actual Step using clean modules without solve/cache diagnostic counters, automatic GC enabled and analytic collision callbacks; no Native Bullet, browser, device, full combat or sustained FPS acceptance.'
}
(OUT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: report[key] for key in ['result', 'checks', 'cacheCounts', 'cacheHitPct', 'isolatedBenchmarks']}, ensure_ascii=False))
