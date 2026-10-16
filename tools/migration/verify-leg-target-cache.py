"""Compare target experiments or final production with frozen 046 controllers."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
baseline = ROOT / '.tmp/outgame-cached-1792088233891'
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
original = (baseline / 'scripts/drive/LegControl.lua').read_text(encoding='utf-8-sig')
start = original.index('local function Evaluation(')
end = original.index('\nfunction M:Clear(', start)
replacement = """local function Evaluation(self,s,foot,q,p)
    local info=self.info[s.leg.type];local origin=s.leg.origin;local rot=s.leg.rot
    local previous=self.ikCache and self.ikCache[s]
    if previous and previous.info==info and previous.rot==rot
        and previous.fx==foot[1] and previous.fy==foot[2] and previous.fz==foot[3]
        and previous.qx==q.x and previous.qy==q.y and previous.qz==q.z and previous.qw==q.w
        and previous.px==p[1] and previous.py==p[2] and previous.pz==p[3]
        and previous.ox==origin[1] and previous.oy==origin[2] and previous.oz==origin[3] then return previous end
    local target=self:Target(s,foot,q,p)
    local value=previous and previous.info==info and previous.target[1]==target[1] and previous.target[2]==target[2] and previous.target[3]==target[3] and previous or {info=info,target=target}
    if self.ikCache then
        value.fx,value.fy,value.fz=foot[1],foot[2],foot[3]
        value.qx,value.qy,value.qz,value.qw=q.x,q.y,q.z,q.w
        value.px,value.py,value.pz=p[1],p[2],p[3]
        value.ox,value.oy,value.oz,value.rot=origin[1],origin[2],origin[3],rot
        self.ikCache[s]=value
    end
    return value
end"""
candidate = original[:start] + replacement + original[end:]
mode = sys.argv[1] if len(sys.argv) > 1 else 'input-cache'
if mode == 'scalar':
    start = original.index('function M:Target(')
    end = original.index('\nlocal function Evaluation(', start)
    replacement = """function M:Target(s,foot,q,p)
    local x,y,z,w=-q.x,-q.y,-q.z,q.w
    local vx,vy,vz=foot[1]-p[1],foot[2]-p[2],foot[3]-p[3]
    local cx,cy,cz=y*vz-z*vy,z*vx-x*vz,x*vy-y*vx
    local twice=2*w;local origin=s.leg.origin;local scale=1/CELL
    local dx=(vx+(cx*twice+(y*cz-z*cy)*2)-origin[1])*scale
    local dy=(vy+(cy*twice+(z*cx-x*cz)*2)-origin[2])*scale
    local dz=(vz+(cz*twice+(x*cy-y*cx)*2)-origin[3])*scale
    local result={}
    for i,axis in ipairs(targetAxes[s.leg.rot])do result[i]=dx*axis[1]+dy*axis[2]+dz*axis[3]end
    return result
end"""
    candidate = original[:start] + replacement + original[end:]
elif mode != 'input-cache':
    raise ValueError(mode)
production = '--production' in sys.argv[2:]
if production:
    candidate = (ROOT / 'scripts/drive/LegControl.lua').read_text(encoding='utf-8-sig')
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


fixture_path = ROOT / 'tools/migration/source-leg-drive-fixtures.json'
fixture = json.loads(fixture_path.read_text(encoding='utf-8-sig'))
types = sorted({leg['type'] for c in fixture['cases'] for leg in c['spec']['legs']})
lua.globals().LEG_BEFORE_ROOT = baseline.as_posix()
lua.globals().LEG_CELL = json.loads((ROOT / 'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))['cell']
lua.globals().LEG_RIGS = convert({t: json.loads((ROOT / f'assets/Parts/Rigs/{t}.json').read_text(encoding='utf-8-sig')) for t in types})
lua.globals().LEG_TARGET_CANDIDATE = candidate
suite = (ROOT / 'tools/migration/check-leg-cache-offline.lua').read_text(encoding='utf-8-sig')


def replace_once(old, new):
    global suite
    assert suite.count(old) == 1, old
    suite = suite.replace(old, new)


replace_once("local legs=assert(loadfile(root..'/scripts/drive/LegControl.lua'))()", """local legs=root=='.' and assert(load(LEG_TARGET_CANDIDATE,'target-input-cache'))() or assert(loadfile(root..'/scripts/drive/LegControl.lua'))()
    local target=legs.Target;count.target=0
    legs.Target=function(...)count.target=count.target+1;return target(...)end""")
replace_once("local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.')", "local old=Modules(LEG_BEFORE_ROOT);local new=Modules('.');LEG_MODULE_PAIR={old=old,new=new}")
replace_once("elseif type(a)=='number' then", """elseif type(a)=='number' then
        if not tolerance then assert(string.pack('d',a)==string.pack('d',b),label..' double bits')end""")
suite += """
function LEG_TARGET_STRESS()
    local seed=91823
    local function R()seed=(seed*48271)%2147483647;return (seed/2147483647-.5)*200 end
    local cases=0
    for rot=0,23 do for i=1,1200 do
        local q={x=R()*.01,y=R()*.01,z=R()*.01,w=R()*.01}
        local foot={R(),R(),R()};local p={R(),R(),R()};local origin={R(),R(),R()}
        if i%11==0 then foot[1]=-0.;q.x=-0.;p[2]=0.;origin[3]=-0. end
        if i%17==0 then q={x=0,y=0,z=0,w=1}end
        if i%19==0 then q={x=0,y=0,z=0,w=0}end
        if i%23==0 then foot={0.,-0.,0.};p={-0.,0.,-0.};origin={0.,-0.,0.}end
        local s={leg={origin=origin,rot=rot}}
        local a=old.legs.Target({},s,foot,q,p);local b=new.legs.Target({},s,foot,q,p)
        Compare(a,b,'random target/'..rot..'/'..i);cases=cases+1
    end end
    return cases
