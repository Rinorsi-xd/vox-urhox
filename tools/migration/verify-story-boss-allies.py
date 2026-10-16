"""Compare real frozen H5 Boss ally methods against the production Lua module."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-allies-source.mjs'],text=True))
lua=LuaRuntime(unpack_returned_tuples=True)

def to_lua(value):
    if isinstance(value,dict):
        return lua.table_from({key:to_lua(item) for key,item in value.items()})
    if isinstance(value,list):
        return lua.table_from([to_lua(item) for item in value])
    return value

def to_python(value):
    if hasattr(value,'items'):
        items=dict(value)
        if items and all(isinstance(key,int) for key in items):
            return [to_python(items[key]) for key in range(1,len(items)+1)]
        return {key:to_python(item) for key,item in items.items()}
    return value

lua.globals().BossData=to_lua(json.loads((ROOT/'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig')))
lua.globals().LegacyBossCode=subprocess.check_output(['git','show','HEAD:scripts/combat/StoryBoss.lua'],text=True,encoding='utf-8')
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.BossRules','combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do
 package.preload[name]=function()return {}end
end
package.preload['core.ResourceData']=function()return {Read=function()return BossData end}end
package.preload['drive.RotorMotion']=function()return {Weapons=function()end}end
local Boss=require 'combat.StoryBoss'
local LegacyBoss=assert(load(LegacyBossCode,'@HEAD:scripts/combat/StoryBoss.lua'))()
return function(test,legacy)
 local sample={driverCalls=0,fireCalls=0,firing=false,salvo=false,throttle=0,handbrake=true,spawns=0}
 local pos={0,2,0};local bossUnit={id='boss'}
 local u={id='ally',alive=true,pos=pos,team='blue',Flush=function()end,Health=function()return 1 end,Position=function()return pos end}
 u.vehicle={rotors={},StepRotors=function()end,Step=function(_,command)sample.throttle=command.throttle;sample.handbrake=command.handbrake end,
  body={translation=function()return {x=0,y=2,z=0}end,rotation=function()return {}end,linvel=function()return {x=0,y=0,z=0}end}}
 u.weapons={fx={},Step=function(_,_,command)sample.fireCalls=sample.fireCalls+1;sample.firing=command.firing;sample.salvo=command.salvo end}
 local entries={{unit={}}}
 for _,d in ipairs(test.drills or {})do
  local unit={id=d.id,pos=d.pos,alive=d.alive,Position=function(self)return self.pos end}
  entries[#entries+1]={unit=unit,tag=d.tag}
 end
 local driver={Step=function(_,_,target)
  sample.driverCalls=sample.driverCalls+1
  return {throttle=.75,handbrake=false},target:Position(),not target.passive,{salvo=true}
 end}
 local self=setmetatable({rules={state=test.state,t=test.t,hp=test.hp or 1,nodes=test.nodes or {{pos={30,3,0},broken=false},{pos={5,4,0},broken=false}}},
  time=test.elapsed or 16,unit=bossUnit,mission={entries=entries},allies={{unit=u,driver=driver,deadAt=test.dead and 0 or nil,env={}}},
  world={layout={enginePit={ceilings=test.roofs or {}}}},
  session={effects={Consume=function()end},weaponAudio={Consume=function()end}},
  Ground=function()return 7 end,UnderRoof=function()return test.underRoof==true end,Cockpit=function()return {3,12,4}end,
  SpawnAlly=function()sample.spawns=sample.spawns+1 end},{__index=legacy and LegacyBoss or Boss})
 if not test.dead then
  local target,passive,unit=self:AllyTarget(u)
  if target then sample.target={pos=target,passive=passive==true,unit=unit and unit.id}end
 end
 if not legacy then self:StepAllies(.016)end;return sample
end
''')
checks=0
legacy_failures=[]
for name,state in [('nearest-unsorted','fight'),('no-drill','intro'),('no-drill','ending'),('node-tie-last','fight'),('roof-tie-last','ult')]:
    case=next(item for item in reference['targets'] if item['test']['name']==name and item['test']['state']==state)
    actual=to_python(run(to_lua(case['test']),True)).get('target')
    expected=case['expected'].get('target')
    if isinstance(expected,dict) and expected.get('unit') is None:
        expected={k:v for k,v in expected.items() if k!='unit'}
    assert actual!=expected,('Regression case did not reproduce against actual HEAD',name,state)
    legacy_failures.append({'name':name,'state':state,'before':actual,'expected':expected})
    checks+=1
for group in ['targets','respawns']:
    for case in reference[group]:
        actual=to_python(run(to_lua(case['test']),False))
        expected=case['expected']
        for key in ['driverCalls','fireCalls','firing','salvo','throttle','handbrake','spawns','target']:
            left=actual.get(key)
            right=expected.get(key)
            if isinstance(right,dict) and right.get('unit') is None:
                right={k:v for k,v in right.items() if k!='unit'}
            assert left==right,(group,case['test'],key,left,right)
            checks+=1
wiring=lua.execute(r'''
local Boss=require 'combat.StoryBoss'
local events={};local self=setmetatable({rules={state='idle'},time=1,mission={player={}},allies={},
 unit={Position=function()return {0,0,0}end,vehicle={Yaw=function()return 0 end},weapons={groups={}}},
 Nodes=function()events[#events+1]='nodes'end,
 StepAllies=function(self,dt)events[#events+1]='allies';Boss.StepAllies(self,dt)end,
 StepUnit=function()events[#events+1]='boss'end,
 Cockpit=function()return {0,1,0}end,Victim=function()return nil end,
 Projectiles=function()events[#events+1]='projectiles'end},{__index=Boss})
self:BeforeStep(.016)
assert(table.concat(events,',')=='nodes,allies,boss,projectiles','Actual BeforeStep ally wiring/order')
self.disposed=true;self:BeforeStep(.016)
assert(#events==4,'Disposed Boss still stepped allies')
return 2
''')
checks+=wiring
report={'pass':True,'checks':checks,'targetScenarios':len(reference['targets']),'respawnScenarios':len(reference['respawns']),
        'source':reference['source'],
        'reproducedBeforeFix':legacy_failures,'beforeStepWiringChecks':wiring,
        'production':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['scripts/combat/StoryBoss.lua','assets/Story/Mission/Level5.json']},
        'boundary':'Actual complete frozen JS FoxBoss/StoryMission modules and actual Lua StoryBoss with native/driver doubles. Target and stage lifecycle contracts only; no rendered Boss fight, physics, sound or performance acceptance.'}
output=ROOT/'docs/migration/evidence/story-boss-allies-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
