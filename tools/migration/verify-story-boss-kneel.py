"""Execute actual H5/Lua Boss BeforeStep and compare physical kneeling input."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/story-boss-kneel-source.mjs'],text=True))
lua=LuaRuntime(unpack_returned_tuples=True)

def to_lua(value):
    if isinstance(value,dict):
        return lua.table_from({k:to_lua(v) for k,v in value.items()})
    if isinstance(value,list):
        return lua.table_from([to_lua(v) for v in value])
    return value

lua.globals().LegacyBossCode=subprocess.check_output(['git','show','HEAD:scripts/combat/StoryBoss.lua'],text=True,encoding='utf-8')
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.BossRules','combat.CarUnit','combat.EnemyDriver','core.Coord','audio.StoryRadio'})do
 package.preload[name]=function()return {}end
end
package.preload['core.ResourceData']=function()return {Read=function()return {boss={}}end}end
local Boss=require 'combat.StoryBoss'
local Legacy=assert(load(LegacyBossCode,'@HEAD:scripts/combat/StoryBoss.lua'))()
return function(test,legacy)
 local control=test.control~=false and {} or nil
 if control then control.kneel=test.initial end
 local atAllies,atVehicle=false,false
 local self=setmetatable({rules={},time=1,mission={player={}},allies={},at={enter={0,0,0}},
  unit={Position=function()return {0,0,0}end,vehicle={mechControl=control,Yaw=function()return 0 end,body={angvel=function()return {y=0}end}},weapons={groups={}}},
  Nodes=function()end,StepAllies=function()atAllies=control and control.kneel or nil end,
  StepUnit=function()atVehicle=control and control.kneel or nil end,
  Cockpit=function()return {0,10,0}end,Victim=function()return nil end,Projectiles=function()end},{__index=legacy and Legacy or Boss})
 local out={}
 for _,step in ipairs(test.steps)do
  self.rules.state=step.state;self:BeforeStep(step.dt)
  out[#out+1]={kneel=control and control.kneel or nil,atAllies=atAllies,atVehicle=atVehicle}
 end
 return out
end
''')
checks=0
frames=0
for case in reference['cases']:
    actual=run(to_lua(case['test']),False)
    for index,expected in enumerate(case['expected'],1):
        for key in ['kneel','atAllies','atVehicle']:
            left=actual[index][key]
            right=expected[key]
            assert left==right or left is not None and right is not None and abs(left-right)<1e-12,(case['test']['name'],index,key,left,right)
            checks+=1
        frames+=1

reproduced=[]
for state,initial in [('kneel',0),('dying',0),('dead',0),('ending',0),('rise',1),('fight',1)]:
    case=next(c for c in reference['cases'] if c['test']['initial']==initial and c['test']['steps']==[{'state':state,'dt':1/60}])
    legacy=run(to_lua(case['test']),True)[1]['kneel']
    expected=case['expected'][0]['kneel']
    assert legacy!=expected,(state,legacy,expected)
    reproduced.append({'state':state,'initial':initial,'before':legacy,'expected':expected})
    checks+=1

report={'pass':True,'checks':checks,'cases':len(reference['cases']),'frames':frames,'source':reference['source'],
        'reproducedBeforeFix':reproduced,
        'production':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in ['scripts/combat/StoryBoss.lua','scripts/drive/MechControl.lua']},
        'boundary':'Actual complete frozen H5 FoxBoss.beforeStep and actual Lua StoryBoss.BeforeStep; native vehicle, other AI, weapons and physics are doubles. Compares mechControl.kneel at the ally and main vehicle stepping boundaries. Natural fifth mission, Bullet support forces, visible kneel/cockpit alignment and mobile performance remain OPEN. No build/browser/native launch.'}
output=ROOT/'docs/migration/evidence/story-boss-kneel-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
