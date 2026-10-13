local Data=require 'story.MissionData'
local Arena=require 'combat.ArenaData'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local V=require 'core.Math3'
local M={};M.__index=M
local function Center(spec,at)
    local a,b=spec.bounds.min,spec.bounds.max;local x,z=(a[1]+b[1])/2,(a[3]+b[3])/2;local yaw=at.yaw or 0
    return {pos={at.pos[1]-x*math.cos(yaw)-z*math.sin(yaw),at.pos[2],at.pos[3]+x*math.sin(yaw)-z*math.cos(yaw)},yaw=yaw}
end
function M.Dependencies(bp,levelNo)
    local tier=math.max(1,math.min(3,((bp:Stats().fitTier or {id=2}).id)-1))
    local parts={};local keys={}
    local function Include(role,offset)
        local t=math.max(1,math.min(5,tier+(offset or 0)));local key='red:'..t..':'..role..':0'
        if keys[key] then return end;keys[key]=true
        for _,p in ipairs(require('construction.Blueprint').New():Load(assert(Arena.prefabs[key])):List()) do parts[#parts+1]=p end
    end
    for _,step in ipairs(assert(Data.levels[levelNo]).steps) do
        for _,e in ipairs(step.enemies or {}) do Include(e.role or step.role or 'assault',e.tier) end
        for _,group in ipairs({step.guards or {},step.counter or {}}) do for _,e in ipairs(group) do Include(e.role or 'assault',e.tier) end end
        for _,beat in ipairs(step.beats or {}) do for _,e in ipairs(beat.spawn or {}) do Include(e.role or 'assault',e.tier) end end
    end
    local out=require('parts.Dependencies').For(parts)
    for _,path in ipairs(require('render.MissionView').Dependencies()) do out[#out+1]=path end
    for _,path in ipairs(require('audio.StoryComms').Dependencies()) do out[#out+1]=path end
    return out
end
function M.New(session,bp)
    local self=setmetatable({session=session,world=session.world,entries={},enemyPositions={},regen=0,damageScale=.6},M)
    self.level=assert(Data.levels[session.map.storyLevel]);self.damageScale=self.level.enemyDamage or .6
    for _,step in ipairs(self.level.steps) do if step.kind=='escort' then
        self.convoy=require('story.ConvoyRules').New(step,self.world.layout.nav,function(x,z,hint,up)
            local hit=self.world:CastRay({x,hint+up,z},{0,-1,0},160,nil);return hit and hint+up-hit.dist or hint
        end)
    end end
    self.rules=require('story.MissionRules').New(self.level,self.convoy)
    if self.convoy then self.truckTarget={passive=true,radius=4,spec={bounds={min={0,0,0},max={0,0,0}}},Position=function() return self.convoy.pos end} end
    for _,u in ipairs(self.world.units) do u:Dispose() end;self.world.units={}
    self.tier=math.max(1,math.min(3,((bp:Stats().fitTier or {id=2}).id)-1))
    self.player=Unit.New(self.world,bp:ToTable(),{name=bp.name,spawn=self.level.spawn,team='blue',autoRespawn=false,externalControl=true,externalView=true,combat=true})
    assert(self.player.alive,'Invalid story player');self.world.units[1]=self.player;self.entries[1]={unit=self.player,env=self:Environment(self.player)}
    self:Place(self.level.spawn);self.voice=require('audio.StoryComms').New(session.scene);self.view=require('render.MissionView').New(session.scene)
    for id,it in pairs(self.level.intel or {}) do if not it.drop then self.view:AddIntel(id,it.pos) end end
    for _,pos in ipairs(self.level.setup and self.level.setup.collectors or {}) do self.view:Collector(pos,true) end
    for _,site in ipairs(self.level.setup and self.level.setup.sites or {}) do self.view:AddSite(site.id,site.pos) end
    if self.convoy then self.view:Truck(self.convoy) end
    return self
end
function M:Environment(unit)
    local world=self.world;local scale=unit.team=='red' and self.damageScale or 1
    return {stats=unit==self.player and world.stats or {shots=0},killHeight=-80,
        castRay=function(...) return world:CastRay(...) end,
        lockables=function(body) return world:Lockables(body,unit.team) end,
        hit=function(hit,damage,dir,impulse,pierce)
            if self.rules.finished then return end
            if hit.owner and hit.owner.ref and hit.owner.ref.team==unit.team then return end
            world.attacker=unit;world:Hit(hit,damage*scale,dir,impulse,pierce);world.attacker=nil
        end,
        explode=function(point,radius,damage,body)
            if not self.rules.finished then
                world.attacker=unit;world:Explode(point,radius,damage*scale,body,function(u) return u.team~=unit.team end);world.attacker=nil
            end
        end}
end
function M:Place(at)
    local u=self.player;local spawn=Center(u.spec,{pos={at.pos[1],at.pos[2]+.5,at.pos[3]},yaw=at.yaw})
    u.spawnAt=spawn;u.vehicle:Place(spawn.pos,spawn.yaw);u:SavePose();u.previous=u.current;self.session.yaw=-spawn.yaw*180/math.pi
end
function M:Begin() self.rules:Begin();self:Events() end
function M:Spawn(step)
    for i,e in ipairs(step.enemies) do
        local n=type(e.at)=='string' and assert(self.world.layout.nav.nodes[e.at]) or nil
        local off=e.off or {0,0};local p=n and {n[1]+off[1],n[2],n[3]+off[2]} or e.at
        local x,z=p[1],#p==3 and p[3] or p[2];local y=#p==3 and p[2] or 40
        if n or #p~=3 then local hit=self.world:CastRay({x,y+(n and 5 or 40),z},{0,-1,0},160,self.player.vehicle.body);if hit then y=hit.point[2] end end
        local at={pos={x,y+1.5,z},yaw=math.atan(self.player.pos[1]-x,self.player.pos[3]-z)}
        local tier=math.max(1,math.min(5,self.tier+(e.tier or 0)))
        local source=Arena.prefabs['red:'..tier..':'..(e.role or step.role or 'assault')..':0']
        local unit=Unit.New(self.world,source,{name=e.name or step.name or '狐狐海盗团',spawn=at,team='red',autoRespawn=false,externalControl=true,combat=true})
        unit.spawnAt=Center(unit.spec,at);unit.vehicle:Place(unit.spawnAt.pos,unit.spawnAt.yaw);unit:SavePose();unit.previous=unit.current
        self.world.units[#self.world.units+1]=unit;self.entries[#self.entries+1]={unit=unit,target=e.target,tag=step.tag,flee=e.flee,boss=e.boss,
            driver=Driver.New(self.world,unit,e.role or step.role or 'assault',i),env=self:Environment(unit)}
        if self.session.hud then self.session.hud.overlay.tags[#self.session.hud.overlay.tags+1]={unit=unit,visible=false} end
    end
end
function M:ClearEnemies()
    for i=#self.entries,2,-1 do local unit=self.entries[i].unit;unit:Dispose();table.remove(self.entries,i) end
    self.world.units={self.player}
    if self.session.hud then self.session.hud.overlay.tags={} end
end
function M:BeforeStep(dt,command,aim)
    for _,entry in ipairs(self.entries) do local u=entry.unit
        u:Flush()
        if u.alive then
            local cmd,target,firing={throttle=0,steer=0,handbrake=true},u:Position(),false
            if u==self.player then cmd=command;target=aim;firing=command.firing==true
            elseif self.player.alive then
                local victim=self.player
                if entry.target=='truck' and self.convoy then victim=self.truckTarget end
                cmd,target,firing=entry.driver:Step(dt,victim)
            end
            if u==self.player then
                if self.world.time-u.hitAt>=5 then u:Heal(.15*dt);self.regen=self.regen+dt
                    if self.regen>=.5 then self.regen=self.regen-.5;u:RestoreMissing(1);u:Flush() end
                else self.regen=0 end
            end
            if u.alive then
                local v=u.vehicle;v:StepRotors(target,cmd.rotorStep,dt);require('drive.RotorMotion').Weapons(v.rotors,u.weapons)
                v:Step(cmd,dt);local p,velocity=v.body.translation(),v.body.linvel()
                local eye=u==self.player and self.session.camera:GetNode().worldPosition or nil
                u.weapons:Step(dt,{firing=firing,aim=target,pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,team=u.team,
                    eye=eye and {-eye.x,eye.y,eye.z}},entry.env)
                self.session.effects:Consume(u.weapons.fx);self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
                if p.y< -40 then u.bodyHp=0;u.kill='掉出地图';u.dirty=true;u:Flush() end
            end
        end
    end
end
function M:CarSize()
    local u=self.player;local p=u:Position();local key=u.bp:Size()
    if self.sizeKey==key then return self.size end
    if not self.session.view then return {w=2,below=1.5,above=1.5} end
    local box=self.session.view.view:GetWorldBounds()
    if not box:Defined() then return {w=2,below=1.5,above=1.5} end
    local a,z=box.min,box.max;local low,high={a.x,a.y,a.z},{z.x,z.y,z.z}
    self.sizeKey=key;self.size={w=math.max(high[1]-low[1],high[3]-low[3])/2,below=math.max(1.5,p[2]-low[2]),above=math.max(1.5,high[2]-p[2])};return self.size
end
function M:AfterStep(dt)
    for i=#self.entries,2,-1 do local entry=self.entries[i];local u=entry.unit
        local fleeing=entry.flee and u.alive and (u:Integrity()<entry.flee or #u.spec.weapons==0 or u.spec.motion.load==0 or u.spec.motion.topSpeed==0)
        if not u.alive or fleeing then
            if fleeing then
                local s=self.rules:StepSpec();self.rules:Emit('say',{lines=s and s.fleeLines,urgent=true})
                self.rules:Emit('banner',{title='狐狐撤退了',sub='小狐号溜了 · 「这次不算！」'});self.rules.flags.huhuFled=true
            else self.rules:Killed(u:Position()) end
            u:Dispose();table.remove(self.entries,i)
            for j=#self.world.units,1,-1 do if self.world.units[j]==u then table.remove(self.world.units,j) end end
            if self.session.hud then for j=#self.session.hud.overlay.tags,1,-1 do if self.session.hud.overlay.tags[j].unit==u then table.remove(self.session.hud.overlay.tags,j) end end end
        end
    end
    local u=self.player
    local enemyPositions=self.enemyPositions;for i=#enemyPositions,1,-1 do enemyPositions[i]=nil end
    local tags=self.enemyTags or {};self.enemyTags=tags;tags.guard=0;tags.counter=0
    for i=2,#self.entries do local entry=self.entries[i];if entry.unit.alive then
        enemyPositions[#enemyPositions+1]=entry.unit:Position();if entry.tag then tags[entry.tag]=(tags[entry.tag] or 0)+1 end
    end end
    self.rules:Step(dt,{alive=u.alive,pos=u:Position(),speed=u.alive and u.vehicle.speed or 0,yaw=u.alive and u.vehicle:Yaw() or 0,
        size=u.alive and self:CarSize() or nil,enemies=#self.entries-1,enemyPositions=enemyPositions,enemyTags=tags,nav=self.world.layout.nav,
        talking=self.voice:Talking(),interact=self.session.pointer.captured and (self.session.controls.held.interact or input:GetKeyDown(KEY_G))})
    self:Events();self.view:Update(dt,self.rules,self.session.camera:GetCamera())
end
function M:Events()
    for _,e in ipairs(self.rules:Drain()) do
        if e.type=='objective' then self.voice:Say(e.step.start);self.view:Objective(e.step,self.rules:Target())
        elseif e.type=='objectiveDone' then self.voice:Say(e.lines)
        elseif e.type=='intel' then self.view:TakeIntel(e.id);self.intelCard={item=e.item,untilAt=self.rules.time+5}
        elseif e.type=='collector' then
            local p=e.step.pos;local x,z=p[1],p[3]
            if math.sqrt((e.pos[1]-x)^2+(e.pos[3]-z)^2)<5.5 then x=e.pos[1]+math.cos(e.yaw)*6.5;z=e.pos[3]-math.sin(e.yaw)*6.5 end
            local hit=self.world:CastRay({x,p[2]+8,z},{0,-1,0},30,self.player.vehicle.body)
            self.view:Collector({x,hit and hit.point[2] or p[2],z})
        elseif e.type=='say' then self.voice:Say(e.lines,e.urgent)
        elseif e.type=='spawn' then self:Spawn(e)
        elseif e.type=='clearEnemies' then self:ClearEnemies()
        elseif e.type=='dropIntel' then self.view:AddIntel(e.id,e.pos)
        elseif e.type=='hideBeacon' then self.view.beacon.root.enabled=false
        elseif e.type=='siteCaptured' then self.view:SiteCaptured(e.id)
        elseif e.type=='scrub' then self.view:Scrub(e.id)
        elseif e.type=='heal' then self.player:Heal(e.fraction)
        elseif e.type=='restore' then self.player:RestoreMissing(e.count);self.player:Flush()
        elseif e.type=='place' then if self.player.alive then self:Place(e.at) end
        elseif e.type=='banner' then self.banner={title=e.title,sub=e.sub,untilAt=self.rules.time+3}
        elseif e.type=='truckHit' then self.view.truck.hitAt=self.view.time
        elseif e.type=='fight' then self:Spawn(e.step);self.voice:Say(e.step.alert,true);self.view.beacon.root.enabled=false
        elseif e.type=='clear' then if e.timeout then self:ClearEnemies() end;self.view:AddIntel('log',e.pos)
        elseif e.type=='dead' then self.session.controls:Clear()
        elseif e.type=='respawn' then self.player:Spawn();self:Place(e.at);self.regen=0;self.sizeKey=nil;self.voice:Say(self.level.respawn,true)
        elseif e.type=='complete' then self:ClearEnemies();self.view:Objective(nil,nil)
        elseif e.type=='result' then
            self.session:Pause();local store=self.session.app.store
            local valid=function(d) return type(d)=='table' end;local progress=store:Read('story-progress',valid) or {};local old=progress[self.level.id]
            local rank={S=3,A=2,B=1};self.newBest=not old or (rank[e.grade] or 0)>(rank[old.grade] or 0)
            progress[self.level.id]={grade=old and (rank[old.grade] or 0)>=(rank[e.grade] or 0) and old.grade or e.grade,time=math.min(old and old.time or math.huge,e.time),clears=(old and old.clears or 0)+1}
            self.saved,self.saveError=store:Write('story-progress',progress,valid)
        end
    end
end
function M:Update(dt) self.voice:Update(dt,self.session:HasFocus()) end
function M:Quote()
    return (self.level.quotes or {S='干得漂亮。公司说下次可以考虑给你报销油费。……只是考虑。',A='还行。车有点花，但人没事。',B='活着回来就好。零件损失我先帮你瞒着。'})[self.rules.grade] or ''
end
function M:SyncPlayer() require('combat.PlayerViewSync').Update(self) end
function M:Snapshot()
    local r=self.rules;return {id=self.level.id,step=r:StepSpec() and r:StepSpec().id,index=r.index,phase=r.phase,time=r.time,stats=r.stats,install=r.install,inside=r.inside,blocked=r.blocked,
        enemies=#self.entries-1,alive=self.player.alive,health=self.player:Health(),finished=r.finished,grade=r.grade,checkpoint=r.checkpoint,respawn=r.respawnLeft,voice=self.voice.card,
        truck=self.convoy and {pos=self.convoy.pos,hp=self.convoy.hp,d=self.convoy.d,total=self.convoy.total,cp=self.convoy.cp,far=self.convoy.far,blocked=self.convoy.blocked},
        hold=r.hold and {left=r.hold.left,energy=r.hold.energy,near=r.hold.near},
        cap=r.cap and {p=r.cap.p,phase=r.cap.phase,scrub=r.cap.scrub,contested=r.cap.contested},
        choice=r.choice,flags=r.flags,progress=r.progress,failing=r.failAt~=nil}
end
function M:Dispose() self:ClearEnemies();self.voice:Dispose();self.view:Dispose() end
return M
