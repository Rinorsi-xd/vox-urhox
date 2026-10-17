"""Verify raw Native trajectories, then actual hitbox/ray Lua across all rotations."""
import hashlib
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
raw = root / '.tmp/perf-leg-f94827b2'
if not raw.exists():
    raw = root / 'docs/migration/evidence/perf-leg-f94827b2'
names = ['baseline-1', 'candidate-1', 'baseline-2', 'candidate-2', 'final-1', 'baseline-3', 'final-2']
results = {name: json.loads((raw / (name + '.json')).read_text('utf8')) for name in names}
base = results['baseline-1']
for name, value in results.items():
    assert value['status'] == 'PASS'
    for key in ('snapshots', 'randomTail', 'metadata'):
        assert value[key] == base[key], (name, key)
    for stage, row in base['stats'].items():
        assert value['stats'][stage]['calls'] == row['calls'], (name, stage)

sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def to_lua(value):
    if isinstance(value, dict):
        return lua.table_from({k: to_lua(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([to_lua(v) for v in value])
    return value

lua.globals().geometry = to_lua(json.loads((root / 'assets/Drive/Geometry.json').read_text('utf8')))
lua.globals().catalog = to_lua(json.loads((root / 'assets/Parts/Catalog.json').read_text('utf8')))
lua.globals().rigs = to_lua({name: json.loads((root / f'assets/Parts/Rigs/{name}.json').read_text('utf8')) for name in ('leg3', 'leg4', 'leg5')})
lua.execute("package.preload['parts.PartAssets']=function() return {Get=function(name) return rigs[name] end} end; package.preload['drive.VehicleSpec']=function() return {GEOMETRY=geometry} end; package.preload['Config']=function() return {CELL=catalog.cell} end")
lua.globals().sourcePath = str(root / 'scripts/?.lua').replace('\\', '/')
lua.execute("package.path=sourcePath..';'..package.path")
lua.globals().before = lua.execute((raw / 'before/LegHitboxes.lua').read_text('utf8'))
lua.globals().after = lua.execute((root / 'scripts/drive/LegHitboxes.lua').read_text('utf8'))
checks = lua.execute(r'''
local V=require 'core.Math3';local Ray=require 'combat.VehicleRay'
local function Equal(a,b)
 if type(a)~='table' then assert(a==b,'scalar mismatch');return end
 assert(type(b)=='table');for k,v in pairs(a) do Equal(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'extra key') end
end
math.randomseed(1016)
local checks=0
for _,kind in ipairs({'leg3','leg4','leg5'}) do for rot=0,23 do
 local leg={type=kind,rot=rot,partId=7,origin={3.5,-1.5,12.25}}
 local function Vehicle()
  return {spec={legs={leg},boxes={},hulls={},sensors={}},wheels={},legStates={},
   body={translation=function()return {x=0,y=0,z=0}end,rotation=function()return {x=0,y=0,z=0,w=1}end}}
 end
 local a,b=Vehicle(),Vehicle();a.legHitboxes=before.New(a);b.legHitboxes=after.New(b)
 for sample=1,24 do
  local toe=rigs[kind].segments.info.origins.toe
  local target={toe[1]+math.random()*3-1.5,toe[2]+math.random()*4-2,math.random()*4-2}
  local blade=math.random()*.8-.4
  a.legStates[7]={target=target,bladeAngle=blade};b.legStates[7]={target=target,bladeAngle=blade}
  a.legHitboxes:Update();b.legHitboxes:Update();Equal(a.legHitboxes.items,b.legHitboxes.items);checks=checks+1
  for _,item in ipairs(a.legHitboxes.items) do for axis=1,3 do
   local d={0,0,0};d[axis]=1;local p=V.Sub(item.center,V.Scale(d,20))
   local ah,bh=Ray.Cast(a,p,d,40),Ray.Cast(b,p,d,40)
   if ah then ah.body=nil end;if bh then bh.body=nil end;Equal(ah,bh);checks=checks+1
  end end
 end
end end
return checks
''')
summary = {
    'status': 'PASS', 'nativeRuns': len(names), 'nativeSnapshotsPerRun': len(base['snapshots']),
    'nativeSnapshotsExact': True, 'nativeRandomTailExact': True, 'nativeCallCountsExact': True,
    'orientationPoseAndRayChecks': checks,
    'checksBoundary': 'Actual production IK, rotation, hitbox, VehicleRay modules and real leg3/4/5 geometry in Lua5.4; loader supplies JSON data. Native runtime covers trajectories separately.',
    'productionSha256': hashlib.sha256((root / 'scripts/drive/LegHitboxes.lua').read_bytes()).hexdigest(),
    'runs': {name: {'wallMs': value['wallMs'], 'hitboxesMs': value['stats']['hitboxes']['ms'], 'boxOnlyMs': value.get('boxOnlyMs'), 'stats': value['stats']} for name, value in results.items()}
}
out = raw / 'verification.json'
out.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf8')
print(json.dumps(summary, indent=2))
