"""Offline observer restoration checks, not actual Native or timing evidence."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

fixture = ROOT / '.tmp/ray-static-shadow-4a3a-1017-a'
identity = json.loads((fixture / 'identity.json').read_text())
for relative, digest in identity['sourceHashes'].items():
    assert hashlib.sha256((fixture / relative).read_bytes()).hexdigest() == digest
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='.tmp/ray-static-shadow-4a3a-1017-a/scripts/?.lua;scripts/?.lua;'..package.path")
lua.execute("assert(loadfile('.tmp/ray-static-shadow-4a3a-1017-a/scripts/ray-static-query-capture.lua'))")
result = lua.execute(r'''
local base=require('combat.VehicleRay');local candidate=require('ray-static-candidate')
local factory=require('ray-static-shadow');local original=base.Cast
local private={unchanged=true}
local v={spec={boxes={{center={0,0,0},half={1,1,1},partId=1}},hulls={},sensors={}},
 rotors={},wheels={},body={translation=function()return{x=0,y=0,z=0}end,
 rotation=function()return{x=0,y=0,z=0,w=1}end},rayStaticBounds=private}
local observer=factory.New(candidate);observer:Install(base)
for i=1,16 do
 if i%2==1 then v.rayBounds=nil end
 local hit=base.Cast(v,{0,0,-5},{0,0,1},20)
 assert(hit and hit.dist==4 and hit.partId==1 and v.rayStaticBounds==private)
end
observer:Restore();assert(base.Cast==original)
local r=observer:Report();assert(r.queries==16 and r.cold==8 and r.warm==8 and r.hits==16)
local failing=factory.New({Cast=function(vehicle)vehicle.rayBounds={bad=true};vehicle.rayStaticBounds={bad=true};error('intentional shadow fail')end})
failing:Install(base);v.rayBounds=nil
local ok,err=pcall(base.Cast,v,{0,0,-5},{0,0,1},20)
assert(not ok and tostring(err):find('intentional shadow fail',1,true))
assert(v.rayBounds.center and not v.rayBounds.bad and v.rayStaticBounds==private)
failing:Restore();assert(base.Cast==original and collectgarbage('isrunning'))
return {queries=r.queries,cold=r.cold,warm=r.warm,errorUnwind=true,originalCastRestored=true,normalGC=true}
''')
record = {'status': 'OFFLINE_SHADOW_OBSERVER_PASS', 'synthetic': True, **dict(result)}
output = ROOT / 'docs/migration/evidence/ray-static-shadow-offline-1017-a.json'
assert not output.exists()
output.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
