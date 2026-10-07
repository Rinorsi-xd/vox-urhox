-- PC source pointer-lock semantics. Sampling is separate from the OS adapter so
-- capture edges, right-click toggle/hold, and focus loss can be replayed exactly.
local M={};M.__index=M
function M.New(session) return setmetatable({session=session,captured=false,ready=false,skip=false,right=false,scopeHold=false,heldTime=0},M) end
function M:SetMouseMode(mode) input.mouseMode=mode end
function M:Capture()
    local s=self.session;if s.disposed or s.dialog then return false end
    s.controls:Clear();self.captured=true;self.ready=false;self.skip=true;self.right=false;self.heldTime=0
    if not s.touch then self:SetMouseMode(MM_RELATIVE) end;return true
end
function M:Release()
    if self.captured and not self.session.touch then self:SetMouseMode(MM_ABSOLUTE) end
    self.captured=false;self.ready=false;self.right=false;self.scopeHold=false;self.heldTime=0
    local s=self.session;s.scope=false;s.firing=false;s.controls:Clear()
    if s.touch and s.hud then s.hud.Clear() end
end
function M:Suppress() self.ready=false;self.session.controls:Clear() end
function M:Sample(sample,dt)
    if not self.captured then return end
    if self.skip then self.skip=false;return end
    if not self.ready then self.ready=not (sample.left or sample.right or sample.middle);return end
    local s=self.session;s.controls:Look(sample.dx or 0,sample.dy or 0);s.controls.held.fire=sample.left==true
    if sample.wheel and sample.wheel~=0 then s:Zoom(sample.wheel) end
    if sample.right and not self.right then
        self.scopeHold=not s.scope;self.heldTime=0;s.scope=not s.scope
    elseif sample.right then self.heldTime=self.heldTime+dt
    elseif self.right and self.scopeHold and self.heldTime+dt>.25 then s.scope=false end
    self.right=sample.right==true
end
function M:Poll(dt)
    if not self.captured then return end
    if self.session.touch then
        if not self.session:HasFocus() then self:Release() end
        return
    end
    if not self.session:HasFocus() or input.mouseMode~=MM_RELATIVE then self:Release();return end
    self:Sample({dx=input.mouseMoveX,dy=input.mouseMoveY,left=input:GetMouseButtonDown(MOUSEB_LEFT),
        right=input:GetMouseButtonDown(MOUSEB_RIGHT),middle=input:GetMouseButtonDown(MOUSEB_MIDDLE),wheel=input:GetMouseMoveWheel()},dt)
end
return M
