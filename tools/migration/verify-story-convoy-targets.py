"""Execute frozen H5 and production Lua enemy targeting while the player is dead."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/story-convoy-target-source.mjs'],text=True))
lua=LuaRuntime(unpack_returned_tuples=True)
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'})do
 package.preload[name]=function()return {}end
end
package.preload['drive.RotorMotion']=function()return {Weapons=function()end}end
local Mission=require 'story.Mission'
return function(alive,target,convoy,trigger)
 local sample={driverCalls=0,fireActive=0,throttle=0,handbrake=true}
 local player={alive=alive}
 local enemy={alive=true,Flush=function()end,Position=function()return {1,2,3}end,team='red'}
 enemy.vehicle={StepRotors=function()end,Step=function(_,command)sample.throttle=command.throttle;sample.handbrake=command.handbrake end,
  body={translation=function()return {x=1,y=2,z=3}end,linvel=function()return {x=0,y=0,z=0}end,rotation=function()return {}end}}
 enemy.weapons={fx={},Step=function(_,_,command)if command.firing then sample.fireActive=sample.fireActive+1 end end}
 local truck={}
 local entry={unit=enemy,target=target~='default' and target or nil,env={},driver={Step=function(_,_,victim)
  sample.driverCalls=sample.driverCalls+1;sample.victim=victim==truck and 'truck' or 'player'
  return {throttle=.75,steer=.2,handbrake=false},{41,5,43},trigger,{}
 end}}
 local self=setmetatable({entries={entry},player=player,convoy=convoy and {} or nil,truckTarget=truck,
  session={effects={Consume=function()end},weaponAudio={Consume=function()end}},Doomed=function()end},{__index=Mission})
 self:BeforeStep(.016,{},{});return sample
end
''')
checks=0
for case in reference['scenarios']:
    actual=dict(run(case['alive'],case['target'],case['convoy'],case['trigger']))
    for key in ['driverCalls','fireActive','throttle','handbrake','victim']:
        assert actual.get(key)==case[key],(case,key,actual)
        checks+=1
    if not case['alive'] and case['target']!='truck':
        assert actual['driverCalls']==0 and actual['fireActive']==0 and actual['handbrake']
        checks+=1
report={'pass':True,'checks':checks,'scenarios':len(reference['scenarios']),'source':reference['source'],
        'production':{'scripts/story/Mission.lua':hashlib.sha256((ROOT/'scripts/story/Mission.lua').read_bytes()).hexdigest()},
        'boundary':'Actual frozen JS StoryMission.beforeStep and production Lua Mission.BeforeStep with native/driver doubles; no collision, rendered gameplay or performance acceptance. Not part of manifest-41e4025e Web evidence.'}
out=ROOT/'docs/migration/evidence/story-convoy-targets-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
