-- Port of source legControl.js (2026-10-05): one chassis, independent support,
-- predictive display gait and articulated hit volumes. Distances are metres.
-- Collision design: mount + normal*.25 -> -normal ray, length .25+1.7*height.
-- Static terrain only; never grip cars/debris/sensors. >=4 usable, non-overloaded
-- legs can grip walls. Fewer legs/overload use <=40 degree slopes. Missing-side
-- support must create real torque, not a pose correction. Jump suppresses rays
-- for .35 s, then casts toward nearby terrain for landing/wall attachment.
local V=require "core.Math3"
local Rot=require "core.Rotations"
local Assets=require "parts.PartAssets"
local IK=require "parts.LegIK"
local Gait=require "drive.LegGait"
local CELL=require("Config").CELL
local add,sub,mul,dot,cross,length,norm=V.Add,V.Sub,V.Scale,V.Dot,V.Cross,V.Length,V.Normalize
local clamp,mix,reject,rotate,arr,vec=V.Clamp,V.Mix,V.Reject,V.RotateUnit,V.Array,V.Vec
local M={};M.__index=M
local UP={0,1,0};local G=9.81;local DEG=math.pi/180;local GRIP=math.cos(40*DEG);local WALL=math.cos(50*DEG)
local targetAxes={}
for rot=0,23 do targetAxes[rot]={Rot.ApplyRot(rot,{1,0,0}),Rot.ApplyRot(rot,{0,1,0}),Rot.ApplyRot(rot,{0,0,1})} end
local function Turn(a,b,t) return norm(mix(a,dot(a,b)<-.95 and add(b,{.01,.01,.01}) or b,t)) end
local function Cone(n,c)
    if dot(n,UP)>=c then return n end
    local h=reject(n,UP);return norm(add(mul(UP,c),mul(h,math.sqrt(1-c*c)/math.max(1e-12,length(h)))))
