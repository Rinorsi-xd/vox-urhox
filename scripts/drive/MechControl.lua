-- Frozen 2026-10-14 mechControl.js. One chassis, world-vertical support rays.
-- mount + UP*.3 -> down to 1.45*standHeight; only fixed terrain, no sensors.
-- A leg farther than 1.12*height cannot support. Planted feet supply the load;
-- swing sensors only receive bullets. Two legs alternate, four use diagonals.
local V=require('core.Math3')
local Rot=require('core.Rotations')
local IK=require('parts.MechIK')
local Gait=require('drive.MechGait')
local CELL=require('Config').CELL
local add,sub,mul,dot,cross,len,norm=V.Add,V.Sub,V.Scale,V.Dot,V.Cross,V.Length,V.Normalize
local clamp,reject,rotate,arr,vec=V.Clamp,V.Reject,V.RotateUnit,V.Array,V.Vec
local UP={0,1,0};local G=9.81;local DEG=math.pi/180
local M={};M.__index=M
local KEEP={'phase','groundedTime','airTime','cooldown','jumpHeld','jumpBuffer','jetFuel','jetBurst','boostFuel','boostRest','boosting','offGround','wasAir','fallSpeed','landing','longJump','aPrev','leanF','leanR','sway','nod','stun','stance','groundRate','groundAcc','slopeTan','slopeF','groundRef'}
local function Smooth(a,b,x) local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t) end
local function Sum(list,fn) local v=0;for _,s in ipairs(list) do v=v+fn(s) end;return v end
function M.New(v)
    local self=setmetatable({v=v,states={},list={},footfalls={}},M);local sides={{},{},{}};local n=0;local com=v.com or {0,0,0}
    for _,l in ipairs(v.spec.mechLegs or {}) do if l.works then local side=math.abs(l.pos[1]-com[1])<.3 and 2 or l.pos[1]<com[1] and 1 or 3;sides[side][#sides[side]+1]=l;n=n+1 end end
    for si,group in ipairs(sides) do
        table.sort(group,function(a,b) return a.pos[3]>b.pos[3] end)
        for i,l in ipairs(group) do local s={leg=l,offset=n>1 and (((i-1)+(si-1)/2)%2)*.5 or 0,info=IK.Data(l.type)};self.states[l.partId]=s;self.list[#self.list+1]=s end
    end
    self.loadAll=Sum(self.list,function(s) return s.leg.load end);local weight=self.loadAll>0 and self.loadAll or 1
    self.standAvg=Sum(self.list,function(s) return s.leg.standHeight*s.leg.load end)/weight
    self.jetMax=Sum(self.list,function(s) return s.leg.jet*s.leg.load end)/weight;self.boostMax=self.jetMax>0 and 2.5+2*self.jetMax or 0
    local inertia=0
    for _,list in ipairs({v.spec.boxes or {},v.spec.hulls or {}}) do for _,b in ipairs(list) do inertia=inertia+b.mass*((b.center[2]-com[2])^2+.5*((b.center[1]-com[1])^2+(b.center[3]-com[3])^2)) end end
    self.inertiaPR=math.max(inertia,(v.mass or 100)*.5);self.sinkCap=.3;self.extCap=.3
    for _,s in ipairs(self.list) do self.sinkCap=math.min(self.sinkCap,IK.SinkCapacity(s.leg.type));self.extCap=math.min(self.extCap,IK.ExtendCapacity(s.leg.type)) end
    self.heft=clamp((v.mass or 100)/math.max(1,self.loadAll),.2,1.5);self:Reset();return self
end
function M:Reset()
    for _,s in ipairs(self.list) do
        s.foot=nil;s.previous=nil;s.grounded=false;s.swing=nil;s.ground=nil;s.normal={0,1,0};s.pitch=0;s.toe=0;s.yaw=0;s.vane=0;s.jet=0;s.pulse=0;s.support=nil;s.force=0;s.target=nil;s.soleLift=0;s.lift=nil;s.airRel=nil
    end
    self.phase=0;self.groundedTime=0;self.offGround=0;self.airTime=0;self.cooldown=0;self.jumpHeld=false;self.jumpBuffer=0
    self.jetFuel=self.jetMax;self.jetBurst=0;self.boostFuel=self.boostMax;self.boostRest=0;self.boosting=false;self.yaw=0;self.wasAir=false;self.fallSpeed=0;self.landing=0;self.longJump=false
    self.aPrev=nil;self.leanF=0;self.leanR=0;self.sway=0;self.nod=0;self.stun=0;self.impulse=0;self.launch=0;self.brake=0;self.stance=1;self.timing=nil
    self.groundRate=0;self.groundAcc=0;self.slopeTan=0;self.slopeF=0;self.groundRef=nil;self.airGait=false;self.lead=nil
end
function M:Snapshot()
    local out={states={}};for _,k in ipairs(KEEP) do out[k]=self[k] end
    for _,s in ipairs(self.list) do local saved={};for _,k in ipairs({'foot','previous','grounded','swing','ground','yaw'}) do saved[k]=s[k] end;out.states[#out.states+1]={s.leg.partId,saved} end;return out
end
function M:Restore(data)
    if not data then return end;for _,k in ipairs(KEEP) do if data[k]~=nil then self[k]=data[k] end end
    self.jetFuel=math.min(self.jetFuel,self.jetMax);self.boostFuel=math.min(self.boostFuel,self.boostMax)
    for _,row in ipairs(data.states or {}) do local s=self.states[row[1]];if s then for k,value in pairs(row[2]) do s[k]=value end end end
end
function M:Cast(p,dir,distance)
    local h=self.v.space:Raycast(p,dir,distance,self.v.body,nil,true,require('drive.TerrainObstacles').SUPPORT_MASK)
    return h and {point=h.point,normal=h.normal,distance=h.dist,collider=h.collider} or nil
end
function M:OffPlane(f,r) if math.sqrt(f*f+r*r)<1e-4 then return 0 end;return math.max(0,math.atan(math.abs(r),math.abs(f))-math.pi/6) end
function M:Squat() return clamp(-self.leanF/.09,0,1) end
function M:Footfall(strength,pos,kind)
    self.footfalls[#self.footfalls+1]={strength=strength,pos={pos[1],pos[2],pos[3]},kind=kind,landing=kind=='land'};if #self.footfalls>8 then table.remove(self.footfalls,1) end
end
function M:Local(s,world,q,p)
    local delta=mul(sub(rotate(V.Inverse(q),sub(world,p)),s.leg.origin),1/CELL);local out={}
    for i,axis in ipairs({{1,0,0},{0,1,0},{0,0,1}}) do out[i]=dot(delta,Rot.ApplyRot(s.leg.rot,axis)) end;return out
end
function M:World(s,point,q,p) return add(p,rotate(q,add(s.leg.origin,mul(Rot.ApplyRot(s.leg.rot,point),CELL)))) end
function M:LegForward(s,q) return rotate(q,Rot.ApplyRot(s.leg.rot,{math.sin(s.yaw),0,math.cos(s.yaw)})) end
function M:Pose(s,target)
    local t=target or s.target or s.info.joints.toe
    return IK.Solve(s.leg.type,s.lift and s.target and not target and add(t,s.lift) or t,s.pitch,s.toe,s.yaw)
end
function M:SharedYaw(cmd,dt)
    local x,z=(cmd.strafe or 0)*.9,cmd.throttle or 0;local want=0
    local function Wrap(a) return a-2*math.pi*math.floor(a/(2*math.pi)+.5) end
    if math.abs(x)>.05 then
        local a=math.atan(-x,z);want=a
        for _,c in ipairs({a-math.pi,a+math.pi}) do if math.abs(Wrap(c-self.yaw))<math.abs(Wrap(want-self.yaw)) then want=c end end
        want=clamp(Wrap(want),-math.pi/6,math.pi/6)
    end;self.yaw=self.yaw+clamp(want-self.yaw,-5*dt,5*dt)
end
function M:Timing(speed,spin,ratio,lat)
    lat=lat or 0;local scale=math.sqrt(self.standAvg/8.5);local r=math.min(1,ratio);local ts=(.6+.06*r)*scale*(self.boosting and 1.08 or 1)*(1-.3*lat)
    if math.abs(spin)>.3 and r<.5 then ts=math.min(ts,math.max(.3*scale,(#self.list==2 and .78 or .55)/math.abs(spin))) end
    local reach=(.55-.43*lat*lat)*self.standAvg;local tan=math.max(0,self.slopeF-.12)
    if tan>1e-3 then local old=reach;reach=math.min(reach,math.max(.3*self.standAvg,.85*(self.sinkCap+self.extCap)*self.standAvg/tan));if reach<old then ts=math.min(ts,math.max(.8*ts,reach/math.max(speed,.5)/.6)) end end
    local stance=clamp(reach/math.max(speed,.5),.15,1.3*ts);return {Ts=ts,ts=stance,cycle=2*ts,duty=stance/(2*ts),tf=math.max(0,ts-stance)}
end
function M:Step(cmd,dt,contactSupport)
    local v=self.v;local body=v.body;local legs=self.list;local n=#legs;local mass=v.mass
    local q,p,vel,w=body.rotation(),arr(body.translation()),arr(body.linvel()),arr(body.angvel())
    local function World(point) return add(p,rotate(q,point)) end
    local up,fwd,right=rotate(q,UP),rotate(q,{0,0,1}),rotate(q,{1,0,0})
    self.cooldown=math.max(0,self.cooldown-dt);self.noLaunch=math.max(0,(self.noLaunch or 0)-dt);self.resync=math.max(0,(self.resync or 0)-dt);self.earlyCool=math.max(0,(self.earlyCool or 0)-dt);self.airTime=math.max(0,self.airTime-dt)
    local jump=cmd.jump==true and not self.jumpHeld;self.jumpHeld=cmd.jump==true;self.jumpBuffer=jump and .25 or math.max(0,self.jumpBuffer-dt)
    local caps=v.capabilities;local loadRatio=mass/math.max(1,caps.totalLoad or self.loadAll);local sup={}
    for _,s in ipairs(legs) do
        local l=s.leg;local mount=World(l.mount);local h=self.airTime<=0 and self:Cast(add(mount,mul(UP,.3)),{0,-1,0},.3+l.standHeight*1.45) or nil
        s.support=nil;if h and h.normal[2]>.45 and h.distance-.3<l.standHeight*1.12 then h.d=h.distance-.3;h.mount=mount;s.support=h;sup[#sup+1]=s end
    end
    local supported=#sup>0
    if supported then self.groundedTime=self.groundedTime+dt;self.offGround=0 else self.offGround=self.offGround+dt;if self.offGround>.12 then self.groundedTime=0 end end
    local normal={0,0,0};for _,s in ipairs(sup) do normal=add(normal,s.support.normal) end;normal=supported and norm(normal) or {0,1,0}
    local vt=reject(vel,normal);local planar=len(vt);local rate=0
    if supported then
        local point={0,0,0};for _,s in ipairs(sup) do point=add(point,s.support.point) end;self.groundRef={point=mul(point,1/#sup),normal=normal}
        local speed=len(reject(vel,UP));rate=clamp(-(normal[1]*vel[1]+normal[3]*vel[3])/math.max(.5,normal[2]),-speed*1.2,speed*1.2)
    else self.groundRef=nil end
    local oldRate=self.groundRate;self.groundRate=self.groundRate+(rate-self.groundRate)*(1-math.exp(-dt*(supported and 6 or 2)))
    self.groundAcc=supported and clamp((self.groundRate-oldRate)/dt,-2*G,2*G) or 0
    self.slopeTan=supported and math.sqrt(math.max(0,1-normal[2]^2))/math.max(.5,normal[2]) or self.slopeTan*math.exp(-dt*2)
    self.slopeF=self.slopeF+(clamp(math.abs(self.groundRate)/math.max(planar,.5),0,1.5)-self.slopeF)*(1-math.exp(-dt*3))
    local total,speedLoad=0,0
    local function Mover(l) if l.works~=false then total=total+l.load;speedLoad=speedLoad+l.load*l.speed end end
    for _,s in ipairs(legs) do Mover(s.leg) end
    for _,list in ipairs({v.spec.wheels or {},v.spec.hovers or {},v.spec.legs or {}}) do for _,l in ipairs(list) do Mover(l) end end
    local baseSpeed=speedLoad/math.max(1,total);local factor=loadRatio>2 and 0 or clamp(1.25-.5*loadRatio,0,1);local degrade=n==0 and 0 or n==1 and .35 or 1
    local top=math.min(v.spec.motion.topSpeed or baseSpeed,baseSpeed*factor)*degrade
    self.boostRest=math.max(0,self.boostRest-dt);self.boosting=self.boostMax>0 and cmd.boost==true and (cmd.throttle or 0)>.1 and self.boostFuel>0 and self.offGround<.12 and supported
    if self.boosting then self.boostFuel=math.max(0,self.boostFuel-dt);self.boostRest=.6 elseif self.boostRest==0 then self.boostFuel=math.min(self.boostMax,self.boostFuel+dt*.45) end
    local topRun=top*(self.boosting and 1.3 or 1);local ratio=top>.5 and clamp(planar/top,0,1.2) or 0
    if supported and self.wasAir then
        self.landing=clamp(self.fallSpeed/9,0,1);if self.fallSpeed>5 and self.jetMax>0 then self.jetBurst=math.max(self.jetBurst,.22) end
        if vel[2]<-2 then body.applyImpulse(vec({0,mass*(-2-vel[2])*.85,0}),true) end
        self.stun=math.max(self.stun,clamp((self.fallSpeed-3)/10,0,1)*((cmd.throttle or 0)>.1 and .18 or .35))
        self:Footfall(clamp(self.fallSpeed/10,.25,1)*(.7+.3*math.min(1,self.heft)),p,'land')
        for _,s in ipairs(legs) do s.pulse=math.max(s.pulse,.6+.4*self.landing) end;self.longJump=false
    end
    self.wasAir=not supported;if not supported then self.fallSpeed=math.max(0,-vel[2]) end;self.landing=math.max(0,self.landing-dt*1.8)
    local supLoad=Sum(sup,function(s) return s.leg.load end);local massShare=math.max(0,mass-(contactSupport or 0)/G)
    local gaitOn=n>=2 and self.groundedTime>.2 and self.cooldown<.4;local stance={};for _,s in ipairs(sup) do if not gaitOn or s.grounded or not s.swing then stance[#stance+1]=s end end
    local stanceLoad=Sum(stance,function(s) return s.leg.load end)
    local lat=planar>.5 and math.sin(self:OffPlane(dot(vt,norm(reject(fwd,UP))),dot(vt,norm(reject(right,UP)))))/math.sin(math.pi/3) or 0
    local tm=self:Timing(planar,dot(w,UP),ratio,lat);self.timing=tm;local footDown=gaitOn and clamp(tm.ts/tm.Ts,.25,1) or 1
    self.stance=self.stance+((#stance>0 and 1 or 0)-self.stance)*(1-math.exp(-dt*25))
    local horizontal=reject(vel,UP);local speed=len(horizontal)
    if self.impulse>0 and supported then
        local brake=speed>.5 and mul(horizontal,-math.min(.07*self.brake,1.6/speed)) or {0,0,0}
        body.applyImpulse(vec(mul(add({0,-self.impulse,0},brake),mass)),true)
        body.applyTorqueImpulse(vec(mul(cross(UP,norm(reject(fwd,UP))),self.inertiaPR*(.07*self.impulse+.06*self.brake))),true);self.nod=math.max(self.nod,self.impulse)
    end
    if self.launch>0 and supported and self.cooldown==0 then
        local fix=0
        if self.slopeTan>.02 then local drop=math.min(.85*self.sinkCap,.07*math.min(1,ratio));local mid=(self.sinkCap-self.extCap)/2
            local want=self.standAvg*(1-(drop+(mid-drop)*clamp(self.slopeTan/.36,0,1)*.8));local err=want-Sum(sup,function(s) return s.support.d end)/#sup
            fix=clamp(err,-.15*self.standAvg,.15*self.standAvg)/math.max(self.launch,.2)*clamp(self.slopeTan/.1,0,1);fix=math.max(fix,-G*self.launch/2)
        end
        local rise=self.groundRate;local gr=self.groundRef
        if gr then local vh=reject(vel,UP);local ahead=add(p,mul(vh,self.launch));local nn=gr.normal;local h=self:Cast({ahead[1],p[2]+self.standAvg,ahead[3]},{0,-1,0},self.standAvg*3)
            local plane=gr.point[2]-(nn[1]*(ahead[1]-gr.point[1])+nn[3]*(ahead[3]-gr.point[3]))/math.max(.5,nn[2])
            if h and h.normal[2]>.45 then rise=rise+clamp((h.point[2]-plane)/math.max(self.launch,.2),-len(vh),len(vh)) end
        end
        local target=G*self.launch/2+rise+fix;if vel[2]<target then body.applyImpulse(vec({0,mass*(target-vel[2]),0}),true) end
        if self.jetMax>0 then self.jetBurst=math.max(self.jetBurst,.16) end
    end
    self.impulse=0;self.launch=0;self.brake=0;local vertical=0;local com=World(v.com or {0,0,0});local lo,hi=math.huge,-math.huge
    for _,s in ipairs(legs) do s.force=0 end;for _,s in ipairs(sup) do lo=math.min(lo,s.support.point[2]);hi=math.max(hi,s.support.point[2]) end
    local spread=#sup>1 and (hi-lo)/2/self.standAvg or 0
    for _,s in ipairs(stance) do
        local mount=s.support.mount;local at=add(mount,mul(right,dot(sub(com,mount),right)));local l=s.leg;local distance=s.support.d+(at[2]-mount[2])
        local drop=math.min(.85*self.sinkCap,.07*math.min(1,ratio)+.2*self.landing+.04*self:Squat());if self.kneel then drop=math.max(drop,self.kneel*self.sinkCap) end
        local mid=(self.sinkCap-self.extCap)/2;drop=drop+(mid-drop)*clamp(self.slopeTan/.36,0,1)*.8;drop=math.min(drop,math.max(.7*self.sinkCap-spread,-.6*self.extCap))
        local x=l.standHeight*(1-drop)-distance;local share=l.load/stanceLoad;local mi=mass*l.load/supLoad;local wn=2*math.pi*1.3;local k,c=mi*wn*wn,mi*wn
        local pv=arr(body.velocityAtPoint(vec(at)))[2]-self.groundRate;local carry=supLoad/stanceLoad
        local force=clamp(massShare*share*(G+self.groundAcc)+(k*x-c*pv)*carry,0,math.max(l.load,massShare*share)*G*4)
        body.addForceAtPoint(vec({0,force,0}),vec(at),true);s.force=force;vertical=vertical+force
    end
    local acc=self.aPrev and mul(sub(vel,self.aPrev),1/dt) or {0,0,0};self.aPrev=vel;local fh,rh=norm(reject(fwd,UP)),norm(reject(right,UP));local k=1-math.exp(-dt*6)
    self.leanF=self.leanF+(clamp(dot(acc,fh)/G*.36,-.1,.055)+.028*math.min(1,ratio)-self.leanF)*k
    self.leanR=self.leanR+(clamp(dot(acc,rh)/G*.3,-.08,.08)-self.leanR)*k
    local sway=0;if gaitOn and n==2 then local on={};for _,s in ipairs(legs) do if s.grounded then on[#on+1]=s end end;if #on==1 then local d=(v.com and v.com[1] or 0)-on[1].leg.pos[1];sway=d>0 and 1 or d<0 and -1 or 0 end end
    self.sway=self.sway+(sway*clamp(planar/4,.15,1)-self.sway)*(1-math.exp(-dt*10));self.nod=math.max(0,self.nod-dt*2.5)
    local swayAmount=(.085-.035*math.min(1,ratio))*(.8+.2*math.min(1,self.heft));local want=norm(add(UP,add(mul(fh,self.leanF),mul(rh,self.leanR-swayAmount*self.sway))));local tilt=cross(up,want)
    local share=supported and clamp(supLoad/math.max(1,self.loadAll),.3,1) or .35;local wa=2*math.pi*.85
    local torque=mul(sub(mul(tilt,self.inertiaPR*wa*wa),mul(reject(w,up),self.inertiaPR*2*.62*wa)),share)
    if supported and self.sway~=0 then torque=add(torque,mul(cross(UP,mul(rh,-self.sway)),mass*G*(.13-.06*math.min(1,ratio)))) end
    local limit=mass*G*self.standAvg*.5;if len(torque)>limit then torque=mul(norm(torque),limit) end;body.addTorque(vec(torque),true)
    local tf,tr=norm(reject(fwd,normal)),norm(reject(right,normal));local fIn,sIn=cmd.throttle or 0,(cmd.strafe or 0)*.9;local inputLen=math.sqrt(fIn*fIn+sIn*sIn)
    if inputLen>1 then fIn=fIn/inputLen;sIn=sIn/inputLen end
    local input=add(mul(tf,fIn),mul(tr,sIn));local moving=len(input)>.1;local off=self:OffPlane(fIn,sIn);local cap=off>.01 and self.standAvg*math.sin(math.pi/3)/math.sin(off) or math.huge
    local desired=mul(input,math.min(len(input)*topRun,cap)/math.max(len(input),1e-6))
    self.stun=math.max(0,self.stun-dt);local plant=gaitOn and .25+.75*self.stance or 1;local recover=1-.75*clamp(self.stun/.35,0,1)
    local upright=1-Smooth(math.cos(15*DEG),math.cos(35*DEG),up[2]);local authority=supported and clamp(supLoad/math.max(1,mass*.5),0,1)*clamp((caps.mechShare or 1)+.001,0,1)*plant*recover*upright or 0
    local yawRate,steer=dot(w,up),cmd.steer or 0
    if authority>0 then
        local gravity=reject({0,-G,0},normal);local force=mul(sub(desired,vt),mass*(moving and 4.5 or 6)*authority/footDown)
        if v.driveJets==nil then v.driveJets=false;for _,t in ipairs(v.spec.thrusters or {}) do if math.abs(t.dir[2])<.7 then v.driveJets=true end end end
        if moving and v.driveJets then local direction=norm(desired);local over=dot(force,direction);if over<0 and dot(vt,direction)>len(desired) then force=sub(force,mul(direction,over)) end end
        force=sub(force,mul(gravity,mass*authority));local max=(moving and (self.boosting and 20 or 15) or 18)*authority/footDown+len(gravity)
        if len(force)>mass*max then force=mul(norm(force),mass*max) end;body.addForce(vec(force),true)
        local chunk=gaitOn and clamp(1-ratio/.35,0,1)*(n==2 and 1 or 0) or 0;local pulse=1-chunk+chunk*2*math.sin(math.pi*((self.phase*2)%1))^2
        local target=steer*(2.4+.25*chunk-.9*math.min(1,ratio))*degrade*pulse;local targetSign=target>0 and 1 or target<0 and -1 or 0;local yawSign=yawRate>0 and 1 or yawRate<0 and -1 or 0
        local gain=chunk>.3 and 14 or (math.abs(target)>math.abs(yawRate) or targetSign~=yawSign) and 5/math.sqrt(self.heft+.4) or 3.2/math.sqrt(self.heft+.4)
        local maxTorque=v.inertiaY*(chunk>.3 and 30 or 8)
        body.addTorque(vec(mul(up,clamp(v.inertiaY*gain*(target-yawRate),-maxTorque,maxTorque)*math.max(authority,supported and .35*recover or 0))),true)
    elseif not supported then
        local vh=reject(vel,UP);local force=mul(sub(mul(input,math.max(top,len(vh))),vh),mass*.6);if len(force)>mass*2.5 then force=mul(norm(force),mass*2.5) end
        if moving then body.addForce(vec(force),true) end;body.addTorque(vec(mul(up,clamp(v.inertiaY*3*(steer-yawRate),-v.inertiaY*3,v.inertiaY*3))),true)
    end
    local jumped=false;local canJump=n>=1 and #sup>=math.max(1,math.ceil(n/2)) and self.groundedTime>=.12 and self.cooldown==0
    if self.jumpBuffer>0 and canJump then
        local height=Sum(legs,function(s) return s.leg.jumpHeight*s.leg.load end)/math.max(1,self.loadAll);local speedUp=math.sqrt(2*G*height)/math.max(1,loadRatio);local dv={0,speedUp-body.linvel().y,0}
        body.setAngvel(vec(add(mul(UP,dot(w,UP)),mul(reject(w,UP),.25))),true);self.sway=0;self.nod=0;self.longJump=ratio>.55
        if self.longJump then dv=add(dv,mul(norm(reject(vel,UP)),math.min(4,.14*planar))) end
        body.applyImpulse(vec(mul(dv,mass)),true);self.cooldown=.75;self.airTime=.3;self.groundedTime=0;self.jumpBuffer=0;jumped=true;self.jetFuel=self.jetMax
        if self.jetMax>0 then self.jetBurst=.32 end;for _,s in ipairs(legs) do s.grounded=false;s.swing=nil end
    end
    local jetOut,jetLift=0,0
    if not supported and not jumped and cmd.jump and self.jetFuel>0 and self.offGround>.12 then
        local thrust=mul(add(mul(UP,(vel[2]>0 and .3 or .85)*G),moving and mul(norm(reject(input,UP)),.3*G) or {0,0,0}),mass)
        body.addForce(vec(thrust),true);jetLift=thrust[2];self.jetFuel=math.max(0,self.jetFuel-dt);jetOut=1
    end
    if supported and not jumped then self.jetFuel=math.min(self.jetMax,self.jetFuel+dt*.8) end;self.jetBurst=math.max(0,self.jetBurst-dt)
    local cruise=supported and not self.boosting and .22*clamp((ratio-.5)/.4,0,1) or 0;local jetFx=math.max(jetOut,self.jetBurst>0 and 1 or 0,self.boosting and 1 or 0,cruise)
    Gait.Step(self,dt,{q=q,p=p,vel=vel,w=w,supported=supported and not jumped,ratio=ratio,cmd=cmd})
    local contacts=0
    for _,s in ipairs(legs) do
        s.jet=s.jet+((s.leg.jet>0 and jetFx or 0)-s.jet)*(1-math.exp(-dt*20));s.pulse=math.max(0,s.pulse-dt*2.5);s.target=s.foot and self:Local(s,s.foot,q,p) or nil
        s.lift=s.foot and s.soleLift~=0 and sub(self:Local(s,add(s.foot,{0,s.soleLift,0}),q,p),s.target) or nil;if s.grounded then contacts=contacts+1 end
    end
    return {legCount=n,mechLegs=n,legAvailable=#sup,legAvailableLoad=supLoad,legContacts=jumped and 0 or contacts,legMode=v.legMode,legJumpReady=canJump,legCooldown=self.cooldown,legGroundedTime=self.groundedTime,
        legVerticalSupport=vertical,legAuthority=authority,legSpeedLimit=top,legJumped=jumped,legGrip=false,legClimbing=false,legCresting=false,legWallPending=false,
        legHeight=#sup>0 and Sum(sup,function(s) return s.support.d end)/#sup or nil,mechJetFuel=self.jetMax>0 and self.jetFuel/self.jetMax or nil,mechJet=jetFx>.5,mechLongJump=self.longJump,
        mechBoostFuel=self.boostMax>0 and self.boostFuel/self.boostMax or nil,mechBoost=self.boosting,boosting=self.boosting,mechJetLift=jetLift}
end
return M
