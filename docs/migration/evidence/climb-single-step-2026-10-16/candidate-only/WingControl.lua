-- Frozen 2026-10-14 wingControl.js: per-surface aerodynamic forces, keyboard
-- flight assistance and low-speed lift. Source-space metres; never aim-follow.
local V=require 'core.Math3'
local FlightResponse=require 'drive.FlightResponse'
local clamp,rotate,dot,cross,sub,len=V.Clamp,V.Rotate,V.Dot,V.Cross,V.Sub,V.Length
local M={}
local RHO,STALL,STALL_END,CAMBER=3.5,math.rad(15),math.rad(28),.22
local ARM,AUTH,VANE={.35,.4,.2},{3,1.6,12},{2.2,1.4}
local function Sign(x) return x>0 and 1 or x<0 and -1 or 0 end
local function Wrap(x) return math.atan(math.sin(x),math.cos(x)) end
local function Smooth(a,b,x) local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t) end
function M.NormalCoefficient(alpha)
    local a=math.abs(alpha);if a<=STALL then return 2*math.pi*alpha end
    local t=clamp((a-STALL)/(STALL_END-STALL),0,1);local k=t*t*(3-2*t)
    return Sign(alpha)*(2*math.pi*STALL*(1-k)*(1-.35*k)+1.2*math.sin(math.min(a,math.pi/2))*k)
