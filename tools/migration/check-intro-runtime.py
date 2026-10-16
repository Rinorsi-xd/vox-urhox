"""Frozen JS and actual production Lua opening lifecycle, with CPU-only native adapters."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-runtime.mjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(v,runtime=lua):
 if isinstance(v,dict):return runtime.table_from({k:table(x,runtime)for k,x in v.items()})
 if isinstance(v,list):return runtime.table_from([table(x,runtime)for x in v])
 return v
def plain(v):
 if hasattr(v,'items'):
  rows=dict(v.items())
  if rows and all(isinstance(k,int)for k in rows):return [plain(rows[k])for k in sorted(rows)]
  return {k:plain(x)for k,x in rows.items()}
 return v
lua.globals().REFERENCE=table(reference)
data=json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8'))
lua.globals().INTRO_DATA=table(data)
paths=['scripts/app/OpeningHost.lua','scripts/intro/IntroBattle.lua','scripts/intro/IntroMontagePool.lua','scripts/intro/IntroSortieCar.lua','scripts/intro/IntroSession.lua',
       'scripts/app/HangarApp.lua','scripts/app/OpeningRetirement.lua','scripts/app/TrialSession.lua','scripts/drive/TrackWorld.lua','scripts/drive/CraterWorld.lua','scripts/render/CombatView.lua','scripts/intro/IntroWarmup.lua','scripts/core/CollectionCycle.lua']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
fixture=(ROOT/'tools/migration/check-intro-runtime.lua').read_text(encoding='utf-8')
historical=ROOT/'.tmp/outgame-cached-1792097529664/scripts'
negative=[]
for module,path,expected in [('intro.IntroBattle','intro/IntroBattle.lua','source cinematic AI presence 0/true'),('app.OpeningHost','app/OpeningHost.lua','brief establishes teaching multipliers')]:
 old=LuaRuntime(unpack_returned_tuples=True);old.globals().REFERENCE=table(reference,old);old.globals().INTRO_DATA=table(data,old)
 raw=(historical/path).read_bytes();old.globals().HISTORICAL=raw.decode('utf-8')
 old.execute('print=function()end;package.preload["'+module+'"]=function()return assert(load(HISTORICAL))()end')
 try:old.execute(fixture)
 except Exception as error:
  assert expected in str(error),str(error)
  negative.append({'manifest':'manifest-8581d52a.json','file':'scripts/'+path,'sha256':hashlib.sha256(raw).hexdigest(),'observedFailure':str(error).split('\n')[0]})
 else:raise AssertionError('Historical negative control unexpectedly passed: '+module)
lua.execute('print=function()end')
result=plain(lua.execute(fixture))
assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
report={'result':'PASS','checks':result['count'],'cases':result,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':hashes,'sourceCleanup':reference['cleanups'],'historicalNegativeControls':negative,
 'boundary':'Actual frozen sortieCar/endPlay/cinematic beforeStep with controlled spec/native/DOM adapters; actual Lua IntroSortieCar, IntroBattle New/Begin/Start/End/BeforeStep, OpeningHost Shot/Start/End/Dispose, IntroMontagePool activation/disposal. 128 eligibility specs, live/dead targets, normal/skip/cancel/repeat teardown. Native simulation and rendered/audio output are not verified; no GPU run.'}
out=ROOT/'docs/migration/evidence/intro-runtime-offline.json';out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':'PASS','checks':report['checks'],'evidence':str(out)}))
