"""Compare frozen Boss path selection with actual Lua navigation and stepping."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-waypoint-source.mjs'],text=True))
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
lua.globals().BossData=to_lua(json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig')))
run,wiring=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.BossRules','combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
local Nav=require 'combat.EnemyDriverNav';local path=Nav.Path
local Boss=require 'combat.StoryBoss';local Legacy=assert(load(LegacyBossCode))()
local function copy(p)if p then return {table.unpack(p)}end end
return function(test)
 local calls={};Nav.Path=function(nav,from,to,width,jitter)
  assert(jitter==nil,'Boss route must not use ordinary enemy random jitter')
  calls[#calls+1]={from=copy(from),to=copy(to),width=width};return path(nav,from,to,width,jitter)
 end
 local position={0,0,0};local self=setmetatable({unit={Position=function()return position end},world={layout={nav=test.nav}}},{__index=Boss})
 local frames={}
 for _,step in ipairs(test.steps)do
  self.time=step.time;position=copy(step.pos);local target=copy(step.to);local goal=copy(self:Waypoint(target))
  local before=copy(self.pathTo);if step.mutateTarget then target[1]=target[1]+500 end
  local recorded={};for i,c in ipairs(calls)do recorded[i]={from=copy(c.from),to=copy(c.to),width=c.width}end
  local route=nil;if self.path then route={};for i,p in ipairs(self.path)do route[i]=copy(p)end end
  frames[#frames+1]={goal=goal,path=route,pathTo=copy(self.pathTo),pathUntil=self.pathUntil,calls=recorded,
   copiedTarget=not before or before[1]==self.pathTo[1] and before[2]==self.pathTo[2] and before[3]==self.pathTo[3]}
 end
 Nav.Path=path;return frames
end,function(nav,legacy,leash)
 local calls=0;Nav.Path=function(...)calls=calls+1;return path(...)end
 local pos=leash and {900,0,0} or {0,0,0};local target={180,0,0}
 local vehicle={body={angvel=function()return {y=0}end},Yaw=function()return 0 end}
 local self=setmetatable({time=0,rules={state='fight',phase=1,cool={fire=999}},
  unit={vehicle=vehicle,weapons={groups={}},Position=function()return pos end},
  mission={player={}},world={layout={nav=nav,enginePit={points={floorCentre={0,0,0}}}}},
  driver={nav=nav,Path=function(_,from,to)return Nav.Path(nav,from,to,30,function()return 1 end)end},
  Nodes=function()end,StepAllies=function()end,StepUnit=function()end,Cockpit=function()return {0,10,0}end,
  focusUnit={alive=true,Position=function()return target end},focusUntil=999,Projectiles=function()end,
  OpenNode=function()end},{__index=legacy and Legacy or Boss})
 for i=0,119 do self.time=i/60;self:BeforeStep(1/60)end
 Nav.Path=path;return calls
end
''')
checks=0
frames=0
for case in reference['cases']:
    actual=python(run(to_lua(case['test'])))
    for left,right in zip(actual,case['expected'],strict=True):
        for key in ['goal','path','pathTo','pathUntil','calls','copiedTarget']:
            assert left.get(key)==right.get(key),(case['test']['name'],frames,key,left.get(key),right.get(key))
            checks+=1
        frames+=1
wide=reference['cases'][0]['test']['nav']
old_calls=wiring(to_lua(wide),True,False)
new_calls=wiring(to_lua(wide),False,False)
old_leash=wiring(to_lua(wide),True,True)
new_leash=wiring(to_lua(wide),False,True)
assert (old_calls,new_calls,old_leash,new_leash)==(120,2,120,0),(old_calls,new_calls,old_leash,new_leash)
checks+=4
production_lines=json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))['level']['steps'][1]['lines']
for item in reference['retiredBarks']:
    assert item=={'key':item['key'],'lineExists':False,'onceResult':False,'said':False,'dialogueCalls':0},item
    assert item['key'] not in production_lines,item
    checks+=2
report={'pass':True,'checks':checks,'cases':len(reference['cases']),'frames':frames,'source':reference['source'],
 'reproducedBeforeFix':{'snapshot':str(old.relative_to(ROOT)),'sha256':hashlib.sha256(old.read_bytes()).hexdigest(),
  'actualBeforeStep120Ticks':{'chaseOld':old_calls,'chaseCurrent':new_calls,'leashedOld':old_leash,'leashedCurrent':new_leash}},
 'retiredBarksNotMigrated':reference['retiredBarks'],
 'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/combat/StoryBoss.lua','scripts/combat/EnemyDriverNav.lua','scripts/combat/EnemyDriverMath.lua']},
 'boundary':'Actual complete frozen FoxBoss._waypoint and real source findPath versus production Lua Waypoint/Nav.Path, plus actual old/current BeforeStep calls with physics/weapon adapters. No rendered driving, natural Boss gameplay or runtime performance acceptance.'}
output=ROOT/'docs/migration/evidence/story-boss-waypoint-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
