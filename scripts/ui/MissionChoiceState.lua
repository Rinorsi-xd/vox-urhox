-- StoryHud choice confirmation uses wall time, independent of world pause/death.
local Ease=require('ui.SourceButtonMotion').Ease
local M={};M.__index=M
local function Now() return Time:GetSystemTime() end
local function Value(t,now)
    if not t then return 0 end
    local p=t.duration==0 and 1 or math.min(1,math.max(0,(now-t.at-t.delay)/t.duration))
    return t.from+(t.target-t.from)*Ease(p,t.curve)
end
local function Tween(t,target,now,duration,curve,delay)
    local value=Value(t,now)
    return {from=value,target=target,at=now,duration=duration*math.abs(target-value),delay=delay or 0,curve=curve}
end
function M.New() return setmetatable({pending={},sample={}},M) end
function M:SetOn(on,now)
    if self.on==on then return end
    self.alpha=Tween(self.alpha,on and 1 or 0,now,200,'ease')
    self.slide=Tween(self.slide,on and 1 or 0,now,300,false);self.on=on
end
function M:Advance(now)
    while self.pending[1] and now>=self.pending[1] do
        local at=table.remove(self.pending,1);self:SetOn(false,at)
    end
end
function M:Open(choice,now)
    if self.disposed or not choice then return end
    now=now or Now();self:Advance(now);self.choice=choice;self.picked=nil;self.choosing=true;self:SetOn(true,now)
end
function M:Pick(choice,index,now)
    if self.disposed or not self.choosing or self.choice~=choice or not choice.options[index] then return false end
    now=now or Now();self:Advance(now);self.choosing=false;self.picked=index;self.pending[#self.pending+1]=now+500;return true
end
function M:Cancel(now)
    if self.disposed then return end
    now=now or Now();self:Advance(now);self.choosing=false;self:SetOn(false,now)
end
function M:State(now)
    if self.disposed or not self.choice then return nil end
    now=now or Now();self:Advance(now)
    local s=self.sample;s.choice=self.choice;s.picked=self.picked;s.on=self.on;s.choosing=self.choosing
    s.alpha=Value(self.alpha,now);s.x=-16*(1-Value(self.slide,now));s.visible=self.on or s.alpha>0 or s.x> -16
    return s
end
function M:Dispose() self.disposed=true;self.choice=nil;self.pending={};self.sample={} end
return M
