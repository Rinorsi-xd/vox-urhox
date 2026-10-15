-- Frozen H5 decision layer; physics and weapons execute the returned commands.
local A=require 'combat.EnemyDriverMath'
local N=require 'combat.EnemyDriverNav'
local Think=require 'combat.EnemyDriverThink'
local Motion=require 'combat.EnemyDriverMotion'
local Missile=require 'combat.MissileWeapons'
local M={};M.__index=M
function M.New(world,unit,role,index,member)
    member=member or {};local s=setmetatable({},M)
    s.world=world;s.unit=unit;s.role=role or 'assault';s.index=index or 1
    local fit=unit.bp and unit.bp:Stats().fitTier
    s.tier=member.tier or unit.tier or fit and fit.id or 1;s.team=unit.team or 'enemy'
    s.skill=member.aimSkill or 1;s.random=A.Seeded(member.seed or index or 1);s.nav=world.layout and world.layout.nav
    s.width=unit.spec.bounds.max[1]-unit.spec.bounds.min[1];s.time=0;s.nextThink=0
    s.reaction=member.reaction or A.T.reactionMin+s.random()*(A.T.reactionMax-A.T.reactionMin)
    s.circle=s.random()<.5 and -1 or 1;if s.role=='assault' then s.circle=1 end;s.lane=s.random()*2-1
    s.route={};s.error=0;s.stuckCount=0;s.resets=0;s.consecutiveStuck=0;s.sampleTime=0;s.reverseUntil=0;s.reverseSteer=0
    s.lastSeen=-math.huge;s.mode='approach';s.command={throttle=0,steer=0}
    local routeSeed=math.floor(s.random()*1e9)
    s.jitter=function(a,b) local k=a<b and a..'|'..b or b..'|'..a;local h=routeSeed
        for i=1,#k do h=((h~string.byte(k,i))*16777619)&0xffffffff end;return 1+.8*(h%1000)/1000
    end;return s
