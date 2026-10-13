-- Frozen storyMission.js basic objective chain; scene/input are supplied snapshots.
local M={};M.__index=M
local function Copy(p) return {p[1],p[2],p[3]} end
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(level)
    return setmetatable({level=level,time=0,index=0,begun=false,finished=false,events={},phase='boot',install=0,
        stats={intel=0,collectors=0,kills=0,deaths=0,fails=0},checkpoint=level.spawn},M)
end
function M:Emit(kind,props) props=props or {};props.type=kind;self.events[#self.events+1]=props end
function M:Drain() local events=self.events;self.events={};return events end
function M:StepSpec() return self.level.steps[self.index] end
function M:Begin() if self.begun then return end;self.begun=true;self.time=0;self:Emit('begin') end
function M:Go(index)
    self.index=index;self.install=0;self.phase='go';self.inside=false;self.blocked=false
    local step=self:StepSpec()
    if step then self:Emit('objective',{step=step,index=index})
    else self.phase='complete';self.completeAt=self.time+4;self:Emit('complete') end
end
function M:Target()
    local s=self:StepSpec();if not s then return nil end
    if s.kind=='pickup' then local it=self.level.intel[s.intel];return it.drop and self.dropPos or it.pos end
    return s.pos
end
function M:Near(pos,target,radius,up,size)
    size=size or {w=2,below=1.5,above=1.5}
    return Flat(pos,target)<radius+math.max(0,size.w-2) and target[2]>pos[2]-size.below-up and target[2]<pos[2]+size.above+up
end
function M:Done(world,lines)
    local s=self:StepSpec();self:Emit('objectiveDone',{step=s,lines=lines or s.done})
    self.checkpoint={pos={world.pos[1],world.pos[2]+1,world.pos[3]},yaw=world.yaw or 0}
    self:Go(self.index+1)
end
function M:Killed(pos) self.stats.kills=self.stats.kills+1;self.lastKill=Copy(pos) end
function M:Step(dt,world)
    if not self.begun or self.finished then return end
    self.time=self.time+dt
    if self.index==0 then if self.time>=1.4 then self:Go(1) end;return end
    if not world.alive then
        self.install=math.max(0,self.install-dt*.8)
        if not self.deadAt then self.deadAt=self.time;self.stats.deaths=self.stats.deaths+1;self:Emit('dead') end
        self.respawnLeft=math.max(0,3-(self.time-self.deadAt))
        if self.respawnLeft<=0 then self:Emit('respawn',{at=self.checkpoint});self.deadAt=nil end
        return
    end
    if self.completeAt then
        if self.time>=self.completeAt and not world.talking then
            local par=self.level.par or {420,600};local s=self.stats
            self.grade=s.deaths==0 and s.fails==0 and self.time<par[1] and 'S' or s.deaths+s.fails<=1 and self.time<par[2] and 'A' or 'B'
            self.finished=true;self:Emit('result',{grade=self.grade,time=self.time})
        end;return
    end
    local s=self:StepSpec();local target=self:Target();self.distance=target and Flat(world.pos,target) or 0
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
