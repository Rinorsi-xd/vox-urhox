"""Offline infrastructure/semantics checks. No engine/browser/performance measurement."""
import json
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def plain(value):
    if hasattr(value,'items'):
        rows=dict(value.items())
        return [plain(rows[i])for i in range(1,len(rows)+1)]if rows and set(rows)==set(range(1,len(rows)+1))else{k:plain(v)for k,v in rows.items()}
    return value

def run(mode,fail=False,scenario='lanes'):
    lua=LuaRuntime(unpack_returned_tuples=True)
    output=[]
    lua.globals().print=lambda *args:output.append(' '.join(map(str,args)))
    lua.globals().cjson=lua.table_from({'encode':lambda value:json.dumps(plain(value),separators=(',',':'))})
    calls=lua.execute((ROOT/'tools/migration/g1-web-cpu-selftest.lua').read_text(),mode,fail,scenario)
    lua.execute((ROOT/'tools/migration/g1-web-cpu-probe.lua').read_text())
    lua.globals().Start()
    for _ in range(90):lua.globals().G1WebCpuUpdate()
    chunks=[json.loads(line.split('G1_WEB_CPU_CHUNK ',1)[1])for line in output if 'G1_WEB_CPU_CHUNK 'in line]
    assert chunks and len(chunks)==chunks[0]['count']
    assert [x['index']for x in chunks]==list(range(1,len(chunks)+1))
    result=json.loads(''.join(x['data']for x in chunks))
    if fail:
        assert result['status']=='FAIL'and 'controlled fixed step failure'in result['error']
        return {'failureHandled':True}
    assert result['status']=='PASS'and result['totalMs']==420
    assert plain(calls)=={'vehicle':372,'physics':62,'ray':372,'rotors':372}
    assert len(result['snapshots'])==1 and len(result['samplesMs'])==60
    if mode=='timing':assert result['scopes']=={} and result['rayEquivalence']is False
    if mode=='equivalence':assert result['rayEquivalence']['calls']==360
    if mode=='profile':
        rows={x['name']:x for x in result['scopes']}
        assert rows['vehicle.Step']['calls']==360 and rows['physics.Step']['calls']==60
        assert rows['physics.Raycast']['calls']==360
        assert rows['vehicle.Step']['ms']==360 and rows['vehicle.Step']['selfMs']==360
    if scenario=='crater':assert result['map']['bodies']==3 and result['map']['terrainChunks']==1 and result['map']['boulders']==2
    return result

results={mode:run(mode)for mode in ['timing','profile','equivalence']}
assert results['timing']['stateDigest']==results['profile']['stateDigest']
assert results['timing']['randomTail']==results['equivalence']['randomTail']
run('timing',True)
run('profile',False,'crater')
lua=LuaRuntime()
for file in ['g1-web-cpu-probe.lua','g1-web-cpu-damage.lua','g1-web-cpu-selftest.lua']:
    lua.execute('assert(load(...))',(ROOT/'tools/migration'/file).read_text())
digest_lua=LuaRuntime(unpack_returned_tuples=True)
digest_lua.globals().cjson=digest_lua.table()
digest_lua.execute('cjson.null=function() end')
digest_lua.execute((ROOT/'tools/migration/g1-web-cpu-selftest.lua').read_text(),'timing',False)
factory=digest_lua.execute((ROOT/'tools/migration/g1-web-cpu-probe.lua').read_text().split('local function Instrument()',1)[0]+'\nreturn Hash')
h=factory();h.add(digest_lua.globals().cjson.null)
assert len(h.get())==16
assert digest_lua.eval('function(add) return pcall(add,function() end) end')(h.add)[0]is False
damage_lua=LuaRuntime(unpack_returned_tuples=True)
profile_check=damage_lua.execute((ROOT/'tools/migration/g1-web-cpu-damage-selftest.lua').read_text(),(ROOT/'tools/migration/g1-web-cpu-damage.lua').read_text())
assert profile_check['status']=='PASS'and profile_check['scopes']==23
for file in ['g1-web-cpu-prepare.cjs','g1-web-cpu-serve.cjs','g1-web-cpu-run.cjs']:
    subprocess.run(['node','--check',str(ROOT/'tools/migration'/file)],check=True)
subprocess.run(['node',str(ROOT/'tools/migration/g1-web-cpu-selftest.cjs')],check=True)
print(json.dumps({'status':'PASS','modes':list(results),'fixedSteps':60,'vehicles':6,
                  'checks':['one coroutine step per Update','timing no wrappers','profile call counts/return semantics','equivalence ray trace','state/RNG preservation','controlled failure one emission','Lua/JS compilation'],
                  'boundary':'Fake native adapters validate tool plumbing only; no game CPU milliseconds, real Bullet, real damage, browser or FPS acceptance.'}))
