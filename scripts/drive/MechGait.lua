-- Source mechControl display gait; support physics stays in MechControl.
-- Sole probes originate at the mount height, never inside a slope or step.
local V=require('core.Math3');local IK=require('parts.MechIK');local CELL=require('Config').CELL
local add,sub,mul,dot,cross,len,norm=V.Add,V.Sub,V.Scale,V.Dot,V.Cross,V.Length,V.Normalize
local clamp,mix,reject,rotate=V.Clamp,V.Mix,V.Reject,V.RotateUnit
local UP={0,1,0};local DEG=math.pi/180;local M={}
local function Smooth(a,b,x) local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t) end
local function Jerk(s) return s*s*s*(10-15*s+6*s*s) end
local function QYaw(q,a) local h=math.sin(a/2);local w=math.cos(a/2);return {x=w*q.x+h*q.z,y=w*q.y+h*q.w,z=w*q.z-h*q.x,w=w*q.w-h*q.y} end
function M.Sole(c,s,pose,q,p,top,target)
    local need,minY=-math.huge,math.huge;local off=sub(target or pose.points.toe,pose.points.toe)
    for _,loc in ipairs(pose.sole) do local point=c:World(s,add(loc,off),q,p);minY=math.min(minY,point[2]);local h=c:Cast({point[1],top,point[3]},{0,-1,0},math.max(0,top-point[2])+s.leg.standHeight*.5)
        if h and h.normal[2]>.2 then need=math.max(need,h.point[2]-point[2]) end
    end;local hinge=c:World(s,target or pose.points.toe,q,p)[2];return {need=need==-math.huge and -1 or need,low=math.max(0,hinge-minY)}
