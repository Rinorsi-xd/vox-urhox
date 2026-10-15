-- Source opening actors run through the shared damage, weapons and rigid bodies.
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local M={};M.__index=M
function M.New(session,data,playerSource,checkpoint)
 local self=setmetatable({session=session,world=session.world,entries={},voice={card=nil},damageScale=.12,stage=0},M)
 if session.practice then session.practice:Dispose();session.practice=nil end
 session.combat=self
 local w=self.world
 for _,u in ipairs(w.units) do u:Dispose() end;w.units={};w.viewEvents={}
 local function Add(source,name,x,z,yaw,team,role,external)
  local u=Unit.New(w,source,{name=name,spawn={pos={x,w:GroundAt(x,z)+1.5,z},yaw=yaw},team=team,externalControl=true,externalView=external,autoRespawn=false,combat=true})
  assert(u.alive,'Invalid opening actor '..name)
  local e={unit=u,env=self:Environment(u)};if role then e.driver=Driver.New(w,u,role,#self.entries+1) end
  w.units[#w.units+1]=u;self.entries[#self.entries+1]=e
  if checkpoint then checkpoint(#self.entries/9,'intro-actors') end
  return u
 end
 self.player=Add(playerSource,'坠舰陨坑 · 实机演示',62,-176,0,'blue',nil,true)
 w.feedbackPlayer=self.player
 for _,cfg in ipairs(require('intro.IntroShots').Cast(data,function(x,z)return w:GroundAt(x,z) end)) do
  Add(cfg.source,cfg.name,cfg.spawn.pos[1],cfg.spawn.pos[3],cfg.spawn.yaw,'red',data.actors.invaders[#self.entries].role,false)
 end
 self.cart=Add(data.actors.cart,'星际前途 · 贵重矿车',30,-170,math.pi/2,'blue',nil,false)
 self.easy=self.entries[6].unit;self.easy.damageMultiplier=8
 self.easy.vehicle:Place({66,w:GroundAt(66,-130)+1.5,-130},math.pi)
 return self
end
function M:Environment(shooter)
 local w=self.world
 local function Scale(victim) return victim==self.player and self.damageScale or victim.damageMultiplier or victim.team=='red' and 2 or 1 end
 return {stats=w.stats,killHeight=-80,castRay=function(...)return w:CastRay(...) end,sweepDrill=function(...)return w:SweepDrill(...) end,
  lockables=function(body)return w:Lockables(body,shooter.team) end,
  hit=function(hit,damage,dir,impulse,pierce)
   local victim=hit.owner and hit.owner.type=='car' and hit.owner.ref
   if victim and victim.team==shooter.team then return end
   w.attacker=shooter;w:Hit(hit,damage*(victim and Scale(victim) or 1),dir,impulse,pierce);w.attacker=nil
  end,
  explode=function(point,radius,damage,body)
   -- Every victim has its own authored incoming multiplier; avoid scaling a
   -- whole splash by the shooter's team, which makes the player invulnerable.
   for _,entry in ipairs(self.entries) do local victim=entry.unit
    if victim.alive and victim.team~=shooter.team then
     w.attacker=shooter;w:Explode(point,radius,damage*Scale(victim),body,function(u)return u==victim end);w.attacker=nil
    end
   end
  end}
end
function M:BeforeStep(dt,command,aim)
 for _,e in ipairs(self.entries) do local u=e.unit;u:Flush()
  if u.alive then
   local cmd,target,firing={throttle=0,steer=0,handbrake=true},u:Position(),false
   if u==self.player then cmd=command;target=aim;firing=command.firing==true
   elseif e.driver and self.stage>0 then
    local victim=(self.stage>=3 or u==self.easy and self.stage>=1) and self.player or self.cart
    cmd,target,firing=e.driver:Step(dt,victim,true)
   end
   if u.vehicle then
    local v=u.vehicle;v:StepRotors(target,cmd.rotorStep,dt);require('drive.RotorMotion').Weapons(v.rotors,u.weapons);v:Step(cmd,dt)
    local p,vel=v.body.translation(),v.body.linvel();local eye=u==self.player and self.session.camera:GetNode().worldPosition
    u.weapons:Step(dt,{firing=firing,aim=target,pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={vel.x,vel.y,vel.z},body=v.body,team=u.team,eye=eye and {-eye.x,eye.y,eye.z}},e.env)
    self.session.effects:Consume(u.weapons.fx);self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
   end
  end
 end
end
function M:AfterStep() end
function M:SyncPlayer() require('combat.PlayerViewSync').Update(self) end
function M:Kill(u)
 if not u or not u.alive then return end
 local p=u:Position();u.bodyHp=0;u.kill='intro';u.dirty=true;u:Flush()
 self.world.fx[#self.world.fx+1]={type='explode',pos=p,radius=4}
end
function M:Dispose() if self.montage then self.montage:Dispose();self.montage=nil end;self.entries={} end
return M