end
function M:IsAlly(u) return u.team==self.team end
function M:Graph() if not self.graphCache or self.graphCache.nav~=self.nav or self.graphCache.width~=self.width then self.graphCache={nav=self.nav,width=self.width,g=N.Graph(self.nav,self.width)} end;return self.graphCache.g end
function M:Nearest(p) return N.Nearest(self.nav,p,self.width) end
function M:Path(from,to) return N.Path(self.nav,from,to,self.width,self.jitter) end
function M:Visible(from,to,target) return N.Visible(self.world,from,to,self.unit.vehicle.body,target) end
function M:Direct(from,to) return N.Direct(self.world,from,to,self.unit.vehicle,self.width) end
function M:Missiles(c,immobilized)
    local ws=c.weapons;local pods={};for _,g in ipairs(ws and ws.groups or {}) do for _,w in ipairs(g.weapons) do if w.stats.homing then pods[#pods+1]=w end end end
    local function restore() if self.missileRestore~=nil then for i,g in ipairs(ws.groups) do if g.kind==self.missileRestore then ws:Select(i);break end end;self.missileRestore=nil end end
    local missile,charging,salvoWindow=false,false,false
    if #pods>0 and c.targetUnit and not c.passive and not immobilized then
        local stats=pods[1].stats;local r=A.Distance(c.pos,c.targetPos);local inLock=r>=(stats.lockMin or 0)+8 and r<=(stats.lockRange or 350)-10
        local fired,pod=false,nil;for _,w in ipairs(pods) do if w.mphase=='fire' or w.mphase=='reload' then fired=true end;if not pod and w.mphase=='ready' then pod=w end end
        if not self.missileNextAt then self.missileNextAt=self.time+2+self.random()*4 end
        if self.missileUntil then
            local ready=true;for _,w in ipairs(pods) do if w.mphase~='ready' then ready=false end end
            if fired or self.time>self.missileUntil or not inLock and ready then self.missileNextAt=self.time+(fired and 8+self.random()*4 or 4);self.missileUntil=nil;restore();if fired then self.volleys=(self.volleys or 0)+1 end end
        elseif self.time>=self.missileNextAt and self.visible and inLock and pod and not ws.offline then
            local cost=Missile.Cost(ws,pod)
            if ws.energy>=cost-1e-6 then
                self.missileUntil=self.time+5;self.missileChargeUntil=nil;self.missileSalvo=ws.energy>=cost+20
                local gi;for i,g in ipairs(ws.groups) do for _,w in ipairs(g.weapons) do if w==pod then gi=i end end end
                if not self.missileSalvo and gi and gi~=ws.current then local group=ws:Group();self.missileRestore=group and group.kind;ws:Select(gi) end
            else
                self.missileChargeUntil=self.missileChargeUntil or self.time+5
                if self.time>self.missileChargeUntil then self.missileChargeUntil=nil;self.missileNextAt=self.time+4 else charging=true end
            end
        else self.missileChargeUntil=nil end
        missile=self.missileUntil~=nil;salvoWindow=missile and self.missileSalvo
    elseif self.missileUntil and ws then self.missileUntil=nil;restore() end
    return missile,charging,salvoWindow or self.role=='boss' and self.time>=20 and self.time%20<3
end
function M:Step(dt,target,charge,shield)
    self.time=self.time+dt;local v=self.unit.vehicle
    if not v or not target then self.salvo=false;return {throttle=0,steer=0,handbrake=true},nil,false end
    local pos=self.unit:Position();local targetPos=target.Position and target:Position() or target.pos or target.position
    if not targetPos then self.salvo=false;return {throttle=0,steer=0},nil,false end
    local targetUnit=target.vehicle and target or target.unit
    local yaw=v.Yaw and v:Yaw() or v.yaw or 0;local bottom=pos[2]+v.spec.bounds.min[2]
    -- The ground probe only contributes to the first-second landing check.
    ---@type number?
    local floor
    if self.time<1 and (not v.capabilities or v.capabilities.totalLoad~=0) and not(v.airdropActive or self.unit.airdropActive) then
        floor=N.Height(self.world,pos[1],pos[3],bottom+3,v.body)
    end
    if(not v.capabilities or v.capabilities.totalLoad~=0) and(v.airdropActive or self.unit.airdropActive or self.time<1 and(not floor or bottom-floor>1)) then
        self.sample=nil;self.progress=nil;self.consecutiveStuck=0;self.reverseUntil=0;self.route={};self.goal=nil;self.mode='landing';self.salvo=false;self.trigger=false
        return {throttle=0,steer=0,handbrake=false},targetPos,false
    end
    local muzzle=.6;for _,w in ipairs(v.spec.weapons or {}) do muzzle=math.max(muzzle,w.pivot and w.pivot[2] or 0) end
    local from={pos[1],pos[2]+muzzle,pos[3]}
    local function aimFrom(origin)
        if shield and shield.active and shield.contains and shield.contains(targetPos) then return shield.aimPoint and shield.aimPoint(origin) or shield.pos end
        return A.Copy(targetPos)
    end
    local c={pos=pos,targetPos=targetPos,targetUnit=targetUnit,target=target,vehicle=v,weapons=self.unit.weapons,charge=charge,shield=shield,passive=target.passive==true,
        yaw=yaw,bottom=bottom,muzzleHeight=muzzle,shootFrom=from,aimFrom=aimFrom,targetAim=aimFrom(from)}
    if self.time>=self.nextThink then Think.Run(self,c) end
    local aim=c.targetAim;local tv=targetUnit and targetUnit.vehicle and targetUnit.vehicle.body.linvel()
    if tv and self.lag and not(shield and shield.active and shield.contains and shield.contains(targetPos)) then
        local lx,lz=aim[1]-from[1],aim[3]-from[3];local length=math.sqrt(lx^2+lz^2);if length==0 then length=1 end
        local ux,uz=lx/length,lz/length;local along=tv.x*ux+tv.z*uz;aim={aim[1]-(tv.x-ux*along)*self.lag,aim[2],aim[3]-(tv.z-uz*along)*self.lag}
    end
    local flat=math.sqrt((aim[1]-from[1])^2+(aim[3]-from[3])^2);local bearing=math.atan(aim[1]-from[1],aim[3]-from[3])+self.error
    self.aim={from[1]+math.sin(bearing)*flat,aim[2]+math.sin(self.error*.3)*flat,from[3]+math.cos(bearing)*flat}
    local command,reset,flip=Motion.Run(self,c,dt,bearing);local ws=c.weapons
    local aligned=not ws;for _,g in ipairs(ws and ws.groups or {}) do for _,w in ipairs(g.weapons) do if ws:Aligned(w) then aligned=true end end end
    local missile,charging,salvo=self:Missiles(c,v.capabilities and v.capabilities.totalLoad==0)
    local trigger=not c.passive and not charging and(targetUnit~=nil or target.shoot or not target.radius) and self.visible and self.visibleSince~=nil and self.time-self.visibleSince>=self.reaction and aligned
    self.command=command;self.salvo=salvo==true;self.trigger=trigger==true
    self.info={command=command,aim=self.aim,trigger=self.trigger,salvo=self.salvo,reset=reset,flip=flip,mode=self.mode,visible=self.visible,retreating=self.tactic=='retreat',life=self.life or 1,tactic=self.tactic,missile=missile,charging=charging}
    return command,self.aim,self.trigger,self.info
end
return M
