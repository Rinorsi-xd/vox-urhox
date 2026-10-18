local Markers=require 'render.SalvageMarkers'
local Raider=require 'combat.DrillRaiderDriver'
local Rivals=require 'salvage.Rivals'
local Gear=require 'salvage.Gear'
local ImportedDependencies=require("parts.Dependencies")
local SalvageFx=require("render.SalvageFx")
local SalvageExplosion=require("render.SalvageExplosion")
local RunRules=require("salvage.RunRules")
local Director=require("salvage.Director")
local SalvageView=require("render.SalvageView")
local SalvageAudio=require("audio.SalvageAudio")
local Cinematics=require("salvage.Cinematics")
local DriverActions=require("combat.DriverActions")
local RotorMotion=require("drive.RotorMotion")
local SalvageLootMotion=require("ui.SalvageLootMotion")
local ResourceData=require("core.ResourceData")
local PlayerViewSync=require("combat.PlayerViewSync")
local ResultReturn=require("salvage.ResultReturn")

local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local Loot=require 'salvage.Loot'
local Unit=require 'combat.CarUnit'
local Drops=require 'salvage.Drops'
local M={};M.__index=M
function M.Dependencies()
    local parts,seen={},{}
    -- Download lookup depends on type and orientation, not authored cells.
    for _,variants in pairs(Data.enemies) do for _,def in ipairs(variants) do
        for _,row in ipairs(def.source.parts) do
            local key=row[1]..':'..row[5]
            if not seen[key] then seen[key]=true;parts[#parts+1]=row end
        end
    end end
    local paths=ImportedDependencies.FromBlueprint({parts=parts})
    paths[#paths+1]='Shaders/BLGL/Salvage/Signal.shader'
    paths[#paths+1]='Shaders/BLGL/Salvage/PersistentMarker.shader'
    paths[#paths+1]='Shaders/BLGL/Outgame/Alpha.shader'
    paths[#paths+1]='Models/Sphere.mdl'
    for _,path in ipairs(SalvageFx.Dependencies()) do paths[#paths+1]=path end
    for _,path in ipairs(SalvageExplosion.Dependencies()) do paths[#paths+1]=path end;return paths
end
function M.New(session,bp)
    local self=setmetatable({},M);self:init(session,bp);return self
end
function M:init(session,bp)
    self.session=session;self.world=session.world;self.entries={};self.voice={card=nil};self.original=bp:ToTable();self.begun=false
    self.runId=tostring(os.time())..':'..tostring(math.random(1,2147483647));self.feed={}
    self.rules=RunRules.New(self.world.layout.salvage.gameplay,Data.ops[session.app.salvageLobby.data.op or 1])
    self.spawn=self.world.layout.salvage.spawns[math.random(#self.world.layout.salvage.spawns)]
    self.player=Unit.New(self.world,self.original,{name=bp.name,spawn=self.spawn,team='blue',externalView=true,externalControl=true,autoRespawn=false,combat=true})
    assert(self.player.alive,'Invalid salvage vehicle');self:Center(self.player,self.spawn)
    self.world.units={self.player};self.entries[1]={unit=self.player,env=self:Environment(self.player)}
    self.gear=Gear.New(self)
    self.director=Director.New(self)
    for _,station in ipairs({{'R1','北岸船坞维修站',575,430},{'R2','西坡加油站维修站',-665,-30},{'R3','编组场维修站',790,-470}}) do
        local x,z=-station[3],station[4];local at=self.director:Surface(x,z,true) or {x,self.world:GroundAt(x,z),z}
        self.rules.objects[#self.rules.objects+1]={id=station[1],name=station[2],kind='station',g=at}
    end
    self.rivals=Rivals.New(self)
    self.view=SalvageView.New(self)
    self.fx=SalvageFx.New(session.scene)
    self.explosion=SalvageExplosion.New(session.scene)
    self.audio=SalvageAudio.New(session.scene)
    self.cine=Cinematics.New(self);self.markers=Markers.New(self)
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
        castRay=function(...) return world:CastRay(...) end,sweepDrill=function(...) return world:SweepDrill(...) end,lockables=function(body) return world:Lockables(body,shooter.team) end,
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
function M:Begin()
    if self.begun then return end;self.begun=true
    local lobby=self.session.app.salvageLobby
    for _,id in ipairs(self.session.app.salvageGear or {}) do if Gear.CARRY[id] then self.gear.pocket[id]=math.min(Gear.CARRY[id],lobby:Owned(id)) end end
    local ok,err=lobby:BeginRun(self.runId,self.gear.pocket)
    if not ok then self.gear.pocket={} end
    if not ok then print('[SalvageRun] Cannot persist begun raid: '..tostring(err)) end
    self.cine:Drop()
end
function M:Feed(title,text,color)
    local hex=color or '#7ad8ff'
    local tint={tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255}
    self.feed[#self.feed+1]={title=title,text=text,color=tint,at=self.rules.time,untilAt=self.rules.time+7}
    if #self.feed>5 then table.remove(self.feed,1) end
end
function M:UpdateFeedback()
    if self.disposed or not self.pendingBroadcasts then return end
    local now=Time:GetSystemTime()
    local i=1
    while i<=#self.pendingBroadcasts do
        local cue=self.pendingBroadcasts[i]
        if now>=cue.at then self:Feed('全频道广播',cue.text,'#ff3b3b');table.remove(self.pendingBroadcasts,i) else i=i+1 end
    end
end
function M:AdvancePresentationTime(dt)
    if self.disposed or not self.begun or not self.landed then return end
    self.rules.time=self.rules.time+math.max(0,dt)
end
function M:TouchContext()
    local r=self.rules;local prompt=not r.finished and r.prompt
    self.touchPrompt=prompt and not prompt.blocked and prompt or nil
    self.touchSwap=false
    if not r.finished and r.search then
        for _,item in ipairs(r.search.items) do if item.state=='full' then self.touchSwap=true;break end end
    end
end
function M:BeforeStep(dt,command,aim)
    if not self.begun or self.rules.finished then return end
    if self.gear.open then command.firing=false;self.session.firing=false end
    command=self.cine:Command(command)
    if self.cine.hold then self.cine:HoldCar();return end
    for _,entry in ipairs(self.entries) do local u=entry.unit;u:Flush()
        if u.alive and not Raider.StepExplosion(u,dt) then
            local cmd,target,firing=command,aim,command.firing==true;local driverInfo
            if u~=self.player then
                if #u.spec.weapons==0 or u.spec.motion.load==0 or u.spec.motion.topSpeed==0 then
                    entry.why=#u.spec.weapons==0 and '武器全被打掉' or '动不了了';u.kill=entry.why;u.dirty=true;u:Flush()
                else
                    local opponent=self.director:Target(entry)
                    cmd,target,firing,driverInfo=entry.driver:Step(dt,opponent)
                    if entry.enc and not entry.enc.alerted or entry.rival and entry.rival.state~='fight' or self.gear:Hidden() then firing=false end
                    entry.engagingPlayer=opponent==self.player and (firing or driverInfo and driverInfo.visible and entry.driver.canEngage) or false
                end
            end
            if u.alive then
                if u==self.player then cmd.strafe=0 end -- E belongs to source salvage interaction.
                DriverActions.Apply(u,driverInfo)
                local v=u.vehicle;v:StepRotors(target,cmd.rotorStep,dt);RotorMotion.Weapons(v.rotors,u.weapons)
                v:Step(cmd,dt);u:RegenerateStructure(dt);local p,velocity=v.body.translation(),v.body.linvel()
                u.weapons:Step(dt,{firing=firing,aim=target,pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,team=u.team,salvo=driverInfo and driverInfo.salvo},entry.env)
                for _,fx in ipairs(u.weapons.fx) do Raider.ArmExplosion(u,fx) end
                self.session.effects:Consume(u.weapons.fx,u~=self.player);self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
                if p.y< -300 then u.kill='掉出地图';u.dirty=true;u:Flush() end
            end
        end
    end
end
function M:AfterStep(dt)
    if not self.begun or self.rules.finished then self:TouchContext();return end
    if not self.landed then self.cine:HoldCar();return end
    -- Preserve H5 Map insertion order; removal shifts the next actor into this slot.
    local i=2
    while i<=#self.entries do local e=self.entries[i];local u=e.unit
        if not u.alive then
            self.explosion:Explode(u:Position(),math.min(5,(u.spec.bounds.radius or 3)*.8),u.elite)
            self.rules.kills=self.rules.kills+1
            local drops={};for _,row in ipairs(Drops[e.kind] or Drops.rat) do drops[#drops+1]=row end
            for _,row in ipairs(self.rivals:OnKill(e)) do drops[#drops+1]=row end
            local fallen=u:Position();local ground=self.director:Surface(fallen[1],fallen[3],true,fallen[2]+2) or fallen
            self.rules:AddExtra({id='K'..self.rules.kills,kind='kill',name=u.name,elite=u.elite,tier=u.elite and 3 or 1,g=ground,loot=drops})
            self:Feed(u.elite and '击毁精英' or '击毁',u.name..(e.why and ' · '..e.why..'，当场炸了' or '')..' · 残骸可以拆',u.elite and '#ff3420' or '#ff8a6a')
            self.rules:Heat(2)
            if e.enc then self.director:Alert(e.enc,'同伴被打爆') end;self.director:Remove(e)
        else i=i+1 end
    end
    local u=self.player;local b=u.spec.bounds;local pos=u:Position()
    if not self.protectionEnded and self.rules.time+dt>8 then
        self.protectionEnded=true;self:Feed('落地保护结束','附近的清道夫据点会在路上提示','#f0a21c')
    end
    if u.alive then
        if self.lastPos then
            local dx,dz=pos[1]-self.lastPos[1],pos[3]-self.lastPos[3]
            self.speed=math.sqrt(dx*dx+dz*dz)/math.max(.001,dt)
            self.lastPos[1],self.lastPos[2],self.lastPos[3]=pos[1],pos[2],pos[3]
        else self.lastPos={pos[1],pos[2],pos[3]} end
    end
    self.gear:Update(dt)
    self.rules:Step(dt,{stationBlocked=function(o) return self:StationBlocked(o) end,alive=u.alive,pos=pos,speed=self.speed or 0,width=math.min(b.max[1]-b.min[1],b.max[3]-b.min[3]),
        firing=self.session.firing,hold=not self.gear.open and self.session.pointer.captured and (self.session.controls.held.interact or input:GetKeyDown(KEY_E)),tap=not self.gear.open and self.tapE,swap=self.tapF})
    self.tapE=false;self.tapF=false
    self:Events()
    self:TouchContext()
    if not self.rules.finished then self.director:Step(dt);self.rivals:Update(dt) end
    self.weigh=(self.weigh or 0)+dt
    if self.weigh>=.5 and u.alive then self.weigh=0;local mass=Loot.Mass(self.rules.cargo)
        if self.weighBody~=u.vehicle.native or self.weighKg~=mass then
            u.vehicle.native.mass=u.vehicle.mass+mass;self.weighBody=u.vehicle.native;self.weighKg=mass
        end
    end
    self.view:Update(dt);self.markers:Update(dt)
    local search=self.rules.search;local cracking=search and search.crack and search.crack<8
    local target=not self.rules.finished and not self.rules.ex and (cracking and search.o or not search and self.rules.target) or nil
    self.fx:Target(target or nil,self.rules.prompt and self.rules.prompt.progress or 0,cracking)
    self.fx:Update(dt,self.rules.time,self.player:Position())
end
function M:Events()
    for _,e in ipairs(self.rules:Drain()) do
        SalvageLootMotion.Event(self,e)
        self.audio:Event(e)
        if e.type=='emptyBox' then self:Feed(e.title,'空的，被人搜过了','#8a8f98')
        elseif e.type=='repairStation' then
            local back=self.player:RestoreMissing(math.huge);self.player:Heal(1);self.player:Flush();self:SyncPlayer()
            self:Feed(e.object.name,'全车修满 · 修回 '..#back..' 块方块 · 用掉 1 个能量电池','#3ddc84')
        elseif e.type=='noise' then self.director:Noise(e.at,e.r);self.rivals:Noise(e.at,e.r)
        elseif e.type=='hunt' then self.director:Hunt(e.n,e.at)
        elseif e.type=='crate' then self.view:Crate(e.object)
        elseif e.type=='hide' then self.view:Hide(e.id)
        elseif e.type=='reveal' then
            if not e.worldBatch and (e.item.r or 0)>=4 then
                if self.fx then self.fx:Reveal(e) end
                self.session.trauma=math.max(self.session.trauma or 0,e.item.r>=5 and .55 or .32)
                if e.item.r>=5 then
                    local o=self.rules.search and self.rules.search.o or {}
                    local item=ResourceData.Read('UI/Outgame.json').items[e.item.id]
                    self.pendingBroadcasts=self.pendingBroadcasts or {}
                    self.pendingBroadcasts[#self.pendingBroadcasts+1]={at=Time:GetSystemTime()+1200,
                        text='有人在'..(o.poi or '附近')..'开出了「'..item.name..'」！各帮派都在往这边赶'}
                end
            end
            self.revealed=self.revealed or {};self.revealed[e.item.id]=self.rules.time
            if not e.worldBatch then self:Feed(self.rules.search and self.rules.search.title or '搜刮',ResourceData.Read('UI/Outgame.json').items[e.item.id].name..' × '..e.item.n) end
        elseif e.type=='wreckLoot' then
            local items=ResourceData.Read('UI/Outgame.json').items
            local function Names(list)
                local out={};for _,row in ipairs(list) do out[#out+1]=items[row[1]].name..'×'..row[2] end;return table.concat(out,'、')
            end
            if #e.items>0 then self:Feed(e.title,Names(e.items),e.core and '#ffb21e' or '#c9c1b2')
            elseif e.empty then self:Feed(e.title,'空的，被人搜过了','#8a8f98') end
            if #e.left>0 then self:Feed('货舱满了',Names(e.left)..' 装不下，丢在原地','#ff6a4d') end
        elseif e.type=='cargoPickup' then
            local mass=0;local items=ResourceData.Read('UI/Outgame.json').items
            for _,row in ipairs(e.items) do mass=mass+(items[row[1]].mass or 1)*row[2] end
            if self.session.stompV~=nil then self.session.stompV=self.session.stompV-math.min(1.6,.25+mass/40) end
        elseif e.type=='cargoDropped' then
            local names={};local items=ResourceData.Read('UI/Outgame.json').items
            for _,row in ipairs(e.items) do names[#names+1]=items[row[1]].name..' × '..row[2] end
            self:Feed('丢掉',table.concat(names,'、')..' 丢在了原地')
        elseif e.type=='worldLoot' then if self.fx then self.fx:Loot(e.at,e.color,e.n) end
        elseif e.type=='airdrop' then self:Airdrop()
        elseif e.type=='vaultStart' then self.cine:NameCard('舰载保险库 · 破解中','整片区域都收到了信号 · 清道夫正在赶来',3)
        elseif e.type=='vaultOpened' then
            local color=ResourceData.Read('UI/Outgame.json').rarity[e.rarity+1].color
            self.fx:Loot(e.at,tonumber(color:sub(2),16),1);self.cine:Flash(.2,.4)
            self.session.trauma=math.max(self.session.trauma or 0,.3)
        elseif e.type=='core' then self.cine:Flash(.3,.6);self.cine:NameCard('核心件已拆下','动静太大 · 附近的清道夫都听见了',2.4)
        elseif e.type=='extractApproach' then
            self.cine:Approach(e.exit,e.wait)
            self:Feed('撤离中',e.exit.name..' · 待在圈里 '..math.ceil(e.wait)..' 秒，运输机正在赶来','#3ddc84')
        elseif e.type=='extractSignal' then self.cine:NameCard('信号塔已呼叫','整片峡谷都听见了 · 坚持 20 秒',3)
        elseif e.type=='extracted' then self.cine:Extract(e.exit)
        elseif e.type=='failed' then
            if not self.player.alive then
                self:Feed('战车被击毁','信号丢失……','#ff3420')
                if self.explosion then self.explosion:Explode(self.player:Position(),3.5,true) end
                self.cine:Death()
            else self:Finish(false,e.reason,false) end
        end
    end
end
function M:Airdrop()
    local p=self.player:Position();local yaw=self.player.vehicle:Yaw();local rand=self.rules.rand
    for _=1,12 do local a=yaw+(rand()-.5)*1.6;local r=160+rand()*100;local at=self.director:Surface(p[1]+math.sin(a)*r,p[3]+math.cos(a)*r,true)
        if at then
            self.rules:AddExtra({id='AD'..math.floor(self.rules.time+.5),kind='cache',ctype='airdrop',name='空投',tier=3,g=at})
            self.fx:Loot(at,0x3ee6ff,0)
            self.cine:NameCard('空投补给已落地','前方 '..math.floor(r+.5)..' 米 · 冒青烟的地方 · 附近的帮派也看见了',3.2)
            self:Feed('空投','保底一件史诗 · 先到先得','#3ee6ff');self.audio:Event({type='airdropLanded'});self.director:Noise(at,420);break
        end
    end
end
function M:Finish(ok,title,keepCar,exit,disposing)
    if self.result then return self.committed end
    if self.cine.playing then
        self.cine:ReleaseCar();self.cine.current=nil;self.cine.playing=false;self.cine.blocking=false;self.cine.barsOn=false;self.cine.skipOn=false;self.cine.captionTitle=nil
        if self.cine.filter then self.cine.filter:Dispose();self.cine.filter=nil end
    end
    local cargo={};for id,n in pairs(self.rules.cargo) do cargo[id]=n end
    if exit and exit.needs then cargo[exit.needs]=cargo[exit.needs]-1;if cargo[exit.needs]==0 then cargo[exit.needs]=nil end end
    local lostCar=0
    if not ok and not keepCar then
        local items=ResourceData.Read('UI/Outgame.json').items;local need={}
        for _,p in ipairs(self.original.parts) do if p[1]~='core' then local id='part:'..p[1];need[id]=(need[id] or 0)+1 end end
        for id,n in pairs(need) do lostCar=lostCar+(items[id] and items[id].price or 0)*math.min(n,self.session.app.salvageLobby:Owned(id)) end
    end
    self.rules.finished=true;self.result={ok=ok,title=title,keepCar=keepCar,cargo=ok and cargo or {},value=ok and Loot.Value(cargo) or 0,
        pocket=self.gear.pocket,lost=not ok and Loot.Value(cargo)+lostCar or 0,time=self.rules.time,kills=self.rules.kills,opened=self.rules.openedCount}
    -- Source consumes the extraction token before showing cargo; failure clears
    -- the hold. Keep the finished world's inventory equal to its retained result.
    self.rules.cargo=self.result.cargo
    self.returnDelay=.25
    if not disposing then self.session:Pause() end
    return self:Commit()
end
function M:Commit()
    if self.committed then return true end
    local ok,err=self.session.app.salvageLobby:CommitRun(self.runId,self.result,self.original.parts)
    self.committed=ok;self.saveError=not ok and tostring(err) or nil;return ok
end
function M:Return()
    local abandoned=not self.result
    if abandoned then self:Finish(false,'放弃行动',true) end
    ResultReturn.Queue(self,abandoned and .2 or 0)
    return true
end
function M:Key(key)
    if self.gear:Key(key) then return true end
    if self.cine.blocking then
        if key==KEY_SPACE then self.cine:Skip() end
        return key~=KEY_ESCAPE and key~=KEY_T
    end
    if self.rules.finished then if key==KEY_RETURN then self.session.wantsReturn=true end;return key~=KEY_ESCAPE and key~=KEY_T end
    if key==KEY_E then
        if self.gear.open then self.gear:Tap()
        elseif self.rules.search or self.rules:Target(self.player:Position()) then self.tapE=true
        else self.gearPress={at=Time:GetSystemTime()} end
        return true
    end
    if key==KEY_F then self.tapF=true;return true end
    return key==KEY_N or key==KEY_BACKSPACE
end
function M:PollGear()
    if not self.gearPress then return end
    if not input:GetKeyDown(KEY_E) then
        local elapsed=Time:GetSystemTime()-self.gearPress.at;self.gearPress=nil
        if elapsed<220 and not self.rules.ex and not self.cine.blocking and self.session.pointer.captured then self.gear:Tap() end
    end
end
function M:StationBlocked(o)
    if self.player:Life()>.999 and not self.gear:Missing() then return '车况完好，用不着' end
    if (self.rules.cargo.cell or 0)<1 then return '需要 1 个能量电池' end
    if math.abs(self.player.vehicle.speed)>2 then return '停稳了才能修' end
end
function M:SyncPlayer() PlayerViewSync.Update(self) end
function M:Snapshot() return {time=self.rules.time,heat=self.rules.heat,cargo=self.rules.cargo,used=Loot.Used(self.rules.cargo),mass=Loot.Mass(self.rules.cargo),value=Loot.Value(self.rules.cargo),
    opened=self.rules.openedCount,kills=self.rules.kills,enemies=#self.entries-1,prompt=self.rules.prompt,search=self.rules.search and {title=self.rules.search.title,crack=self.rules.search.crack,done=self.rules.search.done,items=self.rules.search.items},
    extracts=self.rules.extracts,objective=self.hudObjective,threat=self.threat,lootPulse=self.lootPulse,flights=#(self.lootFlights or {}),audio=self.audio:Snapshot(),cine=self.cine:Snapshot(),result=self.result,committed=self.committed,saveError=self.saveError} end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.begun and not self.result and not self.rules.finished then
        -- H5 dispose treats F5/scene replacement as abandonment as well.
        self:Finish(false,'放弃行动',true,nil,true);ResultReturn.Queue(self,.2)
    elseif self.result then
        ResultReturn.Queue(self,0)
    end
    self.pendingBroadcasts=nil
    -- Cinematics must release the held Bullet body before units/world go away.
    if self.cine then self.cine:Dispose() end
    if self.audio then self.audio:Dispose() end
    if self.markers then self.markers:Dispose() end
    if self.view then self.view:Dispose() end
    if self.fx then self.fx:Dispose() end
    if self.explosion then self.explosion:Dispose() end
    for i=#self.entries,1,-1 do local e=self.entries[i];e.unit:Dispose();e.unit=nil;e.env=nil;e.driver=nil;e.enc=nil;self.entries[i]=nil end
    if self.world then self.world.units={} end
    if self.director then
        for _,enc in ipairs(self.director.encounters) do enc.units={};enc.left=nil end
        self.director.entries={};self.director.encounters={};self.director.run=nil;self.director.world=nil
    end
    self.director=nil;self.cine=nil;self.audio=nil;self.view=nil;self.fx=nil;self.explosion=nil
    if self.gear then self.gear.run=nil end
    if self.rivals then self.rivals.run=nil;self.rivals.squads={} end
    self.markers=nil;self.gear=nil;self.rivals=nil
    self.weighBody=nil;self.lastPos=nil;self.player=nil;self.world=nil;self.session=nil
end
return M
