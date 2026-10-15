-- Frozen shared/battle/match.js: engine-independent, fed after each physics step.
local M={};M.__index=M
function M.New(config)
    local self=setmetatable({cfg=config,round=0,score={blue=0,red=0},history={},events={}},M)
    self:Next();return self
end
function M:Emit(kind,data) data=data or {};data.type=kind;self.events[#self.events+1]=data end
function M:Drain() local events=self.events;self.events={};return events end
function M:Final() return self.score.blue==self.cfg.winRounds-1 and self.score.red==self.cfg.winRounds-1 end
function M:TimeLeft() return self.state=='live' and math.max(0,self.cfg.roundTime-self.t) or self.state=='prep' and self.cfg.roundTime or 0 end
function M:Next()
    self.round=self.round+1;self.state='prep';self.t=0;self.sudden=false
    self:Emit('roundPrep',{round=self.round,final=self:Final(),prep=self.cfg.prep})
end
function M:Won(team,how)
    if team then self.score[team]=self.score[team]+1 end
    self.history[#self.history+1]={round=self.round,winner=team,how=how}
    self.state='roundEnd';self.t=0;self:Emit('roundEnd',{winner=team,how=how,round=self.round})
end
function M:Step(dt,world)
    if self.state=='over' then return end
    self.t=self.t+dt;local c=self.cfg
    if self.state=='prep' then
        if self.t>=c.prep then self.state='live';self.t=0;self:Emit('roundStart',{round=self.round}) end
        return
    end
    if self.state=='roundEnd' then
        if self.t>=c.intermission then
            local champ=self.score.blue>=c.winRounds and 'blue' or self.score.red>=c.winRounds and 'red' or nil
            if champ or self.round>=c.maxRounds then
                self.winner=champ or (self.score.blue~=self.score.red and (self.score.blue>self.score.red and 'blue' or 'red') or nil)
                self.state='over';self:Emit('matchOver',{winner=self.winner})
            else self:Next() end
        end
        return
    end
    local a=world.alive
    if a.blue==0 or a.red==0 then
        local winner=nil ---@type string|nil
        if a.blue>0 then winner='blue' elseif a.red>0 then winner='red' end
        self:Won(winner,'wipe');return
    end
    if not self.sudden and self:TimeLeft()<=c.suddenAt then self.sudden=true;self:Emit('suddenDeath') end
    if self.t>=c.roundTime then
        if a.blue~=a.red then self:Won(a.blue>a.red and 'blue' or 'red','alive')
        else local d=world.hp.blue-world.hp.red;local winner=nil ---@type string|nil
            if math.abs(d)>=.001 then winner=d>0 and 'blue' or 'red' end
            self:Won(winner,'hp') end
    end
end
return M
