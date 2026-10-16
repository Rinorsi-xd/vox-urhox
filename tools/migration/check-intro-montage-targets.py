"""Compare actual source beforeStep with actual Lua host and battle actor control."""
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

reference=json.loads(subprocess.check_output(['node','tools/migration/source-intro-montage-targets.mjs'],encoding='utf-8'))
paths=['scripts/app/OpeningHost.lua','scripts/intro/IntroBattle.lua']
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}

def run(directory):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([table(v) for v in value])
        return value
    lua.globals().REFERENCE=table(reference)
    lua.globals().DIRECTORY=directory.as_posix()
    return lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
package.loaded['construction.Blueprint']={}
package.loaded['app.SceneLoader']={New=function()return{Update=noop}end}
package.loaded['combat.CarUnit']={};package.loaded['combat.EnemyDriver']={}
package.loaded['combat.DriverActions']={Apply=noop}
package.loaded['drive.RotorMotion']={Weapons=noop}
local Host=assert(loadfile(DIRECTORY..'/scripts/app/OpeningHost.lua'))()
local Battle=assert(loadfile(DIRECTORY..'/scripts/intro/IntroBattle.lua'))()
local checks=0
local function check(ok,label)assert(ok,label);checks=checks+1 end
local function near(a,b,label)check(math.abs(a-b)<1e-9,label)end
local function vector(a,b,label)for i=1,3 do near(a[i],b[i],label..i)end end
local function unit(pos)
 local u={alive=true,point=pos,weapons={fx={}},commands={},fires={}}
 u.Position=function(self)return self.point end;u.Flush=noop
 local v={body={translation=function()return{x=pos[1],y=pos[2],z=pos[3]}end,
  linvel=function()return{x=0,y=0,z=0}end,rotation=noop},rotors={}}
 v.Place=function(_,p)u.point=p end;v.StepRotors=function(_,aim,step)u.rotorSteps=(u.rotorSteps or 0)+1;u.rotorAim={aim=aim,step=step} end
 v.Step=function(_,cmd)u.commands[#u.commands+1]=cmd end;u.vehicle=v
 u.weapons.Step=function(_,_,cmd)u.fires[#u.fires+1]=cmd end
 return u
end
local player=unit({66,4,-174});local cart=unit({30,3,-170});local driverCalls=0
local battle=setmetatable({entries={},player=player,cart=cart,stage=0,world={},
 session={effects={Consume=noop},weaponAudio={Consume=noop},camera={GetNode=function()return{worldPosition={x=0,y=0,z=0}}end}}},Battle)
battle.entries[1]={unit=player}
for i=2,8 do local u=unit({i,5,-104});battle.entries[i]={unit=u,driver={Step=function(_,_,victim)
 driverCalls=driverCalls+1;return{throttle=1,steer=.2},victim:Position(),true end}}end
battle.entries[9]={unit=cart};battle.easy=battle.entries[6].unit
battle.montage={Activate=function()return player end}
local s={combat=battle,view={ResetPose=noop},weapons={groups={},projectiles={}}}
s.Tick=function(_,dt,command)battle:BeforeStep(dt,command,command.aim);s.lastCommand=command end
local host=Host.New({car={SetVisible=noop},graphicsSettings={SetSceneVisible=noop}})
host.state.session=s;host.state.activeScene='crater';host.state.hallActor={SetVisible=noop,root={enabled=false}}
host.GroundAt=function()return 0 end
local I={ready=true,playing=false,age=0,time=0,shot='m-drive'}
host.Shot('m-drive',I)
check(battle.driversParked==true,'Actual m-drive host must clear the shared AI target')
for _,shot in ipairs({'m-drive','m-missile'})do
 I.shot=shot;host.Shot(shot,I)
 local target=host.state.montageTarget;target.point={table.unpack(REFERENCE.point)}
 for _,age in ipairs({0,.25,1,2.5,4.5})do
  I.age=age;I.time=age;local before=driverCalls;host.Update(1/60,I)
  check(driverCalls==before,'Parked montage never invokes an enemy driver '..shot..age)
  vector(s.lastCommand.aim,REFERENCE.aim,'Source target aim is one meter above actor '..shot..age)
  check(s.lastCommand.firing==(shot=='m-missile' and true or nil),'Only missile montage fires player weapons')
  for i=2,8 do local u=battle.entries[i].unit;local cmd=u.commands[#u.commands]
   check(cmd.throttle==0 and cmd.handbrake==true,'All live target actors park '..i)
   check(#u.fires==0 and u.rotorAim.aim==nil and u.rotorAim.step==false,'Parked actors step rotors without aim and never advance weapons like source continue '..i)
  end
 end
end
-- Real sortie setup cancels montage parking, preserving the interactive tutorial.
battle:BeginSortie();check(not battle.driversParked,'Replay setup restores enemy drivers')
local before=driverCalls;battle:BeforeStep(1/60,{throttle=0},player:Position())
check(driverCalls==before+7,'All invaders still drive during the real sortie')
for i=2,8 do vector(battle.entries[i].unit.fires[#battle.entries[i].unit.fires].aim,cart:Position(),'Source cart targeting restored')end
battle.driversParked=true;battle:EndSortie();check(not battle.driversParked,'EndSortie restores source cart targeting')
return checks
''')

checks=run(ROOT)
old=ROOT/'.tmp/outgame-cached-1792113063203'
try:
    run(old)
except Exception as error:
    assert 'Actual m-drive host must clear' in str(error),str(error)
    negative=str(error).split('\n')[0]
else:raise AssertionError('Actual frozen 5b8c unexpectedly passes parked-driver contract')
parked=next(c for c in reference['cases'] if c['target'] is None)
assert all(c['kind']=='step' and c['cmd']['throttle']==0 and c['cmd']['handbrake'] for c in parked['calls'])
assert hashes=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
report={'result':'PASS','checks':checks,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
        'productionHashes':hashes,'sourceBeforeStepCases':reference['cases'],'historicalNegativeControl':{'manifest':'manifest-5b8cf21c.json','failure':negative},
        'boundary':reference['boundary']+' Lua executes actual host shot/update and IntroBattle.BeforeStep with vehicle/weapon adapters. Does not prove rendering, stopping distance or live missile impacts.'}
output=ROOT/'docs/migration/evidence/intro-montage-targets-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':checks,'negativeControls':1,'evidence':str(output)}))
