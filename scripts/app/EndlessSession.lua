local ImportedDependencies=require("parts.Dependencies")
local Audio=require("endless.Audio")
local SpawnSpecCache=require("drive.SpawnSpecCache")
local View=require("endless.View")
local SpawnPresentation=require("endless.SpawnPresentation")
local VehicleSpec=require("drive.VehicleSpec")
local DriverActions=require("combat.DriverActions")
local RotorMotion=require("drive.RotorMotion")
local EndlessBanner=require("ui.EndlessBanner")
local Defs=require("parts.Defs")
local Records=require("endless.Records")
local NodeVisibility=require("render.NodeVisibility")
local PlayerViewSync=require("combat.PlayerViewSync")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local Data=require('endless.Data')
local C=Data.config
local Run=require('endless.Run')
local Unit=require('combat.CarUnit')
local Driver=require('combat.EnemyDriver')
local Raider=require('combat.DrillRaiderDriver')
local Query=require('combat.ShieldQuery')
local V=require('core.Math3')
local BP=require('construction.Blueprint')
local M={};M.__index=M
local PARK={throttle=0,steer=0,handbrake=true}
local function Center(spec,at)
    local lo,hi=spec.bounds.min,spec.bounds.max;local x,z=(lo[1]+hi[1])/2,(lo[3]+hi[3])/2;local yaw=at.yaw or 0
    return {pos={at.pos[1]-x*math.cos(yaw)-z*math.sin(yaw),at.pos[2],at.pos[3]+x*math.sin(yaw)-z*math.cos(yaw)},yaw=yaw}
