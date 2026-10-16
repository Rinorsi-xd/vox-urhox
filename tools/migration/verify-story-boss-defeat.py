"""Run actual frozen boss-ending flow versus production Lua death events and ending."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-defeat-source.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)


def to_lua(value):
    if isinstance(value,dict):return lua.table_from({k:to_lua(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([to_lua(v) for v in value])
    return value


def python(value):
    if hasattr(value,'items'):
        rows=dict(value)
        if not rows:return []
        if all(isinstance(k,int) for k in rows):return [python(rows[k]) for k in range(1,len(rows)+1)]
        return {k:python(v) for k,v in rows.items()}
    return value


baseline=ROOT/'.tmp/outgame-cached-1792111525141/scripts/combat/StoryBoss.lua'
lua.globals().LegacyBossCode=baseline.read_text(encoding='utf-8-sig')
current=(ROOT/'scripts/combat/StoryBoss.lua').read_text(encoding='utf-8-sig')
# Recovery/capture behavior is independently checked by the actual-source recovery suite.
# This fixture adapts native direction queries; its ending completion expectations stay unchanged.
tested_hash=hashlib.sha256((ROOT/'scripts/combat/StoryBoss.lua').read_bytes()).hexdigest()
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
assert data['level']['steps'][1]['lines']['down']==reference['downLines']
lua.globals().BossData=to_lua(data)
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules';local Legacy=assert(load(LegacyBossCode))()
return function(test,legacy)
 local calls={};local talking=test.talking
 local voice={Talking=function()return talking end,Hide=function()end,Say=function(_,lines,urgent,append)
  calls[#calls+1]={lines=lines,urgent=urgent,append=append}
 end}
 local rules=Rules.New(BossData.boss,150);rules.state='fight';rules.phase=3;rules.hp=1
 local self=setmetatable({rules=rules,time=10,storyUntil=test['until'],step=BossData.level.steps[2],
  unit={pos={0,0,0}},flow={stage='fight',t=1},missiles={},pending={},
  mission={voice=voice,ClearEnemies=function()end,rules={stats={}}},
  view={Update=function()end},radio={Play=function()end},Capture=function()end,Banner=function()end,OpenDir=function()return 0 end},
  {__index=legacy and Legacy or Boss})
 -- Produce the real death event through the actual production HP rule.
 rules:Hurt(2);self:Events()
 local atDefeat={calls=calls,storyUntil=self.storyUntil,stage=self.flow.stage,cinematic=self.cinematic}
 if test.finish=='skip' then self.skip=true
 else self.flow.t=20;self.flow.pod={};self.flow.truck={t=7.99}end
 talking=false;local finishes={}
 for _,dt in ipairs({0,.02,.02})do
  self:Update(dt)
  finishes[#finishes+1]={done=self.done==true,state=rules.state,stage=self.flow.stage,cinematic=self.cinematic}
 end
 return {atDefeat=atDefeat,finishes=finishes}
end
''')
failures=[]
legacy_failures=[]
checks=1
for case in reference['cases']:
    actual=python(run(to_lua(case['test']),False))
    old=python(run(to_lua(case['test']),True))
    expected=case['expected']
    for key in ['atDefeat','finishes']:
        if actual[key]!=expected[key]:failures.append({'name':case['test']['name'],'key':key,'actual':actual[key],'expected':expected[key]})
        if old[key]!=expected[key]:legacy_failures.append({'name':case['test']['name'],'key':key,'actual':old[key],'expected':expected[key]})
        checks+=1
digest=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
assert digest('scripts/combat/StoryBoss.lua')==tested_hash,'Production changed during the regression'
report={'result':'PASS' if not failures and legacy_failures else 'FAIL','checks':checks,'cases':len(reference['cases']),
 'source':reference['source'],'failures':failures,'reproducedBeforeFix':{'path':str(baseline.relative_to(ROOT)),
 'sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),'failures':legacy_failures},
 'production':{p:digest(p) for p in ['scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua','assets/Story/Mission/Level5.json']},
 'tools':{p:digest(p) for p in ['tools/migration/story-boss-defeat-source.mjs','tools/migration/verify-story-boss-defeat.py']},
 'boundary':'Actual frozen BOSS_KIND.update/FoxBoss.talk versus actual Lua BossRules.Hurt -> StoryBoss.Events/Say and StoryBoss.Update/Finish. Voice/render/physics doubles; no audible playback, natural fifth-mission win, GPU, build or performance acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-defeat-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'cases':len(reference['cases']),'failed':len(failures),
 'beforeFailed':len(legacy_failures),'firstFailure':failures[:1]},ensure_ascii=False))
if failures or not legacy_failures:sys.exit(1)
