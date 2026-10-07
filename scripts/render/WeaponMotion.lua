-- Port of WeaponRig state and mechanical motion. Cell-space presentation only.
local Math=require 'core.Math3'
local M={};M.__index=M
local function Smooth(x) x=Math.Clamp(x,0,1);return x*x*(3-2*x) end
local function Kick(k,a,d) return k<0 and 0 or k<a and k/a or math.exp(-(k-a)*d) end
local function Spring(stiff,damp) return {x=0,v=0,stiff=stiff or 260,damp=damp or 17} end
local function Step(s,target,dt)
    local h=math.min(dt,1/30);s.v=s.v+((target-s.x)*s.stiff-s.v*s.damp)*h;s.x=s.x+s.v*h;return s.x
end
function M.New(typeId,data,profile,random)
    local self=setmetatable({type=typeId,kind=typeId:gsub('%d+$',''),tier=tonumber(typeId:match('%d+$')),data=data,parts={},poses={},
        scale=profile.motionScale,random=random or math.random,charge=1,windup=0,spinV=0,spinRate=0,spinAngle=0,offline=false,
        shotT=-9,barrelShotT={-9,-9},recoil=0,kick=0,recoilS=Spring(420,22),kickS=Spring(300,15),load=0,power=1,offT=-9,onT=-9,
        eject=Spring(),collarS={},collarPop={},collarDone={},crownA={},crownT={},drumA=0,gyroA=0,ringA=0,idleSpin=0,
        pending={},emits={},material={}},M)
    self.seed=self.random()*100;self.flowPhase=self.random();self.crownIdle=self.random()*6;self.big=self.tier>=4
    for i,p in ipairs(data.segments.parts or {}) do
        local item={definition=p,index=i};local list=self.parts[p.name] or {};self.parts[p.name]=list;list[#list+1]=item
    end
    for _,name in ipairs({'coils','fins','collars'}) do
        table.sort(self.parts[name] or {},function(a,b)return a.definition.origin[3]<b.definition.origin[3] end)
    end
    for i in ipairs(self.parts.collars or {}) do self.collarS[i]=Spring(700,34);self.collarPop[i]=-9;self.collarDone[i]=true end
    for i in ipairs(self.parts.crown or {}) do self.crownA[i]=0;self.crownT[i]=0 end
    return self
end
function M:Muzzle(back)
    local m,p=self.data.weapon.muzzle,self.data.weapon.pivot;local d=Math.Normalize(Math.Sub(m,p))
    return Math.Sub(m,Math.Scale(d,back*self.scale[3]))
end
function M:SetState(w,time,system)
    self.live=true;self.charge=w.charge;self.windup=w.windup;self.spinV=w.spin;self.spinRate=w.spinRate;self.spinAngle=w.spinAngle
    local off=system and system.offline==true
    if off~=self.offline then
        self.offline=off;if off then self.offT=time else self.onT=time end
        self.pending[#self.pending+1]={kind=off and 'fizzle' or 'boot',p=self:Muzzle(.1)}
        local cell=(self.parts.cells or {})[1]
        if cell and off then local c=cell.definition;self.pending[#self.pending+1]={kind='fizzle',p={c.origin[1],c.origin[2],c.min[3]}} end
    end
    if w.shotAt~=self.lastShot then
        if self.lastShot~=nil then
            self.shotT=time;local n=self.data.weapon.muzzles and #self.data.weapon.muzzles or 1
            local barrel=n>1 and (w.barrel-2+n)%n+1 or 1;self.barrelShotT[barrel]=time;self:Shot(barrel)
        end
        self.lastShot=w.shotAt
    end
end
function M:Shot(barrel)
    local tier=self.tier;local back,up
    if self.kind=='sniper' then back,up=5+tier*1.2,1.2+tier*.25
    elseif self.kind=='laser' then back,up=2.2+tier*.4,.3+tier*.06 else back,up=.6+tier*.08,0 end
    self.recoilS.v=self.recoilS.v+back*self.scale[3];self.kickS.v=self.kickS.v+up*(.8+self.random()*.4)
    if self.kind=='mg' then self.kickS.v=self.kickS.v+(self.random()-.3)*.12 end
    if self.parts.crown then local i=math.min(barrel,#self.parts.crown);self.crownT[i]=self.crownT[i]+math.pi*2/(tier==4 and 3 or 4) end
    for i in ipairs(self.collarDone) do self.collarDone[i]=false end
end
function M:Set(part,dx,dy,dz,angle,axis,sx,sy,sz)
    local p=part.definition;local s=self.scale;local x=sx or 1
    self.poses[part.index]={p={p.origin[1]+(dx or 0)*s[1],p.origin[2]+(dy or 0)*s[2],p.origin[3]+(dz or 0)*s[3]},
        angle=angle or 0,axis=axis or 'z',scale={x,sy or x,sz or x}}
end
function M:Power(time,dt)
    local target=1;local up=time-self.onT
    if self.offline then local k=time-self.offT;target=k<.3 and ((math.sin(k*60)>0 and .9 or .15)*(1-k/.3)+.12) or .12
    elseif up<.6 then target=.12+.88*Smooth(up/.5) end
    self.power=self.power+(target-self.power)*math.min(1,dt*20)
    local speed=self.kind=='mg' and (.35+self.spinV*3.2) or self.kind=='laser' and (.4+self.load*2.4) or (.3+self.charge*.5+self.windup*5)
    self.flowPhase=self.flowPhase+dt*speed*(self.offline and .2 or 1)
    self.flow={phase=self.flowPhase,freq=self.kind=='sniper' and 4 or 2.6,
        amp=(.45+.3*math.min(1,self.load+self.spinV+self.windup))*(self.offline and .3 or 1),power=self.power,
        sweep=not self.offline and up<.55 and (-.15+1.3*up/.5) or -1,sweepI=not self.offline and up<.55 and 1 or 0}
    local breath=1+.18*math.sin(time*2.3+self.seed);local shot=math.exp(-(time-self.shotT)*10)
    self.material={}
    if self.kind=='mg' then
        self.material.heatGlow={intensity=.35+3.2*self.spinV^1.3+shot*.8*self.spinV,colorMix=math.max(0,self.spinV-.55)/.45}
        self.material.glowBlue={factor=self.big and breath or 1}
    elseif self.kind=='laser' then
        self.material.glowBlue={factor=(self.big and breath or 1+.08*math.sin(time*2.3+self.seed))*(1+.5*self.load+.6*shot),colorMix=shot*.6}
    else
        local intensity=.25+1.75*self.charge^2+self.windup*3
        if self.charge>=1 then intensity=intensity*(.94+self.random()*.12) end
        self.material.chargeGlow={intensity=intensity}
        if self.big then self.material.glowBlue={factor=breath} end
    end
    self.material.glowRed={factor=self.offline and (1.6*(math.sin(time*14)>0 and 1 or .15)/math.max(.12,self.power)) or (.55+.45*(.5+.5*math.sin(time*1.7+self.seed)))}
end
function M:Gatling(t,dt,k,ej)
    local s=self.spinV;local step=math.pi*2/(self.tier==3 and 4 or 6)
    if s<.02 then
        local ph=(t+self.seed)%3.4;self.tickBase=self.tickBase or 0
        if self.lastPh and ph<self.lastPh then self.tickBase=self.tickBase+step end
        self.lastPh=ph;self.idleSpin=self.tickBase+step*Smooth((ph-3)/.3)
    end
    self.spinPose={angle=self.spinAngle+self.idleSpin,buzz=-.045*self.scale[3]*Kick(k,.006,30)*(.4+.6*s)}
    self.drumA=self.drumA+dt*(self.spinRate*.45+.2*(1-ej))
    for _,d in ipairs(self.parts.drum or {}) do
        self:Set(d,0,0,-.12*ej,self.drumA*(d.definition.origin[1]<self.data.weapon.pivot[1] and -1 or 1))
    end
    if self.tier==5 and s>.8 and self.random()<dt*6 then
        local d=(self.parts.drum or {})[self.random()<.5 and 1 or 2]
        if d then local p=d.definition;self.emits[#self.emits+1]={kind='spark',p={p.origin[1],p.origin[2],p.max[3]}} end
    end
end
function M:Laser(t,dt,ej)
    local pw=1-ej
    for _,c in ipairs(self.parts.coils or {}) do
        local idx=c.definition.idx;local b,j=#idx>1 and idx[1]+1 or 1,#idx>1 and idx[2] or idx[1]
        local bump=Kick(t-self.barrelShotT[b]-j*.045,.02,12)
        local s=1+.045*(.5+.5*math.sin(t*2.4-j*1.1+b-1))*pw+.28*bump
        self:Set(c,0,0,.07*bump,0,'z',s,s,1+.5*bump)
    end
    for i,c in ipairs(self.parts.core or {}) do local f=Kick(t-self.barrelShotT[math.min(i,2)],.01,16);self:Set(c,0,0,.1*f,0,'z',1+.8*f,1+.8*f,1) end
    for _,p in ipairs(self.parts.prongs or {}) do
        local side=p.definition.origin[1]<self.data.weapon.muzzle[1] and -1 or 1
        self:Set(p,side*(.035*Kick(t-self.shotT,.02,6)+.01*self.load-.008*ej))
    end
    self.crownIdle=self.crownIdle+dt*.4*pw
    for i,c in ipairs(self.parts.crown or {}) do
        self.crownA[i]=self.crownA[i]+(self.crownT[i]-self.crownA[i])*math.min(1,dt*14)
        self:Set(c,0,0,0,(self.crownA[i]+self.crownIdle)*(i%2==0 and -1 or 1))
    end
    for i,f in ipairs(self.parts.fins or {}) do
        local sy=1+.08*(.5+.5*math.sin(t*1.6-(i-1)*.8))*pw+.55*Math.Clamp(self.load*1.5-(i-1)*.12,0,1)-.15*ej
        local d=f.definition;local h=(d.max[2]-d.min[2])/self.scale[2];self:Set(f,0,(sy-1)*h/2,0,0,'z',1,sy,1)
    end
    for _,s in ipairs(self.parts.shoulder or {}) do
        local side=s.definition.origin[1]<self.data.weapon.pivot[1] and -1 or 1
        self:Set(s,side*(.035*Smooth(self.load*1.3)+.004*(.5+.5*math.sin(t*1.1))*pw))
    end
    for i,b in ipairs(self.parts.battery or {}) do
        local d=b.definition;local a=-.5*ej-.03*(.5+.5*math.sin(t*1.3+(i-1)*1.7))*pw
        local y,z=d.origin[2]-d.min[2],d.origin[3]-d.min[3]
        self.poses[b.index]={p={d.origin[1],d.min[2]+y*math.cos(a)-z*math.sin(a),d.min[3]+y*math.sin(a)+z*math.cos(a)},angle=a,axis='x',scale={1,1,1}}
    end
    if self.big and self.random()<dt*3*self.load then self.emits[#self.emits+1]={kind='mote',p=self:Muzzle(.3+self.random()*.6)} end
end
function M:Sniper(t,dt,k,ej)
    local pw,T,ch,wu=1-ej,self.tier,self.charge,self.windup;local axis=self.data.weapon.muzzle
    local slide=(.12+T*.04)*Kick(k,.025,4.5)
    for _,r in ipairs(self.parts.rails or {}) do
        local p=r.definition.origin;local dx,dy=p[1]-axis[1],p[2]-axis[2];local length=math.sqrt(dx*dx+dy*dy);if length==0 then length=1 end
        local open=(.03+T*.008)*Smooth(wu*1.4)+.004*math.sin(t*38+dx*9)*(ch>=1 and 1 or 0)*pw
        self:Set(r,dx/length*open,dy/length*open,-slide)
    end
    local collars=self.parts.collars or {}
    for j,c in ipairs(collars) do
        local start=(j-1)/#collars*.55;local prog=self.collarDone[j] and 1 or Smooth((ch-start)/.42)
        if self.offline then prog=math.min(prog,.25) end
        if prog>=.999 and not self.collarDone[j] then self.collarDone[j]=true;self.collarPop[j]=t end
        local z=Step(self.collarS[j],-(.24+T*.05)*(1-prog),dt);local pop=1+.2*math.exp(-(t-self.collarPop[j])*9)
        self:Set(c,0,0,z+wu*.012*math.sin(t*85+(j-1)*2),0,'z',pop,pop,1)
    end
    self.gyroA=self.gyroA+dt*(.5+2.4*ch*ch+20*wu)*pw;self.ringA=self.ringA-dt*(.8+1.6*ch+12*wu)*pw
    if self.parts.gyro then self:Set(self.parts.gyro[1],0,0,0,self.gyroA) end
    if self.parts.ring then self:Set(self.parts.ring[1],0,0,0,self.ringA) end
    self.orb={alpha=(wu>0 and .35+wu*.65 or ch>=1 and .18+.08*math.sin(t*6+self.seed) or 0)*pw,
        size=(.18+T*.05)*self.scale[1]*(ch>=1 and wu==0 and .55 or .6+wu*1.8)*(.92+self.random()*.16)}
end
function M:Update(time,dt)
    self.t=time;self.emits=self.pending;self.pending={}
    local k=time-self.shotT
    self.load=self.load+((k<.35 and 1 or 0)-self.load)*math.min(1,dt*(k<.35 and 3 or 1.2))
    self.recoil=math.max(-.05,Step(self.recoilS,0,dt));self.kick=Step(self.kickS,0,dt)
    self:Power(time,dt);local ej=Step(self.eject,self.offline and 1 or 0,dt)
    if self.kind=='mg' then self:Gatling(time,dt,k,ej) elseif self.kind=='laser' then self:Laser(time,dt,ej) else self:Sniper(time,dt,k,ej) end
    local kick=self.kind=='sniper' and .1 or self.kind=='laser' and .07 or .035
    local d=-kick*Kick(k,.012,14)-(.07+self.tier*.006)*ej
    for i,c in ipairs(self.parts.cells or {}) do self:Set(c,0,0,d*(1-(i-1)*.15)) end
end
return M
