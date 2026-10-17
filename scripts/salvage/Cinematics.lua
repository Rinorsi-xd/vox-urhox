local CineDeathFilter=require("render.CineDeathFilter")
local SourceDraw=require("ui.SourceDraw")
local SalvageCineDust=require("render.SalvageCineDust")

local Motion=require 'salvage.CineMotion'
local View=require 'render.SalvageCinematics'
local Tween=require 'ui.SourceButtonMotion'
local Loot=require 'salvage.Loot'
local M={};M.__index=M
local function Vec(a) return Vector3(a[1],a[2],a[3]) end
local function TweenState() return {value=0,start=0,target=0,elapsed=0,duration=0} end
function M.New(run)
    local self=setmetatable({},M);self.run=run;self.session=run.session;self.view=View.New(run.session.scene)
    self.shot=Motion.New();self.approachShot=Motion.New();self.bars=TweenState();self.hud=TweenState();self.caption=TweenState();self.skip=TweenState();self.namecard=TweenState()
    self.time=0;self.flash=0;self.flashTime=0;self.shake=0;self.playing=false;self.blocking=false;return self
end
function M:Start(name,len,block)
    self:ReleaseCar();self.current={name=name,t=0,len=len};self.playing=true;self.blocking=block;self.barsOn=true
    self.captionTitle=nil;self.skipOn=false;self.shot.w=0;return self.current
end
function M:Drop()
    local c=self:Start('drop',9.6,true);local at=self.run.player.spawnAt
    c.S=Vec(at.pos);c.yaw=at.yaw;c.label=self.run.spawn.name
    self:StepShot(c);self:HoldCar();print('[SalvageCine] drop begin')
end
function M:Elite(unit)
    if self.blocking then return end;local c=self:Start('elite',3.2,false);c.unit=unit
end
function M:Approach(exit,wait)
    self.approach={exit=exit,E=Vec(exit.g),t=0,wait=math.max(3,math.min(wait or exit.wait,6))}
    Motion.Approach(self.approachShot,0,self.approach.E,self.approach.wait);self.view:Ship(self.approachShot,.95)
end
function M:Extract(exit)
    local c=self:Start('extract',6.2,true);c.E=Vec(exit.g);c.exit=exit;c.car=Vec(self.run.player:Position());c.yaw=self.run.player.vehicle:Yaw()
    self.approach=nil;self.session.firing=false;self:StepShot(c);self:HoldCar();print('[SalvageCine] extract begin')
end
function M:Death()
    local c=self:Start('death',2.8,true);c.P=Vec(self.run.player:Position());self.approach=nil
    self.session.firing=false;self.filter=CineDeathFilter.New();print('[SalvageCine] death begin')
end
function M:Flash(alpha,duration) self.flash=alpha;self.flashTime=0;self.flashDuration=duration end
function M:NameCard(title,sub,duration) self.cardTitle=title;self.cardSub=sub;self.cardUntil=self.time+duration end
function M:Skip()
    local c=self.current
    if c and c.name=='drop' and c.t<7.2 then c.t=7.2;c.landed=true;self:StepShot(c);self:HoldCar();return true end
    return false
end
function M:ReleaseCar()
    if self.heldNative then
        self.heldNative.kinematic=self.wasKinematic;self.heldNative.linearVelocity=Vector3.ZERO;self.heldNative.angularVelocity=Vector3.ZERO
        self.heldNative=nil;self.wasKinematic=nil
    end
    self.hold=nil
end
function M:HoldCar()
    -- Drop: ground anchor -> origin = anchor - bounds.minY + .15 m.
    -- Extract: raw body origin, suspended 10 m under ship. While held the body
    -- is kinematic: gravity/contact cannot fight the authored pose. Restore its
    -- original mode on release, cancellation and disposal, including a skip.
    local u=self.run.player;local hold=self.hold
    if not hold or not u.alive then self:ReleaseCar();return end
    local native=u.vehicle.native
    if self.heldNative~=native then
        self:ReleaseCar();self.hold=hold;self.heldNative=native;self.wasKinematic=native.kinematic;native.kinematic=true
    end
    local y=hold.y+(self.rawHold and 0 or -u.spec.bounds.min[2]+.15)
    native.position=Vector3(-hold.x,y,hold.z);native.rotation=View.Rotation(0,self.holdYaw,0)
    native.linearVelocity=Vector3.ZERO;native.angularVelocity=Vector3.ZERO;native:ResetForces()
    if self.session.view then self.session.view:ResetPose(false);self.session.view:Update(1,0) end
    u:SavePose();u.previous=u.current
