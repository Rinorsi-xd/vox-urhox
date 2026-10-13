-- Frozen storyMission.js basic objective chain; scene/input are supplied snapshots.
local M={};M.__index=M
local function Copy(p) return {p[1],p[2],p[3]} end
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(level,convoy)
    return setmetatable({level=level,convoy=convoy,time=0,index=0,begun=false,finished=false,events={},phase='boot',install=0,
        stats={intel=0,collectors=0,kills=0,deaths=0,fails=0,checkpoints=0},checkpoint=level.spawn,flags={},beatsFired={},stepT=0,progress=0},M)
end
function M:Emit(kind,props) props=props or {};props.type=kind;self.events[#self.events+1]=props end
function M:Drain() local events=self.events;self.events={};return events end
function M:StepSpec() return self.level.steps[self.index] end
function M:Begin() if self.begun then return end;self.begun=true;self.time=0;self:Emit('begin') end
function M:Go(index)
    self.index=index;self.install=0;self.phase='go';self.inside=false;self.blocked=false
    self.stepT=0;self.beatsFired={};self.asked=false;self.choice=nil;self.pendingAsk=nil;self.progress=0;self.retitle=nil
    local step=self:StepSpec()
    if step then
        if step.kind=='hold' then self.hold=require('story.HoldRules').New(step) end
        if step.kind=='capture' then self.cap=require('story.CaptureRules').New() end
        self:Emit('objective',{step=step,index=index})
    else self.phase='complete';self.completeAt=self.time+4;self:Emit('complete') end
end
function M:Target()
    local s=self:StepSpec();if not s then return nil end
    if s.kind=='pickup' then local it=self.level.intel[s.intel];return it.drop and self.dropPos or it.pos end
    if s.kind=='escort' then return self.convoy.pos end
    if s.kind=='capture' and self.cap and (self.cap.phase=='counter' or self.cap.phase=='cap' and self.playerPos and Flat(self.playerPos,s.pos)<s.r*2.5) then
        local closest,distance=nil,math.huge
        for _,p in ipairs(self.enemyPositions or {}) do local d=Flat(self.playerPos,p);if d<distance then closest=p;distance=d end end
        return closest or s.pos
    end
    return s.pos
end
function M:Near(pos,target,radius,up,size)
    size=size or {w=2,below=1.5,above=1.5}
    return Flat(pos,target)<radius+math.max(0,size.w-2) and target[2]>pos[2]-size.below-up and target[2]<pos[2]+size.above+up
end
function M:Done(world,lines)
    local s=self:StepSpec()
    if s.kind=='hold' then self:Emit('clearEnemies') end
    self:Emit('objectiveDone',{step=s,lines=lines or s.done})
    self.checkpoint={pos={world.pos[1],world.pos[2]+1,world.pos[3]},yaw=world.yaw or 0}
    self:Go(self.index+1)
end
function M:Killed(pos) self.stats.kills=self.stats.kills+1;self.lastKill=Copy(pos) end
function M:Ask(spec) self.choice=spec;self.choiceUntil=self.time+(spec.timeout or 14);self:Emit('choice') end
function M:Choose(index)
    local choice=self.choice;local option=choice and choice.options[index];if not option then return false end
    self.flags[choice.id or 'ask']=index-1;self.choice=nil;self:Emit('say',{lines=option.reply,urgent=true});return true
end
function M:Beats(dt,world)
    self.stepT=self.stepT+dt;local step=self:StepSpec()
    if step.ask and not self.asked and not world.talking and self.stepT>.5 then self.asked=true;self:Ask(step.ask) end
    if self.pendingAsk and self.time>=self.pendingAsk.at then self:Ask(self.pendingAsk.spec);self.pendingAsk=nil end
    if self.choice and self.time>=self.choiceUntil then self:Choose((self.choice.default or 0)+1) end
    for k,beat in ipairs(step.beats or {}) do
        local ready=beat.t and self.stepT>=beat.t or not beat.t and self.progress>=(beat.p or 0)
        local condition=not beat.when or beat.when=='noEnemies' and world.enemies==0 or beat.when=='shieldDamaged' and self.hold and self.hold.energy<.97
        if ready and not self.beatsFired[k] and condition then
            self.beatsFired[k]=true
            if beat.say then self:Emit('say',{lines=beat.say,urgent=beat.urgent}) end
            if beat.spawn then self:Emit('spawn',{enemies=beat.spawn,tag=beat.tag}) end
            if beat.banner then self:Emit('banner',{title=beat.banner[2],sub=beat.banner[3]}) end
            if beat.ask then self.pendingAsk={spec=beat.ask,at=self.time+.3} end
            if beat.run=='dropCoupon' then self.dropPos={0,6.2,-214};self:Emit('dropIntel',{id='coupon',pos=self.dropPos}) end
        end
    end
end
function M:Fail(title,lines)
    if self.failAt then return end;self.failAt=self.time;self.stats.fails=self.stats.fails+1
    self:Emit('say',{lines=lines,urgent=true});self:Emit('banner',{title=title,sub='3 秒后从存档点重来'})
end
function M:Step(dt,world)
    if not self.begun or self.finished then return end
    self.time=self.time+dt
    self.playerPos=world.pos;self.enemyPositions=world.enemyPositions
    if self.index==0 then if self.time>=1.4 then self:Go(1) end;return end
    local step=self:StepSpec()
    if self.failAt and self.time-self.failAt>=3 then
        self.failAt=nil;self:Emit('clearEnemies')
        if step.kind=='escort' then self.convoy:Retry(self)
        elseif step.kind=='hold' then self.hold:Retry(self)
        else self:Go(self.index) end
    end
    if not world.alive then
        self.install=math.max(0,self.install-dt*.8)
        if not self.deadAt then self.deadAt=self.time;self.stats.deaths=self.stats.deaths+1;self:Emit('dead') end
        self.respawnLeft=math.max(0,3-(self.time-self.deadAt))
        if self.respawnLeft<=0 then self:Emit('respawn',{at=self.checkpoint});self.deadAt=nil end
        if step and step.kind=='escort' and not self.failAt then self.convoy:Update(self,dt,world) end
        if step and step.kind=='hold' and not self.failAt then self.hold:Update(self,dt,world) end
        return
    end
    if self.completeAt then
        if self.time>=self.completeAt and not world.talking then
            local par=self.level.par or {420,600};local s=self.stats
            self.grade=s.deaths==0 and s.fails==0 and self.time<par[1] and 'S' or s.deaths+s.fails<=1 and self.time<par[2] and 'A' or 'B'
            if self.level.gradePolicy=='truckHp' then local hp=s.truckHp or 1
                if hp<.35 then self.grade='B' elseif hp<.7 and self.grade=='S' then self.grade='A' end
            end
            if self.level.gradePolicy=='shield' and (s.shield or 1)<.3 and self.grade=='S' then self.grade='A' end
            self.finished=true;self:Emit('result',{grade=self.grade,time=self.time})
        end;return
    end
    local s=self:StepSpec();local target=self:Target();self.distance=target and Flat(world.pos,target) or 0
    self:Beats(dt,world)
    if s.kind=='talk' then
        if self.stepT>1 and self.asked and not self.choice and not world.talking then self:Done(world) end
        return
    end
    if s.kind=='hold' then if not self.failAt and self.hold:Update(self,dt,world) then self:Done(world) end;return end
    if s.kind=='capture' then if self.cap:Update(self,dt,world) then self:Done(world) end;return end
    if s.kind=='escort' then if not self.failAt and self.convoy:Update(self,dt,world) then self:Done(world) end;return end
    if s.kind=='pickup' and target and self:Near(world.pos,target,6,6,world.size) then
        self.stats.intel=self.stats.intel+1;self:Emit('intel',{id=s.intel,item=self.level.intel[s.intel]});self:Done(world)
    elseif s.kind=='reach' and self:Near(world.pos,s.pos,s.r,12,world.size) then self:Done(world)
    elseif s.kind=='install' then
        self.inside=self:Near(world.pos,s.pos,s.r,5,world.size);self.blocked=math.abs(world.speed or 0)>2.5
        if self.inside and world.interact and not self.blocked then self.install=self.install+dt else self.install=math.max(0,self.install-dt*.8) end
        if self.install>=2.4 then self.stats.collectors=self.stats.collectors+1;self:Emit('collector',{step=s,pos=Copy(world.pos),yaw=world.yaw or 0});self:Done(world) end
    elseif s.kind=='clear' then
        if self.phase=='go' and Flat(world.pos,s.pos)<s.trigger then
            self.phase='fight';self.fightAt=self.time;self:Emit('fight',{step=s});return
        end
        if self.phase=='fight' then
            self.enemyCount=world.enemies or 0;local timeout=self.time-self.fightAt>s.timeout
            if self.enemyCount==0 or timeout then
                self.dropPos=Copy(self.lastKill or s.pos);self.dropPos[2]=self.dropPos[2]+.2
                self:Emit('clear',{timeout=timeout and self.enemyCount>0,pos=self.dropPos})
                self:Done(world,timeout and self.enemyCount>0 and s.retreat or s.done)
            end
        end
    end
end
return M
