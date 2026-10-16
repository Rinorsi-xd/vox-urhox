-- Frozen H5 EndlessView: visual-only 0.6s rise and absolute-time immunity blink.
---@class EndlessSpawnPresentation
---@field root Node?
---@field basePosition Vector3?
local M={};M.__index=M
function M.New()
    local self=setmetatable({},M);self:init();return self
end
function M:init()
    self.riseUntil=0;self.root=nil;self.basePosition=nil
end
function M:Rise(now) self.riseUntil=now+.6 end
function M:Sample(now,height,invulnerableUntil)
    local left=math.max(0,self.riseUntil-now)
    return left/.6*math.max(3,height+2),now>=invulnerableUntil or math.floor(now/.12)%2==0
end
function M:Restore()
    if self.root and self.basePosition then self.root.position=self.basePosition end
    self.root=nil;self.basePosition=nil
end
function M:Apply(root,now,height,invulnerableUntil)
    self:Restore()
    local offset,visible=self:Sample(now,height,invulnerableUntil)
    if offset>0 then
        self.root=root;self.basePosition=root.position
        root.position=root.position-Vector3(0,offset,0)
    end
    return visible
end
function M:Dispose() self.root=nil;self.basePosition=nil end
return M
