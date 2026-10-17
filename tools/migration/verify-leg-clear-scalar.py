"""Check a scalar Clear transform against actual frozen complete controllers."""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

TRANSFORM = """local function PosePoint(leg,point,q,p)
    -- Preserve ApplyRot/Scale/Add/RotateUnit grouping without temporary vectors.
    local m=Rot.ROTATIONS[leg.rot].m;local origin=leg.origin
    local vx=origin[1]+(m[1]*point[1]+m[2]*point[2]+m[3]*point[3])*CELL
    local vy=origin[2]+(m[4]*point[1]+m[5]*point[2]+m[6]*point[3])*CELL
    local vz=origin[3]+(m[7]*point[1]+m[8]*point[2]+m[9]*point[3])*CELL
    local x,y,z=q.x,q.y,q.z
    local cx,cy,cz=y*vz-z*vy,z*vx-x*vz,x*vy-y*vx;local twice=2*q.w
    return {p[1]+(vx+(cx*twice+(y*cz-z*cy)*2)),
        p[2]+(vy+(cy*twice+(z*cx-x*cz)*2)),
        p[3]+(vz+(cz*twice+(x*cy-y*cx)*2))}
end
"""
OLD_POINT = 'add(p,rotate(q,add(s.leg.origin,mul(Rot.ApplyRot(s.leg.rot,ik.points[name]),CELL))))'


