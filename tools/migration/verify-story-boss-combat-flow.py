"""Compare actual frozen Boss update/land and current Lua flow event wiring."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-combat-flow-source.mjs'],text=True,encoding='utf-8'))
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

old=ROOT/'.tmp/outgame-cached-1792086673066/scripts'
lua.globals().LegacyBossCode=(old/'combat/StoryBoss.lua').read_text(encoding='utf-8-sig')
lua.globals().LegacyRulesCode=(old/'story/BossRules.lua').read_text(encoding='utf-8-sig')
data=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))
lua.globals().BossData=to_lua(data)
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Boss=require 'combat.StoryBoss';local Rules=require 'story.BossRules'
local Legacy=assert(load(LegacyBossCode))();local LegacyRules=assert(load(LegacyRulesCode))()
return function(test,legacy)
 local calls={};local lands=0;local talking=false
 local voice={Talking=function()return talking end,Say=function(_,lines,urgent,append)calls[#calls+1]={lines=lines,urgent=urgent,append=append}end}
 local rules=(legacy and LegacyRules or Rules).New(BossData.boss,150)
 rules.state=test.state;rules.phase=3;rules.slamKind=test.kind;rules.slamT=2.4;rules.slamTo={40,3,0}
 rules.cool={stomp=99,slam=test.coolSlam or 9,missile=99,fire=99,sweep=99,lanes=99,ult=99}
 local pos={0,20,0};local player={alive=true,pos={10,2,0},Position=function(self)return self.pos end}
 local unit={pos=pos,Position=function()return pos end,vehicle={Yaw=function()return 0 end,telemetry={mechContacts=0,legContacts=0},
  body={linvel=function()return {x=5,y=-3,z=8}end,setLinvel=function()lands=lands+1 end}}}
 local self=setmetatable({rules=rules,flow={stage='fight',t=0},time=0,storyUntil=0,step=BossData.level.steps[2],
  unit=unit,mission={voice=voice,player=player,entries={},rules={stats={}}},view={Update=function()end},
  session={},world={layout={}},pending={},missiles={},
  focusUnit={alive=true,Position=function()return {220,0,0}end},
  radio={Play=function()end},Fx=function()end,Team=function()return {}end,
  Feet=function()return {0,0,0}end,UnderRoof=function()return false end,Ground=function()return 0 end,
  Capture=function()end},{__index=legacy and Legacy or Boss})
 if test.mode=='target' then self.Events=function()rules:Drain()end end
 local frames={}
 for _,step in ipairs(test.steps)do
  if step.resetState then rules.state=step.resetState end
  if step.resetT then rules.t=step.resetT end
  if step.resetLaunched then rules.launched=false end
  self.flight={t=step.flightTime or 0};unit.vehicle.telemetry.mechContacts=step.contacts or 0;unit.vehicle.telemetry.legContacts=step.contacts or 0
  player.alive=step.alive~=false;talking=step.talking==true
  if step.ultPending~=nil then rules.ultPending=step.ultPending end
  for k,v in pairs(step.cool or {})do rules.cool[k]=v end
  self:Update(step.dt)
  if test.mode=='target' then frames[#frames+1]={state=rules.state}
  else local copy={};for i,c in ipairs(calls)do copy[i]={lines=c.lines,urgent=c.urgent,append=c.append}end
   frames[#frames+1]={state=rules.state,lands=lands,coolSlam=rules.cool.slam,launches=#self.pending/BossData.boss.missile.n,calls=copy,storyUntil=self.storyUntil}
  end
 end
 return frames
end
''')
checks=0
frames=0
assert 'barrage' not in data['level']['steps'][1]['lines'] and reference['retiredBarrageAbsent']
checks+=1
for case in reference['cases']:
    actual=python(run(to_lua(case['test']),False))
    for left,right in zip(actual,case['expected'],strict=True):
        for key,value in right.items():
            got=left.get(key)
            assert got==value or isinstance(got,(int,float)) and isinstance(value,(int,float)) and abs(got-value)<1e-10,(case['test']['name'],key,got,value)
            checks+=1
        frames+=1
reproduced=[]
for name in ['flight-hop-0-1-5','flight-hop-2.160001-1-0','player-false-ultPending']:
    case=next(c for c in reference['cases'] if c['test']['name']==name)
    before=python(run(to_lua(case['test']),True))
    assert before!=case['expected'],('old code unexpectedly matched',name)
    reproduced.append({'name':name,'before':before,'expected':case['expected']})
    checks+=1
report={'pass':True,'checks':checks,'cases':len(reference['cases']),'frames':frames,'source':reference['source'],
 'retiredBarrageNotMigrated':reference['retiredBarrageAbsent'],
 'reproducedBeforeFix':{'snapshot':str(old.relative_to(ROOT)),'cases':reproduced},
 'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua','assets/Story/Mission/Level5.json']},
 'boundary':'Complete frozen FoxBoss.update and _land versus production StoryBoss.Update -> BossRules.Step -> StoryBoss.Events. Native HUD, body, FX and projectile launch adapters; target-selection branch actions are adapters. Physics-clock versus render-clock, hop cooldown and player-death gating only; deleted barrage line is confirmed absent rather than reintroduced. No GPU, natural whole mission, audible output or device-performance acceptance.'}
out=ROOT/'docs/migration/evidence/story-boss-combat-flow-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='reproducedBeforeFix'},indent=2))
