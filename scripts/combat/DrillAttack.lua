-- Frozen shared/combat/drill.js. One body motor; additional drills are reserves.
local V=require 'core.Math3'
local Cutters=require('core.ResourceData').Read('Combat/Drills.json').cutters
local M={};M.__index=M
local ZERO={x=0,y=0,z=0}
local IDENTITY={x=0,y=0,z=0,w=1}
function M.New(system)
    local self=setmetatable({},M);self:init(system);return self
end
function M:init(system)
    self.sys=system;self.active=nil;self.held=nil;self.wasHeld=false
end
function M:ControlsBody() return self.active~=nil end
function M:Latched() return self.active~=nil and self.active.phase=='latched' end
function M:Hint()
    local g=self.sys:Group();local w=g and g.weapons[1]
    if not w or not w.stats.drill then return '' end
    if self:Latched() then return '夫元钻头 · 咬死了！车体旋转中…准备起飞' end
    if self.active and self.active.grinding then return '天元钻头 · 持续钻穿！' end
    if self.active then return '钻头突进！' end
    if self.sys.offline then return '能量恢复中' end
    if w.cool>0 then return string.format('钻头冷却 %.1f 秒',w.cool) end
    if self.held then
        return w.windup>=1 and w.stats.holdEnergy and '满蓄力 · 维持耗能中，能量不足自动释放'
            or string.format('蓄力 %d%% · 松开左键突进',math.floor(w.windup*100+.5))
    end
    return '长按左键蓄力 · 松开沿钻头方向突进'
end
function M:Cancel()
    local a=self.active
    if a and a.body.isValid() then
        if a.phase=='latched' then a.body.setBodyType(a.bodyType) end
        a.body.setLinvel(ZERO);a.body.setAngvel(ZERO);a.body.enableCcd(a.ccd)
    end
    if a then a.w.drillPhase='idle';a.w.windup=0;a.w.cool=a.w.stats.interval end
    if self.held then self.held.windup=0;self.held.drillPhase='idle' end
    self.held=nil;self.active=nil;self.wasHeld=false
