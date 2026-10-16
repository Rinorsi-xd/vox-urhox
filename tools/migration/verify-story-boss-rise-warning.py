"""Compare actual frozen FoxBoss hit/update to Lua, including the next kneel."""
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

source=json.loads(subprocess.check_output(['node','tools/migration/story-boss-rise-warning-source.mjs'],text=True,encoding='utf-8'))
legacy=ROOT/'.tmp/outgame-cached-1792123715225/scripts/story/BossRules.lua'
assert hashlib.sha256(legacy.read_bytes()).hexdigest()=='0e18085ace561ad7bf217c8d45a639fcb1343e76f5cef19811d4d0163261d9fb'
production='scripts/story/BossRules.lua'
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
assert data['boss']==source['config'],'Imported boss constants must equal frozen source'

def runner(code):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(v):
        if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
        if isinstance(v,list):return lua.table_from([table(x) for x in v])
        return v
    lua.globals().BossCode=code
    lua.globals().Config=table(data['boss'])
    run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local Rules=assert(load(BossCode))()
return function(test)
 local rules=Rules.New(Config,150);rules.hpMax=20000;rules.hp=test.hp*20000;rules.phase=3
 rules.state='kneel';rules.t=test.age;rules.time=100;rules.kneels=1;rules.riseWarned=test.warned
 for i,n in ipairs(rules.nodes)do n.pos={20+(i-1)*10,0,0};n.hp=100;n.max=100 end
 for k in pairs(rules.cool)do rules.cool[k]=99 end
 local warnings=0;local frames={}
 for _,op in ipairs(test.ops)do
  local damage=nil
  if op.kind=='step' then rules:Step(op.dt,{pos={0,0,0},target=nil,feet={0,0,0},contacts=0,talking=false})
  else damage=rules:Hit(op.node and {20,0,0} or {0,0,0},op.damage,nil,{0,0,0}) end
  for _,e in ipairs(rules:Drain())do if e.type=='riseWarning' then warnings=warnings+1 end end
  frames[#frames+1]={state=rules.state,t=rules.t,hp=rules.hp,riseWarned=rules.riseWarned==true,warnings=warnings,damage=damage}
 end
 return frames
end
''')
    return lambda test:run(table(test))

current=runner((ROOT/production).read_text(encoding='utf-8-sig'))
old=runner(legacy.read_text(encoding='utf-8-sig'))
checks=1
frames=0
negative=[]
for case in source['cases']:
    actual=current(case['test'])
    before=old(case['test'])
    mismatches=[]
    for index,expected in enumerate(case['expected'],1):
        for key,right in expected.items():
            left=actual[index][key]
            assert left==right or isinstance(left,(float,int)) and not isinstance(left,bool) and isinstance(right,(float,int)) and abs(left-right)<1e-8,(case['test']['name'],index,key,left,right)
            checks+=1
            if before[index][key]!=right and not (isinstance(before[index][key],(float,int)) and not isinstance(before[index][key],bool) and isinstance(right,(float,int)) and abs(before[index][key]-right)<1e-8):
                mismatches.append({'frame':index,'key':key,'before':before[index][key],'expected':right})
        frames+=1
    if mismatches:negative.append({'name':case['test']['name'],'differences':mismatches})
assert negative,'Actual prior frozen production must reproduce the missing reset'
assert any(any(d['key']=='warnings' for d in n['differences']) for n in negative),'Negative control must reproduce a missing later warning'
digest=lambda path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
tools=['tools/migration/story-boss-rise-warning-source.mjs','tools/migration/verify-story-boss-rise-warning.py']
report={'result':'PASS','checks':checks,'cases':len(source['cases']),'frames':frames,'source':source['source'],
 'production':{p:digest(p) for p in [production,'assets/Story/Mission/Level5.json']},'tools':{p:digest(p) for p in tools},
 'negativeControl':{'path':str(legacy.relative_to(ROOT)),'sha256':hashlib.sha256(legacy.read_bytes()).hexdigest(),'cases':negative},
 'boundary':'Actual complete frozen H5 FoxBoss.onHit/update versus actual Lua BossRules.Hit/Step. Source rendering/audio/vehicle APIs are doubles. Covers forced rise after an emitted warning and the next kneel warning, early/natural rise and lethal boundaries. No GPU, browser, audible/visual acceptance, natural S5 win, complete epilogue or performance claim.'}
output=ROOT/'docs/migration/evidence/story-boss-rise-warning-offline.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'cases':len(source['cases']),'frames':frames,'negativeCases':len(negative)}))