end
function M:Command(command)
    if not self.playing or not self.blocking then return command end
    local c=self.current
    if c.name=='drop' and c.t>8.3 then return command end
    return {throttle=c.name=='drop' and (self.shot.throttle or 0) or 0,steer=0,handbrake=self.hold~=nil,firing=false}
end
function M:StepShot(c)
    local t,r=c.t,self.shot;self.hold=nil;self.rawHold=false
    if c.name=='drop' then
        Motion.Drop(r,t,c.S,c.yaw,Vec(self.run.player:Position()));self.view:Drop(r,c.yaw,self.run.player.spec.bounds)
        self.hold=r.hold;self.holdYaw=c.yaw
        if r.landed and not c.landed then c.landed=true;self.shake=1.4;self:Flash(.25,.5);self:LandingDust(c.S,false) end
        self.captionTitle=t<2.8 and '打捞行动 · 断坝峡谷' or t>7.4 and t<9.4 and '落地保护 8 秒' or nil
        self.captionSub=t<2.8 and '投放点 · '..c.label or '车和货都在身上 · 被打爆全丢'
        self.skipOn=t<7;self.barsOn=t<=8.6
    elseif c.name=='extract' then
        Motion.Extract(r,t,c.E,c.car);self.view:Ship(r,.7+math.random()*.5)
        self.hold=r.hold;self.rawHold=true;self.holdYaw=c.yaw
        if t>5.2 and not c.white then c.white=true;self:Flash(1,1.2) end
        self.captionTitle=t<2.6 and '撤离 · '..c.exit.name or t>2.8 and '撤离成功' or nil
        self.captionSub=t<2.6 and '挂钩锁定 · 拉升' or '带出价值 '..SourceDraw.Number(Loot.Value(self.run.rules.cargo))
    elseif c.name=='death' then Motion.Death(r,t,c.P)
    else
        Motion.Elite(r,t,Vec(self.run.player:Position()),Vec(c.unit:Position()));self.barsOn=t<=2.6
    end
end
function M:LandingDust(at,approach)
    if not self.dust then self.dust=SalvageCineDust.New(self.session.scene) end
    self.dust:Burst(at,approach)
end
function M:Update(dt)
    if self.disposed then return end
    local shot=self.current
    local advanceTime=not self.run.result and self.run.rules.finished and shot and (shot.name=='extract' or shot.name=='death')
    local presentationDt=math.max(0,dt)
    if self.run.UpdateFeedback then self.run:UpdateFeedback() end
    dt=math.max(0,math.min(dt,.1));self.time=self.time+dt;self.shake=self.shake*math.exp(-dt*5)
    if self.run.explosion and not self.run.result then self.run.explosion:Update(dt,self.session.camera:GetNode(),self.run.player:Position()) end
    self.flashTime=self.flashTime+dt
    if self.dust then self.dust:Update(dt) end
    local c=self.current
    if not self.run.result and (not c or c.name=='elite') then
        local ex=self.run.rules.ex;local a=self.approach
        if ex and (not a or a.exit~=ex.e or a.leaving) then self:Approach(ex.e,ex.approachWait or ex.left);a=self.approach
        elseif not ex and a and not a.leaving then a.leaving=0 end
        if a then
            if a.leaving then
                a.leaving=a.leaving+dt;local r=self.approachShot;r.ship=r.ship+Vector3(40*dt,30*dt,0);self.view:Ship(r,.95)
                if a.leaving>4 then self.view:HideShip();self.approach=nil end
            else
                a.t=a.t+dt;local r=Motion.Approach(self.approachShot,a.t,a.E,a.wait);self.view:Ship(r,.7+math.random()*.5)
                if r.dust and not a.dust then a.dust=true;self:LandingDust(a.E,true) end
            end
        end
    end
    if c then
        c.t=math.min(c.len,c.t+dt);self:StepShot(c);self:HoldCar()
        if self.filter then self.filter:Update(Tween.Ease(math.min(1,c.t/.6),'ease')) end
        if c.t>=c.len then self:Finish(c) end
    end
    Tween.Step(self.bars,self.barsOn and 1 or 0,.45,dt,'ease')
    Tween.Step(self.hud,self.barsOn and 1 or 0,.3,dt,'ease')
    Tween.Step(self.namecard,self.cardUntil and self.time<self.cardUntil and 1 or 0,.25,dt,'ease')
    if self.captionTitle then self.lastTitle=self.captionTitle;self.lastSub=self.captionSub end
    Tween.Step(self.caption,self.captionTitle and 1 or 0,.35,dt,'ease');Tween.Step(self.skip,self.skipOn and .9 or 0,.3,dt,'ease')
    -- H5 records the result inside the final cinematic step, then advances time.
    if advanceTime then self.run:AdvancePresentationTime(presentationDt) end
