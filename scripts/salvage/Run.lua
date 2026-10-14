local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local Loot=require 'salvage.Loot'
local Unit=require 'combat.CarUnit'
local Drops=require 'salvage.Drops'
local M={};M.__index=M
function M.Dependencies()
    local parts={}
    for _,variants in pairs(Data.enemies) do for _,def in ipairs(variants) do
        for _,p in ipairs(require('construction.Blueprint').New():Load(def.source):List()) do parts[#parts+1]=p end
    end end
    return require('parts.Dependencies').For(parts)
end
function M.New(session,bp)
    local self=setmetatable({},M);self:init(session,bp);return self
end
function M:init(session,bp)
    self.session=session;self.world=session.world;self.entries={};self.voice={card=nil};self.original=bp:ToTable();self.begun=false
    self.runId=tostring(os.time())..':'..tostring(math.random(1,2147483647));self.feed={}
    self.rules=require('salvage.RunRules').New(self.world.layout.salvage.gameplay,Data.ops[session.app.salvageLobby.data.op or 1])
    self.spawn=self.world.layout.salvage.spawns[math.random(#self.world.layout.salvage.spawns)]
    self.player=Unit.New(self.world,self.original,{name=bp.name,spawn=self.spawn,team='blue',externalView=true,externalControl=true,autoRespawn=false,combat=true})
    assert(self.player.alive,'Invalid salvage vehicle');self:Center(self.player,self.spawn)
    self.world.units={self.player};self.entries[1]={unit=self.player,env=self:Environment(self.player)}
    self.director=require('salvage.Director').New(self);self.view=require('render.SalvageView').New(self)
    self.audio=require('audio.SalvageAudio').New(session.scene)
end
function M:Center(u,at)
    local a,b=u.spec.bounds.min,u.spec.bounds.max;local x,z=(a[1]+b[1])/2,(a[3]+b[3])/2;local yaw=at.yaw or 0
    u.spawnAt={pos={at.pos[1]-x*math.cos(yaw)-z*math.sin(yaw),at.pos[2],at.pos[3]+x*math.sin(yaw)-z*math.cos(yaw)},yaw=yaw}
    u.vehicle:Place(u.spawnAt.pos,yaw);u:SavePose();u.previous=u.current
end
function M:Environment(shooter)
    local world=self.world;local scale=shooter.team=='red' and .7 or 1
    local function Accept(victim) return victim.team~=shooter.team and (victim~=self.player or self.rules.time>=8) end
    return {stats=shooter==self.player and world.stats or {shots=0},killHeight=-300,
        castRay=function(...) return world:CastRay(...) end,lockables=function(body) return world:Lockables(body,shooter.team) end,
        hit=function(hit,damage,dir,impulse,pierce)
            local victim=hit.owner and hit.owner.ref
            if not self.rules.finished and (not victim or not victim.team or Accept(victim)) then
                world.attacker=shooter;world:Hit(hit,damage*scale,dir,impulse,pierce);world.attacker=nil
            end
        end,
        explode=function(point,radius,damage,body) if not self.rules.finished then
            world.attacker=shooter;world:Explode(point,radius,damage*scale,body,Accept);world.attacker=nil
        end end}
end
function M:Begin() if self.begun then return end;self.begun=true;self:Feed('行动开始',self.spawn.name..' · '..self.rules.op.name..' · 15:00') end
function M:Feed(title,text) self.feed[#self.feed+1]={title=title,text=text,at=self.rules.time,untilAt=self.rules.time+7};if #self.feed>5 then table.remove(self.feed,1) end end
function M:BeforeStep(dt,command,aim)
    if not self.begun or self.rules.finished then return end
    for _,entry in ipairs(self.entries) do local u=entry.unit;u:Flush()
        if u.alive then
            local cmd,target,firing=command,aim,command.firing==true
            if u~=self.player then
                if #u.spec.weapons==0 or u.spec.motion.load==0 or u.spec.motion.topSpeed==0 then u.kill='失去武器或移动';u.dirty=true;u:Flush()
                else cmd,target,firing=entry.driver:Step(dt,self.director:Target(entry));if entry.enc and not entry.enc.alerted then firing=false end end
            end
            if u.alive then
                if u==self.player then cmd.strafe=0 end -- E belongs to source salvage interaction.
                local v=u.vehicle;v:StepRotors(target,cmd.rotorStep,dt);require('drive.RotorMotion').Weapons(v.rotors,u.weapons)
                v:Step(cmd,dt);local p,velocity=v.body.translation(),v.body.linvel()
                u.weapons:Step(dt,{firing=firing,aim=target,pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,team=u.team},entry.env)
                self.session.effects:Consume(u.weapons.fx);self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
                if p.y< -300 then u.kill='掉出地图';u.dirty=true;u:Flush() end
            end
        end
    end
end
function M:AfterStep(dt)
    if not self.begun or self.rules.finished then return end
    for i=#self.entries,2,-1 do local e=self.entries[i];local u=e.unit
        if not u.alive then
            self.rules.kills=self.rules.kills+1;self.rules:Heat(2)
            self.rules:AddExtra({id='K'..self.rules.kills,kind='kill',name=u.name,tier=1,g=u:Position(),loot=Drops[e.kind] or Drops.rat})
            self:Feed(u.elite and '击毁精英' or '击毁',u.name..' · 残骸可以拆')
            if e.enc then self.director:Alert(e.enc) end;self.director:Remove(e)
        end
    end
    local u=self.player;local b=u.spec.bounds
    self.rules:Step(dt,{alive=u.alive,pos=u:Position(),speed=u.alive and u.vehicle.speed or 0,width=math.min(b.max[1]-b.min[1],b.max[3]-b.min[3]),
        firing=self.session.firing,hold=self.session.pointer.captured and (self.session.controls.held.interact or input:GetKeyDown(KEY_E)),tap=self.tapE,swap=self.tapF})
    self.tapE=false;self.tapF=false
    self:Events()
    if not self.rules.finished then self.director:Step(dt) end
    self.weigh=(self.weigh or 0)+dt
    if self.weigh>=.5 and u.alive then self.weigh=0;local mass=Loot.Mass(self.rules.cargo)
        if self.weighBody~=u.vehicle.native or self.weighKg~=mass then
            u.vehicle.native.mass=u.vehicle.mass+mass;self.weighBody=u.vehicle.native;self.weighKg=mass
        end
    end
    self.view:Update(dt)
end
function M:Events()
    for _,e in ipairs(self.rules:Drain()) do
        require('ui.SalvageLootMotion').Event(self,e)
        self.audio:Event(e)
        if e.type=='noise' then self.director:Noise(e.at,e.r)
        elseif e.type=='hunt' then self.director:Hunt(e.n,e.at)
        elseif e.type=='crate' then self.view:Crate(e.object)
        elseif e.type=='hide' then self.view:Hide(e.id)
        elseif e.type=='reveal' then
            self.revealed=self.revealed or {};self.revealed[e.item.id]=self.rules.time
            self:Feed(self.rules.search and self.rules.search.title or '搜刮',require('core.ResourceData').Read('UI/Outgame.json').items[e.item.id].name..' × '..e.item.n)
        elseif e.type=='airdrop' then self:Airdrop()
        elseif e.type=='extracted' then self:Finish(true,'从「'..e.exit.name..'」撤离',false,e.exit)
        elseif e.type=='failed' then self:Finish(false,e.reason,false) end
    end
end
function M:Airdrop()
    local p=self.player:Position();local yaw=self.player.vehicle:Yaw();local rand=self.rules.rand
    for _=1,12 do local a=yaw+(rand()-.5)*1.6;local r=160+rand()*100;local at=self.director:Surface(p[1]+math.sin(a)*r,p[3]+math.cos(a)*r,true)
        if at then self.rules:AddExtra({id='AD'..math.floor(self.rules.time),kind='cache',ctype='airdrop',name='空投',tier=3,g=at});self.director:Noise(at,420);self:Feed('空投补给已落地','前方 '..math.floor(r)..' 米 · 保底一件史诗');break end
    end
end
function M:Finish(ok,title,keepCar,exit)
    if self.result then return self.committed end
    local cargo={};for id,n in pairs(self.rules.cargo) do cargo[id]=n end
    if exit and exit.needs then cargo[exit.needs]=cargo[exit.needs]-1;if cargo[exit.needs]==0 then cargo[exit.needs]=nil end end
    local lostCar=0
    if not ok and not keepCar then
        local items=require('core.ResourceData').Read('UI/Outgame.json').items;local need={}
        for _,p in ipairs(self.original.parts) do if p[1]~='core' then local id='part:'..p[1];need[id]=(need[id] or 0)+1 end end
        for id,n in pairs(need) do lostCar=lostCar+(items[id] and items[id].price or 0)*math.min(n,self.session.app.salvageLobby:Owned(id)) end
    end
    self.rules.finished=true;self.result={ok=ok,title=title,keepCar=keepCar,cargo=ok and cargo or {},value=ok and Loot.Value(cargo) or 0,
        lost=not ok and Loot.Value(cargo)+lostCar or 0,time=self.rules.time,kills=self.rules.kills,opened=self.rules.openedCount}
    self.session:Pause();return self:Commit()
end
function M:Commit()
    if self.committed then return true end
    local ok,err=self.session.app.salvageLobby:CommitRun(self.runId,self.result,self.original.parts)
    self.committed=ok;self.saveError=not ok and tostring(err) or nil;return ok
end
function M:Return()
    if not self.result then self:Finish(false,'放弃行动',true);return false end
    return self.committed or self:Commit()
end
function M:Key(key)
    if self.rules.finished then if key==KEY_RETURN then self.session.wantsReturn=true end;return key~=KEY_ESCAPE and key~=KEY_T end
    if key==KEY_E then self.tapE=true;return true end
    if key==KEY_F then self.tapF=true;return true end
    return key==KEY_N or key==KEY_BACKSPACE
end
function M:SyncPlayer() require('combat.PlayerViewSync').Update(self) end
function M:Snapshot() return {time=self.rules.time,heat=self.rules.heat,cargo=self.rules.cargo,used=Loot.Used(self.rules.cargo),mass=Loot.Mass(self.rules.cargo),value=Loot.Value(self.rules.cargo),
    opened=self.rules.openedCount,kills=self.rules.kills,enemies=#self.entries-1,prompt=self.rules.prompt,search=self.rules.search and {title=self.rules.search.title,crack=self.rules.search.crack,done=self.rules.search.done,items=self.rules.search.items},
    extracts=self.rules.extracts,lootPulse=self.lootPulse,flights=#(self.lootFlights or {}),audio=self.audio:Snapshot(),result=self.result,committed=self.committed,saveError=self.saveError} end
function M:Dispose()
    if self.audio then self.audio:Dispose() end
    if self.view then self.view:Dispose() end
    for _,e in ipairs(self.entries) do e.unit:Dispose() end;self.entries={};self.world.units={}
end
return M
