"""Compare actual frozen StoryMission + CarUnit PARK branch to production Lua."""
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
reference=json.loads(subprocess.check_output(['node','tools/migration/story-dead-player-park-source.mjs'],text=True,encoding='utf-8'))
production=ROOT/'scripts/story/Mission.lua'
legacy=ROOT/'.tmp/outgame-cached-1792115578618/scripts/story/Mission.lua'

def runner(code):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MissionCode=code
    run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache'})do package.preload[name]=function()return {}end end
local sample
package.preload['drive.RotorMotion']=function()return {Weapons=function()sample.rotorWeapons=sample.rotorWeapons+1 end}end
local Mission=assert(load(MissionCode))()
return function(alive,target,convoy,trigger)
 sample={driver=0,physics=0,rotors=0,rotorWeapons=0,weapons=0,firing=0,fx=0,audio=0}
 local player={alive=alive}
 local enemy={alive=true,Flush=function()end,Position=function()return {1,2,3}end,team='red'}
 enemy.vehicle={rotors={},StepRotors=function(_,aim)sample.rotors=sample.rotors+1;sample.rotorAim=aim end,
  Step=function(_,command)sample.physics=sample.physics+1;sample.throttle=command.throttle;sample.handbrake=command.handbrake end,
  body={translation=function()return {x=1,y=2,z=3}end,linvel=function()return {x=0,y=0,z=0}end,rotation=function()return {}end}}
 enemy.weapons={fx={{type='fixture'}},Step=function(_,_,command)sample.weapons=sample.weapons+1;if command.firing then sample.firing=sample.firing+1 end end}
 local entry={unit=enemy,target=target~='default' and target or nil,env={},driver={Step=function()
  sample.driver=sample.driver+1;return {throttle=.75,steer=.2,handbrake=false},{41,5,43},trigger,{}
 end}}
 local self=setmetatable({entries={entry},player=player,convoy=convoy and {} or nil,truckTarget={},
  session={effects={Consume=function()sample.fx=sample.fx+1 end},weaponAudio={Consume=function()sample.audio=sample.audio+1 end}},Doomed=function()end},{__index=Mission})
 self:BeforeStep(.016,{},{});return sample
end
''')
    return run

def plain(value):
    if hasattr(value,'items'):return [value[i] for i in range(1,len(value)+1)]
    return value

keys=['driver','physics','rotors','rotorAim','rotorWeapons','weapons','firing','fx','throttle','handbrake']
def mismatches(code):
    run=runner(code);failures=[]
    for index,case in enumerate(reference['cases']):
        actual=dict(run(case['alive'],case['target'],case['convoy'],case['trigger']))
        for key in keys:
            if plain(actual.get(key))!=case[key]:failures.append({'case':index,'key':key})
        parked=not case['alive'] and case['target']!='truck'
        if actual['audio']!=(0 if parked else 1):failures.append({'case':index,'key':'audio'})
    return failures

code=production.read_text(encoding='utf-8-sig')
assert not mismatches(code),mismatches(code)
negative={
 'frozen-49c15':mismatches(legacy.read_text(encoding='utf-8-sig')),
 'skip-parked-rotors':mismatches(code.replace('v:Step(cmd,dt);v:StepRotors(nil,nil,dt)','v:Step(cmd,dt)')),
 'park-truck-too':mismatches(code.replace("and entry.target~='truck' then","then")),
}
assert all(negative.values()),negative
def sha(relative):return hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()
report={'result':'PASS','checks':len(reference['cases'])*(len(keys)+1),'cases':len(reference['cases']),
 'source':reference['source'],'productionHashes':{'scripts/story/Mission.lua':sha('scripts/story/Mission.lua')},
 'inputs':{relative:sha(relative) for relative in ['tools/migration/story-dead-player-park-source.mjs','tools/migration/verify-story-dead-player-park.py']},
 'negativeControls':negative,'legacy':{'path':str(legacy.relative_to(ROOT)),'sha256':hashlib.sha256(legacy.read_bytes()).hexdigest()},
 'boundary':'Actual frozen StoryMission.beforeStep, CarUnit.step and CarUnit.fire; production Mission.BeforeStep. Physics/driver/weapon/native adapters. Standard non-drill-body vehicles; source regeneration and normal rotor/physics call ordering excluded. No GPU, natural death/respawn, rendered FX, audio listening or performance acceptance.'}
out=ROOT/'docs/migration/evidence/story-dead-player-park-offline.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({**report,'negativeControls':{k:len(v) for k,v in negative.items()}},indent=2))
