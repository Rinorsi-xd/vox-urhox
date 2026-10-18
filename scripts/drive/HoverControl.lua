local TerrainObstacles=require("drive.TerrainObstacles")

local Math=require "core.Math3"
local Capabilities=require "drive.Capabilities"
local C=Math.Clamp
local MIN_UP=math.cos(35*math.pi/180)
local M={}
local function Vec(a) return {x=a[1],y=a[2],z=a[3]} end
function M.Force(h,d,verticalSpeed,share,heightScale)
    local ground=d<math.huge and 1-C((d-h.height)/h.height,0,1) or 0
    local maxForce=2*h.load*9.81;local k=h.load*9.81/(.4*h.height)
    local damping=2*.5*math.sqrt(k*math.min(share,2*h.load))*(verticalSpeed<0 and 2 or 1)
    local over=share/math.max(1e-6,h.load);local sink=over>1 and C(1.5-.5*over,.35,1) or 1
    local target=h.height*(heightScale or 1)*sink;local targetGround=1-C((target-h.height)/h.height,0,1)
    local spring=math.max(0,target-d)-math.max(0,math.min(d,h.height)-target)
    local raw=share*9.81/math.max(.1,targetGround)+k*spring-damping*verticalSpeed
    return {G=ground,force=C(raw*ground,0,maxForce),maxForce=maxForce}
end
function M.Step(v,contactSupport)
    local body=v.body;local q,t=body.rotation(),body.translation()
    local function WorldPoint(p) return Math.Add(Math.Rotate(q,p),{t.x,t.y,t.z}) end
    local function Cast(p,length) return v.space:Raycast(p,{0,-1,0},length,body,nil,false,TerrainObstacles.SUPPORT_MASK) end
    v.hoverStates={}
    local active,totalForce,distance,hoverLoad=0,0,0,0
    for _,h in ipairs(v.spec.hovers) do if h.works then hoverLoad=hoverLoad+h.load end end
    local unsupportedMass=math.max(0,v.mass-(contactSupport or 0)/9.81)
    for _,h in ipairs(v.spec.hovers) do
        local p=WorldPoint(h.pos);local axis=Math.Rotate(q,h.dir)
        local share=unsupportedMass*((v.hoverShares and v.hoverShares[h.partId]) or h.load/math.max(1,hoverLoad))
        -- Valid mounts stay valid when the craft tilts: ground-effect lift is
        -- gimballed upward on hover craft, so a bank cannot pin it into a wall.
        local liftAxis=v.hoverMode and {0,1,0} or axis
        local hit=h.works and (v.hoverMode or axis[2]>=MIN_UP) and Cast(p,2*h.height) or nil
        local d=hit and hit.dist or math.huge;local pv=body.velocityAtPoint(Vec(p))
        local gv=hit and hit.body and hit.body.velocityAtPoint({x=p[1],y=p[2]-d,z=p[3]}) or nil
        local relativeSpeed=pv.y-(gv and gv.y or 0)
        local state=M.Force(h,d,relativeSpeed,share,v.hoverHeightScale or 1)
        state.relativeSpeed=relativeSpeed;state.distance=d<math.huge and d or nil;state.point=p;state.axis=axis;state.emitHits={}
        if state.force>0 and state.G>0 then
            body.addForceAtPoint(Vec(Math.Scale(liftAxis,state.force)),Vec(p),true)
            active=active+1;totalForce=totalForce+state.force*liftAxis[2];distance=distance+d
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
    local accel=13*m.accelFactor*authority
    local topF,topS=m.topSpeed*(throttle<0 and .45 or 1),m.topSpeed*.6
    local un=math.max(1e-9,math.sqrt(throttle^2+strafe^2))
    local ellipse=(throttle==0 and strafe==0) and 0 or 1/math.sqrt((throttle/un/topF)^2+(strafe/un/topS)^2)
    local capF,capS=math.abs(throttle)/un*ellipse,math.abs(strafe)/un*ellipse
    local forward=mass*accel*throttle*Capabilities.Falloff(throttle*vf>0 and math.abs(vf) or 0,capF)
    local lateral=mass*accel*.8*strafe*Capabilities.Falloff(strafe*vs>0 and math.abs(vs) or 0,capS)
    -- Main hover craft tighten lateral drift so travel follows the nose; mixed
    -- chassis keep the older assist damping. Vertical spring stays in Step.
    local damping=v.hoverMode and 2.4 or .6
    local df=(throttle==0 or throttle*vf<0) and damping or .05;local ds=strafe==0 and (v.hoverMode and 5 or .6) or .05
    local cap=mass*(v.hoverMode and 18 or 9.81)*authority
    local sideCap=mass*(v.hoverMode and 32 or 9.81)*authority
    local fx=forward-C(mass*df*vf*authority,-cap,cap);local sx=lateral-C(mass*ds*vs*authority,-sideCap,sideCap)
    body.addForce({x=f[1]*fx+side[1]*sx,y=0,z=f[3]*fx+side[3]*sx},true)
    if v.hoverMode then
        -- A/D drives yaw directly: pivot in place at low speed, ease off as speed
        -- builds so lateral thrust has time to line the craft up.
        local w=body.angvel()
        local yawRate=2.6-1.15*C(speed/math.max(1,m.topSpeed),0,1)
        local target=C(cmd.steer or 0,-1,1)*yawRate
        local torque=C(v.inertiaY*14*(target-w.y),-v.inertiaY*16*authority,v.inertiaY*16*authority)
        body.addTorque({x=0,y=torque,z=0},true)
        body.addTorque({x=-w.x*v.inertiaY*.3*authority,y=0,z=-w.z*v.inertiaY*.3*authority},true)
    end
    return {hoverAuthority=authority}
end
-- Recover pitch/roll even when every ground ray misses, then ease a wedged hull
-- clear of nearby walls. Adds no lift and no forward thrust.
function M.Recovery(v,dt,up)
    if not v.hoverMode then return end
    local load=0
    for _,h in ipairs(v.spec.hovers) do if h.works then load=load+h.load end end
    local authority=C(load/math.max(v.mass,v.capabilities.totalLoad),0,1)
    local angle=math.acos(C(up[2],-1,1))
    if authority<=0 or angle<math.pi/9 then return end
    local w=v.body.angvel();local length=math.sqrt(up[1]^2+up[3]^2)
    local axis=length>1e-5 and {-up[3]/length,0,up[1]/length} or {1,0,0}
    local rate=math.min(1.8,angle*2.5);local gain=6*authority*dt
    v.body.setAngvel({x=w.x+C(axis[1]*rate-w.x,-gain,gain),y=w.y,z=w.z+C(axis[3]*rate-w.z,-gain,gain)},true)
    if angle>math.pi/5 then
        -- A nearly vertical hull wedged on rock cannot rotate in place: probe the
        -- surrounding walls and push along their normals, never through them.
        local nx,nz=0,0
        for _,contact in ipairs(v.staticContacts or {}) do
            if math.abs(contact.normal[2])<=.5 then nx=nx+contact.normal[1];nz=nz+contact.normal[3] end
        end
        local len=math.sqrt(nx*nx+nz*nz)
        if len>1e-5 then
            nx,nz=nx/len,nz/len
            local lv=v.body.linvel()
            local accel=C((3-lv.x*nx-lv.z*nz)*3,0,6)*authority
            v.body.addForce({x=nx*v.mass*accel,y=0,z=nz*v.mass*accel},true)
        end
    end
end
return M