end
function M:Empty()
    self.sys.energy=0
    if not self.sys.offline then self.sys.offline=true;self.sys.fx[#self.sys.fx+1]={type='energy',state='empty'} end
end
function M:Charge(w,dt)
    local sys,s=self.sys,w.stats;local total=s.energy*s.chargeEnergyFraction
    sys.sinceUse=0
    local charging=math.min(dt,(1-w.windup)*s.chargeTime);local cost=charging/s.chargeTime*total
    local paid=math.min(sys.energy,cost);sys.energy=math.max(0,sys.energy-paid)
    w.windup=math.min(1,w.windup+paid/total);if w.windup>1-1e-8 then w.windup=1 end
    if sys.energy<1e-8 then self:Empty();return true end
    if w.windup==1 then
        local hold=s.holdEnergy*math.max(0,dt-charging)
        if sys.energy<=hold+1e-8 then self:Empty();return true end
        sys.energy=sys.energy-hold
    end
    return false
end
function M:PayRelease(w,state)
    if not w.stats.chargeEnergyFraction then return self.sys:Spend(w,state) end
    self.sys.sinceUse=0;self.sys.energy=math.max(0,self.sys.energy-w.stats.energy*(1-w.stats.chargeEnergyFraction))
    if self.sys.energy<1e-8 then self:Empty() end
    return true
end
function M:Step(dt,state,env)
    local sys=self.sys
    for _,g in ipairs(sys.groups) do for _,w in ipairs(g.weapons) do if w.stats.drill then
        w.cool=math.max(0,w.cool-dt);w.charge=1-w.cool/w.stats.interval
        if not (self:Latched() and self.active.w==w) then
            w.spinAngle=w.spinAngle+dt*(self.active and self.active.w==w and 65 or 2+w.windup*48)
        end
    end end end
    if state.live==false then self:Cancel();return end
    if self.active then
        sys.sinceUse=0
        if not self.active.body.isValid() then self:Cancel();return end
        if self:Latched() then self:Roll(dt) else self:Dash(dt,state,env) end
        self.wasHeld=state.firing==true;return
    end
    local g=sys:Group();local w=g and g.weapons[1];local press=state.firing==true
    if self.held and self.held~=w then self.held.windup=0;self.held.drillPhase='idle';self.held=nil end
    if not w or not w.stats.drill then self.wasHeld=press;return end
    sys.pointing=w
    if press and not self.wasHeld and w.cool<=0 and not sys.offline and (not w.stats.chargeEnergyFraction or sys.energy>0) then
        self.held=w;w.windup=0;w.drillPhase='charging'
    end
    local forced=false
    if self.held and press then
        if w.stats.chargeEnergyFraction then forced=self:Charge(w,dt)
        else w.windup=math.min(1,w.windup+dt/w.stats.chargeTime) end
    end
    if self.held and (not press or forced) then
        local charge=w.windup;self.held=nil;w.windup=0;w.drillPhase='idle'
        if charge+1e-8>=w.stats.minCharge and self:PayRelease(w,state) then
            local m=sys:Muzzle(w,state);local b=state.body
            local speed=w.stats.dashSpeed[1]+(w.stats.dashSpeed[2]-w.stats.dashSpeed[1])*charge
            self.active={w=w,body=b,bodyType=b.bodyType(),ccd=b.isCcdEnabled(),phase='dash',dir=m.dir,charge=charge,
                speed=speed,topSpeed=speed,elapsed=0,cutTime=0,cuts=0,engaged=false,nextCut=0,bite=0,grinding=false,targets={},quat=b.rotation()}
            b.enableCcd(true);w.drillPhase='dash';w.shotAt=sys.time
            env.stats.shots=env.stats.shots+1;sys.fx[#sys.fx+1]={type='drill',stage='dash',pos=m.pos,dir=m.dir,easter=w.stats.easter}
            self:Dash(dt,state,env)
        end
    end
    self.wasHeld=press
end
function M:CutDrive(a,dt,brake)
    local b=a.body
    if brake then b.setLinvel(ZERO);return end
    local forward=V.Dot(V.Array(b.linvel()),a.dir)
    local delta=math.max(0,math.min(a.w.stats.boreSpeed-forward,a.w.stats.boreAcceleration*dt))
    b.applyImpulse(V.Vec(V.Scale(a.dir,delta*b.mass())))
end
function M:Dash(dt,state,env)
    local a=self.active;local w,b,dir=a.w,a.body,a.dir
    local remaining=a.engaged and w.stats.boreTime-a.cutTime or w.stats.dashTime-a.elapsed
    if remaining<=1e-8 then self:Finish(false);return end
    local stepTime=math.min(dt,remaining);a.elapsed=a.elapsed+stepTime
    if a.engaged then a.cutTime=a.cutTime+stepTime end
    b.setRotation(a.quat);b.setAngvel(ZERO);b.resetForces();b.resetTorques()
    local tip=self.sys:Muzzle(w,{pos=state.pos,quat=a.quat}).pos;local travel=a.speed*stepTime
    local q=V.QMul(a.quat,w.quat or IDENTITY);local cutters=nil ---@type table[]|nil
    if not w.stats.easter then
        cutters={}
        for _,c in ipairs(Cutters[w.type]) do cutters[#cutters+1]={pos=V.Add(tip,V.RotateUnit(q,c.offset)),half=c.half,quat=q} end
    end
    local hit=env.sweepDrill(tip,dir,travel+.025,b,cutters)
    if hit then
        local advance=a.engaged and 0 or math.max(0,math.min(travel,hit.dist-.025))
        b.setTranslation(V.Vec(V.Add(state.pos,V.Scale(dir,advance))))
        local cuttable=hit.owner and ({car=true,target=true,cone=true,debris=true,reactor=true})[hit.owner.type]
        local target=hit.owner and hit.owner.ref or false;local first=not a.targets[target]
        if w.stats.easter and (first or a.elapsed>=a.nextCut) or not w.stats.easter and a.cuts<w.stats.boreHits and a.elapsed+1e-8>=a.nextCut then
            local damage=(w.stats.easter and first or not w.stats.easter and a.cuts==0) and w.stats.damage or w.stats.boreDamage
            local inside=hit.point
            if hit.collider then
                local inward=V.Sub(V.Array(hit.collider.translation()),hit.point);local bias=.01/math.max(.01,V.Length(inward))
                inside=V.Add(V.Add(V.Sub(hit.point,V.Scale(hit.normal,.035)),V.Scale(dir,.01)),V.Scale(inward,w.stats.easter and 0 or bias))
            end
            local h={};for k,v in pairs(hit) do h[k]=v end;h.point=inside
            env.hit(h,damage*(.35+.65*a.charge),dir,0,w.stats.easter and .65 or .35)
            self.sys.fx[#self.sys.fx+1]={type='drill',stage=first and 'impact' or 'grind',pos=hit.point,dir=dir,easter=w.stats.easter}
            a.targets[target]=true;a.nextCut=a.elapsed+w.stats.boreTick;a.cuts=a.cuts+1
            if first then a.bite=a.elapsed+.055 end
        end
        if w.stats.easter and cuttable and hit.owner.type~='debris' then
            a.phase='latched';w.drillPhase='latched';a.elapsed=0;a.roll=0;a.quat=b.rotation();a.pin=V.Add(tip,V.Scale(dir,advance))
            a.offset=V.Unrotate(a.quat,V.Sub(a.pin,V.Array(b.translation())));a.spin=w.spinAngle
            b.setLinvel(ZERO);b.setBodyType(true);b.setNextKinematicTranslation(b.translation());b.setNextKinematicRotation(a.quat)
        elseif not w.stats.easter and cuttable then
            a.engaged=true;a.grinding=true;a.speed=w.stats.boreSpeed;self:CutDrive(a,dt,true)
        else self:Finish(false) end
        return
    end
    if a.engaged then a.grinding=true;self:CutDrive(a,dt);return end
    a.grinding=false;a.speed=math.min(a.topSpeed,a.speed+dt*110);b.setLinvel(V.Vec(V.Scale(dir,travel/dt)))
end
function M:Roll(dt)
    local a=self.active;a.elapsed=a.elapsed+dt;a.roll=a.roll+dt*(6+22*math.min(1,a.elapsed/.7))
    local s=math.sin(a.roll/2);local q=V.QMul({x=a.dir[1]*s,y=a.dir[2]*s,z=a.dir[3]*s,w=math.cos(a.roll/2)},a.quat)
    local p=V.Vec(V.Sub(a.pin,V.RotateUnit(q,a.offset)))
    a.body.setNextKinematicTranslation(p);a.body.setNextKinematicRotation(q);a.w.spinAngle=a.spin-a.roll
    if a.elapsed>=a.w.stats.latchTime then a.body.setTranslation(p);a.body.setRotation(q);self:Finish(true) end
end
function M:Finish(fling)
    local a=self.active;if not a then return end
    local b=a.body;if a.phase=='latched' then b.setBodyType(a.bodyType) end;b.enableCcd(a.ccd)
    if fling then
        local side=V.RotateUnit(b.rotation(),{1,0,0})
        b.setLinvel(V.Vec(V.Add(V.Add(V.Scale(a.dir,-(8+6*a.charge)),V.Scale(side,6)),{0,10,0})));b.setAngvel(V.Vec(V.Scale(a.dir,9)))
        self.sys.fx[#self.sys.fx+1]={type='drill',stage='fling',pos=a.pin,dir=a.dir,easter=true}
    else b.setLinvel(ZERO);b.setAngvel(ZERO) end
    for _,g in ipairs(self.sys.groups) do for _,w in ipairs(g.weapons) do if w.stats.drill then w.cool=w.stats.interval end end end
    a.w.drillPhase='idle';a.w.windup=0;self.active=nil
end
return M
