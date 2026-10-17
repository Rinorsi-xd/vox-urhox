"""Execute source stash+hub failures and production Lobby+Page consumers."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node','tools/migration/check-salvage-trade-failures-source.cjs'],check=True)
fixtures=json.loads((root/'.tmp/source-salvage-trade-failures.json').read_text(encoding='utf-8'))
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

paths=['scripts/app/SalvageLobby.lua','scripts/ui/SalvagePage.lua','scripts/salvage/StashRules.lua']
hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths}
code=(root/paths[0]).read_text(encoding='utf-8')

def execute(mutation=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict): return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list): return lua.table_from([table(x) for x in v])
        return v
    lua.globals().fixtures=table(fixtures)
    lua.globals().resources=table({name:json.loads((root/'assets'/name).read_text(encoding='utf-8')) for name in ['UI/Outgame.json','UI/SalvageRules.json']})
    if mutation:
        before,after=mutation
        assert before in code
        lua.globals().mutantCode=code.replace(before,after,1)
    return lua,lua.execute((root/'tools/migration/check-salvage-trade-failures.lua').read_text(encoding='utf-8'))

lua,checks=execute()
negatives=[]
for name,mutation in [
    ('old generic stock failure', ("'装在车上的不能卖，先从车上拆下来' or '库存不够'", "'库存不足' or '库存不足'")),
    ('old generic credit failure', ("'信用点不够（还差 '..missing..'）'", "'信用点不足'")),
    ('incorrect shortage ignores quantity', ('price*qty-self.data.credits', 'price-self.data.credits')),
]:
    try: execute(mutation)
    except Exception as error:
        assert 'source business failure' in str(error),str(error)
        negatives.append({'name':name,'result':'REJECTED','failure':str(error).splitlines()[0]})
    else: raise AssertionError('Negative control passed: '+name)
assert hashes=={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths}
report={'result':'PASS','sourceCommit':fixtures['commit'],'sourceHashes':fixtures['sourceHashes'],
        'productionHashes':hashes,'cases':len(fixtures['cases']),'runtime':lua.lua_implementation,
        'checks':[checks[i] for i in range(1,len(checks)+1)],'negativeControls':negatives,
        'boundary':'Real frozen SalvageStash.buy/sell and SalvageHub._trade versus actual Lobby.Trade and Page.Trade. Item data, capacity, installed usage, stock, credit shortage and callback effects are real; page rendering and storage/native dependencies excluded with strict adapters. No Web UI, accounts, visual or performance acceptance.'}
out=root/'docs/migration/evidence/salvage-trade-failures-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','cases':len(fixtures['cases']),'checks':len(checks),'negativeControls':len(negatives),'evidence':str(out)}))
