"""Execute the actual isolated QA builder with real Blueprint/VehicleSpec modules."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value


def read_resource(name):
    return table(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8')))


lua.globals().ReadQaResource = read_resource
lua.execute("""
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=ReadQaResource}
package.loaded['urhox-libs/UI']={}
cjson={null={}}
KEY_F7=7;KEY_F6=6;KEY_F9=9
input={GetKeyPress=function(_,key)return key==KEY_F7 end}
HandleUpdate=function()end;HandlePostUpdate=function()end
""")
source = (ROOT / 'tools/migration/scope-fx-isolated-observer.lua').read_text(encoding='utf-8')
result = lua.execute("""
local entered=false
local app={mode='hangar',loadingFlow={active=false},EnterTrial=function(self,map)
 assert(map=='trial');entered=true;return true
end}
""" + source + """
HandleUpdate()
assert(entered,'Actual QA builder called the real-trial entry adapter')
local spec=require('drive.VehicleSpec').Build(app.blueprint)
assert(spec.ok and spec.dropped==0 and #spec.weapons==4)
local types={};for _,w in ipairs(spec.weapons)do types[#types+1]=w.type end
return {parts=app.blueprint:Size(),dropped=spec.dropped,types=types,
 bounds={spec.bounds.min[1],spec.bounds.min[2],spec.bounds.min[3],spec.bounds.max[1],spec.bounds.max[2],spec.bounds.max[3]}}
""")
out = {'status': 'PASS', 'parts': result.parts, 'dropped': result.dropped,
       'types': [result.types[i] for i in range(1, 5)],
       'bounds': [result.bounds[i] for i in range(1, 7)],
       'boundary': 'Actual production Blueprint/VehicleSpec and actual QA Build execute with JSON resources; only App entry/input/UI adapted. No hardware or render claim.'}
assert out['parts'] == 35
assert out['types'] == ['mg5', 'laser5', 'sniper5', 'missile5']
print(json.dumps(out))
