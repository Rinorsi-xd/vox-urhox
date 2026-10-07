-- Source ground handling. Body/contacts are injected; all positions are source metres.
-- Wheel indices are Lua 1-based. Contact forces are sampled before controls each fixed tick.
local Math=require "core.Math3"
local C=Math.Clamp
local G=9.81
local M={FEEL={soft=.45,bounce=.55,steerIn=9,yawK=11,yawKFree=5,roll=.5,pitch=1,rollDamp=1},TUNING={wheelGrip=1.6,trackGrip=2.4}}
local F=M.FEEL
local function Vec(a) return {x=a[1],y=a[2],z=a[3]} end
local function Smooth(x) local k=C(x,0,1);return k*k*(3-2*k) end
local function Falloff(v,max) return max<=.01 and 0 or (v<=0 and 1 or (v>=max and 0 or 1-(v/max)^3)) end
function M.Step(vehicle,cmd,dt,frame)
    local body,vc=vehicle.body,vehicle.vc
    local mass,m=vehicle.mass,vehicle.spec.motion
    local up,fwd,vel,v,q=frame.up,frame.fwd,frame.vel,frame.speed,frame.q
    local t=cmd.throttle or 0;local drive,braking=0,false
    if t>.01 then if v<-.8 then braking=true else drive=t end
    elseif t<-.01 then if v>.8 then braking=true else drive=t end end
    local contact=0
    for i=1,#vehicle.wheels do if vc.wheelIsInContact(i) then contact=contact+1 end end
    local aStab=.5*G*vehicle.supRear/vehicle.cgH
    local aStabBrake=(vehicle.tracked and .7 or .5)*G*vehicle.supFront/vehicle.cgH
    local aDrive=math.min(10*m.accelFactor,aStab);local force=0
    if drive>0 then force=mass*aDrive*drive*Falloff(v,m.topSpeed)
    elseif drive<0 then force=mass*aDrive*drive*Falloff(-v,m.topSpeed*.45) end
    force=force*vehicle.capabilities.wheelShare
    local nW=math.max(1,#vehicle.wheels)
    local fn,fnSum={},0
    for _,w in ipairs(vehicle.wheels) do
        local f=vc.wheelIsInContact(w.index) and math.max(0,vc.wheelSuspensionForce(w.index)) or 0
        fn[#fn+1]=f;fnSum=fnSum+f
    end
    local function Share(i) return fnSum>0 and fn[i]/fnSum or (contact>0 and 1/contact or 0) end
    local lifts=false;for _,thruster in ipairs(vehicle.spec.thrusters) do if thruster.dir[2]>.7 then lifts=true end end
    local hand=cmd.handbrake==true and not vehicle.hoverMode and not lifts
    local brake=braking and mass*math.min(10,aStabBrake)*dt or (drive==0 and mass*.8*dt or 0)
    local handBrake=mass*9*dt/math.max(1,vehicle.nRear)
    vehicle.drifting=hand
    local steerScale=#vehicle.wheels>0 and not vehicle.tracked and not vehicle.hoverMode and .75 or 1
    vehicle.steer=vehicle.steer+(C(cmd.steer or 0,-1,1)*steerScale-vehicle.steer)*math.min(1,dt*F.steerIn)
    vehicle.aLong=vehicle.aLong+((v-vehicle.vPrev)/dt-vehicle.aLong)*math.min(1,dt*10);vehicle.vPrev=v
    local speed=math.abs(v);local steerAuth=.5
    for _,list in ipairs({vehicle.steerWheels,vehicle.trackWheels}) do for _,w in ipairs(list) do
        if vc.wheelIsInContact(w.index) then steerAuth=1 end
    end end
    local turning=math.abs(vehicle.steer)>.05;local skid=steerAuth<1 and turning
    for _,w in ipairs(vehicle.wheels) do
        local k=math.min(hand and w.rear and .25 or 1,skid and .3 or 1,turning and not w.steer and (w.track and .1 or .3) or 1)
        if k~=w.sideK then w.sideK=k;vc.setWheelSideFrictionStiffness(w.index,k) end
    end
    local hi=1-.25*Smooth((speed-15)/21)
    local rate=math.min(math.max(speed/vehicle.rMin,vehicle.tracked and 2.2 or 1.1),2.2*hi)*steerAuth*(vehicle.tracked and 1.75 or 1)
    local dir=v<-.5 and -1 or (v>.5 and 1 or (t<-.01 and -1 or 1))
    local wantYaw=vehicle.steer*rate*dir
    local rear=math.max(0,1-speed/10);local along=math.max(speed,2)
    for _,w in ipairs(vehicle.wheels) do
        local i=w.index;local inContact=vc.wheelIsInContact(i)
        vc.setWheelEngineForce(i,inContact and not braking and not hand and force*Share(i) or 0)
        vc.setWheelBrake(i,hand and (w.rear and handBrake or 0) or brake*(fnSum>0 and Share(i) or 1/nW))
        local dz=w.center[3]-vehicle.com[3]
        local angle=w.steer and C(math.atan(rate/steerAuth*dz/along),-w.steerAngle,w.steerAngle)*(w.rearFade and rear or 1) or 0
        vc.setWheelSteering(i,vehicle.hoverMode and 0 or vehicle.steer*angle)
    end
    local av=body.angvel();local angular={av.x,av.y,av.z}
    local yawRate=Math.Dot(angular,up);local grip=contact/nW
    vehicle.aLat=vehicle.aLat+(C(v*yawRate,-6.5*G,6.5*G)-vehicle.aLat)*math.min(1,dt*8)
    local steeringAssist=0
    if not vehicle.hoverMode and not vehicle.legMode and contact>0 then
        local kYaw=math.abs(vehicle.steer)>.02 and F.yawK or F.yawKFree
        local target=hand and wantYaw*1.8 or wantYaw
        local tq=C(vehicle.inertiaY*kYaw*(target-yawRate),-vehicle.inertiaY*30,vehicle.inertiaY*30)*grip*(hand and .5 or 1)
        steeringAssist=tq;body.addTorque(Vec(Math.Scale(up,tq)),true)
        local left=Math.Rotate(q,{1,0,0});local vs=Math.Dot(vel,left)
        local aMax=6.5*G*grip*(hand and .15 or 1)
        local a=C(-vs*10,-aMax,aMax);local forceSide=Math.Scale(left,mass*a)
        local sp=math.sqrt(vel[1]^2+vel[3]^2)
        if sp>3 and not hand then
            local beta=math.atan(math.abs(vs),math.abs(v));local keep=1-Smooth((beta-.25)/.35)
            local against=(forceSide[1]*vel[1]+forceSide[3]*vel[3])/sp
            if against<0 and keep>0 then
                forceSide[1]=forceSide[1]-vel[1]/sp*against*keep;forceSide[3]=forceSide[3]-vel[3]/sp*against*keep
            end
        end
        body.addForce(Vec(forceSide),true)
        local rollMax=.7*mass*G*vehicle.halfTrack*grip
        local arm=vehicle.aLong>=0 and vehicle.supRear or vehicle.supFront
        local pitchMax=math.min(.25*mass*G*arm,math.max(0,.65*mass*G*arm-vehicle.cgH*mass*math.abs(vehicle.aLong)))*grip
        local tRoll=C(vehicle.cgH*mass*vehicle.aLat*F.roll,-rollMax,rollMax)*math.min(1,vehicle.halfTrack/vehicle.cgH)
        local tPitch=C(-vehicle.cgH*mass*vehicle.aLong*F.pitch,-pitchMax,pitchMax)
        body.addTorque(Vec(Math.Add(Math.Scale(fwd,tRoll),Math.Scale(left,tPitch))),true)
    end
    if contact>0 then
        local rollRate=Math.Dot(angular,fwd)
        body.addTorque(Vec(Math.Scale(fwd,-vehicle.inertiaY*.6*F.rollDamp*rollRate*contact/nW)),true)
        local tall=math.max(0,vehicle.cgH/math.min(vehicle.supFront,vehicle.supRear)-.4)
        if tall>0 then
            local side=Math.Rotate(q,{1,0,0});local pitchRate=Math.Dot(angular,side)
            body.addTorque(Vec(Math.Scale(side,-vehicle.inertiaY*1.5*tall*pitchRate*contact/nW)),true)
        end
    end
    for _,w in ipairs(vehicle.wheels) do
        local length=vc.wheelSuspensionLength(w.index);local rate=((w.lenPrev or length)-length)/dt;w.lenPrev=length
        if vc.wheelIsInContact(w.index) then
            local x=math.min(1,(1-length/w.rest-.7)/.25)
            if x>0 then
                local f=math.max(0,mass*w.share*(G*5*x*x+12*rate*x))
                body.addForceAtPoint(Vec(Math.Scale(up,f)),vc.wheelHardPoint(w.index),true)
            end
        end
    end
    local support,groundDrive,groundBrake=0,0,0;vehicle.contactStates={}
    for _,w in ipairs(vehicle.wheels) do
        local grounded=vc.wheelIsInContact(w.index)
        local normalLoad=grounded and math.max(0,vc.wheelSuspensionForce(w.index)) or 0
        local normal=vc.wheelContactNormal(w.index)
        support=support+normalLoad*math.max(0,normal and normal.y or 0)
        local state={partId=w.partId,index=w.index,grounded=grounded,normalLoad=normalLoad,engine=vc.wheelEngineForce(w.index),brake=grounded and vc.wheelBrake(w.index)/dt or 0}
        vehicle.contactStates[#vehicle.contactStates+1]=state;groundDrive=groundDrive+state.engine;groundBrake=groundBrake+state.brake
    end
    return {contact=contact,wheels=#vehicle.wheels,wheelSupport=support,wheelAuthority=math.min(vehicle.capabilities.wheelShare,support/(mass*G)),
        groundDrive=groundDrive,groundBrake=groundBrake,steeringTarget=wantYaw,steeringRateLimit=rate,steeringAssist=steeringAssist}
end
return M
