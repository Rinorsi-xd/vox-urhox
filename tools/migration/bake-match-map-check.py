import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
import os
os.chdir(root)
result=LuaRuntime(unpack_returned_tuples=True).execute((root/'tools/migration/bake-match-map-check.lua').read_text(encoding='utf-8'))
report={'result':'PASSED','assertions':result['assertions'],'productionSha256':hashlib.sha256((root/'scripts/render/MatchMapShot.lua').read_bytes()).hexdigest(),'resourceGateSha256':hashlib.sha256((root/'scripts/app/ResourceGate.lua').read_bytes()).hexdigest(),'scope':'Actual Lua ResourceGate modern/legacy/cached/synchronous/throw paths; optional baked validation/fallback; exact 10 second cancellation; late callbacks; Process upload/filter failure release and transferred ownership. No renderer, Web or performance claim.'}
(root/'docs/migration/evidence/match-map-bake-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
