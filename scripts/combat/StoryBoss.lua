local Data=require('core.ResourceData').Read('Story/Mission/Level5.json')
local Rules=require 'story.BossRules'
local Unit=require 'combat.CarUnit'
local Driver=require 'combat.EnemyDriver'
local V=require 'core.Math3'
local Coord=require 'core.Coord'
local Radio=require 'audio.StoryRadio'
local M={};M.__index=M
local C=Data.boss
local PARK={throttle=0,steer=0,strafe=0,climb=0,handbrake=true,jump=false,boost=false,cutLift=false}
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
local function Wrap(a) return math.atan(math.sin(a),math.cos(a)) end
local function Vec(p) return {x=p[1],y=p[2],z=p[3]} end
function M.Dependencies(player)
    local BP=require 'construction.Blueprint';local parts=BP.New():Load(Data.fox):List()
    for _,p in ipairs(BP.New():Load(Data.level.steps[2].drillSource):List()) do parts[#parts+1]=p end
    local tier=V.Clamp((player:Stats().fitTier or {id=3}).id,2,4)
    for _,role in ipairs(C.ally.roles) do
        local source=require('combat.ArenaData').prefabs['blue:'..tier..':'..role..':0'] or require('combat.ArenaData').prefabs['red:'..tier..':'..role..':0']
        for _,p in ipairs(BP.New():Load(assert(source)):List()) do parts[#parts+1]=p end
    end
    local out=require('parts.Dependencies').For(parts)
    out[#out+1]='Story/Mission/Level5.json';out[#out+1]='Shaders/BLGL/Combat/Glow.shader';out[#out+1]='Shaders/BLGL/Combat/Ring.shader'
    for _,p in ipairs(require('render.BossView').Dependencies()) do out[#out+1]=p end
    for _,p in ipairs(Radio.Dependencies()) do out[#out+1]=p end
    return out
end
function M.New(mission,step)
    local self=setmetatable({},M);self.mission=mission;self.world=mission.world;self.session=mission.session;self.step=step
    local dps=0;for _,g in ipairs(mission.player.weapons.groups) do dps=dps+(({mg=336,laser=252,sniper=333,missile=187})[g.kind] or 120)*math.min(1,g.output or g.share or 0) end
    self.rules=Rules.New(C,dps);self.allies={};self.missiles={};self.pending={};self.shots={};self.time=0;self.flow={stage='wait',t=0}
    local points=self.world.layout.enginePit and self.world.layout.enginePit.points or {}
    self.at={enter=points.bossEnter or {30,0,330},outside=points.breachOutside or {30,0,400}}
    local o=V.Scale(V.Add(self.at.enter,self.at.outside),.5);o[2]=self:Ground(o[1],o[3])+2
    local yaw=math.atan(self.at.enter[1]-o[1],self.at.enter[3]-o[3])
    self.unit=Unit.New(self.world,Data.fox,{name='九尾狐 · 狐狐',spawn={pos=o,yaw=yaw},team='red',autoRespawn=false,externalControl=true,combat=true})
    assert(self.unit.alive,'Invalid original FOX boss blueprint');self:CenterPlace(self.unit,o,yaw);self.world.units[#self.world.units+1]=self.unit
    for _,p in ipairs(self.unit.bp:List()) do if p.type=='fxHead' then self.head=p end end
    self.tails={};for _,p in ipairs(self.unit.bp:List()) do if p.type:match('^fxTail') then self.tails[#self.tails+1]=p end end
    self.unit.HitRay=function(_,hit,damage,dir,pierce) return self:Hit(hit.point,damage,pierce) end
    self.unit.Explode=function(_,point,radius,damage) return V.Length(V.Sub(point,self.unit:Position()))<radius+14 and self:Hit(point,damage*.6) or 0 end
    self.unit.Damage=function() return 0 end
    self.unit.HurtHull=function() return 0 end
    self.env=mission:Environment(self.unit,C.dmg);self.driver=Driver.New(self.world,self.unit,'heavy',1)
    self.ownsRadio=mission.radio==nil;self.radio=mission.radio or Radio.New();self.view=require('render.BossView').New(self.session.scene,self);return self
end
function M:Ground(x,z) return self.world:GroundAt(x,z) end
function M:CenterPlace(unit,pos,yaw)
    local a,b=unit.spec.bounds.min,unit.spec.bounds.max;local x,z=(a[1]+b[1])/2,(a[3]+b[3])/2
    unit.spawnAt={pos={pos[1]-x*math.cos(yaw)-z*math.sin(yaw),pos[2],pos[3]+x*math.sin(yaw)-z*math.cos(yaw)},yaw=yaw}
    unit.vehicle:Place(unit.spawnAt.pos,yaw);unit:SavePose();unit.previous=unit.current
end
function M:PartCenter(part)
    local cells=part and part._cells or {};local p={0,0,0}
    for _,c in ipairs(cells) do p[1]=p[1]+c[1];p[2]=p[2]+c[2]+.5;p[3]=p[3]+c[3] end
    if #cells==0 then return V.Add(self.unit:Position(),{0,6,0}) end
    local body=self.unit.vehicle.body;return V.Add(V.Array(body.translation()),V.Rotate(body.rotation(),V.Scale(p,require('Config').CELL/#cells)))
end
function M:Cockpit() return self:PartCenter(self.head or self.unit.bp:CoreParts()[1]) end
function M:Feet()
    local p=self.unit:Position();local y=math.huge
    local control=self.unit.vehicle.mechControl or self.unit.vehicle.legControl
    for _,s in ipairs(control and control.list or {}) do if s.foot then y=math.min(y,s.foot[2]) end end
    return {p[1],y<math.huge and y or self:Ground(p[1],p[3]),p[3]}
end
function M:Nodes()
    local control=self.unit.vehicle.mechControl or self.unit.vehicle.legControl;local legs=control and control.list or {}
    for i,n in ipairs(self.rules.nodes) do local foot=legs[i] and legs[i].foot
        n.pos=foot and V.Add(foot,{0,C.node.lift,0}) or V.Add(self.unit:Position(),{0,-6,0})
    end
end
function M:Hit(point,damage,pierce) self:Nodes();local amount=self.rules:Hit(point,damage,pierce,self:Cockpit());self:Events();return amount end
function M:Team() local out={};if self.mission.player.alive then out[1]=self.mission.player end
    for _,a in ipairs(self.allies) do if a.unit and a.unit.alive then out[#out+1]=a.unit end end;return out end
function M:Victim()
    local team=self:Team();if #team==0 then return nil end
    if #team==1 or self.mission.player.alive and math.random()<.6 then return team[1] end
    return team[math.random(self.mission.player.alive and 2 or 1,#team)]
end
function M:Say(key,bark)
    local lines=self.step.lines[key];if not lines then return end
    if bark and (self.mission.voice:Talking() or self.time<(self.storyUntil or 0)) then return end
    if type(lines[1])=='string' then lines={lines} end
    local busy=self.time<(self.storyUntil or 0)
    if not bark then local duration=0;for _,line in ipairs(lines) do duration=duration+(utf8.len(line[2]) or #line[2])*.11+2 end;self.storyUntil=math.max(self.storyUntil or 0,self.time)+duration end
    self.mission.voice:Say(lines,not busy,busy)
end
function M:Banner(kick,title,sub,kind,ms) self.mission:Banner(kick,title,sub,kind,ms) end
function M:SpawnAlly(index)
    local p=self.mission.player:Position();local angle=(self.mission.player.vehicle and self.mission.player.vehicle:Yaw() or 0)+math.pi+(index-2)*.8
    local x,z=p[1]+math.sin(angle)*22,p[3]+math.cos(angle)*22;local tier=V.Clamp((self.mission.player.bp:Stats().fitTier or {id=3}).id,2,4)
    local role=C.ally.roles[index];local arena=require('combat.ArenaData');local source=arena.prefabs['blue:'..tier..':'..role..':0'] or arena.prefabs['red:'..tier..':'..role..':0']
    local u=Unit.New(self.world,source,{name=({'合同工 · 铁锤','合同工 · 螺丝','合同工 · 扳手'})[index],spawn={pos={x,self:Ground(x,z)+1.5,z},yaw=0},team='blue',autoRespawn=false,externalControl=true,combat=true})
    self:CenterPlace(u,{x,self:Ground(x,z)+1.5,z},math.atan(self.unit.pos[1]-x,self.unit.pos[3]-z));self.world.units[#self.world.units+1]=u
    self.allies[index]={unit=u,driver=Driver.New(self.world,u,role,index,{tier=tier,seed='fox-ally:'..(index-1)..':'..math.floor(self.time),aimSkill=1.3}),env=self.mission:Environment(u,C.ally.dmg)}
    self:Fx(u.pos,3);return u
end
function M:Remove(unit)
    unit:Dispose();for i=#self.world.units,1,-1 do if self.world.units[i]==unit then table.remove(self.world.units,i) end end
end
function M:UnderRoof(pos,margin)
    if self.world.UnderRoof and self.world:UnderRoof(pos[1],pos[3],margin or 1) then return true end
    local h=self.world:CastRay(V.Add(pos,{0,4,0}),{0,1,0},90,self.unit.vehicle.body)
    return h and h.owner and h.owner.ref~=self.unit or false
end
function M:Shelter(pos)
    local best,d=nil,math.huge
    for _,roof in ipairs(self.world.layout.enginePit and self.world.layout.enginePit.ceilings or {}) do
        if Flat(roof.center,pos)<d then best=roof.center;d=Flat(best,pos) end
    end
    return best and {best[1],self:Ground(best[1],best[3]),best[3]} or nil
end
function M:Target() local p=self.mission.player:Position();return self:Threat() and not self:UnderRoof(p,4) and self:Shelter(p) or self.unit:Position() end
function M:Threat() return self.rules.hp>0 and (self.rules.state=='barrage' or self.rules.state=='ult' or #self.missiles>0 or self.raid~=nil) end
function M:AllyTarget(unit)
    if self.rules.state=='ult' and self.rules.t>1 and not self:UnderRoof(unit.pos,3) then local shelter=self:Shelter(unit.pos);if shelter then return shelter,true end end
    for i=2,#self.mission.entries do local e=self.mission.entries[i];if e.tag=='drill' and e.unit.alive and Flat(unit.pos,e.unit.pos)<70 then return e.unit:Position(),false,e.unit end end
    local best,d=nil,math.huge
    if self.rules.state~='kneel' then for _,n in ipairs(self.rules.nodes) do if not n.broken and Flat(unit.pos,n.pos)<d then best=n.pos;d=Flat(unit.pos,n.pos) end end end
    return best or self:Cockpit(),false,self.unit
end
function M:StepUnit(u,cmd,aim,firing,env,dt,salvo)
    u:Flush();if not u.alive then return end;local v=u.vehicle
    v:StepRotors(aim,cmd.rotorStep,dt);require('drive.RotorMotion').Weapons(v.rotors,u.weapons);v:Step(cmd,dt)
    u.weapons:Step(dt,{firing=firing,aim=aim,pos=V.Array(v.body.translation()),quat=v.body.rotation(),vel=V.Array(v.body.linvel()),body=v.body,team=u.team,salvo=salvo},env)
    self.session.effects:Consume(u.weapons.fx);self.session.weaponAudio:Consume(u.weapons.fx,true)
end
function M:BeforeStep(dt)
    if self.disposed then return end;local r=self.rules;self:Nodes()
    for i,a in ipairs(self.allies) do
        if a.deadAt then if self.time-a.deadAt>C.ally.respawn and r.hp>0 and r.state~='ult' then self:SpawnAlly(i) end
        else local u=a.unit
            if not u.alive or u:Health()<C.ally.hull then self:Fx(u.pos,3);self:Remove(u);a.deadAt=self.time;self:Say('allyDown',true)
            else local target,passive,reference=self:AllyTarget(u)
                local fake={passive=passive,radius=passive and 3 or nil,unit=reference,spec={bounds={min={0,0,0},max={0,0,0}}},Position=function() return target end}
                local cmd,aim,fire,driverInfo=a.driver:Step(dt,fake)
                require('combat.DriverActions').Apply(u,driverInfo)
                self:StepUnit(u,cmd,aim,fire and not passive,a.env,dt,driverInfo and driverInfo.salvo)
            end
        end
    end
    local player=self.mission.player
    if r.state=='kneel' and player.weapons then player.weapons.energy=math.min(player.weapons.energyMax,player.weapons.energy+require('combat.WeaponDefs').ENERGY.regen*(C.kneelEnergy-1)*dt) end
    local u=self.unit;local pos=u:Position();local victim=self.focusUnit
    if not victim or not victim.alive or self.time>(self.focusUntil or 0) then self.focusUnit=self:Victim();self.focusUntil=self.time+5+math.random()*2;victim=self.focusUnit end
    local target=victim and victim:Position();local cmd,fire,aim=PARK,false,nil
    local function Face(to,throttle,strafe)
        local err=Wrap(math.atan(to[1]-pos[1],to[3]-pos[3])-u.vehicle:Yaw());local yr=u.vehicle.body.angvel().y
        return {throttle=throttle or 0,steer=V.Clamp(err*2.4-yr*.35,-1,1),strafe=strafe or 0,handbrake=false}
    end
    if r.state=='intro' then cmd=Face(self.at.enter,Flat(pos,self.at.enter)>8 and .8 or 0)
    elseif target and r.state=='fight' then
        local dd=Flat(pos,target);local home=self.world.layout.enginePit and self.world.layout.enginePit.points.floorCentre or {0,0,0}
        local leash=Flat(pos,home)>C.leash;local goal=leash and home or target;local walk=C.walk[r.phase]
        if dd>C.keep[2] then
            self.driver.route=self.driver:Path(pos,goal)
            while #self.driver.route>0 and Flat(pos,self.driver.nav.nodes[self.driver.route[1]])<20 do table.remove(self.driver.route,1) end
            if #self.driver.route>1 then goal=self.driver.nav.nodes[self.driver.route[1]] end
        end
        cmd=Face(goal,leash and walk*1.6 or dd>C.keep[2]*2.2 and walk*2.4 or dd>C.keep[2] and walk or dd<C.keep[1] and -.22 or walk*.35,
            not leash and dd<C.keep[2] and math.sin(self.time*.23)*.35 or 0)
        if math.abs(cmd.throttle)>.2 and dd>C.keep[2] then
            if not self.stuckRef or Flat(self.stuckRef.pos,pos)>C.hop.moved then self.stuckRef={pos={table.unpack(pos)},time=self.time}
            elseif self.time-self.stuckRef.time>C.hop.stuck then self.wantHop=self:OpenNode(target,40,80) or self:OpenNode(pos,25,60);self.stuckRef=nil end
        else self.stuckRef=nil end
        r.cool.fire=r.cool.fire-dt
        if r.cool.fire<=0 then self.firing=not self.firing;r.cool.fire=C.burst[self.firing and 1 or 2]*(.8+math.random()*.4);self.aimErr={(math.random()-.5)*2*C.aimErr,(math.random()-.5)*2*C.aimErr,(math.random()-.5)*2*C.aimErr} end
        if self.firing and dd<420 then
            local eye=self:Cockpit();local to=V.Add(target,{0,1,0});local delta=V.Sub(to,eye);local len=V.Length(delta)
            local hit=self.world:CastRay(eye,V.Normalize(delta),len,u.vehicle.body)
            if not hit or hit.owner and hit.owner.ref==victim then fire=true;aim=V.Add(to,V.Scale(self.aimErr or {0,0,0},len)) end
        end
    elseif target and ({standoff=true,stomp=true,lanes=true,barrage=true,stuck=true,transition=true,rise=true,recover=true})[r.state] then cmd=Face(target) end
    local cockpit=self:Cockpit();aim=aim or V.Add(cockpit,{math.sin(u.vehicle:Yaw())*300,0,math.cos(u.vehicle:Yaw())*300})
    self:StepUnit(u,cmd,aim,fire,self.env,dt,true)
    if self.flight and r.state=='slamAir' then self.flight.t=self.flight.t+dt;local f=self.flight;local k=math.min(1,f.t/f.duration);local b=u.vehicle.body
        if k>=1 then b.setLinvel({x=0,y=math.min(b.linvel().y,-6),z=0}) else
            local want=V.Mix(f.from,f.to,k);want[2]=want[2]+4*f.apex*k*(1-k)
            b.setLinvel(Vec(V.Scale(V.Sub(want,V.Array(b.translation())),1/dt)));b.setAngvel({x=0,y=0,z=0})
        end
    end
    if not ({fight=true,stomp=true,barrage=true,stuck=true,transition=true})[r.state] then for _,g in ipairs(u.weapons.groups) do for _,w in ipairs(g.weapons) do if w.stats.windup then w.charge=0;w.windup=0 end end end end
    self:Projectiles(dt)
end
function M:OpenNode(to,min,max)
    local best,d=nil,math.huge
    for _,p in pairs(self.world.layout.nav and self.world.layout.nav.nodes or {}) do local away=Flat(p,to)
        if away>=min and away<=max and not self:UnderRoof(p,-8) and Flat(p,self.unit.pos)<d then best=p;d=Flat(p,self.unit.pos) end
    end
    return best
end
function M:Fx(pos,size,big) self.mission.explosion:Explode(pos,size,big==true) end
function M:HitUnit(unit,damage,from,push,lift)
    self.world.attacker=self.unit;unit:Explode(V.Add(unit:Position(),{0,2.5,0}),7,damage);self.world.attacker=nil;unit:Flush()
    if unit.vehicle and push then local delta=V.Sub(unit.pos,from);local length=math.max(1,Flat(unit.pos,from));local mass=unit.vehicle.body.mass()
        unit.vehicle.body.applyImpulse({x=delta[1]/length*push*mass,y=(lift or 6)*mass,z=delta[3]/length*push*mass}) end
end
function M:Events()
    for _,e in ipairs(self.rules:Drain()) do
        if e.type=='say' then self:Say(e.key)
        elseif e.type=='kneelLine' then local pool=self.step.lines.kneelPool;self.mission.voice:Say({pool[math.random(#pool)]},false,true)
        elseif e.type=='damage' then self.world:RecordDamage(self.unit,e.amount,e.point,{shield=e.shield,pierce=e.pierce,broke=e.broke})
        elseif e.type=='energyFull' then local ws=self.mission.player.weapons;ws.energy=ws.energyMax;ws.offline=false
        elseif e.type=='kneel' then self:Capture('kneel1',.6);self.mission.rules.stats.kneels=e.kneels;self.mission.rules.retitle='打驾驶舱'
            local left=4-self.rules:Broken();local sub=left>0 and '伤害 ×3 · 驾驶舱 ×4 · 能量回满 · 还剩 '..left..' 条好腿' or self.exposedBanner and '伤害 ×3 · 驾驶舱 ×4 · 能量回满' or '四条腿全废 · 以后打满失衡槽它还会跪'
            self:Banner('虚弱','九尾狐跪下了',(e.interrupted and '大招被打断了 · ' or '')..sub,'install',2600);if left==0 then self.exposedBanner=true end
        elseif e.type=='riseWarning' then self.mission.rules.retitle='它要站起来了'
        elseif e.type=='riseForced' then self:Banner('硬撑','它硬撑着站起来了','这一跪打满了 · 再打下一条腿','enemy',2000)
        elseif e.type=='phase' then self.radio:Play('alert');self:Banner(e.phase==2 and '二阶段' or '三阶段',e.phase==2 and '急眼了' or '九尾全开',e.phase==2 and '钻头小兵 · 跳砸' or '九个导弹舱齐射 · 进顶棚底下','enemy',3000)
        elseif e.type=='nodeBreak' then self.radio:Play('alert');self:Fx(e.pos,2.2)
        elseif e.type=='drills' then local at=self.at.enter;local enemies={};for _,x in ipairs({-14,0,14}) do enemies[#enemies+1]={at={at[1]+x,at[3]-18-math.abs(x)},role='assault',driver='drill',source=self.step.drillSource,name='海盗钻头车 · 天元突破'} end;self.mission:Spawn({enemies=enemies,tag='drill'})
            self:Banner('增援','海盗钻头车','3 辆 · 天元突破 · 从北缺口冲进来','enemy',2400)
        elseif e.type=='impact' then
            self:Fx(V.Add(e.pos,{0,1,0}),4);self.shock={pos=e.pos,r=e.r,age=0}
            local player=self.mission.player;local far=player.alive and Flat(player:Position(),e.pos) or 999
            self.session.trauma=math.max(self.session.trauma or 0,.85*math.max(.25,1-far/120))
            for _,u in ipairs(self:Team()) do local p=u:Position();local tel=u.vehicle.telemetry
                local distance=Flat(p,e.pos);local grounded=(tel.contact or 0)>0 or (tel.mechContacts or tel.legContacts or 0)>0 or (tel.hovers or 0)>0
                local exposed=u==self.mission.player and (grounded or p[2]-e.pos[2]<4) or u~=self.mission.player and p[2]-e.pos[2]<=6
                if distance<e.r and exposed then self:HitUnit(u,e.damage*(1-.4*distance/e.r),e.pos,C.stomp.push,7);if u==self.mission.player and e.kind=='stomp' then self:Say('stompHit',true) end end
            end
            if e.kind=='slam' then for i=#self.mission.entries,2,-1 do local entry=self.mission.entries[i];if entry.tag=='drill' and entry.unit.alive and Flat(entry.unit.pos,e.pos)<11 then entry.unit.bodyHp=0;entry.unit.kill='九尾狐踩扁了';entry.unit.dirty=true;entry.unit:Flush() end end end
        elseif e.type=='land' then local body=self.unit.vehicle.body;local velocity=body.linvel();body.setLinvel({x=0,y=math.min(0,velocity.y),z=0});self.flight=nil
        elseif e.type=='hopImpact' then self.shock={pos=e.pos,r=e.r,age=0};self:Fx(V.Add(e.pos,{0,1,0}),3)
        elseif e.type=='sweep' then
            local half=C.sweep.arc*math.pi/360
            for k=-2,2 do local a=e.yaw+k*half/2.2;self:Fx({e.pos[1]+math.sin(a)*C.sweep.r*.6,e.pos[2]+1.5,e.pos[3]+math.cos(a)*C.sweep.r*.6},3.2) end
            self.session.trauma=math.max(self.session.trauma or 0,.55)
            for _,u in ipairs(self:Team()) do local p=u:Position();local a=Wrap(math.atan(p[1]-e.pos[1],p[3]-e.pos[3])-e.yaw)
            if Flat(p,e.pos)<=C.sweep.r and math.abs(a)<=C.sweep.arc*math.pi/360 and p[2]-e.pos[2]<=12 then self:HitUnit(u,C.sweep.dmg,e.pos,C.sweep.push);if u==self.mission.player then self:Say('sweepHit',true) end end
        end
        elseif e.type=='lanes' then
            for i=0,C.lanes.n-1 do local a=e.yaw+i*math.pi*2/C.lanes.n
                for k=1,4 do local d=C.lanes.len*k/4.5;local x,z=e.pos[1]+math.sin(a)*d,e.pos[3]+math.cos(a)*d;self:Fx({x,self:Ground(x,z)+1,z},2.6) end
            end
            self.session.trauma=math.max(self.session.trauma or 0,.5)
            for _,u in ipairs(self:Team()) do local p=u:Position();for i=0,C.lanes.n-1 do local a=e.yaw+i*math.pi*2/C.lanes.n
            local dx,dz=p[1]-e.pos[1],p[3]-e.pos[3];local along=dx*math.sin(a)+dz*math.cos(a);local off=math.abs(dx*math.cos(a)-dz*math.sin(a))
            if along>=0 and along<=C.lanes.len and off<=C.lanes.w/2+1.5 then self:HitUnit(u,C.lanes.dmg,V.Add(p,{0,-2,0}),6);if u==self.mission.player then self:Say('lanesHit',true) end;break end
        end end
        elseif e.type=='ultBlast' then self.radio:Play('alert');self:Capture('ult',.3);local safe=true;self.ultFlash=self.time
            self.session.trauma=1
            local center=self.world.layout.enginePit and self.world.layout.enginePit.points.floorCentre or {0,0,0}
            for _=1,14 do local a=math.random()*math.pi*2;local r=40+math.random()*300;local x,z=center[1]+math.sin(a)*r,center[3]+math.cos(a)*r;self:Fx({x,self:Ground(x,z)+2,z},5,true) end
            for _,u in ipairs(self:Team()) do if not self:UnderRoof(u:Position(),1) then
                local amount=u.bodyHpMax*C.ult.hit*(u==self.mission.player and 1 or C.ally.ult);self.world.attacker=self.unit
                if u.hull then u:HurtHull(amount,u.pos);u:RecordDamage(amount,u.pos) end
                u:Explode(V.Add(u.pos,{0,1,0}),5,u.hull and 300 or amount);self.world.attacker=nil;u:Flush();self:Fx(V.Add(u.pos,{0,2,0}),4,true);if u==self.mission.player then safe=false end
            end end;self:Say(safe and 'ultSafe' or 'ultHit');self.mission.rules.retitle=self.step.title
        elseif e.type=='launch' then
            local b=self.unit.vehicle.body;local from=V.Array(b.translation());local to={e.pos[1],self:Ground(e.pos[1],e.pos[3])+from[2]-self:Feet()[2],e.pos[3]}
            self.flight={from=from,to=to,t=0,duration=e.flight,apex=self.rules.slamApex}
        elseif e.type=='missiles' then for i=0,C.missile.n-1 do self.pending[#self.pending+1]={at=self.time+i*C.missile.gap,index=i} end
        elseif e.type=='raid' then self:StartRaid()
        elseif e.type=='die' then self:Capture('down',2.4);self.mission:ClearEnemies('drill');self.missiles={};self.pending={};self.raid=nil;self.flow={stage='ending',t=0};self.cinematic=true;self:Say('down');self.mission.rules.retitle='九尾狐瘫倒了'
        elseif e.type=='state' then
            if ({stomp=true,slamCrouch=true,sweep=true,lanes=true,ult=true})[e.state] then self.radio:Play('alert') end
            if e.state=='fight' then self.mission.rules.retitle=self.step.title end
        end
    end
end
function M:AddMissile(from,mid,to,duration,radius,damage,bomb)
    self.missiles[#self.missiles+1]={from=from,mid=mid,to=to,t=0,duration=duration,r=radius,damage=damage,bomb=bomb,prev=from,hist={}}
end
function M:StartRaid()
    local victim=self:Victim();if not victim then return end
    local p=victim:Position();local a=math.random()*math.pi*2;local dir={math.sin(a),0,math.cos(a)};local side={dir[3],0,-dir[1]};local planes={}
    for i=1,C.raid.bombers do local k=i-2;local center=V.Add(p,V.Scale(side,k*22));center[2]=self:Ground(center[1],center[3])+C.raid.alt+(i-1)*4
        planes[i]={from=V.Add(center,V.Scale(dir,-C.raid.len/2)),delay=math.abs(k)*.45,next=0}
    end
    self.raid={t=0,dir=dir,planes=planes};self.radio:Play('alert');self:Banner('空袭','海盗轰炸机','从天上来 · 钻进顶棚底下','enemy',2600);self:Say('raid')
end
function M:Projectiles(dt)
    for i=#self.pending,1,-1 do local e=self.pending[i];if self.time>=e.at and self.rules.hp>0 then
        local from=self:PartCenter(self.tails[e.index%math.max(1,#self.tails)+1] or self.head);local victim=self:Victim();local base=victim and victim:Position() or self.unit.pos
        local velocity=victim and victim.vehicle.body.linvel() or {x=0,z=0};local a=math.random()*math.pi*2;local radius=math.sqrt(math.random())*C.missile.spread
        local x,z=base[1]+velocity.x*C.missile.flight*.45+math.cos(a)*radius,base[3]+velocity.z*C.missile.flight*.45+math.sin(a)*radius
        local to={x,self:Ground(x,z),z};local mid={(from[1]+x)/2+(math.random()-.5)*30,math.max(from[2],to[2])+C.missile.apex*(.8+math.random()*.4),(from[3]+z)/2+(math.random()-.5)*30}
        self:AddMissile(from,mid,to,C.missile.flight*(.9+math.random()*.2),C.missile.r,C.missile.dmg)
        if e.index%3==0 then self.radio:Play('open') end;table.remove(self.pending,i)
    end end
    if self.raid then local raid=self.raid;raid.t=raid.t+dt;local alive=0
        for _,plane in ipairs(raid.planes) do local distance=(raid.t-plane.delay)*C.raid.speed
            if distance<0 then alive=alive+1;plane.pos=nil
            elseif distance<=C.raid.len then alive=alive+1;plane.pos=V.Add(plane.from,V.Scale(raid.dir,distance));plane.next=plane.next-dt
                if math.abs(distance-C.raid.len/2)<C.raid.drop and plane.next<=0 and self.rules.hp>0 then
                    plane.next=C.raid.gap;local ahead=C.raid.speed*C.raid.fall*.55;local a=math.random()*math.pi*2;local radius=math.sqrt(math.random())*C.raid.spread
                    local x,z=plane.pos[1]+raid.dir[1]*ahead+math.cos(a)*radius,plane.pos[3]+raid.dir[3]*ahead+math.sin(a)*radius
                    local to={x,self:Ground(x,z),z};local mid={(plane.pos[1]+x)/2+raid.dir[1]*ahead*.3,plane.pos[2]-4,(plane.pos[3]+z)/2+raid.dir[3]*ahead*.3}
                    self:AddMissile(V.Add(plane.pos,{0,-2,0}),mid,to,C.raid.fall,C.raid.r,C.raid.dmg,true)
                end
            else plane.pos=nil end
        end
        if alive==0 then self.raid=nil end
    end
    for i=#self.missiles,1,-1 do local ms=self.missiles[i];ms.t=ms.t+dt;local k=math.min(1,ms.t/ms.duration);local q=1-k
        local pos=V.Add(V.Add(V.Scale(ms.from,q*q),V.Scale(ms.mid,2*q*k)),V.Scale(ms.to,k*k));local seg=V.Sub(pos,ms.prev);local length=V.Length(seg)
        local boom=k>=1 and pos or nil
        if length>.001 and ms.t>.25 then local hit=self.world:CastRay(ms.prev,V.Scale(seg,1/length),length,self.unit.vehicle.body);if hit and (not hit.owner or hit.owner.ref~=self.unit) then boom=hit.point end end
        ms.prev=pos;table.insert(ms.hist,1,pos);if #ms.hist>14 then table.remove(ms.hist) end
        if boom then
            self:Fx(boom,2.4)
            for _,u in ipairs(self:Team()) do local center=V.Add(u:Position(),{0,1.2,0});local d=V.Length(V.Sub(center,boom))
                if d<=ms.r+2 then local origin=V.Add(boom,{0,1,0});local delta=V.Sub(center,origin);local len=V.Length(delta);local los=self.world:CastRay(origin,V.Normalize(delta),len,nil)
                    if not los or los.owner and los.owner.ref==u or los.dist>=len-2 then
                        self.world.attacker=self.unit;u:Explode(boom,ms.r,ms.damage);self.world.attacker=nil;u:Flush()
                        if u==self.mission.player then self.mission.rules.stats.missileHits=(self.mission.rules.stats.missileHits or 0)+1 end
                    end
                end
            end
            table.remove(self.missiles,i)
        end
    end
end
function M:Update(dt)
    if self.ownsRadio then self.radio:Update(dt) end;self.time=self.time+dt;local f=self.flow;f.t=f.t+dt
    if f.stage~='fight' then
        self.rules.time=self.rules.time+dt;self.rules.t=self.rules.t+dt
        for _,key in ipairs({'stomp','slam','missile','sweep','lanes','ult'}) do self.rules.cool[key]=self.rules.cool[key]-dt end
    end
    if f.stage=='wait' and f.t>.6 and not self.mission.voice:Talking() then self.radio:Play('alert');f.stage='introCine';f.t=0;self.rules:Go('intro');self.cinematic=true
    elseif f.stage=='introCine' then
        if f.t>4.6 and not f.banner then f.banner=true;self.radio:Play('alert');self:Banner('首领','九尾狐','MEGA 级 · 狐狐海盗团镇团之宝','enemy',3600) end
        if f.t>8 or self.skip then
            self.skip=false;if not f.banner then self:Banner('首领','九尾狐','MEGA 级 · 狐狐海盗团镇团之宝','enemy',2400) end
            self.cinematic=false;self.rules:Go('standoff');self:Say('entrance');f.stage='talk';f.t=0
        end
    elseif f.stage=='talk' and f.t>1 and not self.mission.voice:Talking() then
        f.stage='fight';f.t=0;self.rules:Go('fight');for i=1,3 do self:SpawnAlly(i) end;self:Banner('支援','合同工小队到了','铁锤 · 螺丝 · 扳手 · 跟你一起打','install',2600);self:Say('allies');self:Say('fightStart')
    elseif f.stage=='fight' then
        local drill=nil;local nearest=math.huge;for i=2,#self.mission.entries do local entry=self.mission.entries[i];if entry.tag=='drill' and entry.unit.alive then local pos=entry.unit:Position();local distance=Flat(pos,self.unit.pos);if distance<nearest then drill=pos;nearest=distance end end end
        self.rules:Step(dt,{pos=self.unit:Position(),target=self.focusUnit and self.focusUnit.alive and self.focusUnit:Position() or self.mission.player.alive and self.mission.player:Position(),
            yaw=self.unit.vehicle:Yaw(),feet=self:Feet(),contacts=self.unit.vehicle.telemetry.mechContacts or self.unit.vehicle.telemetry.legContacts or self.unit.vehicle.telemetry.contact or 0,drill=drill,
            landing=function(to) local goal=self:UnderRoof(to,-6) and self:OpenNode(to,0,70) or to;goal=goal or to;return {goal[1],self:Ground(goal[1],goal[3]),goal[3]} end,
            talking=self.mission.voice:Talking(),wantHop=self.wantHop,raid=self.raid~=nil});self.wantHop=nil;self:Events()
    elseif f.stage=='ending' then
        if self.skip then self.skip=false;self.mission.voice:Hide();self:Banner('回收','九尾狐瘫倒了','狐狐坐逃生舱跑了 · 小运把残骸拖回公司','install',3000);self:Finish()
        elseif f.t<3.5 and (f.boomAt or 0)<=self.time then f.boomAt=self.time+.45;self:Fx(V.Add(self.unit.pos,{(math.random()-.5)*14,math.random()*8,(math.random()-.5)*14}),3,true);self.session.trauma=math.max(self.session.trauma or 0,.3)
        elseif f.t>5 and not f.pod and not self.mission.voice:Talking() then self.radio:Play('open');f.pod={from=self:Cockpit(),t=0};self:Fx(f.pod.from,2)
        elseif f.pod and not f.truck then f.pod.t=f.pod.t+dt
            local pod=f.pod;pod.smoke=(pod.smoke or 0)-dt
            if pod.smoke<=0 then local t=pod.t;pod.smoke=.18;self:Fx({pod.from[1]+math.sin(t*2.1)*4+t*3,pod.from[2]+t*9-t*t*.25,pod.from[3]+t*t*3.2},.8) end
            if f.pod.t>1.2 and not f.pod.said then f.pod.said=true;self:Say('pod') end
            if f.pod.t>7 and not self.mission.voice:Talking() then f.truck={t=0};self:Say('truck') end
        elseif f.truck then f.truck.t=f.truck.t+dt;if f.truck.t>=8 and not self.mission.voice:Talking() then self:Finish() end end
    end
    self.view:Update(dt);if self.shock then self.shock.age=self.shock.age+dt;if self.shock.age>.7 then self.shock=nil end end
end
function M:Finish() self.flow.stage='done';self.rules:Go('dead');self.cinematic=false;self.done=true end
function M:Key(key,held)
    if not self.cinematic or key~=KEY_RETURN then return false end
    if held and held>=.9 then self.skip=true else self.mission.voice:SkipLine() end;return true
end
function M:AfterCamera(dt)
    if not self.cinematic then return end
    local camera=self.session.camera:GetCamera();local root=camera:GetNode();local pos=self.unit:Position();local f=self.flow
    local eye,at
    if f.stage=='introCine' then local e=self.at.enter;eye={e[1]-22,self:Ground(e[1]-22,e[3]-50)+4,e[3]-50};at=V.Add(pos,{0,7+math.min(4,f.t),0})
    elseif f.pod and not f.truck then local p=f.pod;at={p.from[1]+math.sin(p.t*2.1)*4+p.t*3,p.from[2]+p.t*9-p.t*p.t*.25,p.from[3]+p.t*p.t*3.2};eye=V.Add(self:Cockpit(),{35,10,28})
    else local a=-.5+f.t*.12;eye={pos[1]+math.sin(a)*40,math.max(pos[2]+6,self:Ground(pos[1]+math.sin(a)*40,pos[3]+math.cos(a)*40)+5),pos[3]+math.cos(a)*40};at=V.Add(pos,{0,4,0}) end
    local from=Coord.Vec(eye[1],eye[2],eye[3]);local to=Coord.Vec(at[1],at[2],at[3]);local delta=V.Sub(eye,at);local len=V.Length(delta)
    if len>10 then local dir=V.Scale(delta,1/len);local origin=V.Add(at,V.Scale(dir,9));local hit=self.world:CastRay(origin,dir,len-9,self.mission.player.vehicle and self.mission.player.vehicle.body)
        if hit and (not hit.owner or hit.owner.ref~=self.unit) then from=Coord.Vec(table.unpack(V.Add(origin,V.Scale(dir,math.max(0,hit.dist-1.5))))) end
    end
    root.worldPosition=root.worldPosition:Lerp(from,f.t<.1 and 1 or .08);root:LookAt(to,Vector3.UP)
end
function M:Snapshot() local state=self.rules:Snapshot();state.cinematic=self.cinematic;state.flow=self.flow.stage;state.threat=self:Threat();return state end
function M:Capture(key,delay)
    if self.shots[key] or self.captureWanted then return end
    self.captureWanted={key=key,at=self.time+(delay or 0)}
end
function M:FramePresented()
    local wanted=self.captureWanted;if not wanted or self.time<wanted.at or self.disposed then return end
    local image=Image:new();graphics:TakeScreenShot(image)
    local texture=Texture2D:new();texture:SetNumLevels(1);texture:SetData(image);image:Dispose()
    self.shots[wanted.key]=texture;self.captureWanted=nil
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;if self.ownsRadio then self.radio:Dispose() end;self.view:Dispose()
    for _,a in ipairs(self.allies) do if a.unit and not a.deadAt then self:Remove(a.unit) end end
    self:Remove(self.unit);self.missiles={};self.pending={};self.cinematic=false
    for _,texture in pairs(self.shots) do texture:Dispose() end;self.shots={};self.captureWanted=nil
    self.unit.HitRay=nil;self.unit.Explode=nil;self.unit.Damage=nil;self.unit.HurtHull=nil
    self.allies={};self.focusUnit=nil;self.unit=nil;self.driver=nil;self.env=nil
    self.view=nil;self.radio=nil;self.world=nil;self.session=nil;self.mission=nil
end
return M
