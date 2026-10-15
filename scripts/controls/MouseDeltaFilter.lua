-- Frozen Input._spike: filter individual OS events before accumulating a frame.
local M={};M.__index=M
function M.New() local self=setmetatable({},M);self:Reset();return self end
function M:Reset() self.avgMove=0;self.lastSpike=false;self.dx=0;self.dy=0;self.events=0 end
function M:Push(dx,dy)
    self.events=self.events+1
    local magnitude=math.sqrt(dx*dx+dy*dy);local avg=self.avgMove
    local spike=magnitude>120 and magnitude>avg*8+80 and not self.lastSpike
    self.lastSpike=spike
    if spike then return false end
    self.avgMove=avg+(magnitude-avg)*.3
    self.dx=self.dx+dx;self.dy=self.dy+dy
    return true
end
function M:Consume(rawX,rawY)
    -- An event may be rejected; its unfiltered frame total must not bypass us.
    if self.events==0 and (rawX~=0 or rawY~=0) then self:Push(rawX,rawY) end
    local dx,dy=self.dx,self.dy
    self.dx=0;self.dy=0;self.events=0
    return dx,dy
end
return M
