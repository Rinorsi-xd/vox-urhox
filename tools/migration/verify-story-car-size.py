"""Run frozen H5 carSize/near and actual Lua CarSize/Near across view lifecycles."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=json.loads(subprocess.check_output(['node','tools/migration/story-car-size-source.mjs'],text=True,encoding='utf-8'))
catalog=json.loads((ROOT/'assets/Parts/Catalog.json').read_text(encoding='utf-8-sig'))
assert catalog['cell']==source['cell'], 'Production blueprint cell must match frozen H5 metres'
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value,dict):return lua.table_from({k:convert(v)for k,v in value.items()if v is not None})
    if isinstance(value,list):return lua.table_from([convert(v)for v in value])
    return value
old_path=ROOT/'.tmp/outgame-cached-1792122576512/scripts/story/Mission.lua'
old=old_path.read_bytes()
assert hashlib.sha256(old).hexdigest()=='cefa9c78ac98989a6ebbcb2139ce2a17edce61a362d9028faf876df6b5008cc1', 'Immutable 45f control drift'
lua.globals().SOURCE=convert(source)
lua.globals().OLD_MISSION=old.decode('utf-8-sig')
result=dict(lua.execute((ROOT/'tools/migration/check-story-car-size.lua').read_text(encoding='utf-8')))
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
result.update(source=source['source'],oldProduction={'path':str(old_path),'sha256':hashlib.sha256(old).hexdigest()},
              production={p:sha(p)for p in ['scripts/story/Mission.lua','scripts/story/MissionRules.lua','scripts/Config.lua','assets/Parts/Catalog.json']},
              testInputs={p:sha(p)for p in ['tools/migration/verify-story-car-size.py','tools/migration/check-story-car-size.lua','tools/migration/story-car-size-source.mjs']},
              boundary='Next candidate, not manifest-45f10158. Executes real frozen H5 carSize/near and real Lua CarSize/Near with external bounds doubles. No native model measurement, GPU, natural S2-S5, mobile or performance acceptance.')
output=ROOT/'docs/migration/evidence/story-car-size-offline.json'
output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
