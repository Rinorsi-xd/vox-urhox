from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
source=json.loads(subprocess.check_output(['node','tools/migration/story-hold-rules-source.cjs'],cwd=ROOT))
authored=json.loads((ROOT/'assets/Story/Mission/Level3.json').read_text(encoding='utf-8-sig'))
step=next(s for s in authored['level']['steps'] if s['kind']=='hold')
for key in ['pos','healR','drainR','drain','heal','duration','delay']:
 assert step[key]==source['step'][key],('authored source drift',key)
assert [(b['t'],b['spawn']) for b in step['beats'] if 'spawn' in b]==[(b['t'],b['spawn']) for b in source['step']['beats'] if 'spawn' in b]
lua=LuaRuntime(unpack_returned_tuples=True)
module=lua.execute((ROOT/'scripts/story/HoldRules.lua').read_text(encoding='utf-8-sig'))
def convert(value):
 if isinstance(value,dict):return lua.table_from({k:convert(v) for k,v in value.items()})
 if isinstance(value,list):return lua.table_from([convert(v) for v in value])
 return value
checks=0
def verify(mod):
 count=0;current=None;rules=None;hold=None
 for row in source['trace']:
  if row['name']!=current:
   current=row['name'];hold=mod.New(convert(step))
   rules=lua.execute("return {progress=0,stats={},events={},Emit=function(self,k,p) self.events[#self.events+1]={k,p} end,Fail=function(self,title)self.events[#self.events+1]={'fail',title}end}")
  inp=row['input'];rules.stepT=inp['stepT'];rules.events=lua.table()
  enemies=[e['pos'] for e in inp['enemies'] if e['alive']]
  done=hold.Update(hold,rules,inp['dt'],convert({'alive':inp['alive'],'pos':inp['pos'],'enemyPositions':enemies}))
  expected=row['expected']
  for key in ['left','energy','healT']:
   assert abs(hold[key]-expected[key])<1e-8,(current,key,hold[key],expected[key]);count+=1
  assert abs(rules.progress-expected['progress'])<1e-8;count+=1
  assert rules.retitle==expected['retitle'];count+=1
  assert done==expected['done'];count+=1
  actual=[]
  for i in range(1,len(rules.events)+1):
   event=rules.events[i];kind=event[1];payload=event[2]
   actual.append([kind,payload if kind=='fail' else payload['fraction' if kind=='heal' else 'count']])
  assert len(actual)==len(expected['events']),(current,actual,expected['events']);count+=1
  for a,b in zip(actual,expected['events']):
   assert a[0]==b[0]
   assert abs(a[1]-b[1])<1e-8 if isinstance(a[1],(int,float)) else a[1]==b[1];count+=1
  assert rules.stats.shield==expected['shield'];count+=1
 return count
checks=verify(module)
negative=[]
text=(ROOT/'scripts/story/HoldRules.lua').read_text(encoding='utf-8-sig')
for label,before,after in [('halve drain','near*s.drain*dt','near*s.drain*dt*.5'),('include boundary','Flat(p,s.pos)<s.drainR','Flat(p,s.pos)<=s.drainR'),('heal dead player','world.alive and Flat','true and Flat')]:
 assert before in text
 try:verify(lua.execute(text.replace(before,after)))
 except AssertionError:negative.append(label)
 else:raise AssertionError('Undetected mutation: '+label)
report={'result':'PASS','checks':checks,'frames':len(source['trace']),'negativeControls':negative,'sourceDefaultTargetFollowsPlayer':source['sourceDefaultTargetFollowsPlayer'],'baseline':source['baseline'],'sourceHashes':source['hashes'],'productionSha256':hashlib.sha256((ROOT/'scripts/story/HoldRules.lua').read_bytes()).hexdigest(),'levelSha256':hashlib.sha256((ROOT/'assets/Story/Mission/Level3.json').read_bytes()).hexdigest(),'boundary':'Actual frozen H5 hold and target functions versus real Lua HoldRules and actual authored Level3 data under controlled CPU worlds. Source scalar rules and five spawn lists match. No natural completion, AI/weapon/physics parity, browser, FPS or device acceptance.'}
(ROOT/'docs/migration/evidence/story-hold-rules-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