end
function M:Camera()
    self.view:GuardCamera(self.session.camera:GetNode(),not self.playing)
    if not self.playing then return end
    local r=self.shot;if r.w<=.001 then return end
    local camera=self.session.camera:GetCamera();local node=camera.node;local p,q=node.position,node.rotation
    local desired=self:CameraPosition(r)
    node.position=desired;node:LookAt(Vector3(-r.tgt.x,r.tgt.y,r.tgt.z));local target=node.rotation
    node.position=p:Lerp(node.position,r.w);node.rotation=q:Slerp(target,r.w);camera.fov=camera.fov+(r.fov-camera.fov)*r.w
    if self.shake>.02 then node.position=node.position+Vector3((math.random()-.5)*self.shake,(math.random()-.5)*self.shake,(math.random()-.5)*self.shake) end
end
function M:CameraPosition(r)
    -- Aim -> scenery hit <- .85 m clearance <- authored camera.
    -- Scripted shots run after ThirdPersonCamera, so they need the same wall
    -- protection. Layer 1 excludes the held car and cinematic props. Terrain
    -- height also covers a camera starting below a one-sided terrain triangle.
    local world=self.run.world;local p=Vector3(-r.pos.x,r.pos.y,r.pos.z)
    p.y=math.max(p.y,world:GroundAt(-p.x,p.z)+1.2)
    local target=Vector3(-r.tgt.x,r.tgt.y,r.tgt.z);local delta=p-target;local length=delta:Length()
    if length>.01 then
        local hit=world.space.world:RaycastSingle(Ray(target,delta/length),length,1)
        if hit.body then p=target+delta/length*math.max(0,hit.distance-.85) end
    end
    self.cameraResolved=p;return p
end
function M:Finish(c)
    self:ReleaseCar();self.current=nil;self.playing=false;self.blocking=false;self.barsOn=false;self.captionTitle=nil;self.skipOn=false
    if self.filter then self.filter:Dispose();self.filter=nil end
    if c.name=='drop' then
        self.view:HideShip();self.run.landed=true
        self.run:Feed('行动开始',self.run.spawn.name..' · 时限 15:00 · 货舱 20 格 · '..self.run.rules.op.name..'行动 · 按 E 搜箱子 / 按住 E 拆残骸','#3ee6ff')
    elseif c.name=='extract' then self.run:Finish(true,'从「'..c.exit.name..'」撤离',false,c.exit)
    elseif c.name=='death' then self.run:Finish(false,'战车被击毁',false) end
    print('[SalvageCine] '..c.name..' end')
end
function M:Snapshot()
    return {playing=self.playing,blocking=self.blocking,name=self.current and self.current.name,time=self.current and self.current.t,holding=self.heldNative~=nil,
        bars=self.bars.value,caption=self.lastTitle,skip=self.skipOn,view=self.view:Snapshot(),filter=self.filter~=nil,dust=self.dust and self.dust:Snapshot()}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self:ReleaseCar();self.playing=false;self.blocking=false;self.current=nil;self.approach=nil
    if self.filter then self.filter:Dispose();self.filter=nil end
    if self.dust then self.dust:Dispose();self.dust=nil end;self.view:Dispose()
    self.view=nil;self.run=nil;self.session=nil;self.shot=nil;self.approachShot=nil;self.cameraResolved=nil
end
return M
