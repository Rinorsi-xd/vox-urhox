-- Fixed-step combat logic. No renderer, input, physics engine or UI dependency.
-- env = {stats={shots=0},castRay(origin,dir,length,excludedBody),hit(hit,damage,dir,impulse,pierce)}.
-- body adapter optionally provides applyImpulseAtPoint(impulse,point,wake) as a closure.
local Defs=require "combat.WeaponDefs"
local M=require "core.Math3"
local ENERGY=Defs.ENERGY
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
            g.weapons[#g.weapons+1]=w
        end
    end
    for _,g in ipairs(self.groups) do
        self:Pace(g)
        for i,w in ipairs(g.weapons) do if w.interval>0 then w.cool=(i-1)/#g.weapons*w.interval end end
    end
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
function Weapons:Group() return self.groups[self.current] end
function Weapons:Step(dt,state,env)
    for i=#self.fx,1,-1 do self.fx[i]=nil end
    self.time=self.time+dt;self.blocked=0;self.turning=0;self.pointing=nil
    local g=self:Group()
    local charging=false
    for _,grp in ipairs(self.groups) do for _,w in ipairs(grp.weapons) do
        if w.stats.windup and w.cool>0 then charging=true end
    end end
    if not self.offline and ((state.firing and g) or charging) then self.sinceUse=0 end
    self:Energy(dt)
    if state.firing and not self.wasFiring and g then
        for i,w in ipairs(g.weapons) do
            if w.interval>0 then w.cool=math.max(w.cool,(i-1)/#g.weapons*w.interval) end
        end
    end
    self.wasFiring=state.firing
    for _,grp in ipairs(self.groups) do for _,w in ipairs(grp.weapons) do
        local firing=grp==g and state.firing
        if not (self.offline and w.stats.windup) then w.cool=math.max(firing and -dt or 0,w.cool-dt) end
        self:Aim(w,dt,state);self:Tick(w,dt,firing)
        if grp==g then
            if w.limited then self.blocked=self.blocked+1
            elseif not self:Aligned(w) then self.turning=self.turning+1 end
            if not self.pointing then self.pointing=w end
            if firing and w.cool<=0 and self:Ready(w,dt) then self:Fire(w,state,env) end
        end
    end end
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
    local yaw=M.Clamp(ty,-110*DEG,110*DEG);local pitch=M.Clamp(tp,-12*DEG,55*DEG)
    local step=w.stats.slew*dt
    w.yaw=M.Approach(w.yaw,yaw,step);w.pitch=M.Approach(w.pitch,pitch,step)
    w.limited=yaw~=ty or pitch~=tp
    w.err=math.acos(M.Clamp(M.Dot(M.Turret(FORWARD,w.yaw,w.pitch),M.Normalize(d)),-1,1))
end
function Weapons:Aligned(w) return not w.limited and w.err<=(w.stats.spinUp and 5*DEG or 2*DEG) end
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
    local d=M.Jitter(aimDir,s.spread,self.random)
    self.projectiles[#self.projectiles+1]={w=w,s=s,pos={table.unpack(m.pos)},vel=M.Scale(d,s.speed),
        life=s.range/s.speed,dist=0,fx=s.fx,bright=w.shots%(s.tier==5 and 3 or 4)==0,seed=self.random()}
    self.fx[#self.fx+1]={type="shot",kind="mg",fx=s.fx,pos=m.pos,dir=m.dir,kick=s.kick,shake=s.shake,id=w.id,tier=s.tier,spin=w.spin}
end
function Weapons:Beam(w,m,aimDir,state,env)
    local s=w.stats;w.cool=w.cool+w.interval
    if s.windup then w.windup=0;w.charge=0 end
    local hit=env.castRay(m.pos,aimDir,s.range,state.body)
    if hit then env.hit(hit,Defs.DamageAtDistance(s,hit.dist),aimDir,s.impulse,s.pierce or 0) end
    local to=hit and hit.point or M.Add(m.pos,M.Scale(aimDir,s.range));local kind=Defs.Kind(w.type)
    self.fx[#self.fx+1]={type="shot",kind=kind,fx=s.fx,pos=m.pos,dir=aimDir,kick=s.kick,shake=s.shake,id=w.id,tier=s.tier,barrel=w.barrel}
    self.fx[#self.fx+1]={type="beam",kind=kind,fx=s.fx,tier=s.tier,from=m.pos,to=to,dir=aimDir,hit=hit~=nil,
        normal=hit and hit.normal or nil,target=hit~=nil and hit.owner~=nil and hit.owner.type=="target",id=w.id}
    if w.offs then w.barrel=w.barrel%#w.offs+1 end
end
function Weapons:Integrate(dt,state,env)
    for i=#self.projectiles,1,-1 do
        local p=self.projectiles[i];p.life=p.life-dt
        local step=M.Scale(p.vel,dt);local length=M.Length(step)
        local dir=M.Scale(step,length>0 and 1/length or 1)
        local hit=env.castRay(p.pos,dir,length,state.body)
        if hit then
            env.hit(hit,Defs.DamageAtDistance(p.s,p.dist+hit.dist),dir,p.s.impulse,0)
            self.fx[#self.fx+1]={type="impact",fx=p.fx,pos=hit.point,normal=hit.normal,dir=dir,
                target=hit.owner~=nil and hit.owner.type=="target",tier=p.s.tier,bright=p.bright}
            table.remove(self.projectiles,i)
        else
            p.pos=M.Add(p.pos,step);p.dist=p.dist+length
            if p.life<=0 or p.pos[2]<-5 then table.remove(self.projectiles,i) end
        end
    end
end
function Weapons:Readiness(g)
    local best=0
    for _,w in ipairs(g.weapons) do
        local value=w.stats.spinUp and w.spin or (w.stats.windup and w.charge or 1-math.max(0,w.cool)/w.interval)
        best=math.max(best,value)
    end
    return best
end
return Weapons
