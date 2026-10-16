"""Verify first-event audio preparation against frozen source and real Lua."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
source=json.loads(subprocess.check_output(['node','tools/migration/source-battle-flow-preparation.mjs'],encoding='utf-8'))
data=json.loads((ROOT/'assets/Combat/FlowSounds.json').read_text(encoding='utf-8'))
flow=(ROOT/'scripts/audio/BattleFlow.lua').read_text(encoding='utf-8')
loading=(ROOT/'scripts/app/LoadingFlow.lua').read_text(encoding='utf-8')
fixture=(ROOT/'tools/migration/check-battle-flow-preparation.lua').read_text(encoding='utf-8')
def run(text,host):
 lua=LuaRuntime(unpack_returned_tuples=True)
 def table(v):
  if isinstance(v,dict):return lua.table_from({k:table(x)for k,x in v.items()})
  if isinstance(v,list):return lua.table_from([table(x)for x in v])
  return v
 lua.globals().SOURCE=table(source);lua.globals().DATA=table(data)
 lua.globals().FLOW_SOURCE=text;lua.globals().LOADING_SOURCE=host
 return dict(lua.execute(fixture).items())
result=run(flow,loading)
old=ROOT/'.tmp/outgame-cached-1792129688087/scripts'
negative=[]
for name,text,host,expected in [
 ('41f-runtime-decode',(old/'audio/BattleFlow.lua').read_text(encoding='utf-8'),loading,'no synchronous Sound decode in event/update'),
 ('41f-swallowed-found',flow,(old/'app/LoadingFlow.lua').read_text(encoding='utf-8'),'unprepared found event is not swallowed'),
]:
 try:run(text,host)
 except Exception as error:
  assert expected in str(error),str(error)
  negative.append({'name':name,'failure':str(error).split('\n')[0]})
 else:raise AssertionError('Old production unexpectedly passed: '+name)
mutations=[]
for name,text,host,expected in [
 ('skip-preparation',flow.replace('    self:PreparePending()','    -- skipped'),loading,'decode timeout becomes explicit failure'),
 ('radio-timing',flow.replace('self.time+.38','self.time+.1'),loading,'original radio delay preserved'),
 ('runtime-sync',flow.replace('local sound=self.sounds[cue.path];if not sound then return false end',"local sound=cache:GetResource('Sound',cue.path);if not sound then return false end"),loading,'no synchronous Sound decode in event/update'),
 ('found-timing',flow,loading.replace('match.age>=1.1','match.age>=.1'),'original found presentation still visible'),
]:
 try:run(text,host)
 except Exception as error:
  assert expected in str(error),str(error)
  mutations.append({'name':name,'failure':str(error).split('\n')[0]})
 else:raise AssertionError('Mutation unexpectedly passed: '+name)
paths=['scripts/audio/BattleFlow.lua','scripts/app/LoadingFlow.lua','scripts/combat/BattleController.lua',
 'scripts/app/ResourceGate.lua','scripts/audio/AudioLevels.lua','assets/Combat/FlowSounds.json',
 'tools/migration/check-battle-flow-preparation.lua','tools/migration/verify-battle-flow-preparation.py',
 'tools/migration/source-battle-flow-preparation.mjs']
controller=(ROOT/'scripts/combat/BattleController.lua').read_text(encoding='utf-8')
assert 'self.sounds:Prepare(false,function() if checkpoint then checkpoint(0) end end)'in controller
report={**result,'negativeControls':negative,'mutations':mutations,'sourceCommit':source['sourceCommit'],'sourceHashes':source['hashes'],
 'inputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'boundary':'Actual frozen JS battleFlowMix event/countdown and lobbyAudio timer execute with source SHA checks; actual Lua BattleFlow, ResourceGate and LoadingFlow execute with cache/scene/audio adapters. Resident, raw cached, delayed callback, bounded preparation, complete original closure, actual event/no-cache playback, 380ms radio/1100ms found, cancellation and checkpoint readiness. No native audible output, decode duration, Web FPS or mobile acceptance.'}
(ROOT/'docs/migration/evidence/battle-flow-preparation-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':report['checks'],'negative':len(negative),'mutations':len(mutations)}))
