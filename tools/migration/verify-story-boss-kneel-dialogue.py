"""Compare actual complete frozen Boss._kneel/talk with production rule events."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-kneel-dialogue-source.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
def to_lua(value):
    if isinstance(value,dict):return lua.table_from({k:to_lua(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([to_lua(v) for v in value])
    return value
def python(value):
    if hasattr(value,'items'):
        items=dict(value)
        if not items:return []
        if all(isinstance(k,int) for k in items):return [python(items[k]) for k in range(1,len(items)+1)]
        return {k:python(v) for k,v in items.items()}
    return value

old=ROOT/'.tmp/outgame-cached-1792084158158/scripts/combat/StoryBoss.lua'
lua.globals().LegacyBossCode=old.read_text(encoding='utf-8-sig')
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
lua.globals().BossData=to_lua(data)
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules';local Legacy=assert(load(LegacyBossCode))()
return function(test,legacy)
 local calls={};local draws=0;local talking=false
 local voice={Talking=function()return talking end,Say=function(_,lines,urgent,append)
  calls[#calls+1]={lines=lines,urgent=urgent,append=append}
 end}
 local rules=Rules.New(BossData.boss,150);rules.kneels=test.initialKneels or 1
 local self=setmetatable({rules=rules,step=BossData.level.steps[2],mission={voice=voice,rules={stats={}},player={weapons={energyMax=100}}},
  Capture=function()end,Banner=function()end},{__index=legacy and Legacy or Boss})
 local originalRandom=math.random;local frames={}
 for _,step in ipairs(test.steps)do
  self.time=step.time;self.storyUntil=step.storyUntil;talking=step.talking
  rules.phase=step.phase;rules.state='fight'
  math.random=function(n)draws=draws+1;return math.floor(step.random*n)+1 end
  rules:Kneel();self:Events()
  local copy={};for i,c in ipairs(calls)do copy[i]={lines=c.lines,urgent=c.urgent,append=c.append}end
  frames[#frames+1]={selected=self.lastKneelLine,calls=copy,draws=draws,storyUntil=self.storyUntil,kneels=rules.kneels}
 end
 math.random=originalRandom;return frames
end
''')
checks=0
frames=0
for key in ['kneelPool','kneelP2','kneelP3']:
    assert data['level']['steps'][1]['lines'][key]==reference['authoredLines'][key],key
    checks+=1
for case in reference['cases']:
    actual=python(run(to_lua(case['test']),False))
    for left,right in zip(actual,case['expected'],strict=True):
        for key in ['selected','calls','draws','storyUntil','kneels']:
            assert left.get(key)==right.get(key),(case['test']['name'],key,left.get(key),right.get(key))
            checks+=1
        frames+=1
reproduced=[]
for name in ['phase-2/rng-0.999999/talk-false/until-0','phase-3/rng-0.999999/talk-false/until-0',
             'phase-1/rng-0/talk-true/until-0','no-consecutive-repeat-1-0']:
    case=next(c for c in reference['cases'] if c['test']['name']==name)
    before=python(run(to_lua(case['test']),True))
    assert [f['calls'] for f in before]!=[f['calls'] for f in case['expected']],name
    reproduced.append({'name':name,'beforeCalls':[f['calls'] for f in before],
                       'expectedCalls':[f['calls'] for f in case['expected']]})
    checks+=1
report={'pass':True,'checks':checks,'cases':len(reference['cases']),'frames':frames,'source':reference['source'],
 'reproducedBeforeFix':{'snapshot':str(old.relative_to(ROOT)),'sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'cases':reproduced},
 'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua','assets/Story/Mission/Level5.json']},
 'boundary':'Actual complete frozen FoxBoss._kneel/talk versus production BossRules.Kneel -> StoryBoss.Events -> KneelLine, with HUD/voice/physics adapters. Authored phase lines verified equal; RNG selection, reference-based no-repeat, channel busy strict boundary and suppressed-bark memory compared. No GPU, audible dialogue, natural full fifth mission or performance acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-kneel-dialogue-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='reproducedBeforeFix'},indent=2))
