local M={};M.__index=M
function M.New(cfg,tuning,length)
    local self=setmetatable({cfg=cfg,c=tuning,mode='escort',length=length,half=0,results={},score={blue=0,red=0},events={},history={}},M)
    self:Next();return self
end
function M:Emit(kind,data) data=data or {};data.type=kind;self.events[#self.events+1]=data end
function M:Drain() local events=self.events;self.events={};return events end
function M:Final() return self.half==2 end
function M:TimeLeft() return self.state=='live' and math.max(0,self.limit-self.t) or self.state=='prep' and self.limit or 0 end
function M:Checkpoint()
    local out=0;for _,k in ipairs(self.c.checkpoints) do if k*self.length<=self.s+1e-6 then out=k*self.length end end;return out
end
function M:Next()
    self.half=self.half+1;self.round=self.half;self.attack=self.half==1 and 'blue' or 'red';self.defend=self.attack=='blue' and 'red' or 'blue'
    self.state='prep';self.t=0;self.s=0;self.limit=self.c.time;self.passed=0;self.idle=0;self.fuse=0;self.overtime=false;self.pushing=0;self.contested=false
    self:Emit('halfPrep',{half=self.half,attack=self.attack})
end
function M:HalfDone(done)
    local result={attack=self.attack,dist=self.s,time=self.t,done=done}
    self.results[#self.results+1]=result;self.score[self.attack]=math.floor(self.s+.5)
    self.history[#self.history+1]={round=self.half,attack=self.attack,dist=self.s,time=self.t,done=done,how=done and 'done' or 'time'}
    self.state='halftime';self.t=0;self:Emit('halfEnd',result)
end
function M:Over()
    local b,r=self.results[1],self.results[2]
    if b.done and r.done then if math.abs(b.time-r.time)>=.5 then self.winner=b.time<r.time and 'blue' or 'red' end
    elseif math.abs(b.dist-r.dist)>=1 then self.winner=b.dist>r.dist and 'blue' or 'red' end
    self.state='over';for _,v in ipairs(self.history) do v.winner=self.winner end;self:Emit('matchOver',{winner=self.winner})
end
function M:Step(dt,world)
    if self.state=='over' then return end;self.t=self.t+dt;local c=self.c
    if self.state=='prep' then
        if self.t>=self.cfg.prep then self.state='live';self.t=0;self:Emit('halfStart',{half=self.half,attack=self.attack}) end;return
    elseif self.state=='halftime' then
        if self.t>=c.halftime then if self.half>=2 then self:Over() else self:Next() end end;return
    end
    local a,d=world.near[self.attack] or 0,world.near[self.defend] or 0;self.pushing=a;self.contested=a>0 and d>=a
    local before=self.s
    if a>0 and not self.contested then self.s=self.s+c.speed[math.min(3,a-d)+1]*dt;self.idle=0
    elseif not self.contested then self.idle=self.idle+dt;if self.idle>=c.idleBack then self.s=math.max(self:Checkpoint(),self.s-c.back*dt) end end
    self.s=math.min(self.length,self.s)
    while self.passed<#c.checkpoints and self.s>=c.checkpoints[self.passed+1]*self.length do
        self.passed=self.passed+1;self.limit=self.limit+c.bonus;self:Emit('checkpoint',{n=self.passed,attack=self.attack})
    end
    if self.s>=self.length then self:HalfDone(true);return end
    if self.t>=self.limit then
        if self.t>=self.limit+c.overtimeMax then self:HalfDone(false);return end
        if a>0 then if not self.overtime then self.overtime=true;self:Emit('overtime') end;self.fuse=0
        else self.fuse=self.fuse+dt;if not self.overtime or self.fuse>=c.overtimeFuse then self:HalfDone(false);return end end
    end
    if math.floor(self.s/25)~=math.floor(before/25) then self:Emit('moved',{s=self.s}) end
end
return M
