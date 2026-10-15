-- Frozen shared/battle/match.js. Scores are percentages, not kill counts.
local M={};M.__index=M
local function Other(team) return team=='blue' and 'red' or 'blue' end
local function Clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.New(cfg,tuning)
    local self=setmetatable({cfg=cfg,c=tuning,mode='conquest',round=1,score={blue=0,red=0},points={},
        shield={blue=true,red=true},dominant={blue=0,red=0},events={},history={},state='prep',t=0,overtime=false},M)
    for _,id in ipairs({'A','B','C'}) do self.points[#self.points+1]={id=id,v=0,count={blue=0,red=0},contested=false} end
    self:Emit('roundPrep',{round=1});return self
end
function M:Emit(kind,data) data=data or {};data.type=kind;self.events[#self.events+1]=data end
function M:Drain() local events=self.events;self.events={};return events end
function M:Final() return false end
function M:TimeLeft() return self.state=='live' and math.max(0,self.c.timeLimit-self.t) or self.state=='prep' and self.c.timeLimit or 0 end
function M:Owned(team) local n=0;for _,p in ipairs(self.points) do if p.owner==team then n=n+1 end end;return n end
function M:Add(team,amount) if self.state=='live' then self.score[team]=Clamp(self.score[team]+amount,0,100) end end
function M:Kill(team) self:Add(team,self.c.kill);self:Check() end
function M:Steal(team,damage)
    local foe=Other(team);if self.state~='live' or self.shield[foe] then return 0 end
    local value=math.min(self.score[foe],damage*self.c.steal);self.score[foe]=self.score[foe]-value
    self.score[team]=math.min(100,self.score[team]+value)
    if value>0 then self:Emit('stolen',{team=team,amount=value}) end;self:Check();return value
end
function M:Over(team,how)
    self.state='over';self.winner=team;self.history[#self.history+1]={round=1,winner=team,how=how};self:Emit('matchOver',{winner=team})
end
function M:Check()
    if self.state~='live' then return end
    for _,team in ipairs({'blue','red'}) do if self.score[team]>=100 then self:Over(team,'full');return end end
    if self.t>=self.c.timeLimit then
        local d=self.score.blue-self.score.red
        if math.abs(d)>=.5 then self:Over(d>0 and 'blue' or 'red','time');return end
        if not self.overtime then self.overtime=true;self:Emit('overtime') end
        if self.t>=self.c.timeLimit+self.c.overtime then self:Over(nil,'time') end
    end
end
function M:Step(dt,world)
    if self.state=='over' then return end;self.t=self.t+dt;local c=self.c
    if self.state=='prep' then
        if self.t>=self.cfg.prep then self.state='live';self.t=0;self:Emit('roundStart',{round=1}) end;return
    end
    for _,p in ipairs(self.points) do
        local count=world.inPoint[p.id] or {blue=0,red=0};p.count=count;p.contested=count.blue>0 and count.red>0
        if not p.contested then
            if count.blue==0 and count.red==0 then
                if p.by then
                    local node=(p.by=='blue' and math.floor(p.v*c.nodes+1e-6) or math.ceil(p.v*c.nodes-1e-6))/c.nodes
                    p.v=p.by=='blue' and math.max(node,p.v-c.drain*dt) or math.min(node,p.v+c.drain*dt)
                end
            else
                local team=count.blue>0 and 'blue' or 'red';local before=p.v;p.by=team
                p.v=Clamp(p.v+(team=='blue' and 1 or -1)*dt/c.capture*c.speed[math.min(3,count[team])+1],-1,1)
                local function Node(v) return math.floor(math.abs(v)*c.nodes+1e-6)*(v>0 and 1 or v<0 and -1 or 0) end
                if Node(before)~=Node(p.v) then self:Emit('pointNode',{id=p.id,team=team,node=math.abs(Node(p.v))}) end
                if p.owner and (p.owner=='blue' and p.v or -p.v)<=(c.nodes-1)/c.nodes+1e-6 then
                    local lost=p.owner;p.owner=nil;self:Emit('pointLost',{id=p.id,team=lost})
                end
                if math.abs(p.v)>=1 and p.owner~=team then p.owner=team;self:Emit('pointTaken',{id=p.id,team=team}) end
                if before==0 and p.v~=0 and not p.owner then self:Emit('pointCapturing',{id=p.id,team=team}) end
            end
        end
    end
    for _,team in ipairs({'blue','red'}) do
        local up=self:Owned(Other(team))<#self.points
        if up~=self.shield[team] then self.shield[team]=up;self:Emit(up and 'shieldUp' or 'shieldDown',{team=team}) end
        local n=self:Owned(team);self.dominant[team]=n==#self.points and self.dominant[team]+dt or 0
        self:Add(team,n*c.perPoint*(self.dominant[team]>=c.dominantAfter and c.dominantRate or 1)*dt)
    end
    self:Check()
end
return M