def candidate_from(source):
    assert source.count(OLD_POINT) == 1
    assert source.count('function M:Clear(') == 1
    return source.replace('function M:Clear(', TRANSFORM + 'function M:Clear(').replace(
        OLD_POINT, 'PosePoint(s.leg,ik.points[name],q,p)')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, default=Path('.tmp/perf-vehicle-allocation-20261017-b'))
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--benchmark', action='store_true')
    parser.add_argument('--math3-candidate', type=Path)
    parser.add_argument('--output', type=Path, default=Path('docs/migration/evidence/leg-clear-scalar-offline.json'))
    args = parser.parse_args()
    os.chdir(ROOT)
    baseline = args.baseline.resolve()
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    shared = ['scripts/drive/LegGait.lua', 'scripts/parts/LegIK.lua', 'scripts/core/Math3.lua', 'scripts/core/Rotations.lua']
    for path in shared:
        assert digest(ROOT / path) == digest(baseline / path), 'Shared module drift: ' + path
    before = (baseline / 'scripts/drive/LegControl.lua').read_text(encoding='utf-8-sig')
    candidate = before if args.math3_candidate else candidate_from(before)
    math_candidate = args.math3_candidate.read_text(encoding='utf-8-sig') if args.math3_candidate else None
    if args.production:
        production_path = ROOT / ('scripts/core/Math3.lua' if math_candidate else 'scripts/drive/LegControl.lua')
        assert production_path.read_text(encoding='utf-8-sig') == (math_candidate or candidate)
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

    fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
    fixture = json.loads(fixture_path.read_text(encoding='utf-8-sig'))
    kinds = sorted({leg['type'] for case in fixture['cases'] for leg in case['spec']['legs']})
    lua.globals().LEG_BEFORE_ROOT = baseline.as_posix()
    lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
    lua.globals().LEG_RIGS = convert({kind: json.loads((ROOT / f'assets/Parts/Rigs/{kind}.json').read_text(encoding='utf-8-sig')) for kind in kinds})
    lua.globals().LEG_CLEAR_CANDIDATE = candidate.replace('return M', 'M.PosePoint=PosePoint;return M')
    if math_candidate:
        lua.globals().LEG_MATH3_CANDIDATE = math_candidate
    suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')

    def replace_once(old, new):
        nonlocal suite
        assert suite.count(old) == 1, old
        suite = suite.replace(old, new)

    if math_candidate:
        replace_once('local function Modules(root)', """local function Modules(root)
    package.loaded['core.Math3']=root=='.' and assert(load(LEG_MATH3_CANDIDATE,'scalar-math3'))() or assert(loadfile(root..'/scripts/core/Math3.lua'))()""")

    replace_once("local legs=assert(loadfile(root..'/scripts/drive/LegControl.lua'))()", """local legs=root=='.' and assert(load(LEG_CLEAR_CANDIDATE,'scalar-clear'))() or assert(loadfile(root..'/scripts/drive/LegControl.lua'))()
    count.clear=0;local clear=legs.Clear
    legs.Clear=function(...)count.clear=count.clear+1;return clear(...)end""")
    replace_once("local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.')", "local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.');LEG_MODULE_PAIR={old=old,new=new}")
    replace_once("elseif type(a)=='number' then", """elseif type(a)=='number' then
        if not tolerance then assert(string.pack('d',a)==string.pack('d',b),label..' double bits')end""")
    suite += """
function LEG_CLEAR_STRESS()
    local Rot=require 'core.Rotations';local seed=74271
    local function R()seed=(seed*48271)%2147483647;return (seed/2147483647-.5)*200 end
    local cases=0
    for rot=0,23 do for i=1,1200 do
        local q={x=R()*.01,y=R()*.01,z=R()*.01,w=R()*.01}
        local point={R(),R(),R()};local p={R(),R(),R()};local origin={R(),R(),R()}
        if i%11==0 then point[1]=-0.;q.x=-0.;p[2]=0.;origin[3]=-0. end
        if i%17==0 then q={x=0,y=0,z=0,w=1}end
        if i%19==0 then q={x=0,y=0,z=0,w=0}end
        if i%23==0 then point={0.,-0.,0.};p={-0.,0.,-0.};origin={0.,-0.,0.}end
        local a=V.Add(p,V.RotateUnit(q,V.Add(origin,V.Scale(Rot.ApplyRot(rot,point),LEG_CELL))))
        local b=new.legs.PosePoint({origin=origin,rot=rot},point,q,p)
        Compare(a,b,'random clear/'..rot..'/'..i);cases=cases+1
    end end
    return cases
end
function LEG_CLEAR_BENCH(case,steps)
    local times={}
    for _,name in ipairs({'old','new','new','old','old','new','new','old'})do
        local mod=LEG_MODULE_PAIR[name];local c,e=Analytic(mod,case)
        e.state.lv.z=4;local cmd={throttle=1,steer=.2,strafe=.1}
        local calls=mod.count.clear;collectgarbage('collect');local start=os.clock()
        for i=1,steps do e.forces={};e.rays={};c:Step(cmd,1/60,0)end
        times[#times+1]={name=name,seconds=os.clock()-start,clearCalls=mod.count.clear-calls}
    end
    return {steps=steps,times=times}
end
"""
    lua.execute(suite)
    cases = [plain(lua.globals().LEG_RUN_CASE(convert(case))) for case in fixture['cases']]
    cases.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
    boundaries = plain(lua.globals().LEG_RUN_BOUNDARIES(convert(fixture['cases'][0])))
    stress = 0 if math_candidate else lua.globals().LEG_CLEAR_STRESS()
    benchmarks = []
    if args.benchmark:
        for kind in kinds:
            case = next(case for case in fixture['cases'] if case['spec']['legs'][0]['type'] == kind)
            row = plain(lua.globals().LEG_CLEAR_BENCH(convert(case), 2400))
            row['type'] = kind
            benchmarks.append(row)
    report = {
        'result': 'PASS', 'numericResult': 'PASS', 'runtime': lua.lua_implementation,
        'productionChanged': args.production, 'baseline': str(baseline),
        'baselineSha256': digest(baseline / 'scripts/drive/LegControl.lua'),
        'candidateKind': 'Math3.Mix/Reject/Unrotate' if math_candidate else 'LegControl.Clear',
        'candidateSha256': hashlib.sha256((math_candidate or candidate).encode('utf-8')).hexdigest(),
        'sharedModuleHashes': {path: digest(baseline / path) for path in shared},
        'fixtureSha256': digest(fixture_path), 'checks': lua.globals().LEG_ASSERTIONS(),
        'cases': cases, 'boundaries': boundaries, 'pointStressCases': stress,
        'benchmarks': benchmarks,
        'boundary': 'Actual frozen complete LegControl/Gait/IK versus identical modules with an in-memory scalar math candidate. Packed double comparisons include controller state, telemetry, ray and force values and ordering, mutable-input, restore, destruction and error-unwind cases. Historical H5 fixtures retain their original tolerance. Synthetic full-controller timing is diagnostic only; Native/Bullet, Web FPS and target-device acceptance are separate.'
    }
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / 'docs/migration/evidence'), 'Output must remain in persistent evidence'
    if output.exists():
        raise RuntimeError('Preserve previous evidence; use a fresh output label before rerunning.')
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['result', 'checks', 'pointStressCases', 'benchmarks']}))


if __name__ == '__main__':
    main()
