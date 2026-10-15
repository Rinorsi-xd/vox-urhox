-- Authored version-six schedule from storyEpilogue.js.
local M={};M.__index=M
function M.New(data)
    local steps={{wait=.9,kind='boot'}}
    if data.place then steps[#steps+1]={kind='place',text=data.place,wait=2.4};steps[#steps+1]={kind='placeOut',wait=.7} end
    for _,s in ipairs(data.scenes) do
        if s.panel then steps[#steps+1]={kind='panel',panel=s.panel,page=s.page,wait=s.panel.hold or 1.6} end
        for _,l in ipairs(s.lines or {}) do steps[#steps+1]={kind='say',line=l} end
    end
    steps[#steps+1]={kind='pageOut',wait=1};steps[#steps+1]={kind='stamp',wait=3.4};steps[#steps+1]={kind='finish',wait=.8}
    return setmetatable({steps=steps,index=1,age=0,time=0,current=steps[1],events={},done=false},M)
end
function M:Next()
    if self.done then return end
    self.index=self.index+1;self.age=0;self.current=self.steps[self.index]
    if not self.current then self.done=true;self.events[#self.events+1]={kind='done'};return end
    self.events[#self.events+1]=self.current
end
function M:Step(dt,talking)
    if self.done then return end;self.time=self.time+dt;self.age=self.age+dt
    local s=self.current
    if s.kind=='say' then if self.age>.001 and not talking then self:Next() end
    elseif self.age>=(s.wait or 0) then self:Next() end
end
function M:Finish()
    if self.done or self.current.kind=='finish' then return end
    self.index=#self.steps;self.age=0;self.current=self.steps[self.index];self.events[#self.events+1]=self.current
end
function M:Drain() local e=self.events;self.events={};return e end
return M
