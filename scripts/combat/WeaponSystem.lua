-- Fixed-step combat logic. No renderer, input, physics engine or UI dependency.
-- env = {stats={shots=0},castRay(origin,dir,length,excludedBody),hit(hit,damage,dir,impulse,pierce)}.
-- body adapter optionally provides applyImpulseAtPoint(impulse,point,wake) as a closure.
local Defs=require "combat.WeaponDefs"
local M=require "core.Math3"
local ENERGY=Defs.ENERGY
local Missiles=require 'combat.MissileWeapons'
local Drill=require 'combat.DrillAttack'
local TurretRange=require 'construction.TurretRange'
local DEG=math.pi/180
local FORWARD={0,0,1}
---@class WeaponSystem
---@field pointing table|nil
local Weapons={}
Weapons.__index=Weapons
function Weapons.New(spec,random)
    local self=setmetatable({},Weapons);self:init(spec,random);return self
end
function Weapons:init(spec,random)
    self.groups={};self.projectiles={};self.fx={};self.random=random or math.random
    self.current=1;self.wasFiring=false;self.time=0
    self.energy=ENERGY.max;self.energyMax=ENERGY.max;self.offline=false;self.sinceUse=9
    self.blocked=0;self.turning=0;self.pointing=nil
    local byKind={}
    for _,part in ipairs(spec.weapons) do
        local stats=Defs.Stats(part.type)
        if stats then
            local kind=Defs.Kind(part.type)
            if not byKind[kind] then
                local g={kind=kind,name=Defs.KINDS[kind].name,types={},weapons={}}
                byKind[kind]=g;self.groups[#self.groups+1]=g
            end
            local g=byKind[kind];g.types[part.type]=true
            local w={}
            for k,v in pairs(part) do w[k]=v end
            w.stats=stats;w.cool=0;w.id=part.partId
            w.yaw=0;w.pitch=0;w.prevYaw=0;w.prevPitch=0;w.err=0;w.limited=false
            w.spin=0;w.spinRate=0;w.spinAngle=0;w.charge=1;w.windup=0
            w.barrel=1;w.shotAt=-9;w.dryAt=-9 -- Lua barrel index is 1-based, including shot events.
            if stats.homing then Missiles.Init(w) end
            g.weapons[#g.weapons+1]=w
        end
    end
    for _,g in ipairs(self.groups) do
        self:Pace(g)
        for i,w in ipairs(g.weapons) do if w.interval>0 then w.cool=(i-1)/#g.weapons*w.interval end end
    end
    self.drill=Drill.New(self)
end
function Weapons:Pace(g)
    g.share=0
    for _,w in ipairs(g.weapons) do g.share=g.share+w.stats.share end
    g.output=math.min(1,g.share)
    local pace=1/math.max(1,g.share)
    for _,w in ipairs(g.weapons) do
        w.rate=w.stats.rate and w.stats.rate*pace or 0
        w.interval=w.stats.interval and w.stats.interval/pace or 0
    end
end
function Weapons:Select(index)
    if index>=1 and index<=#self.groups and index%1==0 then self.current=index end
end
function Weapons:Refit(spec)
    self.drill:Cancel()
    local old={};local selected=self:Group() and self:Group().kind
    for _,g in ipairs(self.groups) do for _,w in ipairs(g.weapons) do old[w.id]=w end end
    local rebuilt=Weapons.New(spec,self.random)
    for i,g in ipairs(rebuilt.groups) do
        if g.kind==selected then rebuilt.current=i end
        for _,w in ipairs(g.weapons) do local previous=old[w.id]
            if previous and previous.type==w.type then
                for _,key in ipairs({'cool','yaw','pitch','prevYaw','prevPitch','spin','spinRate','spinAngle','charge','windup','drillPhase','barrel','shotAt','dryAt','bloom',
                    'open','openHold','lock','lockRef','lockIn','lockLost','mphase','readyAt','reloadT','reload','volley','volleyAt','volleyTarget','fired','tubes'}) do w[key]=previous[key] end
            end
        end
    end
    self.groups=rebuilt.groups;self.current=rebuilt.current
end
function Weapons:Group() return self.groups[self.current] end
function Weapons:Step(dt,state,env)
    for i=#self.fx,1,-1 do self.fx[i]=nil end
    self.time=self.time+dt;self.blocked=0;self.turning=0;self.pointing=nil
    local g=self:Group()
    if not self.offline and state.firing and g then self.sinceUse=0 end
    self:Energy(dt)
    self.drill:Step(dt,state,env)
    if state.firing and not self.wasFiring then
        for _,active in ipairs(self.groups) do if state.salvo or active==g then
            for i,w in ipairs(active.weapons) do
                if w.interval>0 and not w.stats.drill then w.cool=math.max(w.cool,(i-1)/#active.weapons*w.interval) end
            end
        end end
    end
    self.wasFiring=state.firing
    for _,grp in ipairs(self.groups) do for _,w in ipairs(grp.weapons) do if not w.stats.drill then
        local active=state.salvo or grp==g
        local firing=active and state.firing
        if not (self.offline and w.stats.windup) then w.cool=math.max(firing and -dt or 0,w.cool-dt) end
        self:Aim(w,dt,state);self:Tick(w,dt,firing)
        if w.stats.homing then Missiles.Lock(self,w,dt,state,env,active);Missiles.Step(self,w,dt,state,env,firing) end
        if w.stats.bloomRecover and (not firing or self.offline) then w.bloom=math.max(0,(w.bloom or 0)-dt*w.stats.bloomRecover) end
        if active then
            if w.limited then self.blocked=self.blocked+1
            elseif not self:Aligned(w) then self.turning=self.turning+1 end
            if not self.pointing then self.pointing=w end
            if not w.stats.homing and firing and w.cool<=0 and self:Ready(w,dt) then self:Fire(w,state,env) end
        end
    end end end
    self:Integrate(dt,state,env)
end
function Weapons:Energy(dt)
    self.sinceUse=self.sinceUse+dt
    if self.sinceUse>ENERGY.delay then self.energy=math.min(ENERGY.max,self.energy+ENERGY.regen*dt) end
    if self.offline and self.energy>=ENERGY.online then
        self.offline=false;self.fx[#self.fx+1]={type="energy",state="online"}
    end
end
function Weapons:Spend(w,state)
    if not self.offline and self.energy>=w.stats.energy then
        self.energy=self.energy-w.stats.energy;self.sinceUse=0;return true
    end
    if not self.offline then self.offline=true;self.fx[#self.fx+1]={type="energy",state="empty"} end
    if self.time-w.dryAt>0.3 then
        w.dryAt=self.time
        local m=self:Muzzle(w,state)
        self.fx[#self.fx+1]={type="dry",kind=Defs.Kind(w.type),pos=m.pos,dir=m.dir,id=w.id,tier=w.stats.tier}
    end
    return false
end
function Weapons:Tick(w,dt,firing)
    local s=w.stats
    if s.spinUp then
        local drive=firing and not self.offline
        if drive then w.spin=math.min(1,w.spin+dt/s.spinUp)
        elseif not (firing and self.offline) then w.spin=math.max(0,w.spin-dt/s.spinDown) end
        w.spinRate=w.rate*(drive and (s.minFrac+(1-s.minFrac)*w.spin^2) or w.spin^2)
        w.spinAngle=(w.spinAngle+dt*w.spinRate*math.pi*2/s.barrels)%(math.pi*2)
    elseif s.windup then
        w.charge=1-math.max(0,w.cool)/w.interval
        if not firing or w.cool>0 or self.offline then w.windup=math.max(0,w.windup-dt*4) end
    end
end
function Weapons:Ready(w,dt)
    if w.stats.windup then
        if not self:Aligned(w) then return false end
        if self.offline then return true end
        w.windup=math.min(1,w.windup+dt/w.stats.windup)
        return w.windup>=1
    end
    return true
end
function Weapons:Aim(w,dt,state)
    w.prevYaw=w.yaw;w.prevPitch=w.pitch
    if not w.pivot then return end
    local pw=M.Add(state.pos,M.Rotate(state.quat,w.pivot))
    local d=M.Unrotate(w.quat,M.Unrotate(state.quat,M.Sub(state.aim,pw)))
    local ty=math.atan(d[1],d[3]);local tp=math.atan(d[2],math.sqrt(d[1]^2+d[3]^2))
    w.aimPitch=tp;w.lofting=w.stats.loft~=nil and (w.mphase=='raise' or w.mphase=='open' or w.mphase=='fire')
    if w.lofting then tp=w.stats.loft end
    local pitch=M.Clamp(tp,w.stats.pitch[1],w.stats.pitch[2])
    local step=w.stats.slew*dt
    local range=w.range;local yawOut=false
    local function Wrap(a) return a-2*math.pi*math.floor(a/(2*math.pi)+.5) end
    if range and not range.free then
        local inside
        for _,angle in ipairs({ty,ty-2*math.pi,ty+2*math.pi}) do if angle>=range.lo and angle<=range.hi then inside=angle;break end end
        local target=inside or (math.abs(Wrap(ty-range.lo))<math.abs(Wrap(ty-range.hi)) and range.lo or range.hi)
        yawOut=inside==nil;w.yaw=w.yaw+M.Clamp(target-w.yaw,-step,step)
    else w.yaw=w.yaw+M.Clamp(Wrap(ty-w.yaw),-step,step) end
    local limits=range and TurretRange.PitchLimits(range,w.yaw)
    if range and not limits then pitch=w.pitch
    elseif limits then pitch=M.Clamp(pitch,limits[1],limits[2]) end
    w.pitch=M.Approach(w.pitch,pitch,step)
    w.limited=pitch~=tp or yawOut or range and range.stuck or false
    w.err=w.lofting and math.max(math.abs(ty-w.yaw-2*math.pi*math.floor((ty-w.yaw)/(2*math.pi)+.5)),math.abs(w.pitch-tp))
        or math.acos(M.Clamp(M.Dot(M.Turret(FORWARD,w.yaw,w.pitch),M.Normalize(d)),-1,1))
end
function Weapons:Aligned(w) return not w.limited and w.err<=(w.lofting and 1.5*DEG or w.stats.aimTol or (w.stats.spinUp and 5*DEG or 2*DEG)) end
function Weapons:VolleyPlan(w) return Missiles.Plan(self,w) end
function Weapons:LockInfo() return Missiles.Info(self) end
function Weapons:Muzzle(w,state,barrel)
    if not w.pivot then return {pos=M.Add(M.Rotate(state.quat,w.muzzle),state.pos),dir=M.Rotate(state.quat,w.dir)} end
    local index=barrel or w.barrel
    local off=w.offs and w.offs[(index-1)%#w.offs+1] or w.off
    local p=M.Add(w.pivot,M.Rotate(w.quat,M.Turret(off,w.yaw,w.pitch)))
    local dir=M.Rotate(w.quat,M.Turret(FORWARD,w.yaw,w.pitch))
    return {pos=M.Add(M.Rotate(state.quat,p),state.pos),dir=M.Rotate(state.quat,dir)}
end
function Weapons:Fire(w,state,env)
    if not self:Aligned(w) or not self:Spend(w,state) then return end
    local s=w.stats;local m=self:Muzzle(w,state)
    local aimDir=M.Normalize(M.Sub(state.aim,m.pos))
    w.shotAt=self.time;env.stats.shots=env.stats.shots+1
    local body=state.body
    if s.recoil and body and body.applyImpulseAtPoint then
        body.applyImpulseAtPoint({x=-m.dir[1]*s.recoil,y=-m.dir[2]*s.recoil,z=-m.dir[3]*s.recoil},
            {x=m.pos[1],y=m.pos[2],z=m.pos[3]},true)
    end
    if s.hitscan then self:Beam(w,m,aimDir,state,env);return end
    w.cool=w.cool+1/math.max(w.rate*s.minFrac,w.spinRate);w.shots=(w.shots or 0)+1
    local spread=s.spreadMax and s.spread+(s.spreadMax-s.spread)*(w.bloom or 0) or s.spread
    if s.spreadMax then w.bloom=math.min(1,(w.bloom or 0)+1/(s.rate*s.bloomTime)) end
    local d=M.Jitter(aimDir,spread,self.random)
    self.projectiles[#self.projectiles+1]={w=w,s=s,pos={table.unpack(m.pos)},vel=M.Scale(d,s.speed),
        life=(s.reach or s.range)/s.speed,dist=0,fx=s.fx,bright=w.shots%(s.tier==5 and 3 or 4)==0,seed=self.random()}
    self.fx[#self.fx+1]={type="shot",kind="mg",fx=s.fx,pos=m.pos,dir=m.dir,kick=s.kick,shake=s.shake,id=w.id,tier=s.tier,spin=w.spin}
end
function Weapons:Beam(w,m,aimDir,state,env)
    local s=w.stats;w.cool=w.cool+w.interval
    if s.windup then w.windup=0;w.charge=0 end
    local hit=env.castRay(m.pos,aimDir,s.reach or s.range,state.body)
    if hit then env.hit(hit,Defs.DamageAtDistance(s,hit.dist),aimDir,s.impulse,s.pierce or 0) end
    local to=hit and hit.point or M.Add(m.pos,M.Scale(aimDir,s.reach or s.range));local kind=Defs.Kind(w.type)
    self.fx[#self.fx+1]={type="shot",kind=kind,fx=s.fx,pos=m.pos,dir=aimDir,kick=s.kick,shake=s.shake,id=w.id,tier=s.tier,barrel=w.barrel}
    self.fx[#self.fx+1]={type="beam",kind=kind,fx=s.fx,tier=s.tier,from=m.pos,to=to,dir=aimDir,hit=hit~=nil,
        normal=hit and hit.normal or nil,target=hit~=nil and hit.owner~=nil and hit.owner.type=="target",material=hit and hit.owner and ({car=true,target=true,debris=true})[hit.owner.type] and 'metal' or 'ground',id=w.id}
    if w.offs then w.barrel=w.barrel%#w.offs+1 end
end
function Weapons:Integrate(dt,state,env)
    for i=#self.projectiles,1,-1 do
        local p=self.projectiles[i];p.life=p.life-dt
        if p.s.homing then p.vel=M.Scale(M.Sub(Missiles.Curve(p,dt),p.pos),1/dt) end
        local step=M.Scale(p.vel,dt);local length=M.Length(step)
        local dir=M.Scale(step,length>0 and 1/length or 1)
        local hit=env.castRay(p.pos,dir,length,p.exclude or state.body)
        if hit then
            if p.s.homing then Missiles.Blast(self,p,hit.point,hit,dir,env)
            else
            env.hit(hit,Defs.DamageAtDistance(p.s,p.dist+hit.dist),dir,p.s.impulse,0)
            self.fx[#self.fx+1]={type="impact",fx=p.fx,pos=hit.point,normal=hit.normal,dir=dir,
                target=hit.owner~=nil and hit.owner.type=="target",material=hit.owner and ({car=true,target=true,debris=true})[hit.owner.type] and 'metal' or 'ground',tier=p.s.tier,bright=p.bright}
            end
            table.remove(self.projectiles,i)
        else
            p.pos=M.Add(p.pos,step);p.dist=p.dist+length
            if p.trail then Missiles.Trail(p) end
            if p.s.homing and p.arrived then Missiles.Blast(self,p,p.pos,nil,dir,env);table.remove(self.projectiles,i)
            elseif p.life<=0 or p.pos[2]<(env.killHeight or -80) then
                if p.s.homing and p.life<=0 then Missiles.Blast(self,p,p.pos,nil,dir,env) end
                table.remove(self.projectiles,i)
            end
        end
    end
end
function Weapons:Readiness(g)
    local best=0
    for _,w in ipairs(g.weapons) do
        local value=w.stats.drill and (w.drillPhase=='charging' and w.windup or w.charge) or w.stats.lockTime and w.lock or w.stats.spinUp and w.spin or (w.stats.windup and w.charge or 1-math.max(0,w.cool)/w.interval)
        best=math.max(best,value)
    end
    return best
end
return Weapons
