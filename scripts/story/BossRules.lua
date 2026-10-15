-- Exact damage/timing contract from frozen FoxBoss; renderer and physics inject poses.
local V=require 'core.Math3'
local M={};M.__index=M
local allowed={fight=true,stomp=true,sweep=true,lanes=true,ult=true,recover=true,slamCrouch=true,slamAir=true,stuck=true,kneel=true,rise=true,barrage=true,transition=true}
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
local function Wrap(a) return math.atan(math.sin(a),math.cos(a)) end
function M.New(config,dps)
    local self=setmetatable({},M);self.config=config;self.hpMax=V.Clamp(math.max(150,dps)*config.hp.perDps,config.hp.min,config.hp.max)
    self.hp=self.hpMax;self.phase=1;self.state='idle';self.time=0;self.t=0;self.events={};self.said={};self.kneels=0;self.kneelDealt=0
    self.nodes={};for i=1,4 do self.nodes[i]={hp=self.hpMax*config.node.hp,max=self.hpMax*config.node.hp,broken=false,pos={0,0,0}} end
    self.cool={stomp=6,slam=4,missile=3,fire=0,sweep=5,lanes=8,ult=0};self.slams={};self.ultsDone=0;return self
end
function M:Emit(kind,data) data=data or {};data.type=kind;self.events[#self.events+1]=data end
function M:Drain() local e=self.events;self.events={};return e end
function M:Say(key,once) if once and self.said[key] then return end;if once then self.said[key]=true end;self:Emit('say',{key=key}) end
function M:Go(state) self.state=state;self.t=0;self:Emit('state',{state=state}) end
function M:Broken() local n=0;for _,node in ipairs(self.nodes) do if node.broken then n=n+1 end end;return n end
function M:Braced() return self.time<(self.braceUntil or 0) end
function M:Kneel()
    if self.state=='kneel' or self.hp<=0 then return end
    local interrupted=self.state=='ult';self.kneels=self.kneels+1;self.kneelDealt=0;self:Go('kneel')
    self:Emit('energyFull');self:Emit('kneel',{interrupted=interrupted,kneels=self.kneels,left=4-self:Broken()})
    if self.kneels==1 then self:Say('firstKneel',true) else self:Emit('kneelLine',{phase=self.phase}) end
    if self:Broken()==4 then self:Say('exposed',true) end
end
function M:Phase(phase)
    if self.phase>=phase then return end;self.phase=phase
    if self.state~='kneel' then self:Go('transition') else self.pendingPhase=true end
    self:Emit('phase',{phase=phase});self:Say(phase==2 and 'phase2' or 'phase3',true)
    if phase==2 then self.slams={'drill'};self.cool.slam=6.5;self.drillsAt=self.time+1.8
    else self.cool.missile=4;self.tailsOpen=true end
end
function M:Hurt(amount)
    local before=self.hp/self.hpMax;self.hp=math.max(0,self.hp-amount);local ratio=self.hp/self.hpMax;local c=self.config
    if self.phase==1 and ratio<=c.phase[1] then self:Phase(2) end
    if self.phase==2 and ratio<=c.phase[2] then self:Phase(3) end
    if before>c.cry and ratio<=c.cry then self:Say('cry',true) end
    for _,threshold in ipairs(c.ult.at) do if before>threshold and ratio<=threshold then self.ultPending=true end end
    if self.hp<=0 then self:Go('dying');self:Emit('die') end
end
function M:Hit(point,damage,pierce,cockpit)
    if not allowed[self.state] or damage<=0 then return 0 end
    local c=self.config;self.hitAt=self.time
    if self.state~='kneel' and not self:Braced() then for _,node in ipairs(self.nodes) do
        if not node.broken and V.Length(V.Sub(point,node.pos))<=c.node.r then
            local amount=math.min(node.hp,damage);node.hp=node.hp-damage;self:Emit('damage',{amount=amount,point=point,node=true,broke=node.hp<=0})
            if node.hp<=0 then node.broken=true;self:Emit('nodeBreak',{pos=node.pos});self:Kneel() end
            return amount
        end
    end end
    if self.state=='kneel' then
        local room=math.max(0,c.kneelCap*self.hpMax-self.kneelDealt)
        local amount=math.min(room,damage*(V.Length(V.Sub(point,cockpit))<6 and c.cockpit or c.weak))
        if amount>0 then self:Emit('damage',{amount=amount,point=point});self.kneelDealt=self.kneelDealt+amount;self:Hurt(amount) end
        if room-amount<=0 and self.state=='kneel' and self.hp>0 then self:Emit('riseForced');self:Go('rise') end
        return amount
    end
    local share=c.chip[self:Broken()+1];local armor=type(pierce)=='table' and (pierce.armor or 0) or 0
    local plain=damage*share;local pierced=damage*(1-share)*armor;local block=damage-plain-pierced
    if plain>0 then self:Emit('damage',{amount=plain,point=point}) end
    if pierced>0 then self:Emit('damage',{amount=pierced,point=point,pierce=true}) end
    if block>.5 then self:Emit('damage',{amount=block,point=point,shield=true});if V.Length(V.Sub(point,cockpit))<7 then self:Say('hardShield',true) end end
    self:Hurt(plain+pierced)
    if self:Broken()==4 and self.hp>0 and not self:Braced() then
        self.staggerNeed=self.staggerNeed or c.stagger.need;self.staggerAt=self.time
        self.staggerV=(self.staggerV or 0)+(plain+pierced)/self.hpMax
        if self.staggerV>=self.staggerNeed and ({fight=true,stomp=true,sweep=true,lanes=true,ult=true,stuck=true,transition=true})[self.state] then
            self.staggerV=0;self.staggerNeed=self.staggerNeed*(1+c.stagger.grow);self:Kneel()
        end
    end
    return plain+pierced
end
function M:StartUlt() self.ultPending=false;self.ultsDone=self.ultsDone+1;self.cool.ult=self.config.ult.every;self:Go('ult');self:Say(self.ultsDone==1 and 'ult' or 'ultAgain') end
function M:StartSlam(kind,to,world)
    self.slamKind=kind;self.slamTo=world.landing and world.landing(to) or to
    local far=Flat(world.pos,self.slamTo);self.slamT=V.Clamp(far/42,kind=='hop' and 1.4 or self.config.slam.flight,4.6)
    self.slamApex=V.Clamp(far*.28,kind=='hop' and 8 or 16,70);self:Go('slamCrouch')
    if not kind then self:Say('slamWarn',true) end
end
function M:Step(dt,world)
    self.time=self.time+dt;self.t=self.t+dt;local c=self.config
    for _,key in ipairs({'stomp','slam','missile','sweep','lanes','ult'}) do self.cool[key]=self.cool[key]-dt end
    if self.drillsAt and self.time>=self.drillsAt and self.hp>0 then self.drillsAt=nil;self:Emit('drills') end
    if (self.staggerV or 0)>0 and self.time-(self.staggerAt or 0)>c.stagger.idle then self.staggerV=math.max(0,self.staggerV-c.stagger.decay*dt) end
    local pos,target=world.pos,world.target;local dd=target and Flat(pos,target) or math.huge
    if self.state=='fight' and target then
        local facing=math.abs(Wrap(math.atan(target[1]-pos[1],target[3]-pos[3])-(world.yaw or 0)))
        if self.ultPending or self.phase==3 and self.cool.ult<=0 then self:StartUlt()
        elseif world.wantHop then self:StartSlam('hop',world.wantHop,world)
        elseif self.phase>=2 and self.cool.slam<=0 and (#self.slams>0 or dd>c.slam.far) then
            local kind=table.remove(self.slams,1);if kind=='drill' and not world.drill then kind=nil end
            self:StartSlam(kind,kind=='drill' and world.drill or target,world)
        elseif self.phase==3 and self.cool.missile<=0 then
            if self.raidNext and not world.raid then self:Emit('raid');self.cool.missile=c.raid.every else self:Go('barrage') end;self.raidNext=not self.raidNext
        elseif self.phase>=2 and self.cool.lanes<=0 and dd<c.lanes.len*.9 then
            self.laneFrom=world.feet;self.laneYaw=math.atan(target[1]-pos[1],target[3]-pos[3]);self:Go('lanes');self:Say('lanesWarn',true)
        elseif self.cool.stomp<=0 and dd<c.stomp.near then self.attackAt=world.feet;self:Go('stomp')
        elseif self.cool.sweep<=0 and dd<c.sweep.r*.95 and facing<.6 then self.attackAt=world.feet;self.sweepYaw=world.yaw;self:Go('sweep');self:Say('sweepWarn',true) end
    elseif self.state=='stomp' and self.t>=c.stomp.warn then self:Emit('impact',{pos=self.attackAt,r=c.stomp.r,damage=c.stomp.dmg,kind='stomp'});self.cool.stomp=c.stomp.every[self.phase];self:Go('recover')
    elseif self.state=='sweep' and self.t>=c.sweep.warn then self:Emit('sweep',{pos=self.attackAt,yaw=self.sweepYaw});self.cool.sweep=c.sweep.every;self:Go('recover')
    elseif self.state=='lanes' and self.t>=c.lanes.warn then self:Emit('lanes',{pos=self.laneFrom,yaw=self.laneYaw});self.cool.lanes=c.lanes.every;self:Go('recover')
    elseif self.state=='ult' and self.t>=c.ult.charge then self:Emit('ultBlast');self:Go('recover');self.recoverT=2.5
    elseif self.state=='recover' and self.t>=(self.recoverT or c.recover) then self.recoverT=nil;self:Go('fight')
    elseif self.state=='slamCrouch' and self.t>=c.slam.crouch then self:Go('slamAir');self:Emit('launch',{pos=self.slamTo,flight=self.slamT,kind=self.slamKind})
    elseif self.state=='slamAir' and (self.t>self.slamT*.9 and world.contacts>0 or self.t>self.slamT+1.2) then
        self:Emit('land')
        if self.slamKind=='hop' then self:Emit('hopImpact',{pos=self.slamTo,r=c.hop.r}) else self:Emit('impact',{pos=self.slamTo,r=c.slam.r,damage=c.slam.dmg,kind='slam'}) end
        if self.slamKind=='drill' then self:Emit('crush');self:Say('crush',true) end
        self.cool.slam=c.slam.every;self:Go(self.slamKind=='hop' and 'recover' or 'fight')
    elseif self.state=='stuck' and self.t>=c.slam.stuck and not world.talking then self:Go('fight')
    elseif self.state=='barrage' then
        if self.t>=1.4 and not self.launched then self.launched=true;self:Emit('missiles') end
        if self.t>=1.4+c.missile.n*c.missile.gap+.6 then self.launched=false;self.cool.missile=c.missile.every;self:Go('fight') end
    elseif self.state=='kneel' then
        if self.t>=c.kneel-c.riseWarn and not self.riseWarned then self.riseWarned=true;self:Emit('riseWarning') end
        if self.t>=c.kneel then self.riseWarned=false;self:Go('rise') end
    elseif self.state=='rise' and self.t>=c.rise then self.braceUntil=self.time+c.brace;self.pendingPhase=false;self:Go('fight');self.cool.stomp=math.max(3,self.cool.stomp);if self.kneels==1 then self:Say('firstRise',true) end
    elseif self.state=='transition' and self.t>=2.6 then self:Go('fight') end
end
function M:Snapshot()
    return {hp=self.hp/self.hpMax,phase=self.phase,nodes=self.nodes,kneel=self.state=='kneel',kneelK=self.state=='kneel' and self.t/self.config.kneel or 0,
        stagger=(self.staggerV or 0)/(self.staggerNeed or self.config.stagger.need),state=self.state,ult=self.state=='ult' and math.max(1,math.ceil(self.config.ult.charge-self.t)) or nil}
end
return M