end
function M.Step(c,dt,f)
    local q,p,vel,w,supported,ratio,cmd=f.q,f.p,f.vel,f.w,f.supported,f.ratio,f.cmd;local legs=c.list;if #legs==0 then return end
    local function Hinge(s) return (s.info.groundY-s.info.joints.toe[2])*CELL end
    local vh=reject(vel,UP);local tm=c.timing or c:Timing(len(vh),dot(w,UP),ratio);local duty,cycle=tm.duty,tm.cycle;local swingT=cycle-tm.ts
    local function HipVelocity(s) return add(vh,reject(cross(w,rotate(q,sub(s.leg.mount,c.v.com or {0,0,0}))),UP)) end
    local function Neutral(s,at,rq)
        local toe=s.info.joints.toe;local a,b=math.cos(s.yaw),math.sin(s.yaw)
        return c:World(s,{toe[1]*a+toe[3]*b,toe[2],-toe[1]*b+toe[3]*a},rq or q,at or p)
    end
    local function Ground(point,s)
        local height=s.leg.standHeight;local h=c:Cast(add(point,mul(UP,height*.7)),{0,-1,0},height*1.6)
        if not h then h=c:Cast(add(point,mul(UP,height*2)),{0,-1,0},height*1.4) end;return h and h.normal[2]>.45 and h or nil
    end
    if not supported then
        local rising,speed=vel[2]>0,len(vh);local direction=speed>.5 and mul(vh,1/speed) or norm(reject(rotate(q,{0,0,1}),UP))
        if not c.airGait then c.airGait=true;local best=-math.huge
            for _,s in ipairs(legs) do local ahead=s.foot and dot(sub(s.foot,p),direction)+(s.grounded and 0 or .5) or 0;if ahead>best then best=ahead;c.lead=s.offset end end
        end
        local fall=clamp(-vel[2]/8,0,1)
        for _,s in ipairs(legs) do
            local jetting=s.leg.jet>0 and (s.jet>.3 or c.jetBurst>0);local height=s.leg.standHeight;local lead=s.offset==c.lead;local rel=sub(Neutral(s),p)
            if jetting then rel=add(add(rel,mul(UP,-.03*height)),mul(direction,-math.min(.12*height,.05*speed)))
            elseif lead then rel=add(add(rel,mul(direction,math.min(.27*height,.011*height*speed))),mul(UP,height*(rising and .1 or .08*(1-fall))))
            else rel=add(add(rel,mul(direction,-math.min(.16*height,.007*height*speed))),mul(UP,height*(rising and .15 or .11))) end
            s.airRel=mix(s.airRel or (s.foot and sub(s.foot,p) or rel),rel,1-math.exp(-dt*7));s.previous=s.foot or add(p,s.airRel);s.foot=add(p,s.airRel);s.grounded=false;s.swing=nil
            local pitch=jetting and -12 or lead and (rising and -4 or 6) or -16;s.pitch=s.pitch+(pitch*DEG-s.pitch)*(1-math.exp(-dt*8))
            s.toe=s.toe+((lead and 4 or 12)*DEG-s.toe)*(1-math.exp(-dt*8));s.vane=s.vane+(1-s.vane)*(1-math.exp(-dt*10));s.yaw=c.yaw;s.soleLift=s.soleLift*math.exp(-dt*10)
        end;c:SharedYaw(cmd,dt);return
    end
    if c.airGait then
        c.airGait=false;local lead=c.lead or legs[1].offset
        for _,s in ipairs(legs) do if not s.foot then s.foot=Neutral(s);s.previous=s.foot end;s.airRel=nil
            if s.offset==lead then local g=Ground(s.foot,s) or Ground(Neutral(s),s);s.foot=g and add(g.point,mul(UP,Hinge(s))) or Neutral(s);s.previous=s.foot;s.grounded=g~=nil;s.swing=nil;s.ground=g and g.point or nil;s.normal=g and g.normal or {0,1,0}
            else s.grounded=false;s.swing={from=s.foot,rel=sub(s.foot,p),to=s.foot,lift=0,u0=nil} end
        end;c.phase=(lead%1)+1e-4;c.noLaunch=.05
    end
    for _,s in ipairs(legs) do if not s.foot or not s.grounded and not s.swing then local g=Ground(Neutral(s),s);s.foot=g and add(g.point,mul(UP,Hinge(s))) or Neutral(s);s.previous=s.foot;s.grounded=g~=nil;s.ground=g and g.point or nil;s.normal=g and g.normal or {0,1,0} end end
    c:SharedYaw(cmd,dt);local moving=false;local far=false;local planted=true
    for _,s in ipairs(legs) do if len(HipVelocity(s))>.35 then moving=true end;if s.grounded and len(reject(sub(s.foot,Neutral(s)),UP))>s.leg.standHeight*.08 then far=true end;if not s.grounded then planted=false end end
    moving=moving or math.abs(cmd.steer or 0)>.1;local settle=not moving and not far;if not(settle and planted) then c.phase=(c.phase+dt/cycle)%1 end
    for _,s in ipairs(legs) do
        local lp=(c.phase-s.offset)%1;local swing=lp>=duty and not(settle and planted);s.previous=s.foot
        if swing then
            local u=clamp((lp-duty)/(1-duty),0,1)
            if not s.swing then
                s.swing={from=s.foot,rel=sub(s.foot,p),to=s.foot,lift=0,u0=0,raise=s.soleLift or 0}
                local airborne=true;for _,other in ipairs(legs) do if other~=s and other.grounded then airborne=false end end
                if tm.tf>.08 and not(c.noLaunch>0) and #legs>=2 and airborne then c.launch=tm.tf;s.jet=math.max(s.jet,1);c:Footfall(clamp(tm.tf/.45,.3,1),s.foot,'launch') end
            end
            if u<.8 then
                local remaining=(1-u)*swingT;local rq=QYaw(q,dot(w,UP)*remaining);local at=add(p,mul(vh,remaining));local target=add(Neutral(s,at,rq),mul(HipVelocity(s),duty*cycle*.5*(1+.8*c:Squat())))
                local reference=c.groundRef;if reference then target[2]=reference.point[2]-(reference.normal[1]*(target[1]-reference.point[1])+reference.normal[3]*(target[3]-reference.point[3]))/math.max(.5,reference.normal[2])+Hinge(s) end
                local ground=Ground(target,s)
                if ground then
                    local forward=norm(reject(c:LegForward(s,q),UP));local info=s.info;local tip=info.segmentBounds.toecap.max[3]*CELL;local heel=(info.joints.toe[3]-info.joints.ball[3]-info.segmentBounds.foot.min[3])*CELL
                    local slope=-(ground.normal[1]*forward[1]+ground.normal[3]*forward[3])/math.max(.5,ground.normal[2])
                    local function Edge(k) local h=Ground(add(ground.point,mul(forward,k)),s);return h and h.point[2]-ground.point[2]-slope*k or 0 end
                    local front,back=Edge(tip),Edge(-heel);if math.max(front,back)>.04*s.leg.standHeight then ground=Ground(add(ground.point,mul(forward,front>.04*s.leg.standHeight and tip+.15 or heel+.15)),s) or ground end
                end
                target=ground and add(ground.point,mul(UP,Hinge(s))) or reference and target or add(target,mul(UP,-s.leg.standHeight*.1))
                local sw=s.swing;sw.to=target;sw.normal=ground and ground.normal or {0,1,0};sw.relTo=sub(target,at)
                local budget=math.max(.05,math.min(s.info.limits['knee-']/165,c.sinkCap*.95)-.04*math.min(1,ratio)-.01)
                sw.lift=s.leg.standHeight*math.min(.08+.08*math.min(1,ratio),budget)+math.min(math.max(0,target[2]-sw.from[2])*.15,s.leg.standHeight*.03)
            end
            local sw=s.swing;if sw.u0==nil then sw.u0=math.min(u,.7) end;local uu=sw.u0~=0 and clamp((u-sw.u0)/(1-sw.u0),0,1) or u;local m=Jerk(uu)
            local position=mix(add(p,mix(sw.rel or sub(sw.from,p),sw.relTo or sub(sw.to,p),m)),sw.to,Smooth(.8,1,uu));local arc=math.sin(math.pi*uu^.85)
            local dx,dz=sw.to[1]-sw.from[1],sw.to[3]-sw.from[3];local span=math.sqrt(dx*dx+dz*dz);local along=span>1e-3 and clamp(((position[1]-sw.from[1])*dx+(position[3]-sw.from[3])*dz)/(span*span),0,1) or 0
            local factor=clamp(span/(.1*s.leg.standHeight),0,1);local frac=Smooth(0,.85,uu)*(1-factor)+math.max(along,Smooth(.8,1,uu))*factor
            position[2]=sw.from[2]+(sw.to[2]-sw.from[2])*frac+sw.lift*arc;local heel=(12+5*math.min(1,ratio))*DEG
            s.pitch=-heel*(1-Smooth(0,.4,u))+7*DEG*math.sin(math.pi*Smooth(.35,1,u));s.toe=heel*(1-Smooth(0,.3,u))
            local forward=c:LegForward(s,q);local function Slope(normal) return clamp(math.asin(clamp(-dot(normal,forward),-1,1)),-33*DEG,33*DEG) end
            s.pitch=s.pitch+Slope(s.normal)+(Slope(sw.normal or UP)-Slope(s.normal))*frac
            local top=add(p,rotate(q,s.leg.mount))[2]+.3
            local height=s.leg.standHeight;local localPoint=c:Local(s,position,q,p);local pose=IK.Solve(s.leg.type,localPoint,s.pitch,s.toe,s.yaw);local sole=M.Sole(c,s,pose,q,p,top,localPoint);local need=sole.need
            local fade=1-Smooth(.7,.95,uu);local rest=math.sqrt((sw.to[1]-position[1])^2+(sw.to[3]-position[3])^2);local edge=math.min(1,s.info.segmentBounds.toecap.max[3]*CELL/math.max(rest,1e-3))
            for _,k in ipairs({.3,.6,edge}) do local point=mix(position,sw.to,k);local h=c:Cast({point[1],top,point[3]},{0,-1,0},top-point[2]+height);if h and h.normal[2]>.2 then need=math.max(need,(h.point[2]+sole.low-point[2])*fade) end end
            local want=math.max(0,need+.03*height*arc);sw.raise=sw.raise or 0
            if want>sw.raise or uu>.85 then sw.raise=want else sw.raise=sw.raise+(want-sw.raise)*(1-math.exp(-dt*6)) end
            position[2]=position[2]+sw.raise;local short=IK.Solve(s.leg.type,c:Local(s,position,q,p),s.pitch,s.toe,s.yaw).short*CELL
            if short>0 then position[2]=position[2]-math.min(short,math.max(0,sw.raise-sole.need-.02)) end
            if uu>.5 and uu<.92 and sole.need>-.02 and #legs>=2 and not(c.earlyCool>0) then local ground=Ground(position,s)
                if ground and ground.point[2]+Hinge(s)>sw.to[2]+.03*height then sw.to=add(ground.point,mul(UP,Hinge(s)));sw.normal=ground.normal;sw.raise=0;c.phase=(s.offset+1e-4)%1;c.earlyCool=.15
                    for _,other in ipairs(legs) do if other~=s and other.swing then other.swing.from=other.foot;other.swing.rel=sub(other.foot,p);other.swing.u0=nil end end
                end
            end
            s.foot=position;s.grounded=false;s.soleLift=0;s.vane=s.vane+(math.sin(math.pi*u)-s.vane)*(1-math.exp(-dt*14));s.yaw=c.yaw
        else
            if s.swing then
                local near=len(sub(s.swing.to,s.foot))<s.leg.standHeight*.25;local ground=Ground(near and s.swing.to or s.foot,s)
                s.foot=ground and add(ground.point,mul(UP,Hinge(s))) or s.swing.to;s.normal=ground and ground.normal or s.swing.normal or {0,1,0};s.soleLift=s.swing.raise or 0;s.swing=nil;s.pulse=math.max(s.pulse,.5+.5*math.min(1,ratio))
                local heavy=(.8+.2*math.min(1,c.heft))*clamp(math.max(len(vh)/5,math.abs(dot(w,UP))/2.4),.15,1);local walkish=clamp(1-tm.tf/.2,0,1)
                c.impulse=math.max(c.impulse,(.6+2.4*walkish)*math.sqrt(c.standAvg/6.5)*heavy);c.brake=0;c:Footfall(clamp(.4+.6*math.max(1-walkish,math.min(1,ratio)),0,1)*heavy,s.foot,'plant')
            end
            s.grounded=true;local stance=settle and planted and 0 or lp/duty;local heel=(12+5*math.min(1,ratio))*DEG;local slope=clamp(math.asin(clamp(-dot(s.normal,c:LegForward(s,q)),-1,1)),-33*DEG,33*DEG)
            s.pitch=-heel*Smooth(.7,1,stance)+slope;s.toe=-s.pitch+slope;s.vane=s.vane-s.vane*(1-math.exp(-dt*8));s.yaw=c.yaw
            local pose=IK.Solve(s.leg.type,c:Local(s,s.foot,q,p),s.pitch,s.toe,s.yaw)
            if math.abs(pose.lateral)>.01 and not pose.over and not pose.under then s.foot=c:World(s,pose.points.toe,q,p) end
            local top=add(p,rotate(q,s.leg.mount))[2]+.3;local want=math.min(M.Sole(c,s,pose,q,p,top,c:Local(s,s.foot,q,p)).need+.01,s.leg.standHeight*.06)
            s.soleLift=s.soleLift+(math.max(0,want)-s.soleLift)*(1-math.exp(-dt*(want>s.soleLift and 40 or 8)))
            if pose.over and #legs==2 and len(vh)>3 and not(c.resync>0) and dot(sub(s.foot,p),vh)<0 then c.phase=(s.offset+duty+.002)%1;c.resync=.2 end
        end
    end
end
return M
