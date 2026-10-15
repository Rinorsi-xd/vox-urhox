-- Source legGait.js: predictive footholds, locked stance and alternating/wave gait.
-- All state is source-space metres; IK targets alone use local cell units.
local V=require "core.Math3"
local add,sub,mul,dot,length,norm=V.Add,V.Sub,V.Scale,V.Dot,V.Length,V.Normalize
local clamp,mix,reject,rotate,inverse,arr,vec=V.Clamp,V.Mix,V.Reject,V.RotateUnit,V.Inverse,V.Array,V.Vec
local M={}
local function Smooth(u) return u*u*u*(10+u*(-15+6*u)) end
local function Bump(u) return 64*(u*(1-u))^3 end
local function Lift(u) return u*u*(1-u)^3/.03456 end
local function Ramp(a,b,x) local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t) end
local function Copy(a) return {table.unpack(a)} end
local function Predict(q,w,t)
    local a=length(w)*t;if a<1e-5 then return q end
    local axis=norm(w);local s=math.sin(a/2)
    return V.QMul({x=axis[1]*s,y=axis[2]*s,z=axis[3]*s,w=math.cos(a/2)},q)
end
local function Half(s,d) return 1/math.sqrt((d[3]/(s.strideMax/2))^2+(d[1]/(s.restH*.25))^2+1e-9) end
local function Lead(s,q,ts)
    local lead=mul(s.u,ts/2);local l=length(lead);if l<1e-6 then return lead end
    local max=Half(s,norm(rotate(inverse(q),lead)));return l>max and mul(lead,max/l) or lead
end
function M.Reset(c)
    for _,s in ipairs(c.list) do s.mode='free';s.sw=nil;s.cycle=-1 end
    c.phase=0;c.phaseAcc=0;c.cadence=0;c.settle=0;c.parked=true;c.airClock=0
