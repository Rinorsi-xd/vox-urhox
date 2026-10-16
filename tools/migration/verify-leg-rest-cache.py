"""Reproduce a rejected rest-cache experiment entirely in memory; no GPU."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    baseline = ROOT / '.tmp/outgame-cached-1792086673066'
    source = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
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
        if all(isinstance(key, int) for key, _ in entries):
            return [plain(value[index]) for index in range(1, len(value) + 1)]
        return {key: plain(item) for key, item in entries}

    fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
    fixture = json.loads(fixture_path.read_text(encoding='utf-8-sig'))
    source_checks = {}
    for name, expected in fixture['provenance'].items():
        actual = hashlib.sha256((source / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
        source_checks[name] = {'fixture': expected, 'baseline': actual, 'match': expected == actual}
    assert all(row['match'] for name, row in source_checks.items() if name != 'shared/drive/legControl.js'), 'Source fixture provenance drift'
    assert source_checks['shared/drive/legControl.js']['baseline'] == '5c389f262b4370858ef9190e2554cbaebcd51d76b7d428baf8b174c8f56ee95e'
    types = sorted({leg['type'] for case in fixture['cases'] for leg in case['spec']['legs']})
    lua.globals().LEG_BEFORE_ROOT = baseline.as_posix()
    lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
    lua.globals().LEG_RIGS = convert({name: json.loads((ROOT / f'assets/Parts/Rigs/{name}.json').read_text(encoding='utf-8-sig')) for name in types})
    suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')
    gait_path = ROOT / 'scripts/drive/LegGait.lua'
    original_gait = gait_path.read_text(encoding='utf-8-sig')
    assert digest(gait_path) == digest(baseline / 'scripts/drive/LegGait.lua'), 'Production Gait must retain uncached implementation'
    assert original_gait.count('World(s.rest)') == 7
    candidate_gait = original_gait.replace('World(s.rest)', 'Rest(s)')
    anchor = '    local function World(localPoint) return add(p,rotate(q,localPoint)) end'
    assert candidate_gait.count(anchor) == 1
    candidate_gait = candidate_gait.replace(anchor, anchor + "\n    local rests={}\n    local function Rest(s)\n        local value=rests[s]\n        if not value then value=World(s.rest);rests[s]=value end\n        return value\n    end")
    lua.globals().LEG_REST_CANDIDATE = candidate_gait

    def replace_once(old, new):
        nonlocal suite
        assert suite.count(old) == 1, old
        suite = suite.replace(old, new)

    replace_once("local function Modules(root)", """local function Modules(root)
    local mathBase=assert(loadfile(root..'/scripts/core/Math3.lua'))()
    local mathCount={rotate=0}
    local mathCopy={};for k,v in pairs(mathBase)do mathCopy[k]=v end
    mathCopy.RotateUnit=function(...)mathCount.rotate=mathCount.rotate+1;return mathBase.RotateUnit(...)end
    package.loaded['core.Math3']=mathCopy
""")
    replace_once('return {ik=ik,legs=legs,count=count}', 'return {ik=ik,legs=legs,count=count,mathCount=mathCount}')
    replace_once("package.loaded['drive.LegGait']=assert(loadfile(root..'/scripts/drive/LegGait.lua'))()", "package.loaded['drive.LegGait']=root=='.' and assert(load(LEG_REST_CANDIDATE,'rejected-rest-cache'))() or assert(loadfile(root..'/scripts/drive/LegGait.lua'))()")
    # Isolate the Gait change: both variants use the current controller rules.
    replace_once("local legs=assert(loadfile(root..'/scripts/drive/LegControl.lua'))()", "local legs=assert(loadfile('scripts/drive/LegControl.lua'))()")
    replace_once("local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.')", "local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.');LEG_MODULE_PAIR={old=old,new=new}")
    replace_once("elseif type(a)=='number' then", """elseif type(a)=='number' then
        if not tolerance then assert(string.pack('d',a)==string.pack('d',b),label..' double bits')end
""")
    suite += """
function LEG_REST_BENCH(case,steps)
    local times={};local rotateCounts={}
    for _,name in ipairs({'old','new','new','old','old','new'})do
        local mod=LEG_MODULE_PAIR[name];local c,e=Analytic(mod,case)
        e.state.lv.z=4;local cmd={throttle=1,steer=.2,strafe=.1}
        local before=mod.mathCount.rotate;collectgarbage('collect');local start=os.clock()
        for i=1,steps do e.forces={};e.rays={};c:Step(cmd,1/60,0)end
        times[#times+1]={name=name,seconds=os.clock()-start}
        rotateCounts[name]=mod.mathCount.rotate-before
    end
    return {steps=steps,times=times,rotateCounts=rotateCounts}
end
"""
    lua.execute(suite)
    rows = [plain(lua.globals().LEG_RUN_CASE(convert(case))) for case in fixture['cases']]
    rows.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
    boundaries = plain(lua.globals().LEG_RUN_BOUNDARIES(convert(fixture['cases'][0])))
    transforms = {name: {'rotate': lua.globals().LEG_MODULE_PAIR[name]['mathCount']['rotate']} for name in ['old', 'new']}
    benchmarks = []
    for kind in types:
        case = next(case for case in fixture['cases'] if case['spec']['legs'][0]['type'] == kind)
        row = plain(lua.globals().LEG_REST_BENCH(convert(case), 1200))
        row['type'] = kind
        benchmarks.append(row)
    paths = ['scripts/drive/LegGait.lua', 'scripts/drive/LegControl.lua', 'scripts/parts/LegIK.lua', 'scripts/core/Math3.lua']
    report = {
        'result': 'REJECTED_NO_CPU_GAIN', 'numericResult': 'PASS', 'runtime': lua.lua_implementation,
        'productionChanged': False, 'candidateSha256': hashlib.sha256(candidate_gait.encode('utf-8')).hexdigest(),
        'baseline': str(baseline), 'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455',
        'reference': {path: digest(baseline / path) for path in paths},
        'productionHashes': {path: digest(ROOT / path) for path in paths},
        'fixtureSha256': digest(fixture_path), 'sourceProvenance': source_checks,
        'fixtureControlDelta': 'Historical trajectories predate the frozen source control fixes. Unchanged no-jet/pure-leg trajectories remain regression inputs; new mixed-load, drive-jet and restore rules require separate direct frozen-JS checks. Both Gait variants use identical current LegControl rules.',
        'checks': lua.globals().LEG_ASSERTIONS(), 'cases': rows, 'boundaries': boundaries,
        'replayTransformCalls': transforms, 'isolatedBenchmarks': benchmarks,
        'boundary': 'Actual frozen Lua Gait versus a candidate generated only in memory, both with identical current LegControl and IK. No production cache is installed. Same ray/velocity/force ordering against historical H5 fixtures with 2e-5 source tolerance; old/new full numeric outputs compared by packed double bits. Mixed terrain is synthetic. Full controller timings show no repeatable CPU gain; this experiment is rejected and does not prove native Bullet, Web FPS, GPU, mobile or sustained-device performance.'
    }
    output = ROOT / 'docs/migration/evidence/leg-rest-cache-offline.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['result', 'checks', 'replayTransformCalls', 'isolatedBenchmarks']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
