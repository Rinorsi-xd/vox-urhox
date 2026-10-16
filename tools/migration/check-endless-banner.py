"""Executed frozen H5 event/clock goldens against production Lua and mounted HUD."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node','tools/migration/check-endless-banner-source.cjs'],check=True)
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value,dict): return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([table(v) for v in value])
    return value
source=json.loads((root/'.tmp/source-endless-banner-fixtures.json').read_text(encoding='utf-8'))
lua.globals().goldens=table(source)
paths=['scripts/ui/EndlessBanner.lua','scripts/ui/EndlessHud.lua','scripts/app/EndlessSession.lua','scripts/endless/Run.lua']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
checks=list(lua.execute((root/'tools/migration/check-endless-banner.lua').read_text(encoding='utf-8')).values())
assert hashes=={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},'Production drift'
report={'result':'PASS','checks':checks,'sourceCommit':source['sourceCommit'],'sourceHashes':source['hashes'],
        'productionHashes':hashes,'sourceBatches':len(source['batches']),'clockSteps':len(source['clock']),
        'boundary':'Actual frozen H5 EndlessSession.events, EndlessHud.announce/update and original configs. Actual Lua Events/Banner/Run.CheckClear/mounted EndlessHud state.Update; native/UI/physics/audio/dependencies are doubles. No GPU/browser/rendered/account/performance acceptance. Not in d966b4f2.'}
out=root/'docs/migration/evidence/endless-banner-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':len(checks),'sourceBatches':len(source['batches']),'clockSteps':len(source['clock']),'evidence':str(out)}))
