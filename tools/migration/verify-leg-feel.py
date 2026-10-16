"""Execute actual frozen H5 and production Lua leg rules without a GPU."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
subprocess.run(['node', 'tools/migration/source-leg-feel-fixtures.mjs'], check=True)
lua = LuaRuntime(unpack_returned_tuples=True)


def convert(value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items() if v is not None})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return value


def plain(value):
    if not hasattr(value, 'items'):
        return value
    rows = list(value.items())
    if rows and all(isinstance(k, int) for k, _ in rows):
        return [plain(value[i]) for i in range(1, len(value) + 1)]
    return {k: plain(v) for k, v in rows}


fixture_path = ROOT / '.tmp/source-leg-feel-fixtures.json'
fixture = json.loads(fixture_path.read_text(encoding='utf-8'))
baseline = ROOT / '.tmp/outgame-cached-1792086673066'
types = sorted({leg['type'] for c in fixture['cases'] for leg in c['spec']['legs']})
lua.globals().LEG_BEFORE_ROOT = baseline.as_posix()
lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
lua.globals().LEG_RIGS = convert({t: json.loads((ROOT / f'assets/Parts/Rigs/{t}.json').read_text(encoding='utf-8-sig')) for t in types})
suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')
suite += """
function LEG_FEEL_CASE(case,name)
    local mod=name=='old' and old or new
    local c,e,v=Analytic(mod,case)
    for k,value in pairs(case.state)do e.state[k]=Copy(value)end
    c.Cast=function(_,p,d,distance)
        local t=math.abs(d[2])>1e-9 and -p[2]/d[2] or math.huge
        local hit=t>1e-7 and t<=distance and {distance=t,point=V.Add(p,V.Scale(d,t)),normal={0,1,0},collider=1} or nil
        e.rays[#e.rays+1]={p=Copy(p),d=Copy(d),length=distance,hit=Copy(hit)}
        return hit
    end
    for frame,expected in ipairs(case.frames)do
        e.forces={};e.rays={}
        local telemetry=c:Step(case.command,1/60,0)
        local states={};for i,s in ipairs(c.list)do states[i]={id=s.leg.partId,foot=s.foot,target=s.target,mode=s.mode,bladeAngle=s.bladeAngle}end
        Compare({telemetry=telemetry,forces=e.forces,rays=e.rays,driveJets=v.driveJets,offGround=c.offGround,wallMemo=c.wallMemo,states=states},expected,case.name..'/'..frame,2e-5)
    end
    return true
end
function LEG_FEEL_SNAPSHOT(case,expected,name)
    local mod=name=='old' and old or new
    local a=Analytic(mod,case);local b=Analytic(mod,case)
    a.offGround=.12;a.wallMemo=expected.restored.wallMemo
    b.offGround=.03;b.wallMemo={normal={1,0,0},ttl=.8}
    local saved=a:Snapshot();b:Restore(saved)
    Compare(b.offGround,expected.restored.offGround,'restore offGround')
    Compare(b.wallMemo,expected.restored.wallMemo,'restore wallMemo',2e-5)
    b.offGround=.07;b.wallMemo={normal={1,0,0},ttl=.9}
    b:Restore({states={}})
    Compare(b.offGround,.07,'partial restore retains offGround')
    Compare(b.wallMemo,{normal={1,0,0},ttl=.9},'partial restore retains memo',2e-5)
    return true
end
"""
lua.execute(suite)
results = {}
for name in ['old', 'new']:
    failures = []
    passed = 0
    before = lua.globals().LEG_ASSERTIONS()
    for case in fixture['cases']:
        try:
            lua.globals().LEG_FEEL_CASE(convert(case), name)
            passed += 1
        except Exception as error:
            failures.append({'case': case['name'], 'error': str(error).split('\n')[0]})
    for i, row in enumerate(fixture['snapshots']):
        try:
            lua.globals().LEG_FEEL_SNAPSHOT(convert(fixture['cases'][0]), convert(row), name)
            passed += 1
        except Exception as error:
            failures.append({'case': f'snapshot-{i}', 'error': str(error).split('\n')[0]})
    results[name] = {'passed': passed, 'failed': len(failures), 'checks': lua.globals().LEG_ASSERTIONS() - before, 'failures': failures}
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
paths = ['scripts/drive/LegControl.lua', 'scripts/drive/LegGait.lua', 'scripts/parts/LegIK.lua', 'scripts/core/Math3.lua']
report = {'result': 'PASS' if results['new']['failed'] == 0 and results['old']['failed'] > 0 else 'FAIL',
          'sourceCommit': fixture['sourceCommit'], 'sourceHashes': fixture['hashes'],
          'fixtureSha256': digest(fixture_path), 'cases': len(fixture['cases']), 'frames': sum(len(c['frames']) for c in fixture['cases']),
          'snapshots': len(fixture['snapshots']), 'runtime': lua.lua_implementation,
          'productionHashes': {p: digest(ROOT / p) for p in paths}, 'referenceHashes': {p: digest(baseline / p) for p in paths},
          'results': results, 'boundary': 'Frozen H5 actual LegController, Gait and IK executed by Node; actual production Lua executed in Lua 5.4. Analytic ground/body adapters preserve ray and force order; source numeric tolerance 2e-5. Does not verify native Bullet, browser feel, FPS or mobile.'}
(ROOT / 'docs/migration/evidence/leg-feel-offline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'cases': report['cases'], 'frames': report['frames'], 'results': {k: {n: r[n] for n in ['passed', 'failed', 'checks']} for k, r in results.items()}}))
if report['result'] != 'PASS':
    print(json.dumps(results['new']['failures'][:6]))
    raise SystemExit(1)
