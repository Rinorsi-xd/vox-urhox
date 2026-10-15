-- Frozen H5 lock, magazine and cubic flight rules; all positions use source metres.
local V=require 'core.Math3'
local Defs=require 'combat.WeaponDefs'
local M={}
local function Copy(p) return {p[1],p[2],p[3]} end
local function Basis(f)
    local right=V.Normalize({-f[3],0,f[1]})
    return right,V.Cross(right,f)
end
function M.Init(w)
    w.open=0;w.openHold=0;w.lock=0;w.mphase='ready';w.readyAt=-9
    w.reloadT=0;w.volley=0;w.volleyAt=0;w.reload=1;w.tubes={}
    for i=1,w.offs and #w.offs or 1 do w.tubes[i]=true end
end
function M.Cost(sys,w)
    local total=w.stats.share
    for _,g in ipairs(sys.groups) do for _,weapon in ipairs(g.weapons) do if weapon==w then
        total=0;for _,other in ipairs(g.weapons) do if other.stats.homing then total=total+other.stats.share end end
        return Defs.ENERGY.max*w.stats.share/math.max(1,total)
    end end end
    return Defs.ENERGY.max*w.stats.share/math.max(1,total)
end
function M.Plan(sys,w)
    local n=#w.tubes;local cost=M.Cost(sys,w);local per=cost/n
    if sys.offline or sys.energy<per-1e-6 then return {count=0,energy=0,cost=cost,per=per} end
    if sys.energy>=cost then return {count=n,energy=cost,cost=cost,per=per} end
    return {count=math.max(1,math.min(n,math.floor(n*sys.energy/cost+.5))),energy=sys.energy,cost=cost,per=per}
