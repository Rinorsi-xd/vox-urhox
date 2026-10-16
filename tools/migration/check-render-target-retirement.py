"""CPU safety/order and forced-GC regression against actual Lua 5.4."""
import hashlib,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
production='scripts/render/RenderTargetLifetime.lua'
historical=ROOT/'.tmp/outgame-cached-1792098352922'/production
raw=(ROOT/production).read_bytes()
lua.globals().PRODUCTION=raw.decode('utf-8')
lua.globals().HISTORICAL=historical.read_text(encoding='utf-8')
collection='scripts/core/CollectionCycle.lua'
collection_raw=(ROOT/collection).read_bytes()
lua.globals().COLLECTION=collection_raw.decode('utf-8')
def plain(value):
 if hasattr(value,'items'):
  rows=dict(value.items())
  if rows and all(isinstance(key,int)for key in rows):return [plain(rows[key])for key in sorted(rows)]
  return {key:plain(item)for key,item in rows.items()}
 return value
result=plain(lua.execute((ROOT/'tools/migration/check-render-target-retirement.lua').read_text(encoding='utf-8')))
assert (ROOT/production).read_bytes()==raw
assert (ROOT/collection).read_bytes()==collection_raw
baseline=json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
report={'result':'PASS','checks':result['count'],'baseline':baseline['commit'],'productionHashes':{production:hashlib.sha256(raw).hexdigest(),collection:hashlib.sha256(collection_raw).hexdigest()},
 'historical':{'manifest':'manifest-3ba43bd8.json','sha256':hashlib.sha256(historical.read_bytes()).hexdigest()},'cases':result,
 'boundary':'Actual Lupa Lua 5.4 collector and production retirement/CollectionCycle modules, table finalizers model borrowed native RenderSurface parent access. Background collection completes in both incremental and generational initial modes through the shared coordinator. No GPU/native userdata/rendered output verification or measured frame-time speedup. GC step requests are not hard time limits.'}
out=ROOT/'docs/migration/evidence/render-target-retirement-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':report['checks'],'cases':result['modes'],'evidence':str(out)}))
