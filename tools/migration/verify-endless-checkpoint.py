"""Actual session persistence and event chains, with the frozen old package as a negative control."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=json.loads(subprocess.check_output(['node','tools/migration/endless-checkpoint-source.cjs','--stdout'],text=True,encoding='utf-8'))
paths=['scripts/app/EndlessSession.lua','scripts/endless/Run.lua']
hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths}
fixture=(root/'tools/migration/check-endless-checkpoint.lua').read_text(encoding='utf-8')

def execute(session,only_flow=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict): return lua.table_from({k:table(v) for k,v in value.items()})
        if isinstance(value,list): return lua.table_from([table(v) for v in value])
        return value
    lua.globals().goldens=table(source)
    lua.globals().sessionSource=session
    lua.globals().onlyFlow=only_flow
    return list(lua.execute(fixture).values())

checks=execute((root/paths[0]).read_text(encoding='utf-8'))
old=root/'.tmp/outgame-cached-1792125241918/scripts/app/EndlessSession.lua'
negative={'path':str(old.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'cases':[]}
for flow in [None,'clear','supply','edit-return']:
    try:
        execute(old.read_text(encoding='utf-8'),flow)
    except Exception as error:
        negative['cases'].append({'flow':flow or 'source-goldens','rejected':True,'reason':str(error).splitlines()[0]})
    else:
        raise AssertionError('Old actual package must fail missing-warning check: '+str(flow))
assert hashes=={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths},'Production drift'
tool_paths=['tools/migration/endless-checkpoint-source.cjs','tools/migration/check-endless-checkpoint.lua','tools/migration/verify-endless-checkpoint.py']
report={'result':'PASS','checks':checks,'sourceCommit':source['commit'],'sourceHashes':source['sourceHashes'],
        'sourceCases':len(source['cases']),'productionHashes':hashes,'testInputs':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in tool_paths},
        'negativeControl':negative,'boundary':'Actual frozen JS persist and actual Lua CheckClear/ChooseSupply/ResumeEdit -> Events/Persist. Storage/native/physics/audio/UI edges are controlled adapters. No GPU, natural full-wave battle, successful natural extraction, actual account, visual or performance acceptance.'}
out=root/'docs/migration/evidence/endless-checkpoint-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':len(checks),'sourceCases':len(source['cases']),'negativeControl':negative,'productionHashes':hashes}))