end
function M.New(v)
    local self=setmetatable({v=v,states={},list={},info={}},M);local sides,order={},{}
    self.ikScope=setmetatable({},{__close=function() self.ikCache=nil end})
    for _,l in ipairs(v.spec.legs) do if l.works then
        local key=table.concat(l.out,',');if not sides[key] then sides[key]={};order[#order+1]=key end
        table.insert(sides[key],l);self.info[l.type]=Assets.Get(l.type,l.rot).segments.info
    end end
    for si,key in ipairs(order) do
        local group=sides[key];table.sort(group,function(a,b)
            if a.pos[3]~=b.pos[3] then return a.pos[3]<b.pos[3] end
            if a.pos[1]~=b.pos[1] then return a.pos[1]<b.pos[1] end
            return a.pos[2]<b.pos[2]
        end)
        for i,l in ipairs(group) do
            local s={leg=l,group=(i+si-2)%2,jumpGlow=0};self.states[l.partId]=s;self.list[#self.list+1]=s
        end
    end
    self.loadAll=0;self.reachAvg=0;self.heightAvg=0;self.stepHeight=0
    for _,s in ipairs(self.list) do
        local l=s.leg;self.loadAll=self.loadAll+l.load;self.reachAvg=self.reachAvg+l.reach*l.load
        self.heightAvg=self.heightAvg+l.height*l.load;self.stepHeight=self.stepHeight+(l.stepHeight or 1)*l.load
    end
    local weight=math.max(1,self.loadAll);self.reachAvg=self.reachAvg/weight;self.heightAvg=self.heightAvg/weight;self.stepHeight=self.stepHeight/weight
    local ip=0;local c=v.com
    for _,list in ipairs({v.spec.boxes,v.spec.hulls}) do for _,b in ipairs(list) do
        ip=ip+b.mass*((b.center[2]-c[2])^2+.5*((b.center[1]-c[1])^2+(b.center[3]-c[3])^2))
    end end
    self.inertiaPR=math.max(ip,v.mass*.5);Gait.Setup(self);self:Reset();return self
end
function M:Cast(p,d,distance)
    local h=self.v.space:Raycast(p,d,distance,self.v.body,nil,true,require('drive.TerrainObstacles').SUPPORT_MASK)
    return h and {point=h.point,normal=h.normal,distance=h.dist,collider=h.collider} or nil
end
function M:Reset()
    for _,s in ipairs(self.list) do
        s.foot=nil;s.previous=nil;s.grounded=false;s.swing=nil;s.contact=nil;s.target=nil;s.bladeAngle=0
        s.available=false;s.force=0;s.support=nil;s.lastGround=nil;s.jumpGlow=0
    end
    self.surf={0,1,0};self.normal=self.surf;self.climbing=false;self.edge=false;self.wallAhead=false
    self.groundedTime=0;self.cooldown=0;self.airTime=0;self.jumpHeld=false;self.jumpBuffer=0;self.wallMemo=nil
    Gait.Reset(self)
end
local STATE={'surf','groundedTime','cooldown','airTime','jumpHeld','jumpBuffer','phase','phaseAcc','cadence','settle'}
function M:Snapshot()
    local out={states={}};for _,k in ipairs(STATE) do out[k]=self[k] end
    for _,s in ipairs(self.list) do
        local t={};for _,k in ipairs({'foot','previous','grounded','swing','contact','mode','sw','cycle'}) do t[k]=s[k] end
        out.states[#out.states+1]={s.leg.partId,t}
    end
    return out
end
function M:Restore(data)
    if not data then return end
    for _,k in ipairs(STATE) do if data[k]~=nil then self[k]=data[k] end end;self.normal=self.surf
    for _,entry in ipairs(data.states or {}) do local s=self.states[entry[1]];if s then for k,value in pairs(entry[2]) do s[k]=value end end end
end
function M:IsStep(h,surf,input,ground)
    local lift=math.min(self.stepHeight,self.heightAvg*.6);local above=dot(sub(h.point,ground),surf)
    local top=self:Cast(add(add(h.point,mul(surf,lift-above)),mul(input,.3)),mul(surf,-1),lift)
    return top~=nil and top.distance>.02 and dot(top.normal,surf)>.8
end
function M:Target(s,foot,q,p)
    local delta=mul(sub(rotate(V.Inverse(q),sub(foot,p)),s.leg.origin),1/CELL);local result={}
    for i,axis in ipairs(targetAxes[s.leg.rot]) do result[i]=dot(delta,axis) end
    return result
end
local function Evaluation(self,s,foot,q,p)
    -- Recompute the target before comparing scalar values: foot, q and p may
    -- be modified in place. Only identical inputs share a solve within Step.
    local target=self:Target(s,foot,q,p);local info=self.info[s.leg.type]
    local previous=self.ikCache and self.ikCache[s]
    if previous and previous.info==info and previous.target[1]==target[1] and previous.target[2]==target[2] and previous.target[3]==target[3] then return previous end
    local value={info=info,target=target}
    if self.ikCache then self.ikCache[s]=value end
    return value
end
function M:Clear(s,foot,q,p,from)
    local value=Evaluation(self,s,foot,q,p);local ik=value.pose
    if not ik then ik=IK.Solve(value.info,value.target);value.pose=ik end
    if ik.error>.08 then return false end
    local points={};for _,name in ipairs({'shoulderJoint','elbow','knee','toe'}) do
        points[#points+1]=add(p,rotate(q,add(s.leg.origin,mul(Rot.ApplyRot(s.leg.rot,ik.points[name]),CELL))))
    end
    for i=from or 1,3 do local dl=sub(points[i+1],points[i]);local d=length(dl)
        if d>1e-4 and self:Cast(points[i],norm(dl),math.max(0,d-(i==3 and .06 or 0))) then return false end
    end
    return true
end
function M:Reachable(s,foot,q,p)
    local value=Evaluation(self,s,foot,q,p);return IK.Reachable(value.info,value.target,value)
end
function M:Step(cmd,dt,contactSupport)
    self.ikCache={};local ikScope <close> = self.ikScope
    local v=self.v;local body=v.body;local legs=self.list;local n=#legs;local mass=v.mass
    local q,p,vel,w,com=body.rotation(),arr(body.translation()),arr(body.linvel()),arr(body.angvel()),arr(body.center())
    local function World(localPoint) return add(p,rotate(q,localPoint)) end
    local up,fwd,right=rotate(q,UP),rotate(q,{0,0,1}),rotate(q,{1,0,0})
    self.cooldown=math.max(0,self.cooldown-dt);self.airTime=math.max(0,self.airTime-dt)
    if self.wallMemo then self.wallMemo.ttl=self.wallMemo.ttl-dt;if self.wallMemo.ttl<=0 then self.wallMemo=nil end end
    local jump=cmd.jump==true and not self.jumpHeld;self.jumpHeld=cmd.jump==true
    self.jumpBuffer=jump and .3 or math.max(0,self.jumpBuffer-dt)
    local caps=v.capabilities;local usable=self.loadAll+caps.wheelLoad+caps.hoverLoad;local ratio=mass/math.max(1,usable)
    local grip=v.legMode and n>=4 and ratio<=1;local gripCos=grip and -1 or GRIP
    local leaving=self.airTime>0 or n<2;local sn=self.surf;local sup={}
    for _,s in ipairs(legs) do
        local l=s.leg;local mount=World(l.pos)
        local h=not leaving and self:Cast(add(mount,mul(sn,.25)),mul(sn,-1),.25+l.height*1.7) or nil
        if h and dot(h.normal,sn)>.25 then h.d=h.distance-.25;h.mount=mount;s.support=h;sup[#sup+1]=s else s.support=nil end
    end
    local surf0=self.surf;local tf,tr=norm(reject(fwd,surf0)),norm(reject(right,surf0))
    local input=add(mul(tf,cmd.throttle or 0),mul(tr,cmd.strafe or 0));if length(input)>1 then input=norm(input) end
    local moving=length(input)>.1
    local function Extent(d)
        local extent=.5;for _,s in ipairs(legs) do extent=math.max(extent,math.abs(dot(rotate(q,sub(s.leg.pos,v.com)),d))) end;return extent
    end
    ---@type number[]|nil
    local estimate=nil
    local wsum=0;local nsum={0,0,0}
    for _,s in ipairs(sup) do local k=s.leg.load*(1-clamp((s.support.d-s.leg.height)/s.leg.height,0,.8));nsum=add(nsum,mul(s.support.normal,k));wsum=wsum+k end
    if wsum>0 then estimate=norm(nsum) end
    self.wallAhead=false;self.edge=false
    ---@type table|nil
    local attach=nil
    if grip and moving and #sup>0 then
        local ext=Extent(input);local look=self.reachAvg*.7+length(reject(vel,surf0))*.3
        local h=self:Cast(add(com,mul(surf0,-self.heightAvg*.35)),input,ext+look)
        local lowest=sup[1].support.point;for _,s in ipairs(sup) do if dot(s.support.point,surf0)<dot(lowest,surf0) then lowest=s.support.point end end
        if h and dot(h.normal,surf0)<.8 and dot(h.normal,input)<-.3 and not self:IsStep(h,surf0,input,lowest) then
            local f=clamp(1-(h.distance-ext)/look,0,1)
            if f>.25 or self.wallMemo then
                self.wallMemo={normal=h.normal,ttl=.8};estimate=norm(add(mul(estimate or surf0,.2),mul(h.normal,1.3)))
            else estimate=norm(add(mul(estimate or surf0,1-f),mul(h.normal,f*1.3))) end
            self.wallAhead=true
        elseif self.wallMemo and self.wallMemo.ttl>0 then
            local memo=self.wallMemo;local on=0;for _,s in ipairs(sup) do if dot(s.support.normal,memo.normal)>.9 then on=on+1 end end
            if on>=math.ceil(#sup/2) then self.wallMemo=nil
            else memo.ttl=.8;estimate=norm(add(mul(estimate or surf0,.2),mul(memo.normal,1.3)));self.wallAhead=true end
        end
        local front={};if #sup<n then for _,s in ipairs(legs) do if dot(rotate(q,sub(s.leg.pos,v.com)),input)>.2 then front[#front+1]=s end end end
        local beyond=#front>0;for _,s in ipairs(front) do if s.support and s.support.d<=s.leg.height*1.35 then beyond=false end end
        if beyond then
            local start=add(add(com,mul(input,ext+self.reachAvg*.35)),mul(surf0,-self.heightAvg*1.3))
            local h2=self:Cast(start,mul(input,-1),ext+self.reachAvg)
            if h2 and dot(h2.normal,input)>.3 then estimate=norm(add(mul(estimate or surf0,.45),mul(h2.normal,.9)));self.edge=true end
        end
    end
    if #sup==0 and not leaving and grip then
        local ext=Extent(norm(vel));local dirs={}
        if length(vel)>1.5 then dirs[#dirs+1]=norm(vel) end;if moving then dirs[#dirs+1]=input end;dirs[#dirs+1]=mul(up,-1)
        for _,d in ipairs(dirs) do
            local h=self:Cast(com,d,ext+self.reachAvg*.9+length(vel)*.4)
            if h and dot(h.normal,d)<-.2 and dot(vel,h.normal)<1 then attach=h;estimate=h.normal;break end
        end
    end
    if estimate then self.surf=Turn(self.surf,Cone(estimate,gripCos),1-math.exp(-dt*(attach and 6 or (self.edge or self.wallAhead) and 4.5 or 8)))
    elseif #sup==0 then self.surf=Turn(self.surf,UP,1-math.exp(-dt*1.5)) end
    local surf=self.surf;self.normal=surf;local onWall=dot(surf,UP)<WALL
    local supLoad=0;for _,s in ipairs(sup) do supLoad=supLoad+s.leg.load end
    local massShare=math.max(0,mass-(contactSupport or 0)/G);local vertical,normalForce=0,0
    for _,s in ipairs(legs) do s.force=0 end
    for _,s in ipairs(sup) do
        local l=s.leg;local d=s.support.d;local mi=mass*l.load/supLoad;local wn=2*math.pi*1.8
        local k=mi*wn*wn;local damping=2*.85*mi*wn;local pv=dot(arr(body.velocityAtPoint(vec(s.support.mount))),sn)
        local ff=massShare*l.load/supLoad*G*math.max(0,dot(UP,sn))
        -- Flat ground already has gravity; downward adhesion would fight hover lift.
        local pullMax=grip and not self.wallMemo and dot(UP,sn)<.85 and l.load*G*.8 or 0
        local force=clamp(ff+k*(l.height-d)-damping*pv,-pullMax,l.load*G*2.2)
        if d>l.height*1.5 then force=math.min(force,0) end
        if self.wallMemo then body.addForce(vec(mul(sn,force)),true) else body.addForceAtPoint(vec(mul(sn,force)),vec(s.support.mount),true) end
        s.force=force;vertical=vertical+force*sn[2];normalForce=normalForce+math.max(0,force)
    end
    local tilt=cross(up,surf);local angle=math.asin(clamp(length(tilt),0,1))
    if (#sup>0 or attach) and (self.wallAhead or self.edge or attach or angle>20*DEG) and angle>2*DEG then
        local wa=2*math.pi*(attach and 1.4 or 1);local inertia=self.inertiaPR
        local torque=sub(mul(tilt,inertia*wa*wa),mul(reject(w,surf),inertia*2*.9*wa));local limit=0
        if #sup>0 then for _,s in ipairs(sup) do limit=limit+s.leg.load*G*s.leg.reach*.6 end else limit=mass*G*self.reachAvg*.5 end
        if length(torque)>limit then torque=mul(norm(torque),limit) end;body.addTorque(vec(torque),true)
    end
    if attach and attach.distance<Extent(mul(attach.normal,-1))+self.reachAvg*.7 then body.addForce(vec(mul(attach.normal,-mass*6)),true) end
    local supported=#sup>0
    if supported then self.groundedTime=self.groundedTime+dt;self.offGround=0
    else self.offGround=(self.offGround or 0)+dt;if self.offGround>.15 then self.groundedTime=0 end end
    local degrade=n<2 and 0 or (#sup<4 and n>=4) and .3 or n<4 and .3 or 1
    local speedSum=0;for _,s in ipairs(legs) do speedSum=speedSum+s.leg.load*s.leg.speed end
    for _,list in ipairs({v.spec.wheels,v.spec.hovers}) do for _,l in ipairs(list) do if l.works~=false then speedSum=speedSum+l.load*l.speed end end end
    local factor=ratio>2 and 0 or clamp(1.25-.5*ratio,0,1)
    local speedLimit=math.min(v.spec.motion.topSpeed,speedSum/math.max(1,usable)*factor)*degrade*((onWall or self.wallAhead) and .55 or 1)
    local share=caps.legShare~=0 and caps.legShare or 1
    local authority=supported and clamp(supLoad/math.max(1,mass*.6),0,1)*clamp(share,0,1) or 0
    local vt=reject(vel,surf);local jumped=false
    if authority>0 then
        local gt=reject({0,-G,0},surf);local hold=grip or dot(surf,UP)>=GRIP
        local force=mul(sub(mul(input,speedLimit),vt),mass*(moving and 3 or 6)*authority)
        if hold then force=sub(force,mul(gt,mass*authority)) end
        local max=(moving and 10 or 14)*authority+(hold and length(gt) or 0)
        if length(force)>mass*max then force=mul(norm(force),mass*max) end;body.addForce(vec(force),true)
        local target=(cmd.steer or 0)*1.6*degrade
        body.addTorque(vec(mul(surf,clamp(v.inertiaY*6*(target-dot(w,surf)),-v.inertiaY*6,v.inertiaY*6)*authority)),true)
    elseif not supported and v.legMode then
        body.addTorque(vec(mul(up,clamp(v.inertiaY*2*((cmd.steer or 0)*1.2-dot(w,up)),-v.inertiaY*2,v.inertiaY*2))),true)
    end
    if self.jumpBuffer>0 and v.legMode and n>=4 and #sup>=4 and self.groundedTime>=.3 and self.cooldown==0 then
        local h=0;for _,s in ipairs(legs) do h=h+s.leg.jumpHeight*s.leg.load end;h=h/math.max(1,self.loadAll)
        local speed=math.sqrt(2*G*h)/math.max(1,ratio);local jn=surf;if dot(jn,UP)<.7 then jn=norm(add(jn,mul(UP,.7))) end
        local dv=mul(jn,speed);if moving then dv=add(dv,mul(norm(reject(input,jn)),speed*.75)) end
        dv=add(dv,mul(jn,-math.max(0,dot(vel,jn))));body.applyImpulse(vec(mul(dv,mass)),true)
        self.cooldown=1.2;self.airTime=.35;self.groundedTime=0;self.jumpBuffer=0;jumped=true
        for _,s in ipairs(legs) do s.jumpGlow=1;s.grounded=false;s.swing=nil end
    end
    Gait.Step(self,dt,{q=q,p=p,up=up,surf=surf,supported=supported and not jumped,body=body})
    local contacts,height=0,0;for _,s in ipairs(legs) do if s.grounded then contacts=contacts+1 end end
    for _,s in ipairs(sup) do height=height+s.support.d end
    self.climbing=supported and onWall
    return {legCount=n,legAvailable=#sup,legAvailableLoad=supLoad,legContacts=jumped and 0 or contacts,legMode=v.legMode,
        legClimbing=self.climbing,legCresting=self.edge,legWallPending=self.wallAhead and not onWall,legStowed=false,
        legJumpReady=v.legMode and n>=4 and #sup>=4 and self.groundedTime>=.3 and self.cooldown==0,
        legCooldown=self.cooldown,legGroundedTime=self.groundedTime,legForce=normalForce,legVerticalSupport=vertical,
        legAuthority=authority,legSpeedLimit=speedLimit,legJumped=jumped,legHeight=#sup>0 and height/#sup or nil,legGrip=grip}
end
return M
