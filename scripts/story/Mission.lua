local Data=require 'story.MissionData'
local Arena=require 'combat.ArenaData'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local V=require 'core.Math3'
local SpawnSpecCache=require 'drive.SpawnSpecCache'
local M={};M.__index=M
local function Center(spec,at)
    local a,b=spec.bounds.min,spec.bounds.max;local x,z=(a[1]+b[1])/2,(a[3]+b[3])/2;local yaw=at.yaw or 0
    return {pos={at.pos[1]-x*math.cos(yaw)-z*math.sin(yaw),at.pos[2],at.pos[3]+x*math.sin(yaw)-z*math.cos(yaw)},yaw=yaw}
end
local function SpawnSource(self,e,role)
    local tier=math.max(1,math.min(5,self.tier+(e.tier or 0)))
    return e.source or Arena.prefabs['red:'..tier..':'..(e.role or role or 'assault')..':0'],tier
end
function M:PrepareSpawnSpecs(checkpoint)
    self.spawnSpecCache=SpawnSpecCache.New()
    local sources,seen={},{}
    local function Include(e,role)
        local source=SpawnSource(self,e,role)
        if source and not seen[source] then seen[source]=true;sources[#sources+1]=source end
    end
    for _,step in ipairs(self.level.steps) do
        for _,e in ipairs(step.enemies or {}) do Include(e,step.role) end
        for _,group in ipairs({step.guards or {},step.counter or {}}) do for _,e in ipairs(group) do Include(e) end end
        for _,beat in ipairs(step.beats or {}) do for _,e in ipairs(beat.spawn or {}) do Include(e) end end
        if step.drillSource then Include({source=step.drillSource}) end
    end
    for i,source in ipairs(sources) do
        self.spawnSpecCache:Prepare(source,checkpoint and function() checkpoint((i-1)/#sources) end or nil)
    end
    if checkpoint then checkpoint(1) end
end
function M.Dependencies(bp,levelNo)
    local tier=math.max(1,math.min(3,((bp:Stats().fitTier or {id=2}).id)-1))
    local parts={};local keys={}
    local function Include(role,offset)
        local t=math.max(1,math.min(5,tier+(offset or 0)));local key='red:'..t..':'..role..':0'
        if keys[key] then return end;keys[key]=true
        for _,p in ipairs(require('construction.Blueprint').New():Load(assert(Arena.prefabs[key])):List()) do parts[#parts+1]=p end
    end
    local level=assert(Data.levels[levelNo])
    for _,step in ipairs(level.steps) do
        for _,e in ipairs(step.enemies or {}) do Include(e.role or step.role or 'assault',e.tier) end
        for _,group in ipairs({step.guards or {},step.counter or {}}) do for _,e in ipairs(group) do Include(e.role or 'assault',e.tier) end end
        for _,beat in ipairs(step.beats or {}) do for _,e in ipairs(beat.spawn or {}) do Include(e.role or 'assault',e.tier) end end
    end
    local out=require('parts.Dependencies').For(parts)
    for _,path in ipairs(require('render.MissionView').Dependencies()) do out[#out+1]=path end
    for _,path in ipairs(require('render.SalvageExplosion').Dependencies()) do out[#out+1]=path end
    -- S1 uses runtime fallback quotes rather than authored level.quotes.
    local voiceScope={level=level,quotes={}}
    for _,grade in ipairs({'S','A','B'}) do voiceScope.quotes[grade]=M.Quote({level=level,rules={grade=grade}}) end
    for _,path in ipairs(require('audio.StoryComms').Dependencies(voiceScope)) do out[#out+1]=path end
    for _,path in ipairs(require('audio.StoryRadio').Dependencies()) do out[#out+1]=path end
    if levelNo==5 then
        for _,path in ipairs(require('combat.StoryBoss').Dependencies(bp)) do out[#out+1]=path end
        for _,path in ipairs(require('ui.Epilogue').Dependencies()) do out[#out+1]=path end
    end
    return out
end
function M.New(session,bp,options)
    local self=setmetatable({session=session,world=session.world,entries={},enemyPositions={},regen=0,damageScale=.6},M)
    if options and options.retain then options.retain(self) end
    self.level=assert(Data.levels[session.map.storyLevel]);self.damageScale=self.level.enemyDamage or .6
    if self.level.setup and self.level.setup.points then
        local points=assert(self.world.layout.enginePit,'Original EnginePit map is required for Level5').points
        self.level={};for k,v in pairs(Data.levels[session.map.storyLevel]) do self.level[k]=v end
        self.level.spawn={pos=points.rampTop or {0,26,-438},yaw=0}
        self.level.steps={};for i,s in ipairs(Data.levels[session.map.storyLevel].steps) do local copy={};for k,v in pairs(s) do copy[k]=v end;self.level.steps[i]=copy end
        self.level.steps[1].pos=points.spawn or self.level.steps[1].pos
    end
    for _,step in ipairs(self.level.steps) do if step.kind=='escort' then
        self.convoy=require('story.ConvoyRules').New(step,self.world.layout.nav,function(x,z,hint,up)
            local hit=self.world:CastRay({x,hint+up,z},{0,-1,0},160,nil);return hit and hint+up-hit.dist or hint
        end)
    end end
    self.rules=require('story.MissionRules').New(self.level,self.convoy,function() return Time:GetSystemTime()/1000 end)
    self.objective=require('ui.MissionObjective').New(session.touch)
    self.choiceView=require('ui.MissionChoiceState').New()
    if self.convoy then self.truckTarget={passive=true,radius=4,spec={bounds={min={0,0,0},max={0,0,0}}},Position=function() return self.convoy.pos end} end
    for _,u in ipairs(self.world.units) do u:Dispose() end;self.world.units={}
    self.tier=math.max(1,math.min(3,((bp:Stats().fitTier or {id=2}).id)-1))
    local checkpoint=options and options.checkpoint
    self:PrepareSpawnSpecs(checkpoint and function(p) checkpoint(p*.35) end or nil)
    self.player=Unit.New(self.world,bp:ToTable(),{name=bp.name,spawn=self.level.spawn,team='blue',autoRespawn=false,externalControl=true,externalView=true,combat=true})
    assert(self.player.alive,'Invalid story player');self.world.units[1]=self.player;self.entries[1]={unit=self.player,env=self:Environment(self.player)}
    self:Place(self.level.spawn);self.voice=require('audio.StoryComms').New(session.scene,self.level.id=='s5' and {voices={}} or nil);self.view=require('render.MissionView').New(session.scene)
    self.radio=require('audio.StoryRadio').New()
    if self.level.id~='s1' then self.view:AlarmOff() end
    self.explosion=require('render.SalvageExplosion').New(session.scene,nil,{checkpoint=checkpoint and function(p) checkpoint(.35+p*.65) end or nil,retain=function(explosion) self.explosion=explosion end})
    self.view.onLand=function(pos,k) require('render.StoryStomp').Emit(session.effects,pos,k);session.stompV=(session.stompV or 0)-2.2 end
    for id,it in pairs(self.level.intel or {}) do if not it.drop then self.view:AddIntel(id,it.pos) end end
    for _,pos in ipairs(self.level.setup and self.level.setup.collectors or {}) do self.view:Collector(pos,true) end
    for _,site in ipairs(self.level.setup and self.level.setup.sites or {}) do self.view:AddSite(site.id,site.pos) end
    if self.convoy then self.view:Truck(self.convoy) end
    self.wallTimers=require('story.MissionTimers').New(self)
    return self
end
function M:Environment(unit,overrideScale)
    local world=self.world;local scale=overrideScale or (unit.team=='red' and self.damageScale or 1)
    return {stats=unit==self.player and world.stats or {shots=0},killHeight=-80,
        castRay=function(...) return world:CastRay(...) end,
        sweepDrill=function(...) return world:SweepDrill(...) end,
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
function M:Banner(kick,title,sub,kind,ms)
    local at=self.rules.time
    self.banner={kick=kick,title=title,sub=sub or '',kind=kind or '',at=at,untilAt=at+(ms or 3200)/1000}
end
function M:Spawn(step)
    for i,e in ipairs(step.enemies) do
        local n=type(e.at)=='string' and assert(self.world.layout.nav.nodes[e.at]) or nil
        local off=e.off or {0,0};local p=n and {n[1]+off[1],n[2],n[3]+off[2]} or e.at
        local x,z=p[1],#p==3 and p[3] or p[2];local y=#p==3 and p[2] or 40
        if n or #p~=3 then local hit=self.world:CastRay({x,y+(n and 5 or 40),z},{0,-1,0},160,self.player.vehicle.body);if hit then y=hit.point[2] end end
        local at={pos={x,y+1.5,z},yaw=math.atan(self.player.pos[1]-x,self.player.pos[3]-z)}
        local source,tier=SpawnSource(self,e,step.role)
        local unit=Unit.New(self.world,source,{name=e.name or step.name or '狐狐海盗团',spawn=at,team='red',autoRespawn=false,externalControl=true,combat=true,spawnSpecCache=self.spawnSpecCache})
        if not e.flee then unit.hullMin=e.boss and .35 or .55 end
        unit.spawnAt=Center(unit.spec,at);unit.vehicle:Place(unit.spawnAt.pos,unit.spawnAt.yaw);unit:SavePose();unit.previous=unit.current
        self.world.units[#self.world.units+1]=unit;self.entries[#self.entries+1]={unit=unit,target=e.target,tag=step.tag,flee=e.flee,boss=e.boss,scripted=e.scripted or e.noBlast,
            driver=(e.driver=='drill' and require('combat.DrillRaiderDriver') or Driver).New(self.world,unit,e.role or step.role or 'assault',i,{tier=tier,
                seed='story:'..self.level.id..':'..(step.tag or '')..':'..(i-1)..':'..math.floor(self.rules.time)}),env=self:Environment(unit)}
        if self.session.hud then self.session.hud.overlay.tags[#self.session.hud.overlay.tags+1]={unit=unit,visible=false} end
        require('render.StoryStomp').Emit(self.session.effects,{at.pos[1],at.pos[2]-1,at.pos[3]},.8)
    end
end
function M:ClearEnemies(tag)
    local removed={}
    for i=#self.entries,2,-1 do local entry=self.entries[i]
        if not tag or entry.tag==tag then removed[entry.unit]=true;entry.unit:Dispose();table.remove(self.entries,i) end
    end
    for i=#self.world.units,1,-1 do if removed[self.world.units[i]] then table.remove(self.world.units,i) end end
    if self.session.hud then local tags=self.session.hud.overlay.tags
        for i=#tags,1,-1 do if removed[tags[i].unit] then table.remove(tags,i) end end
    end
end
function M:BeforeStep(dt,command,aim)
    if self.boss then self.boss:BeforeStep(dt) end
    for _,entry in ipairs(self.entries) do local u=entry.unit
        u:Flush()
        if u~=self.player and u.alive then self:Doomed(entry) end
        if u.alive and not entry.mustFlee then
            local cmd,target,firing,driverInfo={throttle=0,steer=0,handbrake=true},u:Position(),false,nil
            if u==self.player then cmd=command;target=aim;firing=command.firing==true
                if self.boss and self.boss.cinematic then cmd={throttle=0,steer=0,handbrake=true};firing=false end
            elseif self.player.alive or entry.target=='truck' then
                local victim=self.player
                if entry.target=='truck' and self.convoy then victim=self.truckTarget end
                cmd,target,firing,driverInfo=entry.driver:Step(dt,victim)
                require('combat.DriverActions').Apply(u,driverInfo)
            end
            if u==self.player then
                if self.world.time-u.hitAt>=5 then u:Heal(.15*dt);self.regen=self.regen+dt
                    if self.regen>=.5 then self.regen=self.regen-.5;u:RestoreMissing(1);u:Flush() end
                else self.regen=0 end
            end
            if u.alive then
                local v=u.vehicle
                if u~=self.player and not self.player.alive and entry.target~='truck' then
                    v:Step(cmd,dt);v:StepRotors(nil,nil,dt)
                else
                    v:StepRotors(target,cmd.rotorStep,dt);require('drive.RotorMotion').Weapons(v.rotors,u.weapons)
                    v:Step(cmd,dt);local p,velocity=v.body.translation(),v.body.linvel()
                    local eye=u==self.player and self.session.camera:GetNode().worldPosition or nil
                    u.weapons:Step(dt,{firing=firing,salvo=driverInfo and driverInfo.salvo,aim=target,pos={p.x,p.y,p.z},quat=v.body.rotation(),vel={velocity.x,velocity.y,velocity.z},body=v.body,team=u.team,
                        eye=eye and {-eye.x,eye.y,eye.z}},entry.env)
                    self.session.effects:Consume(u.weapons.fx,u~=self.player);self.session.weaponAudio:Consume(u.weapons.fx,u~=self.player)
                    if p.y< -40 then u.bodyHp=0;u.kill='掉出地图';u.dirty=true;u:Flush() end
                end
            end
        end
    end
end
function M:Doomed(entry)
    local u=entry.unit;local action=require('story.EnemyRules').Doom(u.spec,u.hull~=nil,u:Health(),entry.flee,entry.boss)
    if action=='flee' then entry.mustFlee=true;return true end
    if action~='destroy' then return false end
    local core=u.bp:CoreParts()[1];if not core then return false end
    local events=self.world.viewEvents
    for i=#events,1,-1 do local e=events[i];if e.unit==u and(e.type=='unitRebuilt' or e.type=='partRestored') then table.remove(events,i) end end
    u.incomingDamageMultiplier=1;u:Damage(core.id,require('parts.Defs').PARTS.core.hp*u.partScale*10,u:Position());u:Flush();return true
end
function M:CarSize()
    local u=self.player;local p=u:Position();local key=u.bp:Size()
    local view=self.session.view and self.session.view.view;local root=view and view.root
    if root and self.sizeKey==key and self.sizeVis==root and self.size then return self.size end
    self.sizeKey=key;self.sizeVis=root
    if root then
        local box=view:GetWorldBounds()
        if box:Defined() then
            local a,z=box.min,box.max
            self.size={w=math.max(z.x-a.x,z.z-a.z)/2,below=math.max(1.5,p[2]-a.y),above=math.max(1.5,z.y-p[2])};return self.size
        end
    end
    -- Until rendered bounds exist, use the source blueprint-cell fallback in metres.
    local bb=u.bp:Stats().bb;local valid=bb and bb.minX==bb.minX and bb.minX~=math.huge and bb.minX~=-math.huge
    local cell=require('Config').CELL;local h=valid and (bb.maxY-bb.minY+1)*cell/2 or 1.5
    self.sizeVis=nil
    self.size={w=valid and math.max(bb.maxX-bb.minX,bb.maxZ-bb.minZ)*cell/2 or 2,below=h,above=h};return self.size
end
function M:AfterStep(dt)
    -- Preserve the source Map's spawn order, including simultaneous kills and flee dialogue.
    local i=2
    while i<=#self.entries do local entry=self.entries[i];local u=entry.unit
        local fleeing=entry.flee and u.alive and (entry.mustFlee or u:Integrity()<entry.flee)
        if not u.alive or fleeing then
            if fleeing then
                local p=u:Position();require('render.StoryStomp').Emit(self.session.effects,{p[1],p[2]-1,p[3]},.8)
                local s=self.rules:StepSpec();self.rules:Emit('say',{lines=s and s.fleeLines,urgent=true})
                self.rules:Emit('banner',{kick='狐狐撤退了',title='小狐号溜了',sub='「这次不算！」',kind='ok',ms=2600});self.rules.flags.huhuFled=true
            else
                local pos=u:Position();self.rules:Killed(pos)
                if not entry.flee and not entry.scripted then
                    self.explosion:Explode(pos,math.min(5,(u.spec.bounds.radius or 3)*.8),entry.boss)
                    local far=math.sqrt((pos[1]-self.player.pos[1])^2+(pos[3]-self.player.pos[3])^2)
                    self.session.trauma=math.max(self.session.trauma or 0,(entry.boss and .8 or .55)*math.max(0,1-far/70))
                end
            end
            u:Dispose();table.remove(self.entries,i)
            for j=#self.world.units,1,-1 do if self.world.units[j]==u then table.remove(self.world.units,j) end end
            if self.session.hud then for j=#self.session.hud.overlay.tags,1,-1 do if self.session.hud.overlay.tags[j].unit==u then table.remove(self.session.hud.overlay.tags,j) end end end
        else i=i+1 end
    end
    local u=self.player
    local enemyPositions=self.enemyPositions;for i=#enemyPositions,1,-1 do enemyPositions[i]=nil end
    local tags=self.enemyTags or {};self.enemyTags=tags;tags.guard=0;tags.counter=0
    for i=2,#self.entries do local entry=self.entries[i];if entry.unit.alive then
        enemyPositions[#enemyPositions+1]=entry.unit:Position();if entry.tag then tags[entry.tag]=(tags[entry.tag] or 0)+1 end
    end end
    self.rules:Step(dt,{alive=u.alive,pos=u:Position(),speed=u.alive and u.vehicle.speed or 0,yaw=u.alive and u.vehicle:Yaw() or 0,
        size=u.alive and self:CarSize() or nil,enemies=#self.entries-1,enemyPositions=enemyPositions,enemyTags=tags,nav=self.world.layout.nav,
        bossDone=self.boss and self.boss.done,bossTarget=self.boss and self.boss:Target(),
        talking=self.voice:Talking(),interact=self.session.pointer.captured and (self.session.controls.held.interact or input:GetKeyDown(KEY_G))})
    self:Events();self.view:Update(dt,self.rules,self.session.camera:GetCamera())
end
function M:Events()
    for _,e in ipairs(self.rules:Drain()) do
        if e.type=='begin' then self:Banner('剧情模式 · 任务 '..self.level.no,self.level.name,self.level.en..' · '..(self.level.place or '坠舰陨坑')..' · '..(self.level.tagline or 'CV-07 ARGUS'),'',4200)
        elseif e.type=='objective' then
            if self.choiceView then self.choiceView:Cancel() end
            if self.objective then self.objective:Objective(e.step,e.index,#self.level.steps) end
            self.voice:Say(e.step.start);self.view:Objective(e.step,self.rules:Target())
            if e.step.kind=='boss' and not self.boss then self.boss=require('combat.StoryBoss').New(self,e.step);self.view:HideBeacon() end
        elseif e.type=='objectiveDone' then self.voice:Say(e.lines);if e.step.id=='exit' then self.view:AlarmOff() end
        elseif e.type=='intel' then self.radio:Play('pickup');self.view:TakeIntel(e.id);self.intelCard={item=e.item,untilAt=self.rules.time+8}
        elseif e.type=='collector' then
            local p=e.step.pos;local x,z=p[1],p[3]
            if math.sqrt((e.pos[1]-x)^2+(e.pos[3]-z)^2)<5.5 then x=e.pos[1]+math.cos(e.yaw)*6.5;z=e.pos[3]-math.sin(e.yaw)*6.5 end
            local hit=self.world:CastRay({x,p[2]+8,z},{0,-1,0},30,self.player.vehicle.body)
            self.view:Collector({x,hit and hit.point[2] or p[2],z})
            self.radio:Play('install')
            local total=0;for _,step in ipairs(self.level.steps or {}) do if step.kind=='install' then total=total+1 end end
            local count=self.rules.stats.collectors;local symbol=({'①','②','③'})[count] or tostring(count)
            self:Banner('采集器上线','采集器 '..symbol,count..' / '..total..' 台已安装','install',2400)
        elseif e.type=='say' then self.voice:Say(e.lines,e.urgent)
        elseif e.type=='spawn' then self:Spawn(e)
        elseif e.type=='clearEnemies' then self:ClearEnemies()
        elseif e.type=='dropIntel' then self.view:AddIntel(e.id,e.pos)
        elseif e.type=='hideBeacon' then self.view:HideBeacon()
        elseif e.type=='siteCaptured' then self.view:SiteCaptured(e.id);local site=self.view.sites[e.id];if site then local p=site.flag.root.position;require('render.StoryStomp').Emit(self.session.effects,{-p.x,p.y,p.z},.6) end
        elseif e.type=='scrub' then self.radio:Play('pickup');self.view:Scrub(e.id)
        elseif e.type=='radio' then
            if self.choiceView and e.choice then self.choiceView:Pick(e.choice,e.index) end
            self.radio:Play(e.cue)
        elseif e.type=='choice' then
            if self.choiceView then self.choiceView:Open(e.choice or self.rules.choice) end
            self.radio:Play('open')
        elseif e.type=='heal' then self.player:Heal(e.fraction)
        elseif e.type=='restore' then self.player:RestoreMissing(e.count);self.player:Flush()
        elseif e.type=='place' then if self.player.alive then self:Place(e.at) end
        elseif e.type=='banner' then self:Banner(e.kick or '',e.title,e.sub,e.kind,e.ms)
        elseif e.type=='truckHit' then self.view.truck.hitAt=self.view.time
        elseif e.type=='fight' then self.radio:Play('alert');self:Spawn({enemies=e.step.enemies,role=e.step.role,name=e.step.name,tag=e.step.id});self.voice:Say(e.step.alert,true);self.view:HideBeacon()
            self:Banner('遭遇敌人','海盗侦察队',#(e.step.enemies or {})..' 艘侦察艇 · 狐狐海盗团','enemy',2800)
        elseif e.type=='clear' then if e.timeout then self:ClearEnemies() end;self.view:AddIntel('log',e.pos)
        elseif e.type=='dead' then self.session.controls:Clear()
        elseif e.type=='respawn' then self.radio:Play('drop');self.player:Spawn();self:Place(e.at);self.regen=0;self.sizeKey=nil;self.voice:Say(self.level.respawn,true)
        elseif e.type=='complete' then self.radio:Play('done');self:ClearEnemies();self.view:Objective(nil,nil)
            if self.choiceView then self.choiceView:Cancel() end
            if self.objective then self.objective:Done() end
            self:Banner('任务 '..self.level.no..' · '..self.level.name,'任务完成','MISSION COMPLETE','ok',5200)
        elseif e.type=='result' then
            self.voice:PrepareResultQuote(self:Quote())
            self.session:Pause();local store=self.session.app.store
            local valid=function(d) return type(d)=='table' end;local progress=store:Read('story-progress',valid) or {};local old=progress[self.level.id]
            local rank={S=3,A=2,B=1};self.newBest=not old or e.time<(old.time or math.huge) or (rank[e.grade] or 0)>(rank[old.grade] or 0)
            progress[self.level.id]={grade=old and (rank[old.grade] or 0)>=(rank[e.grade] or 0) and old.grade or e.grade,time=math.min(old and old.time or math.huge,e.time),clears=(old and old.clears or 0)+1}
            self.saved,self.saveError=store:Write('story-progress',progress,valid)
        end
    end
    if self.objective and self.player.alive and self.rules.retitle then self.objective:Retitle(self.rules.retitle) end
end
function M:StartEpilogue(root,onDone)
    if self.epilogue then return true end
    if self.level.id~='s5' or not self.rules.finished then return false end
    local store=self.session.app.store;local valid=function(d) return type(d)=='table' end
    local progress=store:Read('story-progress',valid) or {};local version=self.level.epilogue.version
    if (tonumber(progress.epilogue) or 0)>=version then return false end
    progress.epilogue=version
    self.epilogueSaved,self.epilogueSaveError=store:Write('story-progress',progress,valid)
    self.epilogue=require('ui.Epilogue').Attach(self.session.scene,root,function()
        self.epilogue=nil;if onDone then onDone() end
    end,self.boss and self.boss.shots)
    return true
end
function M:FramePresented() if self.boss then self.boss:FramePresented() end end
function M:Update(dt)
    self.radio:Update(dt,self.session:HasFocus())
    if self.epilogue then self.epilogue:Update(dt,self.session:HasFocus());return end
    if not self.rules.finished then self.explosion:Update(dt,self.session.camera:GetNode(),self.player:Position()) end
    self.voice:Update(dt,self.session:HasFocus())
    local title=self.rules.retitle
    if self.boss and self.session:HasFocus() then self.boss:Update(dt) end
    if self.objective and self.rules.retitle and self.rules.retitle~=title then self.objective:Retitle(self.rules.retitle) end
end
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
        choice=r.choice,flags=r.flags,progress=r.progress,failing=r.failAt~=nil,boss=self.boss and self.boss:Snapshot()}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.wallTimers then self.wallTimers:Dispose();self.wallTimers=nil end
    if self.objective then self.objective:Dispose();self.objective=nil end
    if self.choiceView then self.choiceView:Dispose();self.choiceView=nil end
    if self.spawnSpecCache then self.spawnSpecCache:Dispose();self.spawnSpecCache=nil end
    if self.epilogue then self.epilogue:Dispose();self.epilogue=nil end
    if self.boss then self.boss:Dispose() end
    self:ClearEnemies()
    if self.voice then self.voice:Dispose() end
    if self.radio then self.radio:Dispose() end
    if self.view then self.view:Dispose() end
    if self.explosion then self.explosion:Dispose() end
    self.entries={};self.enemyPositions={};self.enemyTags={}
    self.player=nil;self.truckTarget=nil;self.convoy=nil;self.boss=nil
    self.voice=nil;self.radio=nil;self.view=nil;self.explosion=nil;self.world=nil;self.session=nil
end
return M