end
function M.Info(sys)
    local g=sys:Group();if not g then return end
    local best=false
    for _,w in ipairs(g.weapons) do if w.stats.lockTime and (not best or w.lock>best.lock) then best=w end end
    if not best then return end
    local plan=M.Plan(sys,best);local ph=best.mphase
    return {ref=best.lockRef,progress=best.lock,locked=best.lock>=1,inside=best.lockIn==true,box=best.stats.lockBox,
        reload=ph=='reload' and best.reload or 1,phase=ph,firing=ph=='raise' or ph=='open' or ph=='fire',
        cooling=ph=='reload' or ph=='close',cost=plan.cost,costFrac=plan.cost/sys.energyMax,energyOk=plan.count>0,
        ready=ph=='ready' and plan.count>0,count=plan.count,tubes=#best.tubes}
end
local function InBox(c,eye,f,right,up,box)
    local v=V.Sub(c.pos,eye);local z=V.Dot(v,f);if z<=.5 then return end
    local k=math.tan(box)
    return V.Dot(v,right)/z/k,V.Dot(v,up)/z/k,z
end
function M.Lock(sys,w,dt,state,env,active)
    local s=w.stats
    local function Decay(rate)
        w.lock=math.max(0,w.lock-dt*rate);if w.lock==0 then w.lockRef=nil end
    end
    w.lockIn=false
    if not active or not state.aim then Decay(2);return end
    local eye=state.eye or V.Add(state.pos,V.Rotate(state.quat,w.pivot or w.muzzle))
    local f=V.Normalize(V.Sub(state.aim,eye));local right,up=Basis(f)
    local list=env.lockables and env.lockables(state.body) or {};local present=false
    for _,c in ipairs(list) do if c==w.lockRef then present=true;break end end
    if present and w.lockRef.alive~=false then
        local x,y,z=InBox(w.lockRef,eye,f,right,up,s.lockBox);local keep=w.lock>=1 and s.lockKeep or 1
        if x and math.abs(x)<=keep and math.abs(y)<=keep and z<=s.lockRange and z>=(s.lockMin or 0) then
            w.lockIn=true;w.lockLost=0;w.lock=math.min(1,w.lock+dt/s.lockTime);return
        end
    end
    if w.lockRef and w.lock>=1 then
        w.lockLost=(w.lockLost or 0)+dt;if w.lockLost<s.lockGrace then return end
    end
    local best=false;local bestD=math.huge
    for _,c in ipairs(list) do
        local x,y,z=InBox(c,eye,f,right,up,s.lockBox)
        if x and math.abs(x)<=1 and math.abs(y)<=1 and z<=s.lockRange and z>=(s.lockMin or 0) then
            local d=math.sqrt(x*x+y*y);if d<bestD then bestD=d;best=c end
        end
    end
    if best then
        if best~=w.lockRef then w.lockRef=best;w.lock=0 end
        w.lockIn=true;w.lockLost=0;w.lock=math.min(1,w.lock+dt/s.lockTime);return
    end
    Decay(1.5)
end
function M.Step(sys,w,dt,state,env,firing)
    local s=w.stats;local n=#w.tubes;local before=w.mphase
    if before=='ready' then
        w.open=math.max(0,w.open-dt/s.closeTime);w.reload=1
        if firing and w.lock>=1 and w.lockRef and M.Plan(sys,w).count>0 then w.mphase='raise' end
    elseif before=='raise' then
        if not firing or w.lock<1 or not w.lockRef then w.mphase='ready'
        elseif w.lofting and sys:Aligned(w) then w.mphase='open' end
    elseif before=='open' then
        w.open=math.min(1,w.open+dt/s.openTime)
        if w.open>=1 then
            local plan=M.Plan(sys,w)
            if plan.count==0 or not w.lockRef then w.mphase='close'
            else
                sys.energy=math.max(0,sys.energy-plan.energy);sys.sinceUse=0
                w.fired=plan.count;w.volley=plan.count;w.volleyAt=sys.time;w.barrel=1
                w.volleyTarget=w.lockRef;w.mphase='fire'
                if env.stats then env.stats.shots=env.stats.shots+1 end
            end
        end
    elseif before=='reload' then
        w.reloadT=w.reloadT+dt;w.reload=math.min(1,w.reloadT/(w.interval*(w.fired or n)))
        for i=1,math.floor(w.reload*n+1e-6) do w.tubes[i]=true end
        if w.reload>=1 then w.mphase='close' end
    elseif before=='close' then
        w.open=math.max(0,w.open-dt/s.closeTime)
        if w.open<=0 then w.mphase='ready';w.readyAt=sys.time end
    end
    if (before=='open' or before=='fire') and w.mphase=='fire' then
        while w.volley>0 and sys.time>=w.volleyAt do M.Launch(sys,w,state,env) end
        if w.volley==0 then w.mphase='reload';w.reloadT=0;w.reload=0 end
    end
    local cues={open='missile_open',reload='missile_reload',close='missile_close'}
    if before~=w.mphase and cues[w.mphase] then sys.fx[#sys.fx+1]={type='mechanism',cue=cues[w.mphase],pos=Copy(state.pos)} end
end
function M.Launch(sys,w,state,env)
    local s=w.stats;local muzzle=sys:Muzzle(w,state,w.barrel)
    w.volley=w.volley-1;w.volleyAt=w.volleyAt+s.gap;w.tubes[w.barrel]=false;w.reload=0;w.shotAt=sys.time
    local n=w.offs and #w.offs or 1
    if w.volley<n-1 and env.stats then env.stats.shots=env.stats.shots+1 end
    if s.recoil and state.body and state.body.applyImpulseAtPoint then
        state.body.applyImpulseAtPoint({x=-muzzle.dir[1]*s.recoil,y=-muzzle.dir[2]*s.recoil,z=-muzzle.dir[3]*s.recoil},
            {x=muzzle.pos[1],y=muzzle.pos[2],z=muzzle.pos[3]},true)
    end
    local target=w.volleyTarget;local tp=Copy(target and target.pos or state.aim)
    local toT=V.Sub(tp,muzzle.pos);local D=math.max(4,V.Length(toT));local f=V.Normalize(toT)
    local right0,up0=Basis(f);local k=w.barrel-1;local side=k%2==1 and 1 or -1
    local tilt=(math.floor(k/2)*.618%1)*1.1-.3+(sys.random()-.5)*.2
    local right=V.Add(V.Scale(right0,math.cos(tilt)),V.Scale(up0,math.sin(tilt)*side))
    local rank=n>2 and math.floor(k/2)/math.max(1,math.ceil(n/2)-1) or 1
    local wide=math.min(s.spreadMax,math.max(s.spreadMin,D*s.spreadW))*(.55+.45*rank)*(.9+.2*sys.random())
    local high=D*s.lift*(.6+.8*sys.random())+rank*1.5
    local c1=V.Add(V.Add(muzzle.pos,V.Scale(muzzle.dir,math.min(11,3+D*.18))),V.Scale(right,side*wide));c1[2]=c1[2]+high
    local path={p0=Copy(muzzle.pos),c1=c1,side=V.Scale(right,side*wide*.8),up=high*.5,back=math.min(12,D*.28),dur=(D*1.25+wide)/s.cruise}
    sys.projectiles[#sys.projectiles+1]={w=w,s=s,pos=Copy(muzzle.pos),vel=V.Scale(muzzle.dir,12),life=path.dur+1.5,
        age=0,dist=0,fx=s.fx,target=target,path=path,['end']=tp,aim=Copy(state.aim),exclude=state.body,seed=sys.random(),trail={Copy(muzzle.pos)}}
    sys.fx[#sys.fx+1]={type='shot',kind='missile',fx=s.fx,pos=muzzle.pos,dir=muzzle.dir,kick=s.kick,shake=s.shake,
        id=w.id,tier=s.tier,barrel=w.barrel,locked=target~=nil}
    if w.offs then w.barrel=w.barrel%#w.offs+1 end
end
function M.Curve(p,dt)
    local P=p.path;p.age=p.age+dt
    if p.target and p.target.alive~=false and p.target.pos then p['end']=Copy(p.target.pos) end
    local e=p['end'];local f=V.Normalize(V.Sub(e,P.p0))
    local c2=V.Add(V.Sub(e,V.Scale(f,P.back)),P.side);c2[2]=c2[2]+P.up
    local u=math.min(1,p.age/P.dur);local t=u^1.3;local it=1-t;local b={}
    for j=1,3 do b[j]=it*it*it*P.p0[j]+3*it*it*t*P.c1[j]+3*it*t*t*c2[j]+t*t*t*e[j] end
    p.arrived=u>=1;return b
end
function M.Trail(p)
    -- Reuse the oldest sample once the frozen forty-point trail is full.
    local sample=#p.trail>=40 and table.remove(p.trail,1) or {}
    sample[1],sample[2],sample[3]=p.pos[1],p.pos[2],p.pos[3];p.trail[#p.trail+1]=sample
end
function M.Blast(sys,p,point,hit,dir,env)
    local s=p.s;local damage=Defs.DamageAtDistance(s,V.Length(V.Sub(point,p.path.p0)))
    if hit then env.hit(hit,damage*s.direct,dir,s.impulse,0) end
    if env.explode then env.explode(point,s.radius,damage*(hit and 1-s.direct or 1),p.exclude) end
    sys.fx[#sys.fx+1]={type='blast',kind='missile',pos=point,normal=hit and hit.normal or nil,dir=dir,
        radius=s.radius,tier=s.tier,target=hit~=nil and hit.owner~=nil and hit.owner.type=='target',hit=hit~=nil}
end
return M
