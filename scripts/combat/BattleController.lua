local Data=require 'combat.ArenaData'
local BP=require 'construction.Blueprint'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local M={};M.__index=M
function M.Dependencies(bp,roster,mode)
    local tier=(bp:Stats().fitTier or {id=5}).id;local parts={}
    local fallback=not roster
    roster=roster or require('combat.Matchmaker').Find({Read=function() return nil end,Write=function() return true end},Data.modes[mode or 'elimination'].size,tier,nil,90862445)
    for _,team in ipairs({'blue','red'}) do for _,member in ipairs(roster[team]) do
        if not member.player then
            local variants=fallback and tier<=3 and (member.role=='assault' or member.role=='heavy') and {0,1} or {member.variant or 0}
            for _,variant in ipairs(variants) do for _,p in ipairs(BP.New():Load(Data.prefabs[team..':'..tier..':'..member.role..':'..variant]):List()) do parts[#parts+1]=p end end
        end
    end end
    local paths=require('parts.Dependencies').For(parts)
    if mode=='escort' then for _,path in ipairs(require('parts.Dependencies').For(BP.New():Load(Data.payload):List())) do paths[#paths+1]=path end end
    paths[#paths+1]='Shaders/BLGL/Combat/Objective.shader'
    for _,style in ipairs({'round','square'}) do paths[#paths+1]='UI/Match/minimap-mask-'..style..'.png' end
    for _,path in ipairs(require('audio.BattleFlow').Dependencies(false)) do paths[#paths+1]=path end
    for _,team in ipairs({'blue','red'}) do for _,member in ipairs(roster[team]) do paths[#paths+1]='UI/Avatars/'..member.avatar..'.jpg' end end
    if fallback then for i=2,11 do paths[#paths+1]=string.format('UI/Avatars/a%02d.jpg',i) end end
    for i=1,13 do paths[#paths+1]=string.format('Sounds/Match/m%02d.wav',i) end
    for _,face in ipairs({'smile','deadpan','talk'}) do paths[#paths+1]=require('ui.CommsPortrait').Path('nono',face) end
    return paths
end
function M.New(session,bp,checkpoint)
    local self=setmetatable({},M);self.session=session;self.world=session.world;self.entries={};self.events={}
    self.mode=session.map.battleMode or 'elimination'
    self.baseDamage=self.world.RecordDamage;self.baseKill=self.world.RecordKill
    session.battle=self;session.combat=self
    self.sounds=require('audio.BattleFlow').New()
    self.sounds:Prepare(false,function() if checkpoint then checkpoint(0) end end)
    self.objectives=require('combat.BattleObjectives').New(self,self.mode);self.rules=self.objectives:Rules()
    self.voice=require('audio.MatchVoice').New(self)
    self.tier=(bp:Stats().fitTier or {id=5}).id;self.banner=nil;self.stats={};self.lastHit={};self.clock=0
    for _,u in ipairs(self.world.units) do u:Dispose() end;self.world.units={}
    self.roster=session.map.battleRoster or require('combat.Matchmaker').Find(session.app.store,Data.modes[self.mode].size,self.tier)
    for _,team in ipairs({'blue','red'}) do for i,member in ipairs(self.roster[team]) do
        local source=member.player and bp:ToTable() or Data.prefabs[team..':'..self.tier..':'..member.role..':'..(member.variant or 0)]
        local spawn=self:SpawnAt(team,i)
        local progress=checkpoint and function(p) checkpoint((#self.entries+p*.95)/(#self.roster.blue+#self.roster.red)) end or nil
        local unit=Unit.New(self.world,source,{name=member.name,spawn=spawn,team=team,autoRespawn=false,externalControl=true,externalView=member.player,combat=true},progress,function(candidate)
            self.world.units[#self.world.units+1]=candidate
        end)
        assert(unit.alive,'Invalid battle vehicle '..member.name)
        local entry={unit=unit,member=member,slot=i,guardUntil=self.world.time+3,repair=0}
        if member.player then self.player=unit else entry.driver=Driver.New(self.world,unit,member.role,#self.entries+1,member) end
        self.entries[#self.entries+1]=entry;self.stats[unit]={damage=0,kills=0,deaths=0,assists=0}
        local shooter=unit
        local function CanDamage(victim)
            return victim.team~=shooter.team and self.world.time>=(victim.guardUntil or 0) and not self.objectives:HomeProtected(victim)
        end
        entry.env={stats=member.player and self.world.stats or {shots=0},killHeight=-80,
            castRay=function(...) return self.objectives:Cast(shooter,...) end,
            sweepDrill=function(...) return self.objectives:SweepDrill(shooter,...) end,
            lockables=function(excluded) return self.world:Lockables(excluded,shooter.team,function(u) return not self.objectives:Ignore(u) end) end,
            explode=function(point,radius,damage,excluded)
                if self.rules.state~='live' then return end
                self.objectives:Explode(shooter,point,radius,damage)
                self.world.attacker=shooter
                self.world:Explode(point,radius,damage,excluded,CanDamage,function(...) return self.objectives:Cast(shooter,...) end)
                self.world.attacker=nil
            end,
            hit=function(hit,damage,dir,impulse,pierce)
                if self.rules.state~='live' then return end
                if self.objectives:Hit(shooter,hit,damage) then return end
                local victim=hit.owner and hit.owner.type=='car' and hit.owner.ref
                if victim and not CanDamage(victim) then return end
                self.world.attacker=shooter;self.world:Hit(hit,damage,dir,impulse,pierce);self.world.attacker=nil
            end}
        if checkpoint then checkpoint(#self.entries/(#self.roster.blue+#self.roster.red)) end
    end end
    self.baseDamage=self.world.RecordDamage;self.baseKill=self.world.RecordKill
    self.world.RecordDamage=function(world,unit,amount,point,opts)
        local attacker=world.attacker
        if attacker and attacker~=unit and amount>0 then
            self.stats[attacker].damage=self.stats[attacker].damage+amount;unit.lastHitBy=attacker
            local hits=self.lastHit[unit] or {};hits[attacker]=world.time;self.lastHit[unit]=hits
            if attacker==self.player then self.baseDamage(world,unit,amount,point,opts) end
        end
    end
    self.world.RecordKill=function(world,unit,pos)
        self.stats[unit].deaths=self.stats[unit].deaths+1
        local hits=self.lastHit[unit] or {};local attacker,latest=false,-math.huge
        for by,at in pairs(hits) do if world.time-at<10 and at>latest then attacker=by;latest=at end end
        for by,at in pairs(hits) do if world.time-at<10 and by~=attacker and by.team~=unit.team then self.stats[by].assists=self.stats[by].assists+1 end end
        self.lastHit[unit]=nil
        self.voice:Kill(unit,attacker)
        local function Identity(u) return u and {name=u.name,team=u.team,me=u==self.player} or nil end
        local group=attacker and attacker.weapons and attacker.weapons.groups and attacker.weapons.groups[1]
        require('ui.MatchFeed').Push(self,Identity(attacker),Identity(unit),group and group.kind)
        if attacker and attacker.team~=unit.team then
            self.stats[attacker].kills=self.stats[attacker].kills+1
            if self.mode=='conquest' then self.rules:Kill(attacker.team) end
            if attacker==self.player then self.baseKill(world,unit,pos) else world.fx[#world.fx+1]={type='explode',pos=pos,radius=3} end
        else world.fx[#world.fx+1]={type='explode',pos=pos,radius=3} end
    end
    for _,entry in ipairs(self.entries) do entry.unit.guardUntil=entry.guardUntil end
    self.objectives:PlaceCart()
    return self
end
function M:SpawnAt(team,slot)
    local forward=self.objectives:Spawn(team,slot);if forward then return forward end
    local layout=self.world.layout;local x=(Data.modes[self.mode].size==4 and {-21,-7,7,21} or {-15,0,15})[slot];local z=team=='blue' and -60 or 60;local y=0
    if layout.pads then
        local south=self.mode=='escort' and team==self.rules.attack or self.mode~='escort' and team=='blue'
        local pad=layout.pads[south and 'player' or 'enemy'];local side=x
        return {pos={pad.pos[1]+math.cos(pad.yaw)*side,pad.pos[2],pad.pos[3]-math.sin(pad.yaw)*side},yaw=pad.yaw}
    end
    if layout.nav and layout.nav.nodes.bY then
        local p=layout.nav.nodes[team=='blue' and 'bY' or 'ebY'];z=p[3];y=p[2]
    end
    return {pos={x,y,z},yaw=team=='blue' and 0 or math.pi}
end
function M:Pick(entry)
    return require('combat.MatchTarget').Pick(self,entry)
end
function M:BeforeStep(dt,command,aim)
    local live=self.rules.state=='live'
    self.objectives:PlaceCart()
    for _,entry in ipairs(self.entries) do local u=entry.unit
        if not u.alive and live and self.mode~='elimination' and u.deadAt>=0 and self.world.time-u.deadAt>=self.rules.cfg.respawn then
            u.spawnAt=self:SpawnAt(u.team,entry.slot);u:Spawn();u.guardUntil=self.world.time+3;entry.repair=0
            if u==self.player then self.voice:Say('respawned') end
            if entry.driver then entry.driver=Driver.New(self.world,u,entry.member.role,entry.slot,entry.member) end
        end
        if u.alive then
            local cmd={throttle=0,steer=0,handbrake=true};local target=aim;local firing=false;local driverInfo
            if live then
                u.repairing=false
                u:RegenerateStructure(dt)
                if u==self.player then cmd=command;firing=command.firing==true
                else
                    local goal,charge=self.objectives:Goal(entry,self:Pick(entry))
                    cmd,target,firing,driverInfo=entry.driver:Step(dt,goal,charge)
                end
                self.objectives:UnitTick(entry,dt)
            end
            u:Flush()
            if u.alive then
                require('combat.DriverActions').Apply(u,driverInfo)
                local v=u.vehicle;v:StepRotors(live and target or nil,live and cmd.rotorStep,live and dt or 0)
                require('drive.RotorMotion').Weapons(v.rotors,u.weapons)
                v:Step(cmd,dt);local p,velocity=v.body.translation(),v.body.linvel()
                local eye=u==self.player and self.session.camera:GetNode().worldPosition or nil
                u.weapons:Step(dt,{firing=live and firing,aim=target or u:Position(),pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,
                    team=u.team,live=live,salvo=live and driverInfo and driverInfo.salvo,eye=eye and {-eye.x,eye.y,eye.z}},entry.env)
                self.session.effects:Consume(u.weapons.fx,u~=self.player)
                self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
                if p.y< -40 then local core=u.bp:CoreParts()[1];if core then u:Damage(core.id,1e9,u:Position());u:Flush() end end
            end
        end
    end
end
function M:WorldState()
    local out={alive={blue=0,red=0},hp={blue=0,red=0}}
    for _,e in ipairs(self.entries) do local u=e.unit;if u.alive then out.alive[u.team]=out.alive[u.team]+1;out.hp[u.team]=out.hp[u.team]+u:Health() end end
    return self.objectives:WorldState(out)
end
function M:AfterStep(dt)
    self.sounds:Countdown(self.rules.cfg.prep-self.rules.t,self.rules.state=='prep')
    self.clock=self.clock+dt;local worldState=self:WorldState();self.rules:Step(dt,worldState)
    for _,event in ipairs(self.rules:Drain()) do
        self.events[#self.events+1]=event
        self.sounds:Event(event)
        self.voice:Event(event)
        self.objectives:Event(event)
        if event.type=='roundPrep' and event.round>1 or event.type=='halfPrep' and event.half>1 then
            self.spectate=0
            self.world.debris:Clear()
            self.lastHit={}
            for i,e in ipairs(self.entries) do
                e.unit.spawnAt=self:SpawnAt(e.unit.team,e.slot);e.unit:Spawn();e.repair=0;e.unit.guardUntil=self.world.time+3
                if e.driver then e.driver=Driver.New(self.world,e.unit,e.member.role,i,e.member) end
            end
        end
        local notice=require('ui.MatchBanner').ForEvent(self,event,worldState)
        if notice then self:Banner(notice.text,notice.tag,notice.sub,notice.cls,notice.ms,notice.mini) end
        if event.type=='matchOver' then
            require('ui.MatchBanner').Clear(self)
            self.session:Pause()
            if not self.result then
                self.mvp=require('combat.MvpMotion').Winner(self.entries,self.stats)
                self.result=require('combat.Matchmaker').Record(self.session.app.store,self.rules.winner,self.roster.rating.red,self.stats[self.player].kills,self.mvp and self.mvp.unit==self.player)
                self.session.weaponAudio:SetActive(false);self.session.drivingAudio:SetActive(false);self.session.feedbackAudio:SetActive(false);self.session.drillSpeed:Clear()
                self.voice:Reset()
                self.mvpShow=require('app.MvpShow').New(self.session,self.mvp,self.stats[self.mvp.unit])
            end
        end
    end
    self.objectives:Update(dt)
end
function M:Banner(text,tag,sub,cls,ms,mini) return require('ui.MatchBanner').Push(self,text,tag,sub,cls,ms,mini) end
function M:Restart()
    require('ui.MatchBanner').Clear(self)
    require('ui.MatchFeed').Clear(self)
    if self.mvpShow then self.mvpShow:Dispose();self.mvpShow=nil end
    self.mvp=nil;self.lastHit={}
    self.session:Pause();self.result=nil;self.objectives:Reset();self.rules=self.objectives:Rules();self.voice:Reset();self.world.debris:Clear()
    for i,e in ipairs(self.entries) do
        e.unit.spawnAt=self:SpawnAt(e.unit.team,e.slot);e.unit:Spawn();e.unit.guardUntil=self.world.time+3;e.repair=0;self.stats[e.unit]={damage=0,kills=0,deaths=0,assists=0}
        if e.driver then e.driver=Driver.New(self.world,e.unit,e.member.role,i,e.member) end
    end
    self:SyncPlayer();self.session.combatView:Consume(self.world);self.session.effects:Clear()
    self.objectives:PlaceCart()
end
function M:SyncPlayer()
    require('combat.PlayerViewSync').Update(self)
end
function M:Snapshot()
    local units={}
    for _,e in ipairs(self.entries) do local u=e.unit
        units[#units+1]={name=u.name,team=u.team,alive=u.alive,hp=u:Health(),parts=u.bp:Size(),position=u:Position(),
            player=u==self.player,role=e.member.role,mode=e.driver and e.driver.mode,stats=self.stats[u],avatar=e.member.avatar}
    end
    return {mode=self.mode,state=self.rules.state,round=self.rules.round,score=self.rules.score,timeLeft=self.rules:TimeLeft(),sudden=self.rules.sudden,points=self.rules.points,
        payload=self.mode=='escort' and {position=self.objectives:At(self.rules.s).pos,distance=self.rules.s,length=self.objectives.length,half=self.rules.half,attack=self.rules.attack,contested=self.rules.contested},
        winner=self.rules.winner,units=units,playerAlive=self.player.alive,playerHealth=self.player:Health(),history=self.rules.history,
        radio={ready=self.voice.ready,queued=#self.voice.queue,card=self.voice.card},mvp=self.mvpShow and self.mvpShow:Snapshot()}
end
function M:Dispose()
    if self.mvpShow then self.mvpShow:Dispose();self.mvpShow=nil end
    if self.sounds then self.sounds:Dispose() end
    if self.voice then self.voice:Dispose() end
    if self.objectives then self.objectives:Dispose() end
    self.world.RecordDamage=self.baseDamage;self.world.RecordKill=self.baseKill
    self.entries={};self.stats={};self.events={}
end
return M