end
function M.Setup(c)
    local sides={}
    for _,s in ipairs(c.list) do
        local l=s.leg;local h=sub(l.toe,l.pos);local hh={h[1],0,h[3]};local H=length(hh)
        s.restH=H;s.rest=Copy(l.toe);s.side=nil
        if H>.1 and math.abs(hh[3]/H)<.5 then
            s.side=hh[1]>0 and 1 or -1;sides[s.side]=sides[s.side] or {};table.insert(sides[s.side],s)
        end
        s.offset=s.group*.5;s.mode='free';s.cycle=-1;s.nb={};s.wave=0;s.spacing=math.huge
    end
    for _,group in pairs(sides) do
        local lo,hi=math.huge,-math.huge
        for _,s in ipairs(group) do lo=math.min(lo,s.leg.pos[3]);hi=math.max(hi,s.leg.pos[3]) end
        local mid,half=(lo+hi)/2,(hi-lo)/2
        for _,s in ipairs(group) do
            local l=s.leg;local th=half>.05 and clamp((l.pos[3]-mid)/half,-1,1)*28*math.pi/180 or 0
            local h=sub(l.toe,l.pos);local d=norm({h[1],0,h[3]});local nd=norm(add(mul(d,math.cos(th)),{0,0,math.sin(th)}))
            s.rest=add(l.pos,{nd[1]*s.restH,h[2],nd[3]*s.restH})
        end
        table.sort(group,function(a,b) return a.rest[3]<b.rest[3] end)
        for i,s in ipairs(group) do
            for _,j in ipairs({i-1,i+1}) do if group[j] then
                s.nb[#s.nb+1]=group[j];s.spacing=math.min(s.spacing,math.abs(group[j].rest[3]-s.rest[3]))
            end end
            if #group>=4 then s.wave=1/#group;s.offset=((s.side>0 and .5 or 0)+(i-1)/#group)%1 end
        end
    end
    local stride=math.huge
    for _,s in ipairs(c.list) do
        local lim=math.min(s.restH*1.1,s.leg.reach*.6)
        for _,o in ipairs(s.nb) do lim=math.min(lim,(math.abs(o.rest[3]-s.rest[3])-.35)*(s.wave>0 and .5/s.wave or 1)) end
        s.strideMax=math.max(.3,lim);stride=math.min(stride,s.strideMax)
    end
    c.strideMax=stride<math.huge and stride or 1;M.Reset(c)
end
function M.Foothold(c,s,base,pq,pp,up,surf,md)
    local l=s.leg;local mount=add(pp,rotate(pq,l.pos))
    local tries={base,mix(mount,base,.8),mix(mount,base,.6)};local pu=rotate(pq,{0,1,0})
    local dirs=dot(surf,pu)<math.cos(15*math.pi/180) and {surf,pu} or {pu}
    ---@type table|nil
    local fallback=nil
    for _,d in ipairs(dirs) do for _,t in ipairs(tries) do
        local h=c:Cast(add(t,mul(d,l.height*.9+.3)),mul(d,-1),l.height*2.2+.3)
        if h and h.distance>.02 and (dot(h.normal,pu)>.25 or dot(h.normal,surf)>.5) and c:Reachable(s,h.point,pq,pp) then
            if c:Clear(s,h.point,pq,pp) then return h end
            -- A fallback may brush the upper leg, but cannot plant through a wall
            -- or let the blade cross terrain. Clear uses Lua's one-based segment.
            local delta=sub(h.point,mount)
            if not fallback and not c:Cast(mount,norm(delta),math.max(0,length(delta)-.1)) and c:Clear(s,h.point,pq,pp,3) then fallback=h end
        end
    end end
    if md then for _,t in ipairs(tries) do
        local start=add(add(t,mul(pu,-(.3+l.height*.35))),mul(md,.25))
        local h=c:Cast(start,mul(md,-1),l.height*1.4+.25)
        if h and h.distance>.02 and dot(h.normal,md)>.3 and c:Reachable(s,h.point,pq,pp) then return h end
    end end
    local out=rotate(pq,l.out)
    for _,d in ipairs({norm(add(out,mul(pu,-.6))),out}) do
        local h=c:Cast(mount,d,l.reach*.8)
        if h and c:Reachable(s,h.point,pq,pp) and c:Clear(s,h.point,pq,pp) then return h end
    end
    return fallback
end
local function Finish(c,q,p)
    for _,s in ipairs(c.list) do
        s.grounded=s.mode=='stance';s.swing=s.sw
        if not s.grounded then s.contact=nil end
        s.target=c:Target(s,s.foot,q,p);s.bladeAngle=s.sw and Bump(s.sw.t)*.2 or 0;s.retracted=false;s.avoiding=false
    end
end
function M.Step(c,dt,ctx)
    local q,p,up,surf,body=ctx.q,ctx.p,ctx.up,ctx.surf,ctx.body;local legs=c.list
    local function World(localPoint) return add(p,rotate(q,localPoint)) end
    local lin,ang=arr(body.linvel()),arr(body.angvel());local vt=reject(lin,surf)
    for _,s in ipairs(legs) do
        s.previous=s.foot and Copy(s.foot) or nil;s.jumpGlow=math.max(0,s.jumpGlow-dt*3);s.available=s.support~=nil
        s.foot=s.foot or World(s.rest)
    end
    if not ctx.supported then
        local k=1-math.exp(-dt*10);local fall=Ramp(1,-6,lin[2]);local vl=rotate(inverse(q),lin)
        local trail={-vl[1]*.03,0,-vl[3]*.03};if length(trail)>.4 then trail=mul(norm(trail),.4) end
        c.airClock=c.airClock+dt
        for _,s in ipairs(legs) do
            local l=s.leg;local h=sub(s.rest,l.pos);local paddle=.08*math.sin(2*math.pi*(1.6*c.airClock+s.offset))
            local target=add(add(l.pos,{h[1]*.85,h[2]*(.55+.45*fall)+paddle,h[3]*.85}),trail)
            s.foot=mix(s.foot,World(target),k);s.mode='free';s.sw=nil;s.contact=nil
        end
        c.cadence=0;c.phase=0;c.settle=0;c.parked=true;Finish(c,q,p);return
    end
    local vmax=0
    for _,s in ipairs(legs) do
        s.u=reject(arr(body.velocityAtPoint(vec(World(s.rest)))),surf);local speed=length(s.u);vmax=math.max(vmax,speed)
        s.need=speed>1e-3 and speed/(2*Half(s,norm(rotate(inverse(q),s.u)))) or 0
    end
    local sn=Ramp(1.5,8,vmax);local beta=.62-.12*sn
    if c.parked and vmax>.35 then c.parked=false elseif not c.parked and vmax<.15 then c.parked=true end
    local need=0;local swinging,off=false,false
    for _,s in ipairs(legs) do
        need=math.max(need,s.need);swinging=swinging or s.mode=='swing'
        off=off or (s.mode=='stance' and length(reject(sub(s.foot,World(s.rest)),surf))>.22)
    end
    local f=c.parked and 0 or clamp(math.max(1.1+.13*vmax,need*beta),0,3.8)
    if f==0 then c.settle=c.settle+dt;if swinging or (off and c.settle<1.5) then f=1.6 end else c.settle=0 end
    local restart=c.cadence==0 and f>0 and not swinging
    if restart then c.phaseAcc=math.floor(c.phaseAcc)+1;for _,s in ipairs(legs) do s.cycle=-1 end end
    c.cadence=f==0 and 0 or c.cadence+(f-c.cadence)*math.min(1,dt*10)
    local fc=math.max(c.cadence,f>0 and .5 or 0);c.phaseAcc=c.phaseAcc+fc*dt;c.phase=c.phaseAcc%1
    local ts=fc>0 and beta/fc or 0
    local function Dir(s) return length(s.u)>.3 and norm(s.u) or nil end
    local function Timed(s,n,dur)
        local pq,pp=Predict(q,ang,dur),add(p,mul(vt,dur))
        local h=M.Foothold(c,s,add(add(pp,rotate(pq,s.rest)),Lead(s,pq,ts)),pq,pp,up,surf,Dir(s))
        if not h then return false end
        local span=length(reject(sub(h.point,s.foot),surf))
        s.mode='plant';s.sw={from=Copy(s.foot),n0=n,to=h.point,hit=h,t=0,dur=dur,lift=clamp(.2*span+.08,.12,math.max(.45,(s.leg.stepHeight or 1)*.6))}
        return true
    end
    for _,s in ipairs(legs) do
        local acc=c.phaseAcc+s.offset;local lp,cyc=acc%1,math.floor(acc)
        if s.mode=='stance' then
            local slip=fc>0 and s.need*beta>3.8 and math.min(.6,1-3.8/(s.need*beta)) or 0
            if slip>0 then
                local moved=add(s.foot,mul(s.u,slip*dt));local cn=s.contact.normal;local g=c:Cast(add(moved,mul(cn,.1)),mul(cn,-1),.3)
                if g then s.foot=g.point;s.contact=g end
            end
            local n=s.contact.normal;local h=c:Cast(add(s.foot,mul(n,.08)),mul(n,-1),.2)
            if not h or h.collider~=s.contact.collider or not c:Reachable(s,s.foot,q,p) then s.mode='free';s.contact=nil
            elseif fc>0 and lp>=beta and s.cycle~=cyc and (lp-beta)/(1-beta)<.3 then
                s.mode='swing';s.cycle=cyc;s.sw={from=Copy(s.foot),n0=n,u0=(lp-beta)/(1-beta),t=0}
            elseif fc>0 and lp>=beta and s.cycle~=cyc and (restart or (lp-beta)/(1-beta)<.6) then
                if Timed(s,n,clamp((1-beta)/fc,.14,.3)) then s.cycle=cyc end
            elseif fc>0 and length(reject(sub(s.foot,World(s.rest)),surf))>math.min(s.strideMax*.75+.25,s.spacing*.9) then
                local down=0;local neighbors=true
                for _,o in ipairs(legs) do if o.mode=='stance' then down=down+1 end end
                for _,o in ipairs(s.nb) do if o.mode~='stance' then neighbors=false end end
                if neighbors and down>=math.ceil(#legs/2) and Timed(s,n,clamp((1-beta)/fc,.12,.25)) and lp>=beta*.5 then s.cycle=cyc end
            end
        end
        if s.mode=='swing' then
            local sw=s.sw;local u=(lp-beta)/(1-beta)
            local prog=(lp<beta or s.cycle~=cyc) and 1 or clamp((u-sw.u0)/math.max(.05,1-sw.u0),0,1);sw.t=prog
            if prog<.75 then
                local rem=(1-prog)*(1-sw.u0)*(1-beta)/math.max(fc,.5);local pq,pp=Predict(q,ang,rem),add(p,mul(vt,rem))
                local h=M.Foothold(c,s,add(add(pp,rotate(pq,s.rest)),Lead(s,pq,ts)),pq,pp,up,surf,Dir(s))
                if h then sw.to=sw.to and mix(sw.to,h.point,math.min(1,dt*14)) or h.point;sw.hit=h end
            end
            sw.to=sw.to or World(s.rest)
            local n1=sw.hit and sw.hit.normal or surf;local ln=norm(add(sw.n0,n1));local delta=sub(sw.to,sw.from)
            local span,rise=length(reject(delta,ln)),math.max(0,dot(delta,ln))
            local lift=clamp((.2*span+.08)*(1-.3*sn)+rise*.6,.12,math.max(.45,(s.leg.stepHeight or 1)*.6))
            local line=mix(sw.from,sw.to,Smooth(prog));local dir=norm(reject(delta,ln));local rest=reject(sub(World(s.rest),line),ln)
            local side=span>.05 and sub(rest,mul(dir,dot(rest,dir))) or {0,0,0}
            s.foot=add(add(line,mul(ln,Lift(prog)*lift)),mul(side,.6*Bump(prog)))
            if prog>=1 then
                if sw.hit and c:Reachable(s,sw.to,q,p) then
                    local g=c:Cast(add(sw.to,mul(n1,.15)),mul(n1,-1),.3)
                    s.foot=g and g.point or Copy(sw.to);s.contact=g or sw.hit;s.mode='stance'
                else s.mode='free' end
                s.sw=nil
            end
        end
        if s.mode=='free' then
            local h=M.Foothold(c,s,World(s.rest),q,p,up,surf,Dir(s))
            if h then s.mode='plant';s.sw={from=Copy(s.foot),n0=surf,to=h.point,hit=h,t=0}
            else s.foot=mix(s.foot,World(add(s.rest,{0,-s.leg.height*.1,0})),1-math.exp(-dt*10)) end
        end
        if s.mode=='plant' then
            local sw=s.sw;sw.t=math.min(1,sw.t+dt/(sw.dur or .14))
            s.foot=add(mix(sw.from,sw.to,Smooth(sw.t)),mul(norm(add(sw.n0,sw.hit.normal)),Lift(sw.t)*(sw.lift or .08)))
            if sw.t>=1 then
                if c:Reachable(s,sw.to,q,p) then s.foot=Copy(sw.to);s.contact=sw.hit;s.mode='stance';if lp>=beta then s.cycle=cyc end
                else s.mode='free' end
                s.sw=nil
            end
        end
    end
    Finish(c,q,p)
end
return M
