"""Offline instrumentation equivalence and local marker stack checks."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

subprocess.run(['node', str(ROOT / 'tools/migration/g1-web-cpu-local-sections-prepare.cjs')], check=True)
identity = json.loads((ROOT / '.tmp/outgame-cached-1792171171463/identity.json').read_text(encoding='utf-8'))
source = Path(identity['source_directory']) / 'scripts'
variants = ROOT / '.tmp/g1-web-cpu-local-sections-candidates'
read = lambda p: p.read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
merge = lua.execute(read(ROOT / 'tools/migration/g1-web-cpu-local-sections-selftest.lua'), read(source / 'drive/VehicleSpec.lua'), read(variants / 'VehicleSpec.lua'))
options = lua.table_from({'skipOccIds': True, 'probe': merge['probe']})
turret = lua.execute(read(ROOT / 'tools/migration/g1-web-cpu-occids-selftest.lua'), read(source / 'construction/TurretRange.lua'), read(variants / 'TurretRange.lua'), options)
assert merge['cases'] == 34 and turret['comparisons'] == 61
for name in ['TurretRange.For.Signatures', 'TurretRange.For.Invalidations', 'TurretRange.Prepare',
             'TurretRange.Evaluate', 'TurretRange.SameContext', 'MergeBoxes.Index', 'MergeBoxes.Sort', 'MergeBoxes.Sweep']:
    assert merge['calls'][name] > 0, name

profiler = LuaRuntime(unpack_returned_tuples=True)
setup = read(ROOT / 'tools/migration/g1-web-cpu-damage-selftest.lua').split('local M=assert(load(...))()', 1)[0]
profiler.execute(setup)
module = profiler.execute(read(ROOT / 'tools/migration/g1-web-cpu-damage.lua'))
check = profiler.eval('''function(M)
 local now=0;local function clock()now=now+1;return now end
 local p=M.LocalProfile(clock,true);p.Reset()
 local a=G1_WEB_CPU_LOCAL_SECTIONS.Begin('TurretRange.Prepare')
 local b=G1_WEB_CPU_LOCAL_SECTIONS.Begin('TurretRange.Evaluate')
 G1_WEB_CPU_LOCAL_SECTIONS.Finish(b);G1_WEB_CPU_LOCAL_SECTIONS.Finish(a)
 local rows=p.Snapshot();assert(#rows==8)
 local sum,outer=0,0
 for _,r in ipairs(rows)do assert(r.ms>=r.selfMs and r.selfMs>=0);sum=sum+r.selfMs;if r.name=='TurretRange.Prepare'then outer=r.ms end end
 assert(sum==outer)
 p.Reset();for _,r in ipairs(p.Snapshot())do assert(r.ms==0 and r.calls==0)end
 p.Restore();assert(G1_WEB_CPU_LOCAL_SECTIONS.Begin('disabled')==nil)
 local none=M.LocalProfile(clock,false);assert(none.Snapshot()==false)
 return true
end''')
assert check(module)
print(json.dumps({'status': 'PASS', 'turretSteps': 61, 'mergeCases': 34, 'localScopes': 8,
                  'boundary': 'Offline exact outputs/checkpoints/RNG and nested timer plumbing only; no real runtime timing.'}))
