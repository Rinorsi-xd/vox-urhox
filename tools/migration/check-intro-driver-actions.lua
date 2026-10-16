-- Actual opening dispatch and recovery module; no native world or rendering.
package.path='scripts/?.lua;'..package.path
package.loaded['combat.CarUnit']={}
package.loaded['combat.EnemyDriver']={}
local rotorCalls={}
package.loaded['drive.RotorMotion']={Weapons=function(rotors,weapons) rotorCalls[#rotorCalls+1]={rotors,weapons} end}
local Battle=require 'intro.IntroBattle'
local checks=0
local function Check(ok,label) checks=checks+1;assert(ok,label) end
local function Fixture(stage,info,playerInfo)
 local f={log={},effects={},sounds={},driverCalls={},positions={},weaponCalls={},vehicleCalls={},rotorCalls={}}
 local function Log(unit,action) f.log[#f.log+1]=unit..':'..action end
 local function Actor(name,team)
  local position={x=1,y=2,z=3}
  local vehicle={spec={bounds={radius=5}},rotors={name=name}}
  vehicle.body={translation=function() return {x=position.x,y=position.y,z=position.z} end,
   linvel=function() return {x=4,y=5,z=6} end,rotation=function() return {w=1} end}
  function vehicle:Place(p,yaw) Log(name,'place');position={x=p[1],y=p[2],z=p[3]};f.positions[#f.positions+1]={name=name,pos=p,yaw=yaw} end
  function vehicle:Yaw() return .7 end
  function vehicle:StepRotors(aim,step,dt) Log(name,'rotors');f.rotorCalls[#f.rotorCalls+1]={name=name,aim=aim,step=step,dt=dt} end
  function vehicle:Step(command,dt) Log(name,'step');f.vehicleCalls[name]={command=command,dt=dt} end
  local weapons={fx={name=name}}
  function weapons:Step(dt,command,env) Log(name,'fire');f.weaponCalls[name]={dt=dt,command=command,env=env} end
  local actor={name=name,team=team,alive=true,vehicle=vehicle,weapons=weapons}
  function actor:Position() return {position.x,position.y,position.z} end
  function actor:Flush() Log(name,'flush') end
  return actor
 end
 f.player=Actor('player','blue');f.enemy=Actor('enemy','red');f.cart=Actor('cart','blue');f.parked=Actor('parked','red')
 local driver={}
 function driver:Step(dt,victim,charge)
  Log('enemy','driver');f.driverCalls[#f.driverCalls+1]={dt=dt,victim=victim,charge=charge}
  return {throttle=1,steer=.25}, {9,8,7},true,info
 end
 f.enemyDriver=driver
 local playerDriver={Step=function()error('player must never run enemy AI')end}
 f.session={camera={GetNode=function()return {worldPosition={x=11,y=12,z=13}} end},
  effects={Consume=function(_,fx)f.effects[#f.effects+1]=fx end},
  weaponAudio={Consume=function(_,fx,remote)f.sounds[#f.sounds+1]={fx=fx,remote=remote} end}}
 f.battle=setmetatable({session=f.session,stage=stage,player=f.player,cart=f.cart,easy=f.enemy,
  entries={{unit=f.player,driver=playerDriver,env={name='player-env'}},{unit=f.enemy,driver=driver,env={name='enemy-env'}},{unit=f.parked,env={name='parked-env'}}}},Battle)
 return f
end
local command={throttle=.5,firing=true,rotorStep=true}
local aim={31,32,33}
local function Run(stage,info)
 local f=Fixture(stage,info);f.battle:BeforeStep(1/60,command,aim)
 Check(f.vehicleCalls.player.command==command,'player keeps actual input command')
 Check(f.weaponCalls.player.command.aim==aim and f.weaponCalls.player.command.firing,'player keeps actual aim and trigger')
 Check(f.weaponCalls.player.command.salvo==nil,'enemy salvo never leaks to player')
 Check(f.weaponCalls.parked.command.salvo==nil,'enemy salvo never leaks to parked actor')
 Check(f.weaponCalls.player.command.eye[1]==-11 and f.weaponCalls.player.command.eye[2]==12 and f.weaponCalls.player.command.eye[3]==13,'player eye coordinate unchanged')
 Check(f.weaponCalls.enemy.env.name=='enemy-env','enemy environment ownership unchanged')
 Check(#f.effects==3 and #f.sounds==3,'existing events consumed once per living actor')
 Check(f.sounds[1].remote==false and f.sounds[2].remote==true,'audio keeps remote flag')
 return f
end
local info={reset={pos={100,20,300},yaw=.2},flip=true,salvo=true}
local f=Run(1,info)
Check(#f.driverCalls==1 and f.driverCalls[1].victim==f.player and f.driverCalls[1].charge,'easy enemy targets player in teaching step')
Check(#f.positions==2,'both recovery actions applied')
Check(f.positions[1].pos==info.reset.pos and f.positions[1].yaw==.2,'reset preserves driver position and yaw')
Check(f.positions[2].pos[1]==100 and f.positions[2].pos[2]==23 and f.positions[2].pos[3]==300 and f.positions[2].yaw==.7,'flip follows reset at current body position')
local expected={'player:flush','player:rotors','player:step','player:fire','enemy:flush','enemy:driver','enemy:place','enemy:place','enemy:rotors','enemy:step','enemy:fire','parked:flush','parked:rotors','parked:step','parked:fire'}
for i,label in ipairs(expected) do Check(f.log[i]==label,'source recovery then rotor/vehicle/fire order '..i) end
Check(#f.log==#expected,'no extra simulation calls')
Check(f.weaponCalls.enemy.command.salvo==true,'driver salvo reaches actual weapon dispatch')
Check(f.weaponCalls.enemy.command.pos[1]==100 and f.weaponCalls.enemy.command.pos[2]==23,'fire reads recovered body position')
for _,cfg in ipairs({{reset={pos={5,6,7},yaw=.3}},{flip=true},{salvo=false},{}}) do
 local each=Run(3,cfg)
 Check(each.driverCalls[1].victim==each.player,'survival enemies target player')
 Check(each.weaponCalls.enemy.command.salvo==cfg.salvo,'salvo false and nil preserved')
 Check(#each.positions==(cfg.reset and 1 or 0)+(cfg.flip and 1 or 0),'recovery executes only requested actions')
end
local old=Run(2,nil)
Check(old.weaponCalls.enemy.command.salvo==nil and #old.positions==0,'legacy three-return driver still accepted')
local inactive=Run(0,info)
Check(#inactive.driverCalls==1 and #inactive.positions==2 and inactive.driverCalls[1].victim==inactive.cart,'source background stage runs enemy AI and recovery against cart')
Check(inactive.weaponCalls.enemy.command.firing==true and inactive.weaponCalls.enemy.command.salvo==true,'source background combat dispatches driver trigger and salvo')
local distant=Fixture(2,info);distant.battle.easy=distant.cart;distant.battle:BeforeStep(.02,command,aim)
Check(distant.driverCalls[1].victim==distant.cart,'other early actors retain cart target')
local dead=Fixture(3,info);dead.enemy.alive=false;dead.battle:BeforeStep(.02,command,aim)
Check(#dead.driverCalls==0 and dead.weaponCalls.enemy==nil and #dead.positions==0,'dead actors never recover or fire')
local lost=Fixture(3,info);lost.enemyDriver.Step=function()lost.enemy.vehicle=nil;return {},{},false,info end
lost.battle:BeforeStep(.02,command,aim)
Check(lost.weaponCalls.enemy==nil,'removed vehicle remains guarded before recovery')
return {result='PASS',assertions=checks,lua=_VERSION,nativePhysicsTested=false,
 boundary='Actual IntroBattle.BeforeStep and DriverActions with native-free actor doubles; no rendered AI or native physics acceptance.'}
