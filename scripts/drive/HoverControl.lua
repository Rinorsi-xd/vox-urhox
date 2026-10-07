local Math=require "core.Math3"
local Capabilities=require "drive.Capabilities"
local C=Math.Clamp
local MIN_UP=math.cos(35*math.pi/180)
local M={}
local function Vec(a) return {x=a[1],y=a[2],z=a[3]} end
function M.Force(h,d,verticalSpeed,share,heightScale)
    local ground=d<math.huge and 1-C((d-h.height)/h.height,0,1) or 0
    local maxForce=2*h.load*9.81;local k=h.load*9.81/(.4*h.height)
    local damping=2*.65*math.sqrt(k*math.min(share,2*h.load))*(verticalSpeed<0 and 2 or 1)
    local target=h.height*(heightScale or 1);local targetGround=1-C((target-h.height)/h.height,0,1)
    local spring=math.max(0,target-d)-math.max(0,math.min(d,h.height)-target)
    local raw=share*9.81/math.max(.1,targetGround)+k*spring-damping*verticalSpeed
    return {G=ground,force=C(raw*ground,0,maxForce),maxForce=maxForce}
end
function M.Step(v,contactSupport)
    local body=v.body;local q,t=body.rotation(),body.translation()
    local function WorldPoint(p) return Math.Add(Math.Rotate(q,p),{t.x,t.y,t.z}) end
    local function Cast(p,length) return v.space:Raycast(p,{0,-1,0},length,body) end
    v.hoverStates={}
    local active,totalForce,distance,hoverLoad=0,0,0,0
    for _,h in ipairs(v.spec.hovers) do if h.works then hoverLoad=hoverLoad+h.load end end
    local unsupportedMass=math.max(0,v.mass-(contactSupport or 0)/9.81)
    for _,h in ipairs(v.spec.hovers) do
        local p=WorldPoint(h.pos);local axis=Math.Rotate(q,h.dir)
        local share=unsupportedMass*((v.hoverShares and v.hoverShares[h.partId]) or h.load/math.max(1,hoverLoad))
        local hit=h.works and axis[2]>=MIN_UP and Cast(p,2*h.height) or nil
        local d=hit and hit.dist or math.huge;local pv=body.velocityAtPoint(Vec(p))
        local gv=hit and hit.body and hit.body.velocityAtPoint({x=p[1],y=p[2]-d,z=p[3]}) or nil
        local relativeSpeed=pv.y-(gv and gv.y or 0)
        local state=M.Force(h,d,relativeSpeed,share,v.hoverHeightScale or 1)
        state.relativeSpeed=relativeSpeed;state.distance=d<math.huge and d or nil;state.point=p;state.axis=axis;state.emitHits={}
        if state.force>0 and state.G>0 then
            body.addForceAtPoint(Vec(Math.Scale(axis,state.force)),Vec(p),true)
            active=active+1;totalForce=totalForce+state.force*axis[2];distance=distance+d
            for _,e in ipairs(h.emits or {}) do
                local origin=WorldPoint(e.pos);local eh=Cast(origin,2*h.height)
                state.emitHits[#state.emitHits+1]=eh and {point={origin[1],origin[2]-eh.dist,origin[3]},normal=eh.normal,distance=eh.dist} or false
            end
        end
        v.hoverStates[h.partId]=state
    end
    local scale=v.hoverHeightScale or 1;local sum=0
    for _,h in ipairs(v.spec.hovers) do if h.works then sum=sum+h.height*h.load end end
    return {hovers=active,hoverCount=#v.spec.hovers,hoverForce=totalForce,hoverSupport=totalForce/(v.mass*9.81),
        hoverHeight=active>0 and distance/active or nil,hoverHeightTarget=hoverLoad>0 and sum/hoverLoad*scale or nil,hoverHeightScale=scale}
end
function M.Motion(v,cmd,frame)
    local body,mass,m=v.body,v.mass,v.spec.motion
    local effectiveLoad=0
    for _,h in ipairs(v.spec.hovers) do
        local state=v.hoverStates[h.partId]
        if h.works then effectiveLoad=effectiveLoad+h.load*(state and state.G or 0) end
    end
    local authority=C(effectiveLoad/math.max(mass,v.capabilities.totalLoad),0,1)
    if authority<=0 then return {hoverAuthority=0} end
    local fwd,vel=frame.fwd,frame.vel
    local length=math.sqrt(fwd[1]^2+fwd[3]^2);if length==0 then length=1 end
    local f={fwd[1]/length,0,fwd[3]/length};local side={f[3],0,-f[1]}
    local vf,vs=Math.Dot(vel,f),Math.Dot(vel,side);local speed=math.sqrt(vf*vf+vs*vs)
    local throttle,strafe=C(cmd.throttle or 0,-1,1),v.hoverMode and C(cmd.strafe or 0,-1,1) or 0
    local norm=math.max(1,math.sqrt(throttle^2+strafe^2));throttle=throttle/norm;strafe=strafe/norm
    local accel=8*m.accelFactor*authority
    local forward=mass*accel*throttle*Capabilities.Falloff(throttle*vf>0 and speed or 0,m.topSpeed*(throttle<0 and .45 or 1))
    local lateral=mass*accel*.8*strafe*Capabilities.Falloff(strafe*vs>0 and speed or 0,m.topSpeed*.6)
    local df=(throttle==0 or throttle*vf<0) and 1.2 or .05;local ds=strafe==0 and 1.2 or .05
    local cap=mass*9.81*authority
    local fx=forward-C(mass*df*vf*authority,-cap,cap);local sx=lateral-C(mass*ds*vs*authority,-cap,cap)
    body.addForce({x=f[1]*fx+side[1]*sx,y=0,z=f[3]*fx+side[3]*sx},true)
    if v.hoverMode then
        local w=body.angvel();local target=C(cmd.steer or 0,-1,1)*1.8
        local torque=C(v.inertiaY*6*(target-w.y),-v.inertiaY*6*authority,v.inertiaY*6*authority)
        body.addTorque({x=0,y=torque,z=0},true)
        body.addTorque({x=-w.x*v.inertiaY*.3*authority,y=0,z=-w.z*v.inertiaY*.3*authority},true)
    end
    return {hoverAuthority=authority}
end
return M