end
local function Init(v,ws,com)
    v.wingSurfaces={};v.wingLever={.05,.05,.05};v.wingArea=0;v.wingLiftArea=0
    local left,right,pitch,rudder=false,false,false,false
    for _,w in ipairs(ws) do
        v.wingArea=v.wingArea+w.area
        if w.kind=='wing' then v.wingLiftArea=v.wingLiftArea+w.area*w.lift*math.abs(w.n[2]) end
        rudder=rudder or w.kind=='rudder'
        for _,s in ipairs(w.surfaces) do
            local torque=cross(sub(s.pos,com),w.n)
            v.wingSurfaces[#v.wingSurfaces+1]={wing=w,s=s,key=w.partId..':'..s.name,torque=torque}
            for k=1,3 do v.wingLever[k]=math.max(v.wingLever[k],math.abs(torque[k])) end
            if w.kind=='wing' then pitch=true;left=left or s.pos[1]<com[1];right=right or s.pos[1]>com[1] end
        end
    end
    v.wingLiftArea=math.max(.5,v.wingLiftArea)
    local inertia={0,0,0}
    local function Add(c,h,m)
        local d=sub(c,com);h=h or {0,0,0}
        inertia[1]=inertia[1]+m*(d[2]^2+d[3]^2+(h[2]^2+h[3]^2)/3)
        inertia[2]=inertia[2]+m*(d[1]^2+d[3]^2+(h[1]^2+h[3]^2)/3)
        inertia[3]=inertia[3]+m*(d[1]^2+d[2]^2+(h[1]^2+h[2]^2)/3)
    end
    for _,list in ipairs({v.spec.boxes,v.spec.hulls or {}}) do for _,b in ipairs(list) do Add(b.center,b.half,b.mass) end end
    for _,w in ipairs(v.spec.wheels) do Add(w.center,nil,w.mass) end
    v.wingInertia={math.max(inertia[1],v.mass*.5),math.max(inertia[2],v.mass*.5),math.max(inertia[3],v.mass*.5)}
    v.wingAuthority={pitch and 1 or .25,rudder and 1 or .35,left and right and 1 or .3}
end
function M.Step(v,cmd,dt,contact,support)
    local ws=v.spec.wings;if not ws or #ws==0 then return {} end
    contact=contact==true or type(contact)=='number' and contact>0
    local body=v.body;local q=body.rotation();local iq=V.Inverse(q)
    if body.addFlightAngularAcceleration and v.flightResponse==nil then v.flightResponse=FlightResponse.New(v) or false end
    local response=v.flightResponse or nil;local com=response and response.com or v.com
    local p,lv,av=body.translation(),body.linvel(),body.angvel()
    local vb,wb=rotate(iq,V.Array(lv)),rotate(iq,V.Array(av));local up=rotate(iq,{0,1,0})
    local airspeed,forward=len(vb),vb[3]
    local st=v.wingState or {surfaces={},phase='parked',airTime=0,groundTime=0,deploy=0,brake=0,controls={0,0,0},height=0};v.wingState=st
    if not v.wingSurfaces then Init(v,ws,com) end
    if contact then st.groundTime=st.groundTime+dt;st.airTime=0 else st.airTime=st.airTime+dt;st.groundTime=0 end
    local hit=not contact and v.space:Raycast({p.x,p.y+v.spec.bounds.min[2]+.05,p.z},{0,-1,0},40,body,nil,false) or nil
    st.height=contact and 0 or hit and hit.dist or 40
    local throttle=clamp(cmd.throttle or 0,-1,1);local flying=not contact and st.airTime>.25
    local stallSpeed=math.sqrt(2*v.mass*9.81/(RHO*math.max(.5,v.wingArea)*1.1));st.stallSpeed=stallSpeed
    local phase
    if contact then phase=airspeed<1.5 and math.abs(throttle)<.01 and 'parked' or forward>stallSpeed*.55 and throttle>0 and 'takeoff' or 'taxi'
    elseif st.airTime<3 and vb[2]>-1 and st.height<12 then phase='climb'
    elseif throttle<0 then phase='brake'
    elseif st.height<10 and rotate(q,vb)[2]<-.8 and throttle<=0 then phase='landing'
    else phase=throttle>0 and airspeed>stallSpeed*1.8 and 'boost' or 'cruise' end
    st.phase=phase
    local lw,uw=rotate(q,{1,0,0}),rotate(q,{0,1,0});local bank=math.atan(-lw[2],uw[2])
    st.bankRate=st.bank==nil and 0 or st.bankRate+(Wrap(bank-st.bank)/math.max(dt,.001)-st.bankRate)*math.min(1,dt*12);st.bank=bank
    local steer,climb,rudder=clamp(cmd.steer or 0,-1,1),clamp(cmd.climb or 0,-1,1),clamp(cmd.strafe or 0,-1,1)
    local nose=rotate(q,{0,0,1});local nosePitch=math.asin(clamp(nose[2],-1,1))
    local liftCap=clamp(.5*RHO*26^2*v.wingLiftArea*.8/(v.mass*9.81),0,1)
    local slow=1-Smooth(stallSpeed*.8,stallSpeed*1.4,math.sqrt(vb[1]^2+vb[3]^2))
    local hover=v.flightTarget==nil and liftCap>.3 and slow*liftCap or 0;st.hover=hover
    local uPitch,uYaw,uRoll=0,0,0
    if flying then
        uRoll=clamp(Wrap(steer*1.05*(1-slow)-bank)*2.2-st.bankRate*1.2,-1,1)
        st.pitchHold=st.pitchHold or nosePitch
        if climb~=0 then st.pitchHold=clamp(st.pitchHold+climb*.9*dt*(1-slow),-1.2,1.2) else st.pitchHold=st.pitchHold-clamp(st.pitchHold,-.35*dt,.35*dt) end
        st.pathK=(st.pathK or 0)+((climb~=0 and 0 or 1)-(st.pathK or 0))*math.min(1,dt*2)
        local qa=.5*RHO*airspeed^2*v.wingLiftArea;local need=qa>1 and v.mass*9.81/qa or 1
        local levelNose=airspeed>stallSpeed and clamp((need-CAMBER)/(2*math.pi),-.12,.08)*st.pathK or 0
        local errW=Wrap(st.pitchHold+levelNose-nosePitch);local err=errW*math.cos(bank)
        local pull=steer~=0 and math.max(0,math.sin(bank*Sign(steer)))*.6*clamp(1+errW*9,0,1.6) or 0
        st.trim=clamp((st.trim or 0)+err*dt*.9,-.6,.6)
        uPitch=clamp(err*2.6+pull+st.trim+wb[1]*.8,-1,1)
        local aoa=math.atan(-vb[2],math.max(1,math.abs(vb[3])))
        if aoa>.2 then uPitch=math.min(uPitch,-(aoa-.2)*3);st.trim=math.min(st.trim,0) end
        uYaw=clamp(rudder*.9+steer*.2-wb[2]*.7,-1,1)
    else
        st.pitchHold=nosePitch
        local rotateSpeed=clamp((forward-stallSpeed*.6)/(stallSpeed*.4),0,1)
        uPitch=clamp(math.max(0,climb)*.9*rotateSpeed+wb[1]*.6,-1,1)
        uRoll=clamp(wb[3]*.5-bank*1.2,-1,1);st.trim=(st.trim or 0)*math.exp(-dt*2)
    end
    st.controls={uPitch,uYaw,uRoll};local tau={-uPitch,uYaw,-uRoll}
    local wantDeploy=({taxi=true,takeoff=true,climb=true})[phase] and .55 or phase=='landing' and .85 or 0
    st.deploy=st.deploy+clamp(wantDeploy-st.deploy,-dt*1.2,dt*1.2)
    local wantBrake=not contact and throttle<0 and -throttle or contact and throttle<0 and forward>2 and .6 or 0
    st.brake=st.brake+clamp(wantBrake-st.brake,-dt*2.5,dt*2.5)
    st.throttle=throttle;st.airspeed=airspeed;st.forward=forward
    local qRef=.5*RHO*26^2;local tx=clamp((p.y-140)/60,0,1);local thin=math.sqrt(1-tx*tx)
    local function ForceAt(fb,pb)
        local wd,r=rotate(q,fb),rotate(q,pb);if wd[2]>0 then wd[2]=wd[2]*thin end
        local force,point=V.Vec(wd),{x=p.x+r[1],y=p.y+r[2],z=p.z+r[3]}
        if response then
            body.addForce(force,true)
            body.addFlightAngularAcceleration(response:ForceAt(force,point),dt)
        else body.addForceAtPoint(force,point,true) end
    end
    local liftTotal,alphaSum,alphaW=0,0,0
    for _,w in ipairs(ws) do
        local pv=V.Add(vb,cross(wb,sub(w.pos,com)));local vn,vc=dot(pv,w.n),dot(pv,w.c);local speed2=vn*vn+vc*vc;local speed=math.sqrt(speed2)
        if speed>=.5 then
            local alpha=math.atan(vn,math.abs(vc));local qa=.5*RHO*speed2*w.area*w.lift
            local lifting=w.kind=='wing' and Sign(w.n[2]) or 0
            local camber=CAMBER*lifting*clamp(1-math.abs(alpha)/STALL_END,0,1);local flaps=.35*st.deploy*lifting
            local fn=-M.NormalCoefficient(alpha)*qa+(camber+flaps)*qa*math.min(1,math.abs(vc)/math.max(speed,1e-6))
            local drag=.035*.5*RHO*len(pv)*w.area*(1+st.deploy*.6);local arm={}
            for k=1,3 do arm[k]=com[k]+(w.pos[k]-com[k])*ARM[k] end
            ForceAt(V.Sub(V.Scale(w.n,fn),V.Scale(pv,drag)),arm)
            local lift=fn*dot(w.n,up);liftTotal=liftTotal+lift*(lift>0 and thin or 1)
            if w.kind=='wing' then alphaSum=alphaSum+math.abs(alpha)*w.area;alphaW=alphaW+w.area end
        end
    end
    st.lift=liftTotal;st.alpha=alphaW>0 and alphaSum/alphaW or 0;st.stall=flying and st.alpha>STALL
    local qNow=.5*RHO*math.max(0,forward)^2;local power=clamp(qNow/qRef,0,1);st.authority=power
    local rollPower=flying and math.max(power,.6*clamp(forward/12,0,1)) or power;local torqueB={}
    for k=1,3 do torqueB[k]=tau[k]*AUTH[k]*v.wingAuthority[k]*v.wingInertia[k]*(k==3 and rollPower or power) end
    local vane=clamp(.5*RHO*airspeed^2/qRef,0,1.5)*(airspeed>3 and 1 or 0)
    if not contact and vane>0 then
        local aoa=clamp(math.atan(-vb[2],math.max(1,math.abs(vb[3]))),-1,1);local slip=clamp(math.atan(vb[1],math.max(1,math.abs(vb[3]))),-1,1)
        torqueB[1]=torqueB[1]+aoa*VANE[1]*v.wingInertia[1]*vane
        torqueB[2]=torqueB[2]+slip*VANE[2]*v.wingAuthority[2]*v.wingInertia[2]*vane
    end
    st.vtol=0
    if hover>.01 then
        local mg=v.mass*9.81;local residual=math.max(0,mg-(support or 0)-math.max(0,liftTotal));local target=climb*7*slow
        local fy=clamp(residual*hover+v.mass*clamp((target-lv.y)*2.5,-9.81*1.1,9.81*1.1)*hover,0,mg*2*hover)
        if fy>0 then body.addForce({x=0,y=fy*thin,z=0},true);st.vtol=fy/mg end
        if not contact then
            local hp=clamp(-nosePitch*2.6+wb[1],-1,1);local hr=clamp(-bank*2.2-st.bankRate*1.2,-1,1);local hy=clamp((steer*1.3-wb[2])*1.5,-1,1)
            torqueB[1]=torqueB[1]-hp*4.5*v.wingInertia[1]*hover;torqueB[2]=torqueB[2]+hy*4.5*v.wingInertia[2]*hover;torqueB[3]=torqueB[3]-hr*4.5*v.wingInertia[3]*hover
        end
    end
    if power>.001 or vane>0 or hover>.01 then
        local torque=V.Vec(rotate(q,torqueB))
        if response then body.addFlightAngularAcceleration(response:Torque(torque),dt) else body.addTorque(torque,true) end
    end
    local schedule=clamp(qRef/math.max(qNow,qRef*.25),.45,1)
    for _,x in ipairs(v.wingSurfaces) do
        local want=0;for k=1,3 do want=want+tau[k]*x.torque[k]/v.wingLever[k] end
        want=clamp(want,-1,1)*schedule;local lifting=x.wing.kind=='wing' and Sign(x.wing.n[2]) or 0
        want=clamp(want+st.deploy*lifting*.7,-1,1);local cur=st.surfaces[x.key] or 0
        st.surfaces[x.key]=cur+clamp(want-cur,-3.2*dt,3.2*dt)
    end
    if st.brake>.01 and airspeed>1 then ForceAt(V.Scale(vb,-st.brake*.3*.5*RHO*airspeed*v.wingArea),com) end
    return {wingLift=liftTotal,wingPhase=phase,airspeed=airspeed,stallSpeed=stallSpeed,wingStall=st.stall,wingBank=bank,wingHover=hover,wingVtol=st.vtol}
end
return M
