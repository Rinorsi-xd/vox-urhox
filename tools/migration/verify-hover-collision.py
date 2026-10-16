"""Check the 120 hover mounting contracts against the current frozen H5 source."""
import hashlib
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

js = r'''
import fs from 'node:fs';import {pathToFileURL} from 'node:url';import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const source=baseline.snapshot,load=p=>import(pathToFileURL(source+'/'+p));
const {buildVehicleSpec}=await load('shared/drive/vehicleSpec.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {HOVER_GLB}=await load('shared/parts/hoverData.js');
const old=JSON.parse(fs.readFileSync('tools/migration/source-vehicle-fixtures.json'));
const cases=[];
for(const c of old.cases.filter(c=>/^hover[1-5]$/.test(c.part.type))){
 const bp=new Blueprint();bp.add(c.part);bp.connectivity=()=>({coreId:1,reached:new Set([1])});
 cases.push({part:[...bp.parts.values()][0],spec:buildVehicleSpec(bp),old:c.spec});
}
const files=['shared/drive/vehicleSpec.js','shared/parts/hoverMount.js','shared/parts/hoverData.js','shared/parts/defs.js','shared/build/blueprint.js'];
const hashes=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(fs.readFileSync(source+'/'+p)).digest('hex')]));
for(const [p,h]of Object.entries(hashes))if(h!==baseline.files[p].sha256)throw Error('Frozen source changed: '+p);
process.stdout.write(JSON.stringify({commit:baseline.commit,oldCommit:old.commit,hashes,hoverData:HOVER_GLB,cases},
 (k,v)=>v instanceof Set?[...v]:ArrayBuffer.isView(v)?Array.from(v):v));
'''
fixture = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT, text=True, encoding='utf-8'))
assert len(fixture['cases']) == 120
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


def plain(value):
    if hasattr(value, 'items'):
        rows = list(value.items())
        if not rows or all(isinstance(k, int) for k, _ in rows):
            return [plain(value[i]) for i in range(1, len(value) + 1)]
        return {k: plain(v) for k, v in rows}
    if isinstance(value, float) and (value == float('inf') or value == -float('inf') or value != value):
        return None
    return value


def diffs(a, b, path=''):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return [] if abs(a-b) <= 1e-7*max(1, abs(b)) else [path]
    if type(a) is not type(b):
        return [path]
    if isinstance(a, dict):
        return [p for k in a.keys() | b.keys() for p in diffs(a.get(k), b.get(k), path+'.'+str(k))]
    if isinstance(a, list):
        if len(a) != len(b):
            return [path+'.length']
        return [p for i, (x, y) in enumerate(zip(a, b)) for p in diffs(x, y, path+'.'+str(i+1))]
    return [] if a == b else [path]


lua.globals().read_resource = lambda p: convert(json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8-sig')))
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function()return {Read=function(p)return read_resource(p)end}end")
build = lua.eval("require('drive.VehicleSpec').BuildParts")
fields = ['ok', 'reason', 'partIds', 'dropped', 'boxes', 'hulls', 'sensors', 'wheels', 'hovers', 'legs', 'thrusters', 'weapons', 'bounds', 'motion']
select = lambda v: {k: v[k] for k in fields if k in v}
current_failures, historical, samples = [], [], []
for case in fixture['cases']:
    part = case['part']
    actual = select(plain(build(convert([part]))))
    expected = select(case['spec'])
    changed = diffs(actual, expected)
    if changed:
        current_failures.append({'type': part['type'], 'rot': part['rot'], 'paths': changed})
    old_paths = diffs(select(case['old']), expected)
    if old_paths:
        historical.append({'type': part['type'], 'rot': part['rot'], 'paths': old_paths})
    if part['rot'] == 0:
        samples.append({'type': part['type'], 'rot': 0,
                        'oldHull': case['old']['hulls'][0], 'currentHull': expected['hulls'][0],
                        'oldBounds': case['old']['bounds'], 'currentBounds': expected['bounds']})
mounts = json.loads((ROOT / 'assets/Parts/HoverMounts.json').read_text(encoding='utf-8-sig'))
mount_differences = diffs(mounts, fixture['hoverData'])
assert not current_failures, current_failures[:1]
assert not mount_differences, mount_differences[:1]
assert len(historical) == 120
digest = lambda p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
paths = ['scripts/drive/VehicleSpec.lua', 'scripts/parts/Mounts.lua', 'scripts/parts/PartAssets.lua',
         'assets/Parts/HoverMounts.json', 'assets/Drive/Geometry.json', 'assets/Parts/Catalog.json']
report = {'result': 'PASS', 'sourceCommit': fixture['commit'], 'legacyFixtureCommit': fixture['oldCommit'],
          'sourceHashes': fixture['hashes'], 'inputs': {p: digest(p) for p in paths},
          'legacyFixtureSha256': digest('tools/migration/source-vehicle-fixtures.json'),
          'currentCases': len(fixture['cases']), 'currentFailureCount': len(current_failures),
          'currentFailures': current_failures, 'mountVariants': 10, 'mountDataDifferenceCount': len(mount_differences),
          'legacyCasesDifferentFromCurrentSource': len(historical),
          'legacyTopLevelDifferenceCounts': dict(Counter(p.split('.')[1] for c in historical for p in set(c['paths']))),
          'legacyDifferences': historical, 'examples': samples,
          'conclusion': 'Legacy fixture drift; current Lua hover collision and bounds match frozen b276 source. No production fix or API-binding workaround needed.',
          'boundary': 'Actual frozen buildVehicleSpec and current Lua BuildParts; source geometry contract only, no native collision trajectory or rendered acceptance.',
          'toolSha256': digest('tools/migration/verify-hover-collision.py')}
out = ROOT / 'docs/migration/evidence/hover-collision-current.json'
out.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k not in ['legacyDifferences', 'examples', 'inputs', 'sourceHashes']}, indent=2))
