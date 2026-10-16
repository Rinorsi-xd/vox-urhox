"""Execute frozen JS finish and actual Lua session/host exit lifecycle without GPU."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-finish.mjs'],encoding='utf-8'))
paths=['scripts/intro/IntroSession.lua','scripts/app/OpeningHost.lua','scripts/app/OpeningRetirement.lua','scripts/audio/IntroAudio.lua','scripts/audio/IntroAudioTail.lua']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
 if isinstance(value,dict):return lua.table_from({key:table(item)for key,item in value.items()})
 if isinstance(value,list):return lua.table_from([table(item)for item in value])
 return value
lua.globals().REFERENCE=table(reference)
result=lua.execute((ROOT/'tools/migration/check-intro-finish.lua').read_text(encoding='utf-8'))
assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
report={'result':'PASS','checks':result['count'],'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':hashes,'source':reference,'cases':[result['checks'][i]for i in range(1,result['count']+1)],
 'boundary':'Executed frozen JavaScript _finish/_skipNow and actual Lua IntroSession/OpeningHost/OpeningRetirement/IntroAudio/IntroAudioTail with controlled native/UI adapters. Covers 699/701 ms visual handoff and clamped-dt versus wall-clock divergence, 1.2 second gain zero and 1.4 second audio release, focus loss with absolute release deadline, independent tail reachability, duplicate completion, partial/post-handoff cancellation/Stop/replacement, deferred native retirement and tutorial ownership. No page alpha rendering, GPU, audible output, browser frame-time or native userdata acceptance.'}
out=ROOT/'docs/migration/evidence/intro-finish-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':report['checks'],'evidence':str(out)}))
