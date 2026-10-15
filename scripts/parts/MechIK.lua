-- Frozen H5 shared/parts/mechIK.js. All solver coordinates are source cells.
local M={}
local geometry,sinks,extensions={},{},{}
local DEG=math.pi/180
local FLEX={mech3=11,mech4=0,mech5=2}
local function Clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function Add(a,b) return {a[1]+b[1],a[2]+b[2]} end
local function Sub(a,b) return {a[1]-b[1],a[2]-b[2]} end
local function Len(a) return math.sqrt(a[1]^2+a[2]^2) end
local function Ang(a) return math.atan(a[2],a[1]) end
local function Rotate(a,r) local c,s=math.cos(r),math.sin(r);return {a[1]*c-a[2]*s,a[1]*s+a[2]*c} end
local function Wrap(a) return a-2*math.pi*math.floor(a/(2*math.pi)+.5) end
local function Sign(a) return a<0 and -1 or a>0 and 1 or 0 end
function M.Data(type) return require('parts.PartAssets').Get(type).segments.info end
function M.Geometry(type)
    if geometry[type] then return geometry[type] end
    local d=M.Data(type);local p=d.plane
    local H,K,A,F,T=p.hip,p.knee,p.ankle,p.ball,p.toe
    local p1,p2,p3=Ang(Sub(K,H)),Ang(Sub(A,K)),Ang(Sub(F,A))
    local l1,l2,l3=Len(Sub(K,H)),Len(Sub(A,K)),Len(Sub(F,A))
    local delta=p3-p1;local cv={l1+l3*math.cos(delta),l3*math.sin(delta)}
    local C,gam=Len(cv),Ang(cv);local lim=d.limits or {}
    local function Distance(s) return math.sqrt(C*C+l2*l2+2*C*l2*math.cos(s+p2-p1-gam)) end
    local a,b=Distance(-(lim['knee-'] or 60)*DEG),Distance((lim['knee+'] or 60)*DEG)
    local sole={};local sb=d.segmentBounds;local gy=-d.groundY
    for _,sx in ipairs({-1,1}) do
        sole[#sole+1]={sx*sb.foot.max[1],Sub({d.joints.ball[3]+sb.foot.min[3],gy},T),false}
        sole[#sole+1]={sx*sb.foot.max[1],Sub({d.joints.ball[3],gy},T),false}
        sole[#sole+1]={sx*sb.toecap.max[1],Sub({d.joints.toe[3],gy},T),true}
        sole[#sole+1]={sx*sb.toecap.max[1],Sub({d.joints.toe[3]+sb.toecap.max[3],gy},T),true}
    end
    local g={d=d,H=H,K=K,A=A,F=F,T=T,PHI1=p1,PHI2=p2,PHI3=p3,L1=l1,L2=l2,L3=l3,
        DELTA=delta,C=C,GAM=gam,SGN=Wrap(p1+gam-Ang(Sub(F,H)))>0 and 1 or -1,
        P1={d.act.sleeve.origin[3],-d.act.sleeve.origin[2]},P2={d.act.rod.origin[3],-d.act.rod.origin[2]},
        reach=C+l2,rest=Len(Sub(F,H)),lim=lim,type=type,standHeight=d.standHeight,
        dMin=math.max(math.abs(C-l2)+1e-4,math.min(a,b)),dMax=math.min(C+l2-1e-4,math.max(a,b)),
        roll=(lim.roll or 6)*DEG,footDown=(lim['foot-'] or 30)*DEG,footUp=(lim['foot+'] or 60)*DEG,
        toeUp=(lim['toe+'] or 19)*DEG,toeDown=(lim['toe-'] or 7)*DEG,sole=sole}
    geometry[type]=g;return g
end
local function Plain(g,target,pitch,toe,yaw)
    local c,s=math.cos(yaw),math.sin(yaw)
    local x0,z,y0=target[1]*c-target[3]*s,target[1]*s+target[3]*c,target[2]
    local roll=Clamp(-math.atan(x0,y0),-g.roll,g.roll);local cr,sr=math.cos(roll),math.sin(roll)
    local x,y=x0*cr+y0*sr,-x0*sr+y0*cr
    local tt={z,-y};local fr=Sub(Add(tt,Rotate(Sub(g.F,g.T),pitch)),g.H);local d0=Len(fr)
    local u=Clamp((g.rest-d0)/(g.rest*.22),-.35,1.3);local e=(FLEX[g.type] or 0)*DEG*u
    local cv={g.L1+g.L3*math.cos(g.DELTA+e),g.L3*math.sin(g.DELTA+e)};local C,gam=Len(cv),Ang(cv)
    local function Distance(k) return math.sqrt(C*C+g.L2*g.L2+2*C*g.L2*math.cos(k+g.PHI2-g.PHI1-gam)) end
    local a,b=Distance(-(g.lim['knee-'] or 60)*DEG),Distance((g.lim['knee+'] or 60)*DEG)
    local dMin=math.max(math.abs(C-g.L2)+1e-4,math.min(a,b));local dMax=math.min(C+g.L2-1e-4,math.max(a,b))
    local d=Clamp(d0,dMin,dMax);local ca=Clamp((C*C+d*d-g.L2*g.L2)/(2*C*d),-1,1)
    local denominator=d0~=0 and d0 or 1;local fd={fr[1]/denominator*d,fr[2]/denominator*d}
    if d0<dMin and math.abs(fr[2])<dMin then
        local fh=Sign(fr[1]~=0 and fr[1] or 1)*math.sqrt(dMin*dMin-fr[2]*fr[2])
        local k=Clamp((math.abs(fr[1])/dMin-.08)/.25,0,1);local w=k*k*(3-2*k)
        local v={fd[1]*(1-w)+fh*w,fd[2]*(1-w)+fr[2]*w};local lm=Len(v);if lm==0 then lm=1 end
        fd={v[1]/lm*d,v[2]/lm*d}
    end
    local al=Ang(fd)+g.SGN*math.acos(ca);local cv2={C*math.cos(al),C*math.sin(al)}
    local be=Ang(Sub(fd,cv2));local th1=al-gam;local th3=th1+g.DELTA+e
    local r1,r2,r3=Wrap(th1-g.PHI1),Wrap(be-g.PHI2),Wrap(th3-g.PHI3)
    local p1w=Add(g.H,Rotate(Sub(g.P1,g.H),r1));local kw=Add(g.H,Rotate(Sub(g.K,g.H),r1))
    local p2w=Add(kw,Rotate(Sub(g.P2,g.K),r2))
    local sleeve=Wrap(Ang(Sub(p2w,p1w))-Ang(Sub(g.P2,g.P1))-r1)
    local rod=Wrap(Ang(Sub(p1w,p2w))-Ang(Sub(g.P1,g.P2))-r2)
    local aw=Add(kw,Rotate(Sub(g.A,g.K),r2));local fw=Add(aw,Rotate(Sub(g.F,g.A),r3))
    local tw=Add(fw,Rotate(Sub(g.T,g.F),pitch))
    local function To3(q)
        local zz,yy=q[1],-q[2];local xr,yr=-yy*sr,yy*cr
        return {xr*c+zz*s,yr,-xr*s+zz*c}
    end
    local tc=Clamp(toe,-g.toeDown,g.toeUp);local lat={cr*c,sr,-cr*s};local sole={}
    for _,corner in ipairs(g.sole) do
        local pt=To3(Add(tw,Rotate(corner[2],pitch+(corner[3] and tc or 0))))
        sole[#sole+1]={pt[1]+lat[1]*corner[1],pt[2]+lat[2]*corner[1],pt[3]+lat[3]*corner[1]}
    end
    return {yaw=yaw,roll=roll,thigh=r1,shin=Wrap(r2-r1),tarsus=Wrap(r3-r2),foot=Wrap(pitch-r3),
        toecap=tc,sleeve=sleeve,rod=rod,act=Len(Sub(p1w,p2w))/Len(Sub(g.P1,g.P2)),r3=r3,
        error=math.sqrt(Len(Sub(fd,fr))^2+x*x),lateral=x,over=d0>dMax,under=d0<dMin,ankleFlex=e,short=math.max(0,dMin-d0),
        points={hip=To3(g.H),knee=To3(kw),ankle=To3(aw),ball=To3(fw),toe=To3(tw)},sole=sole}
end
function M.Solve(type,target,pitch,toe,yaw)
    local g=M.Geometry(type);pitch,toe,yaw=pitch or 0,toe or 0,yaw or 0
    local r=Plain(g,target,pitch,toe,yaw)
    for _=1,2 do
        local f=Clamp(r.foot,-g.footDown,g.footUp)
        if math.abs(f-r.foot)<1e-5 then break end
        pitch=r.r3+f;r=Plain(g,target,pitch,toe,yaw)
    end
    r.foot=Clamp(r.foot,-g.footDown,g.footUp);return r
end
local function Capacity(type,cache,direction,maximum)
    if cache[type] then return cache[type] end
    local d=M.Data(type);local t=d.joints.toe;local lo,hi=0,maximum
    for _=1,24 do
        local mid=(lo+hi)/2
        if M.Solve(type,{t[1],t[2]+direction*d.standHeight*mid,t[3]}).error<1e-3 then lo=mid else hi=mid end
    end
    cache[type]=lo;return lo
end
function M.SinkCapacity(type) return Capacity(type,sinks,-1,.5) end
function M.ExtendCapacity(type) return Capacity(type,extensions,1,.6) end
return M
