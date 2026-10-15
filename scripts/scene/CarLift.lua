-- Original three/src/scene/carLift.js curves, in metres. No storage/UI state.
---@class CarLift
---@field root Node|nil
---@field anim table|nil
local M={};M.__index=M
function M.New(root) return setmetatable({root=root},M) end
function M:SetY(y)
    local p=self.root.position;self.root.position=Vector3(p.x,y,p.z)
end
function M:Finish()
    if not self.anim then return end
    local target=self.anim.to;self.anim=nil;self:SetY(target)
end
function M:Play(from,to,duration,back)
    self:Finish()
    self.anim={from=from,to=to,duration=duration,back=back,t=0}
end
function M:Sink(depth) self:Play(self.root.position.y,-depth,.2,false) end
function M:Rise(depth,rest)
    self:SetY(rest-depth);self:Play(rest-depth,rest,.45,true)
end
function M:Settle(rest) self:Finish();self:SetY(rest) end
function M:Update(dt)
    local a=self.anim;if not a then return end
    a.t=math.min(1,a.t+dt/a.duration)
    local t=a.t;local u=t-1
    local eased=a.back and (1+2.4*u*u*u+1.4*u*u) or t*t*t
    self:SetY(a.from+(a.to-a.from)*eased)
    if t>=1 then self:Finish() end
end
function M:Dispose() self.anim=nil;self.root=nil end
return M