end
function LEG_TARGET_BENCH(case,steps)
    local times={};local counts={}
    for _,name in ipairs({'old','new','new','old','old','new','new','old'})do
        local mod=LEG_MODULE_PAIR[name];local c,e=Analytic(mod,case)
        e.state.lv.z=4;local cmd={throttle=1,steer=.2,strafe=.1}
        local before=mod.count.target;collectgarbage('collect');local start=os.clock()
        for i=1,steps do e.forces={};e.rays={};c:Step(cmd,1/60,0)end
        times[#times+1]={name=name,seconds=os.clock()-start}
        counts[name]=mod.count.target-before
    end
    return {steps=steps,times=times,targetCalls=counts}
end
"""
lua.execute(suite)
rows = [plain(lua.globals().LEG_RUN_CASE(convert(c))) for c in fixture['cases']]
rows.append(plain(lua.globals().LEG_RUN_MIXED(convert(fixture['cases'][0]))))
boundaries = plain(lua.globals().LEG_RUN_BOUNDARIES(convert(fixture['cases'][0])))
calls = {n: lua.globals().LEG_MODULE_PAIR[n]['count']['target'] for n in ['old', 'new']}
stress_cases = lua.globals().LEG_TARGET_STRESS()
benchmarks = []
for kind in types:
    case = next(c for c in fixture['cases'] if c['spec']['legs'][0]['type'] == kind)
    row = plain(lua.globals().LEG_TARGET_BENCH(convert(case), 3000))
    row['type'] = kind
    benchmarks.append(row)
profile_path = ROOT / 'docs/migration/evidence/combat-performance-2026-10-15T18-18-10-110Z/report.json'
profile = json.loads(profile_path.read_text(encoding='utf-8-sig'))
a, b = profile['profiles'][66], profile['profiles'][67]
timings = {k: {'calls': v['calls'] - a['timings'].get(k, {}).get('calls', 0), 'totalMs': v['totalMs'] - a['timings'].get(k, {}).get('totalMs', 0)}
           for k, v in b['timings'].items() if k.startswith('crater:live:') and any(t in k for t in ['LegControl', 'vehicle.Step', 'RaySuspension', 'physics.Space.Step'])}
report = {'result': 'PASS' if production else 'REJECTED_NO_CPU_GAIN' if mode == 'input-cache' else 'EXPERIMENT_NUMERIC_PASS', 'numericResult': 'PASS', 'runtime': lua.lua_implementation,
          'mode': mode,
          'productionChanged': production, 'reference': str(baseline), 'referenceSha256': digest(baseline / 'scripts/drive/LegControl.lua'),
          'candidateSha256': hashlib.sha256(candidate.encode('utf-8')).hexdigest(),
          'fixtureSha256': digest(fixture_path), 'checks': lua.globals().LEG_ASSERTIONS(), 'cases': rows,
          'boundaries': boundaries, 'targetStressCases': stress_cases, 'replayTargetCalls': calls, 'benchmarks': benchmarks,
          'productionHashes': {p: digest(ROOT / p) for p in ['scripts/drive/LegControl.lua', 'scripts/drive/LegGait.lua', 'scripts/parts/LegIK.lua', 'scripts/core/Math3.lua']} if production else {},
          'runtimeEvidence': {'path': str(profile_path.relative_to(ROOT)), 'sha256': digest(profile_path),
                              'fromProfile': 66, 'toProfile': 67, 'fromAt': a['at'], 'toAt': b['at'], 'timings': timings,
                              'boundary': 'Same Lua crater:live phase, six cars and 78 fixed steps. Interval includes active scenario instrumentation; inclusive timers cannot be added.'},
          'boundary': ('Actual frozen 046 Lua controllers/Gait/IK against actual production LegControl read from disk. ' if production else 'Actual frozen 046 Lua controllers/Gait/IK against a candidate generated only in memory. ') + 'Historical no-jet/pure-leg recorded H5 trajectories plus synthetic mixed terrain and mutable-input boundaries. Exact double outputs/order are compared. Full controller isolated timings do not prove native Bullet, browser FPS or device performance.'}
output = 'leg-target-scalar-offline.json' if production else f'leg-target-{mode}-experiment.json'
(ROOT / 'docs/migration/evidence' / output).write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: report[k] for k in ['result', 'checks', 'replayTargetCalls', 'benchmarks']}))
