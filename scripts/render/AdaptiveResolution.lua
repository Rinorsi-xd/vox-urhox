-- H5 crater policy: a 1.5 s window, quick reduction and slower recovery.
-- Separate from viewport/UI coordinates and from persistent graphics settings.
local M={};M.__index=M
function M.FrameCap()
    local cap=engine.maxFps
    if not cap or cap<=0 then return 60 end
    return math.min(60,cap)
end
function M.New(enabled)
    return setmetatable({enabled=enabled~=false,scale=1,elapsed=0,frames=0,lastFps=0},M)
end
function M:ResetWindow() self.elapsed=0;self.frames=0 end
function M:Sample(dt,active)
    -- Background throttling and resume stalls must not lower foreground quality.
    if not self.enabled or not active or not dt or dt<=0 or dt>.25 then self:ResetWindow();return false end
    self.elapsed=self.elapsed+dt;self.frames=self.frames+1
    if self.elapsed<1.5 then return false end
    self.lastFps=self.frames/self.elapsed;self:ResetWindow()
    local previous=self.scale
    -- H5 thresholds (50 / 58.5 at a 60 FPS cap) scale with the active frame cap,
    -- otherwise a 30 FPS cap reads as "slow" forever and pins the 70% floor.
    local cap=M.FrameCap()
    if self.lastFps<cap*50/60 then self.scale=math.max(.7,self.scale-.1)
    elseif self.lastFps>cap*58.5/60 then self.scale=math.min(1,self.scale+.05) end
    self.scale=math.floor(self.scale*100+.5)/100
    return previous~=self.scale
end
function M:Size(width,height,dpr,quality,fixed)
    if fixed then return math.max(1,width),math.max(1,height) end
    dpr=math.max(1,dpr)
    local base=quality=='high' and math.min(dpr,1.5) or 1
    local scale=base/dpr*self.scale
    return math.max(1,math.floor(width*scale+.5)),math.max(1,math.floor(height*scale+.5))
end
return M