end
local function Radius(spec) return math.sqrt((spec.bounds.max[1]-spec.bounds.min[1])^2+(spec.bounds.max[3]-spec.bounds.min[3])^2)/2 end
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function M.Dependencies(bp)
    local parts=bp and bp:List() or {};local seen={}
    for _,source in pairs(Data.prefabs) do for _,p in ipairs(BP.New():Load(source):List()) do if not seen[p.type] then parts[#parts+1]=p;seen[p.type]=true end end end
    local out=ImportedDependencies.For(parts);out[#out+1]='Shaders/BLGL/Combat/Objective.shader';for _,path in ipairs(Audio.Dependencies()) do out[#out+1]=path end;return out
end
function M.New(session,bp,saved)
    local self=setmetatable({},M);self:init(session,bp,saved);return self
end
function M:init(session,bp,saved)
    self.session=session;self.world=session.world;self.entries={};self.pending={};self.spawnSerial=0;self.repairClock=0;self.invulnerableUntil=self.world.time+C.spawnInvulnerability
    self.rules=Run.New(bp,session.map.endlessSeed or os.time(),saved or session.map.endlessSaved);self.run=self.rules;self.spawnRadii={};self.spawnSpecCache=SpawnSpecCache.New();self.banner=nil;self.voice={card=nil};self.audio=Audio.New(session.scene)
    self.shield=assert(self.world.layout.base and self.world.layout.base.shield,'Endless requires crater base shield')
    self.spawn=self.world.layout.spawn or self.world.layout.pads.player
    for _,u in ipairs(self.world.units) do u:Dispose() end;self.world.units={}
    self.player=Unit.New(self.world,self.run.blueprint,{name=bp.name,spawn=self.spawn,team='blue',autoRespawn=false,externalControl=true,externalView=true,combat=true})
    assert(self.player.alive,'Invalid endless player');self.player.spawnAt=Center(self.player.spec,self.spawn);self.player.vehicle:Place(self.player.spawnAt.pos,self.player.spawnAt.yaw);self.player:SavePose();self.player.previous=self.player.current
    self.world.units[1]=self.player;self.entries[1]={unit=self.player,env=self:Environment(self.player)}
    self.baseDamage=self.world.RecordDamage;self.world.RecordDamage=function(world,u,amount,point,opts)
        if amount>0 then if u==self.player then self.run:PlayerHit() else self.run:RecordDamage(amount) end end
        self.baseDamage(world,u,amount,point,opts)
    end
    self.shieldTarget={active=self.run.shield.hp>0,pos=self.shield.pos,zone=self.shield,
        contains=function(at) return Query.Contains(self.shield,at) end,
        aimPoint=function(from)
            local pos=self.shield.pos;local to={pos[1],pos[2]+8,pos[3]};local delta=V.Sub(to,from);local length=V.Length(delta)
            if length<.000001 then return to end
            local hit=Query.Ray(self.shield,from,V.Scale(delta,1/length),length);return hit and hit.point or to
        end}
    self.view=View.New(session.scene,self.shield)
    self.spawnPresentation=SpawnPresentation.New();self.spawnPresentation:Rise(self.world.time);self:Events()
end
function M:Environment(unit)
    local world=self.world;local function EnemyScale() return unit.endless and unit.endless.damageScale or 1 end
    local function Cast(fn,...)
        local from,dir,len=...;local hit=fn(world,...)
        if unit~=self.player and self.run.shield.hp>0 then local shield=Query.Ray(self.shield,from,dir,len)
            if shield and (not hit or shield.dist<=hit.dist) then shield.owner={type='endlessShield'};return shield end
        end;return hit
    end
    local function Protected(u) return u==self.player and (world.time<self.invulnerableUntil or self.run.shield.hp>0 and Query.Contains(self.shield,u:Position())) end
    return {stats=unit==self.player and world.stats or {shots=0},killHeight=-80,
        castRay=function(...) return Cast(world.CastRay,...) end,
        sweepDrill=function(...) return Cast(world.SweepDrill,...) end,
        lockables=function(body) return world:Lockables(body,unit.team) end,
        hit=function(hit,damage,dir,impulse,pierce)
            if self.run.state=='over' or self.run.state=='editing' then return end
            local owner=hit.owner;local amount=damage*EnemyScale()
            if owner and owner.type=='endlessShield' then self.run:ShieldHit(amount,hit.point);return end
            local target=owner and owner.ref
            if target and target.team==unit.team then return end
            if target==self.player and self.run.shield.hp>0 and Query.Contains(self.shield,self.player:Position()) then self.run:ShieldHit(amount,hit.point);return end
            if target and Protected(target) then return end
            world.attacker=unit;world:Hit(hit,amount,dir,impulse,pierce);world.attacker=nil
        end,
        explode=function(point,radius,damage,body)
            if self.run.state=='over' or self.run.state=='editing' then return end
            if unit~=self.player and self.player.alive and self.run.shield.hp>0 and Query.Contains(self.shield,self.player:Position()) then
                local delta=V.Sub(self.player:Position(),point);local len=V.Length(delta);local dir=V.Scale(delta,1/math.max(.0001,len));local hit=Query.Ray(self.shield,point,dir,radius)
                local blocker=hit and world:CastRay(point,dir,hit.dist,body)
                if hit and (not blocker or blocker.dist>=hit.dist) then self.run:ShieldHit(damage*EnemyScale(),hit.point) end;return
            end
            world.attacker=unit;world:Explode(point,radius,damage*EnemyScale(),body,function(u) return u.team~=unit.team and not Protected(u) end);world.attacker=nil
        end}
end
function M:SpawnRadius(key,source)
    local radius=self.spawnRadii[key]
    if not radius then
        self.spawnSpecCache:Prepare(source)
        local spec=self.spawnSpecCache:Get(source) or VehicleSpec.Build(BP.New():Load(source))
        radius=Radius(spec);self.spawnRadii[key]=radius
    end
    return radius
end
function M:Spawn()
    local r=self.run;local nextMeta=r.queue[1]
    if r.state~='combat' or not nextMeta or Count(r.alive)>=C.maxEnemies or r.time<r.nextSpawn then return end
    local key=nextMeta.prefab or (nextMeta.role..':'..nextMeta.tier..':'..nextMeta.variant)
    local source=assert(Data.prefabs[key],'Missing endless prefab '..key)
    local radius=self:SpawnRadius(key,source)
    local gates={};for _,g in ipairs(self.world.layout.enemyGates or {}) do if nextMeta.role=='boss' and g.id=='N' or nextMeta.role~='boss' and (r.wave>=C.airdropFromWave or not g.drop) then gates[#gates+1]=g end end
    if #gates==0 then return end
    local gate
    for i=1,#gates do local g=gates[(self.spawnSerial+i-1)%#gates+1];local free=true
        for _,u in ipairs(self.world.units) do if u.alive and Flat(g.pos,u:Position())<radius+1+Radius(u.spec) then free=false;break end end
        for _,p in ipairs(self.pending) do if Flat(p.gate.pos,g.pos)<(radius+1)*2 then free=false end end
        if free then gate=g;break end
    end
    if not gate then return end;local meta=r:TakeSpawn();if not meta then return end;self.spawnSerial=self.spawnSerial+1
    if gate.drop then self.pending[#self.pending+1]={meta=meta,gate=gate,at=r.time+C.airdropWarning};self.view:Warn(meta.id,gate.pos)
    else self:SpawnUnit(meta,gate,false) end
end
function M:SpawnUnit(meta,gate,air)
    local key=meta.prefab or (meta.role..':'..meta.tier..':'..meta.variant);local source=Data.prefabs[key]
    self:SpawnRadius(key,source)
    local pos={table.unpack(gate.pos)};if air then pos[2]=pos[2]+C.airdropHeight end
    local u=Unit.New(self.world,source,{name=(meta.elite and '★ 精英 ' or '')..source.name,spawn={pos=pos,yaw=gate.yaw or 0},team='red',autoRespawn=false,externalControl=true,combat=true,hpMultiplier=meta.hpScale,spawnSpecCache=self.spawnSpecCache})
    u.spawnAt=Center(u.spec,{pos=pos,yaw=gate.yaw or 0});u.vehicle:Place(u.spawnAt.pos,u.spawnAt.yaw);u:SavePose();u.previous=u.current;u.endless=meta;u.airdropActive=air;u.airdropStableTime=0
    local driver=meta.prefab=='huhu-fuyuan' and Raider or Driver
    self.world.units[#self.world.units+1]=u;self.entries[#self.entries+1]={unit=u,env=self:Environment(u),driver=driver.New(self.world,u,meta.role,self.spawnSerial,{aimSkill=1,reaction=.25})}
end
function M:Airdrop(u,dt)
    if not u.airdropActive or not u.alive then return end
    local v=u.vehicle;local vel=v.body.linvel();local q=v.body.rotation();local contact=(v.telemetry.hoverSupport or 0)>.5
    for _,w in ipairs(v.wheels) do if v.vc.wheelIsInContact(w.index) then contact=true end end
    local legs=(v.legControl or v.mechControl) and #v.wheels==0
    if legs and math.abs(vel.y)<.5 then contact=true end
    local stable=contact and math.abs(vel.y)<2 and 1-2*(q.x*q.x+q.z*q.z)>.8
    u.airdropStableTime=stable and u.airdropStableTime+dt or 0
    if u.airdropStableTime>=C.airdropLandingStableTime or v.capabilities and v.capabilities.totalLoad==0 then u.airdropActive=false;v.airdropActive=false;return end
    local near=contact;for _,w in ipairs(v.wheels) do
        local p=v.vc.wheelHardPoint(w.index);if p and self.world.space:Raycast({p.x or p[1],p.y or p[2],p.z or p[3]},{0,-1,0},(w.rest or 0)+(w.radius or 0)+C.airdropBrakingHeight,v.body,nil,true) then near=true end
    end
    v.airdropActive=true;local limit=near and C.airdropLandingFallSpeed or C.airdropMaxFallSpeed
    if vel.y< -limit then v.body.setLinvel({x=vel.x,y=-limit,z=vel.z},true) end
end
function M:BeforeStep(dt,command,aim)
    local r=self.run;if r.state=='editing' or r.state=='over' then return end;r:Step(dt);self:Events()
    local p=self.player;self.shieldTarget.active=r.shield.hp>0
    if p.alive then
        local base=r.shield.hp>0 and Query.Contains(self.shield,p:Position());p.repairing=base
        if base then p:Heal(C.baseHealRate*dt);self.repairClock=self.repairClock+dt
            if self.repairClock>=C.baseRestoreInterval then self.repairClock=self.repairClock-C.baseRestoreInterval;p:RestoreMissing(1);p:Flush() end
        else self.repairClock=0;if self.world.time-p.hitAt>=C.regenDelay then p:Heal(C.regenRate*dt) end end
    end
    self:Spawn()
    for i=#self.pending,1,-1 do local wait=self.pending[i];if r.time>=wait.at then table.remove(self.pending,i);self.view:ClearWarning(wait.meta.id);self:SpawnUnit(wait.meta,wait.gate,true) end end
    for _,entry in ipairs(self.entries) do local u=entry.unit;u:Flush();if u.alive and not Raider.StepExplosion(u,dt) then
        local cmd,target,fire=command,aim,command.firing==true;local driverInfo
        if u~=p then if p.alive and not u.airdropActive then cmd,target,fire,driverInfo=entry.driver:Step(dt,p,r.charge,self.shieldTarget) else cmd,target,fire=PARK,u:Position(),false end end
        DriverActions.Apply(u,driverInfo)
        local v=u.vehicle;v:StepRotors(target,cmd.rotorStep,dt);RotorMotion.Weapons(v.rotors,u.weapons);v:Step(cmd,dt);self:Airdrop(u,dt)
        local pos,vel=v.body.translation(),v.body.linvel()
        u.weapons:Step(dt,{firing=fire,aim=target or u:Position(),pos={pos.x,pos.y,pos.z},quat=v.body.rotation(),vel={vel.x,vel.y,vel.z},body=v.body,team=u.team,live=true,salvo=driverInfo and driverInfo.salvo},entry.env)
        for _,fx in ipairs(u.weapons.fx) do Raider.ArmExplosion(u,fx) end
        self.session.effects:Consume(u.weapons.fx,u~=p);self.session.weaponAudio:Consume(u.weapons.fx,u~=p)
        if pos.y< -40 then local core=u.bp:CoreParts()[1];if core then u:Damage(core.id,1e9,u:Position());u:Flush() end end
    end end
end
function M:AfterStep(dt)
    for i=#self.entries,2,-1 do local u=self.entries[i].unit;if not u.alive then
        self.run:EnemyKilled(u.endless.id,u.bp:List(),u.pos);table.remove(self.entries,i)
        for j=#self.world.units,1,-1 do if self.world.units[j]==u then table.remove(self.world.units,j);break end end
    end end
    if not self.player.alive and not self.handledDeath then self.handledDeath=true;self.run:LoseLife() end
    if self.player.alive then self.handledDeath=false;for _,id in ipairs(self.run.dropOrder) do local drop=self.run.pendingDrops[id];if drop and V.Length(V.Sub(drop.pos,self.player:Position()))<=C.pickupRadius then self.run:PickupDrop(id) end end end
    self:Events();self.view:Update(self,dt)
end
function M:Events()
    local banners=EndlessBanner;local tierAnnouncement=''
    for _,e in ipairs(self.run:Drain()) do
        self.view:Event(e)
        if self.run.state~='editing' then
            if e.type=='gameOver' then if self.run.lives==0 then self.audio:Play('game_over') end else self.audio:Event(e,self.session.camera and self.session.camera:GetNode()) end
        end
        local env=self.session.environment;local shield=env and env.effects and env.effects.shields and env.effects.shields[1]
        if shield then if e.type=='shieldHit' and e.point then shield:Hit(e.point) elseif e.type=='shieldRaise' then shield:Raise() elseif e.type=='shieldDown' then shield:Down() end end
        local text;text,tierAnnouncement=banners.Event(e,tierAnnouncement);if text then self:Banner(text) end
        if e.type=='waveClear' then self.session:Pause();self.audio:Play('supply_open')
        elseif e.type=='pickup' then self.session.app.toasts:Push('获得 '..Defs.PARTS[e.partType].name..' ×'..e.count,'ok')
        elseif e.type=='credits' and e.amount>0 then self.session.app.toasts:Push('+'..e.amount..' 金钱 · 共 '..e.total,'ok',1400)
        elseif e.type=='respawn' then self.player:Spawn();self.invulnerableUntil=self.world.time+e.invulnerability;self.spawnPresentation:Rise(self.world.time);self.handledDeath=false;self:SyncPlayer();self.session:ResetCamera()
        elseif e.type=='repair' then self.player:Heal(1);self.player:RestoreMissing(math.huge);self.player:Flush();self:SyncPlayer()
        elseif e.type=='save' then self:Persist()
        elseif e.type=='gameOver' then self:Finish(e.result) end
    end
end
function M:Banner(text) EndlessBanner.Push(self,text) end
function M:Persist()
    if self.run.state~='rest' then return end
    local ok,err=self.session.app.store:Write(C.runKey,self.run:Save(),Records.Run)
    if not ok then self.session.app.toasts:Push('本局进度未能写入浏览器存储','warn') end
    return ok,err
end
function M:Finish(result)
    self.rules.finished=true;self.result=result;self.session:Pause()
    local store=self.session.app.store;local old=store:Read(C.bestKey,function(d) return type(d)=='table' end) or {score=0};self.isBest=result.score>old.score;self.best=self.isBest and result or old
    if self.isBest then store:Write(C.bestKey,result,Records.Best) end;store:Write(C.runKey,nil,Records.Run,true)
end
function M:WaitForRespawn()
    if self.run.respawnAt==nil then return false end
    self.session.app.toasts:Push('战车被摧毁，请等待 '..math.ceil(math.max(0,self.run.respawnAt-self.run.time))..' 秒后复原','info')
    return true
end
function M:NextWave()
    if self:WaitForRespawn() then return false end
    if self.run:NextWave() then self:Events();self.session:Resume();return true end;return false
end
function M:ChooseSupply(i) local result=self.run:ChooseSupply(i);self:Events();return result end
function M:Buy(id) local result=self.run:Buy(id);self:Events();return result end
function M:EnterEdit()
    if self:WaitForRespawn() then return false end
    if self.run.state=='rest' and not Query.Contains(self.shield,self.player:Position()) then self.session.app.toasts:Push('回到基地护盾里才能改装','warn');return false end
    if not self.run:BeginEdit() then self.session.app.toasts:Push('战斗中不能改装','warn');return false end
    self.session:Pause();self.session.accumulator=0;self.edit=DeferredModules['endless.Edit'].New(self);self.edit:Enter();self:Events();return true
end
function M:ResumeEdit(source)
    local result=self.run:ResumeEdit(source);if not result.ok then return result end
    local anchor=self.edit.anchor;self.edit:Leave();self.edit=nil;local u=self.player;u.source=self.run.blueprint;u:Spawn();local at=Center(u.spec,{pos={anchor.pos[1],anchor.pos[2]+.3,anchor.pos[3]},yaw=anchor.yaw})
    u.vehicle:Place(at.pos,at.yaw);u:SavePose();u.previous=u.current;u.spawnAt=Center(u.spec,self.spawn);self.invulnerableUntil=self.world.time+C.spawnInvulnerability;self.spawnPresentation:Rise(self.world.time);self:SyncPlayer();self:Persist();self:Events();self.session:Resume();return result
end
function M:HandleKey(key)
    if self.edit then return self.edit:HandleKey(key) end
    if key==KEY_G then self:EnterEdit();return true elseif key==KEY_V then if not self.run:UseRepair() then self.session.app.toasts:Push('没有可用的维修补给','info') end;self:Events();return true
    elseif key==KEY_RETURN or key==KEY_KP_ENTER then self:NextWave();return true
    elseif key==KEY_BACKSPACE or key==KEY_N or key==KEY_T then return true end;return false
end
function M:Update(dt) self.audio:Update(dt,self.run,self.session.camera:GetNode(),self.session.feedbackAudio.volume);if self.edit then self.edit:Update(dt) end end
function M:RestorePresentation() self.spawnPresentation:Restore() end
function M:Present()
    if self.disposed or self.edit or not self.player.alive then return end
    local s=self.session;local root=s.view.view.root;local b=self.player.spec.bounds
    local blink=self.spawnPresentation:Apply(root,self.world.time,b.max[2]-b.min[2],self.invulnerableUntil)
    local visibility=NodeVisibility
    visibility.Set(root,not s.firstPerson and blink,true)
    if #s.restoreFlash.items>0 then s.restoreFlash.root:SetTransform(root.worldPosition,root.worldRotation,root.worldScale) end
    visibility.Set(s.restoreFlash.root,root.enabled,true)
end
function M:SyncPlayer() PlayerViewSync.Update(self) end
function M:Snapshot() return {state=self.run.state,wave=self.run.wave,tier=self.run.tier,lives=self.run.lives,score=self.run.score,credits=self.run.credits,enemies=Count(self.run.alive),pending=#self.run.queue,shield=self.run.shield,editing=self.edit~=nil} end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.edit then self.edit:Leave();self.edit=nil end
    if self.spawnPresentation then self.spawnPresentation:Dispose();self.spawnPresentation=nil end
    if self.spawnSpecCache then self.spawnSpecCache:Dispose();self.spawnSpecCache=nil end
    self.world.RecordDamage=self.baseDamage;self.view:Dispose();self.audio:Dispose()
    for i=#self.entries,1,-1 do local e=self.entries[i];e.unit=nil;e.env=nil;e.driver=nil;self.entries[i]=nil end
    self.pending={};self.baseDamage=nil;self.shieldTarget=nil;self.spawnRadii={}
    self.view=nil;self.audio=nil;self.player=nil;self.world=nil;self.session=nil;self.shield=nil
end
return M
