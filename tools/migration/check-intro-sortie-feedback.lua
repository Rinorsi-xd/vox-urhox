-- Real opening UI, shared damage aggregation and sortie transitions; native boundaries doubled.
package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(value,label)assert(value,label);checks[#checks+1]=label end
local function Noop()end
local function Panel()
 local p={children={}}
 function p:AddChild(child)self.children[#self.children+1]=child end
 function p:Destroy()self.destroyed=true;for _,child in ipairs(self.children)do child:Destroy()end end
 return p
end
package.loaded['urhox-libs/UI']={Panel=Panel,GetViewportSize=function()return 1600,900 end}
package.loaded['ui.MechReticle']=function()local p=Panel();p.Render=Noop;return p end
package.loaded['ui.DriveFeedback']=function()local p=Panel();function p:Render()self.rendered=true end;return p end
package.loaded['ui.SourceDraw']={}
package.loaded['core.Coord']={Vec=function(x,y,z)return{x=x,y=y,z=z}end}
package.loaded['ui.ReticleState']={Update=function(r,dt)r.clock=(r.clock or 0)+dt end,
 Layout=function(w,h)return{k=1,cx=w/2,cy=h/2,width=w,height=h}end}
package.loaded['ui.ReticleTarget']={Update=Noop}
package.loaded['combat.CarUnit']={};package.loaded['combat.EnemyDriver']={}
local player={alive=true,externalView=true,team='blue',bp={Size=function()return 10 end},
 Position=function()return{0,0,0}end,Life=function()return 1 end,rawHpMax=100,partScale=1}
local enemy={alive=true,externalView=true,team='red',name='enemy',spec={},
 bp={Size=function()return 10 end},Position=function()return{0,0,30}end}
local calls={};local audio={}
for _,name in ipairs({'Hit','Kill','ScoreTick'})do audio[name]=function(_,...)calls[#calls+1]={name=name,args={...}}end end
local session={combat={player=player},pointer={captured=true},feedbackAudio=audio,
 world={units={player,enemy},metrics=require('drive.TrialMetrics').New({}),time=0,viewEvents={}},
 camera={GetNode=function()return{position={x=0,y=0,z=0},WorldToLocal=function(_,p)return p end}end},
 ConfirmKill=function(_,target)calls[#calls+1]={name='ConfirmKill',target=target}end}
local ui=require('ui.IntroSortieUi').New(session)
Check(session.openingOverlay==ui.overlay and ui.overlay~=nil,'opening binds shared battle feedback without replacing application HUD')
ui.overlay.Project=function()return 800,350 end
ui.overlay.AimMarker=function()return'ok'end
local battle=setmetatable({session=session,world=session.world},require('intro.IntroBattle'))
session.world.viewEvents={{type='unitDamaged',unit=player,amount=10,point={1,0,0}}}
battle:AfterStep()
Check(#ui.overlay.feedback.hits==1,'real IntroBattle consumes damage direction before shared world view clears events')
session.world.metrics:Damage(0,enemy,25,{0,0,30},false)
ui:Update(.26)
Check(ui.reticle.hit>0 and not ui.reticle.killed,'real enemy damage drives reticle hit marker')
Check(ui.overlay.pops[1].amount==25 and ui.overlay.pops[1].t<1,'shared damage accumulation produces real pooled damage number')
Check(calls[1].name=='Hit' and calls[1].args[1]=='hit','damage invokes shared hit confirmation audio')
ui:Update(.31)
Check(ui.reticle.hit==0,'hit marker retires on the opening update clock')
enemy.alive=false;session.world.metrics:Damage(1,enemy,10,{0,0,30},true)
ui:Update(.01)
Check(ui.reticle.killed and ui.reticle.hit>0,'kill upgrades reticle confirmation')
Check(ui.overlay.feedback.score.target==300 and #ui.overlay.feedback.cubes==22,'kill creates original score and cube feedback')
Check(calls[#calls].name=='ConfirmKill' and calls[#calls].target==enemy,'kill routes existing impact feedback')
Check(calls[#calls-1].name=='Kill','kill routes existing confirmation sound')
local owned=session.openingOverlay;ui:Dispose()
Check(session.openingOverlay==nil and ui.root.destroyed and ui.reticle.destroyed,'opening disposes feedback widgets and clears session reference')
ui=require('ui.IntroSortieUi').New(session);session.openingOverlay={replacement=true};ui:Dispose()
Check(session.openingOverlay.replacement,'late UI disposal preserves replacement owner')
local oldTarget=package.loaded['ui.ReticleTarget'];package.loaded['ui.ReticleTarget']=nil
session.camera.GetCamera=function()return{}end
session.weapons={LockInfo=function()return nil end}
ui=require('ui.IntroSortieUi').New(session);player.alive=false;session.vehicle=nil
local stateUpdate=package.loaded['ui.ReticleState'].Update
package.loaded['ui.ReticleState'].Update=function()error('dead reticle must not read the disposed player vehicle')end
ui:Update(.1)
Check(ui.overlay.focus==nil and ui.overlay.aim.visible==false,'real ReticleTarget/DriveOverlay continue safely after player vehicle disposal')
ui:Dispose();player.alive=true;package.loaded['ui.ReticleState'].Update=stateUpdate;package.loaded['ui.ReticleTarget']=oldTarget
package.loaded['app.SceneLoader']={New=function()return{Update=Noop}end}
package.loaded['construction.Blueprint']={}
package.loaded['controls.DriveAim']={Look=function()return .5 end}
for i=0,9 do _G['KEY_'..i]='digit-'..i end;KEY_ESCAPE='escape'
local pressed=KEY_2;input={GetKeyPress=function(_,key)return key==pressed end}
local host=require('app.OpeningHost').New({});local commands,selections,ticks,feedbackUpdates=0,{},0,0
local drivingCommand
local driving={scope=false,yaw=0,pitch=0,vehicle={spec={wings={}}},
 combat={player={alive=true}},pointer={captured=true,Poll=Noop},
 controls={Read=function()return{throttle=1,steer=0}end,TakeLook=function()return 4,5 end,
  Command=function(_,command,vehicle,yaw,pitch)commands=commands+1;command.aimYaw=yaw;command.aimPitch=pitch end},
 weapons={Group=function()return{kind='laser'}end,Select=function(_,index)selections[#selections+1]=index end},
 Tick=function(_,dt,command)ticks=ticks+1;Check(dt<=.05,'opening retains bounded shared fixed-step delta');drivingCommand=command end}
host.state.session=driving;host.state.activeScene='crater';host.state.sortieUi={Update=function()feedbackUpdates=feedbackUpdates+1 end}
host.Update(.02,{ready=true,playing=true})
Check(commands==1 and selections[1]==2 and drivingCommand.throttle==1,'real OpeningHost sends source command actions and number-key weapon selection')
Check(math.abs(drivingCommand.aimYaw+4*.0024*.5)<1e-10 and math.abs(drivingCommand.aimPitch+5*.002*.5)<1e-10,'opening aim command uses the same yaw/pitch signs and slowed look sensitivity')
driving.pointer.captured=false;host.Update(.02,{ready=true,playing=true})
Check(commands==1 and #selections==1 and drivingCommand.throttle==0 and drivingCommand.handbrake,'lost capture prevents action/weapon selection and delivers neutral command')
driving.pointer.captured=true;driving.combat.player.alive=false;host.Update(.02,{ready=true,playing=true})
Check(commands==1 and ticks==3 and feedbackUpdates==3,'dead player never receives vehicle command while feedback/world lifecycle still advances')
local state={controlling=true,pos={0,0,0},enemyHit=false,playerAlive=true}
local trace={};local intro={time=0,audio={Sfx=function(_,id)trace[#trace+1]=id end},host={
 SortieStatus=function()return state end,
 SortieHit=function(mine)trace[#trace+1]=mine and 'player-kill' or 'timeout-kill' end,
 SortieStep=function(step)trace[#trace+1]='step-'..step end}}
local Sortie=require 'intro.IntroSortie'
for _,mine in ipairs({true,false})do
 local sortie=Sortie.New(intro);sortie:Update(0);state.pos={0,0,19};sortie:Update(.1);sortie:Update(.5)
 state.enemyHit=mine;intro.time=42;sortie:Update(mine and .1 or 15)
 Check(sortie.pending==3 and sortie.mine==mine and sortie.killAt==42,'source kill begins immediately before success hold: '..tostring(mine))
 Check(trace[#trace-2]==(mine and 'player-kill' or 'timeout-kill') and trace[#trace-1]=='slam','source kill cue precedes success confirmation: '..tostring(mine))
 sortie:Update(.49);Check(sortie.step==2,'success hold remains visible: '..tostring(mine))
 sortie:Update(.02);Check(sortie.step==3,'reinforcement clock follows half second success hold: '..tostring(mine))
 state.pos={0,0,0};state.enemyHit=false
end
return{count=#checks,checks=checks}
