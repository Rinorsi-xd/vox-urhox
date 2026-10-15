"""Exercise actual Lua prefab assembly and new-car physical specs without native APIs."""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
null = lua.table()

def convert(value):
    if value is None:
        return null
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

def read_resource(name):
    return convert(json.loads((root / 'assets' / name).read_text(encoding='utf-8-sig')))

lua.globals().read_resource = read_resource
lua.globals().cjson = lua.table(null=null)
lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path; package.preload['core.ResourceData']=function() return {Read=function(path) return read_resource(path) end} end")
results = lua.execute("""
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Defs=require 'parts.Defs'
local Spec=require 'drive.VehicleSpec'
local result={}
local n=0
for id,key in pairs(Prefab.keys) do
  local bp=Prefab.Create(BP.New(),id)
  local expected=Defs.DATA.presets[key]
  assert(bp:Size()==#expected.parts,'Full part count '..id)
  for i,p in ipairs(bp:List()) do
    local q=expected.parts[i]
    assert(p.type==q.type and p.rot==(q.rot or require('core.Rotations').IDENTITY) and p.color==(q.color or Defs.PARTS[q.type].color),'Original part fields '..id..':'..i)
    assert(p.pos[1]==q.pos[1] and p.pos[2]==q.pos[2] and p.pos[3]==q.pos[3],'Original position '..id..':'..i)
  end
  n=n+1
end
assert(n==19,'Nineteen registered presets')
for _,id in ipairs({'manta','rat','roach','fox'}) do
  local bp=Prefab.Create(BP.New(),id)
  local spec=Spec.Build(bp)
  assert(spec.ok,'Valid source prefab '..id..': '..tostring(spec.reason))
  assert(#spec.partIds==bp:Size(),'No dropped parts '..id)
  result[#result+1]={id=id,parts=bp:Size(),weapons=#spec.weapons,wheels=#spec.wheels,hovers=#spec.hovers,legs=#spec.legs,mechLegs=#spec.mechLegs,boxes=#spec.boxes}
end
return result
""")
report = {
    'result': 'PASS',
    'sourceCommit': 'b276064942ae09c0227ec28d4cfda1d5ff006455',
    'runtime': lua.lua_implementation,
    'presetsExact': 19,
    'vehicles': [{key: value for key, value in results[i].items()} for i in range(1, len(results) + 1)],
    'sources': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in [
        'scripts/construction/Prefab.lua', 'scripts/construction/Blueprint.lua',
        'scripts/drive/VehicleSpec.lua', 'assets/Parts/Catalog.json']},
    'boundary': 'Actual production Lua assembly and physical-spec calculation. Resource reads bridge actual JSON. No rendered model, native/Web gameplay, weapon firing, pointer or performance acceptance.',
}
out = root / 'docs/migration/evidence' / ('baseline-cars-lua-' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ'))
out.mkdir(parents=True)
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'evidence': str(out), **report}, indent=2))
