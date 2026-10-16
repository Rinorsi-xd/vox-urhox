"""Compare actual frozen async acts with actual production Lua coroutine scheduling."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
ref=json.loads(subprocess.check_output(['node','tools/migration/source-intro-timing.mjs'],encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def table(v):
 if isinstance(v,dict):return lua.table_from({k:table(x)for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([table(x)for x in v])
 return v
lua.globals().TIMING_DATA=table(json.loads((ROOT/'assets/Intro/Intro.json').read_text(encoding='utf-8')))
run=lua.execute((ROOT/'tools/migration/check-intro-timing.lua').read_text())
checks=0;failures=[];cases=[]
def compare_cues(label,expected,found,start=0):
 global checks
 expected=[e for e in expected if e['type']=='sfx']
 checks+=1
 if len(expected)!=len(found):failures.append({'event':label+' count','expected':len(expected),'actual':len(found)});return
 for a,b in zip(found,expected):
  checks+=1
  opt=a['opt'];want=b.get('opt',{})
  if a['id']!=b['id']or abs(a['t']-start-b['t'])>.035 or any((opt[k]if opt is not None and opt[k]is not None else 1 if k in ['vol','rate']else None)!=v for k,v in want.items()):
   failures.append({'event':label+' cue','expected':b,'actualId':a['id'],'actualAge':a['t']-start})
for c in ref['cases']:
 result=run(c['held'],c['n06'],c['n10'],None)
 shots={s['id']:s['t']for _,s in result['shots'].items()}
 if not cases:
  for label,begin,end in [('actNo','no','sortie-brief'),('sortieBrief','sortie-brief','familiar')]:
   compare_cues(label,ref['acts'][label]['events'],[e for _,e in result['sounds'].items()if e['shot']in (['no']if label=='actNo'else ['sortie-brief','sortie-countdown'])and e['id']not in ['stopMusic','bgm_metal_a','stopAlarm']],shots[begin])
  source_start=next(e['t']for e in c['events']if e['type']=='shot'and e['id']=='familiar')
  source_end=next(e['t']for e in c['events']if e['type']=='shot'and e['id']=='galaxy')
  compare_cues('familiar',[dict(e,t=e['t']-source_start)for e in c['events']if source_start<=e['t']<source_end],[e for _,e in result['sounds'].items()if e['shot']=='familiar'],shots['familiar'])
  music=next(e for _,e in result['sounds'].items()if e['id']=='bgm_metal_a')
  expected_music=next(e for e in ref['acts']['sortieBrief']['events']if e['type']=='music')
  checks+=1
  if any(music['opt'][k]!=v for k,v in expected_music['opt'].items()):failures.append({'event':'sortie music parameters'})
  alarm_stop=next(e for _,e in result['sounds'].items()if e['id']=='stopAlarm')
  checks+=1
  if abs(alarm_stop['t']-shots['decide'])>.01 or alarm_stop['fade']!=.6:failures.append({'event':'sortie alarm fade'})
 actual={'decideDuration':shots['decided']-shots['decide'],'missileDuration':shots['m-salvage']-shots['m-missile']}
 src_payslip=next(e['t']for e in c['events']if e['type']=='shot'and e['id']=='payslip')
 src_decide=next(e['t']for e in c['events']if e['type']=='shot'and e['id']=='decide')
 for cue in ['stamp','laser_big','shred']:
  expected=next(e for e in c['events']if e['type']=='sfx'and e['id']==cue and src_payslip<=e['t']<src_decide)
  found=next((s for _,s in result['sounds'].items()if s['id']==cue and shots['payslip']<=s['t']<shots['decide']),None)
  checks+=1
  if found is None or abs((found['t']-shots['payslip'])-(expected['t']-src_payslip))>.025:
   failures.append({'event':'payslip '+cue,'expectedAge':expected['t']-src_payslip,'actualAge':found['t']-shots['payslip']if found else None})
  elif any(found['opt'][key]!=value for key,value in expected['opt'].items()):failures.append({'event':'payslip cue parameters','cue':cue})
 for key,value in actual.items():
  checks+=1
  if abs(value-c[key])>.025:failures.append({'held':c['held'],'n06':c['n06'],'n10':c['n10'],'event':key,'actual':value,'expected':c[key]})
 for shot,nextshot in [('galaxy','payslip'),('payslip','decide')]:
  start=next(e['t']for e in c['events']if e['type']=='shot'and e['id']==shot)
  stop=next(e['t']for e in c['events']if e['type']=='shot'and e['id']==nextshot)
  expected=[e for e in c['events']if e['type']=='sfx'and e['id']=='blip'and start<=e['t']<stop]
  found=[e for _,e in result['sounds'].items()if e['id']=='blip'and shots[shot]<=e['t']<shots[nextshot]]
  checks+=1
  if len(found)!=len(expected):failures.append({'event':shot+' blip count','actual':len(found),'expected':len(expected)})
  else:
   for a,b in zip(found,expected):
    checks+=1
    if abs((a['t']-shots[shot])-(b['t']-start))>.025 or abs(a['opt']['rate']-b['opt']['rate'])>.02 or a['opt']['vol']!=b['opt']['vol']:
     failures.append({'event':shot+' blip time/parameters'});break
 # Compare every following narration start against the source rear sequence.
 source_start=next(e['t']for e in c['events']if e['type']=='shot'and e['id']=='familiar')
 for expected in [e for e in c['events']if e['type']=='voice']:
  found=next(e for _,e in result['voices'].items()if e['id']==expected['id'])
  checks+=1
  if abs((found['t']-shots['familiar'])-(expected['t']-source_start))>.075:
   failures.append({'event':'voice '+expected['id'],'actual':found['t']-shots['familiar'],'expected':expected['t']-source_start})
 for expected in [e for e in c['events']if e['type']=='captionOverride']:
  found=next(e for _,e in result['voices'].items()if e['id']=='vo_'+expected['id'])
  checks+=1
  if found['caption']!=expected['text']:
   failures.append({'event':'caption override '+expected['id'],'actual':found['caption'],'expected':expected['text']})
 # After the camera task ends, a long narration waits without continuing fire.
 for _,f in result['firing'].items():
  if f['age']>5.22:
   checks+=1
   if f['on']:failures.append({'event':'firing after source task','age':f['age']});break
 cases.append({k:c[k]for k in ['held','n06','n10']}|actual)
for shot in ['decide','m-missile']:
 r=run(True,8,7,shot);checks+=1
 assert r['skipped']and not any(s['id']==('decided' if shot=='decide'else 'm-salvage')for _,s in r['shots'].items()),'skip must cancel pending beat'
for part in ['gate','contract']:
 r=run(True,5.04,4.13,None,part);shots={s['id']:s['t']for _,s in r['shots'].items()}
 compare_cues('gate '+part,ref['acts']['actGate']['events'],[e for _,e in r['sounds'].items()if e['t']>=shots['gate']and e['id']not in ['stopMusic','stopAlarm']],shots['gate'])
 if part=='contract':
  compare_cues('contract',ref['acts']['actContract']['events'],[e for _,e in r['sounds'].items()if shots['contract']<=e['t']<shots['gate']and e['id']not in ['stopMusic','stopAlarm','bgm_jazz_a']],shots['contract'])
  fade=next(e for _,e in r['sounds'].items()if e['id']=='stopAlarm');checks+=1
  if fade['fade']!=1.5 or abs(fade['t']-shots['contract'])>.01:failures.append({'event':'contract alarm fade'})
for shot in ['sortie-brief','sortie-countdown','decide','m-missile']:
 r=run(True,8,7,shot,'full');shots={s['id']:s['t']for _,s in r['shots'].items()}
 stops=[s for _,s in r['sounds'].items()if s['id']=='stopAlarm'];checks+=1
 expected=.6 if shot in ['decide','m-missile']else .2
 if not stops or stops[0]['fade']!=expected:failures.append({'event':'skip alarm '+shot})
report={'result':'FAIL'if failures else'PASS','checks':checks,'cases':cases,'failures':failures,'baseline':ref['baseline'],
 'sourceCaptionOverrides':[e for e in ref['cases'][0]['events']if e['type']=='captionOverride'],
 'sourceHashes':ref['sourceHashes'],'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in ['scripts/intro/IntroSession.lua']},
 'boundary':'Actual frozen Intro familiar/galaxy/payslip/decide/montage/recruit/NO, IntroStory contract/gate, playSortie reachable brief through countdown, and real wipe helper; actual production Lua IntroSession.Ad/Run/Update. Explicit source Say text overrides are captured from real calls and compared to actual Lua caption at Voice. DOM/audio/physics/input adapters, awaited animations and setTimeout execute virtual timing. 240Hz held/unattended, short/long voice and skip. Contract signature auto-submits; v12 dialogue isolated. Sortie gameplay remains outside this schedule fixture. No audio listening, rendered layers, Web physics, continuity or mobile acceptance.'}
out=ROOT/'docs/migration/evidence/intro-timing-offline.json'
if '--before'in sys.argv:out=out.with_name('intro-timing-offline-before.json')
out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
assert not failures,'Opening differs from source schedule'
