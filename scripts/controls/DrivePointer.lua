-- PC source pointer-lock semantics. Sampling is separate from the OS adapter so
-- capture edges, right-click toggle/hold, and focus loss can be replayed exactly.
local M={};M.__index=M
local Platform=require 'urhox-libs.Platform.PlatformUtils'
function M.New(session) return setmetatable({session=session,web=Platform.IsWebPlatform(),captured=false,pending=false,lockWait=0,ready=false,skip=false,right=false,scopeHold=false,heldTime=0},M) end
function M:SetMouseMode(mode) input.mouseMode=mode end
function M:Capture()
    local s=self.session;if s.disposed or s.dialog then return false end
    if self.pending or self.captured then return true end
    -- Browser pointer lock completes after this click handler, often on the
    -- next frame. Do not enable driving or treat the old mode as lock loss.
    self.pending=self.web and not s.touch;self.lockWait=0
    s.controls:Clear();self.captured=not self.pending;self.ready=false;self.skip=true;self.right=false;self.heldTime=0
    if not s.touch then self:SetMouseMode(MM_RELATIVE) end;return true
end
function M:Release()
    if (self.captured or self.pending) and not self.session.touch then self:SetMouseMode(MM_ABSOLUTE) end
    self.captured=false;self.pending=false;self.lockWait=0;self.ready=false;self.right=false;self.scopeHold=false;self.heldTime=0
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
    if self.pending then
        if not self.session:HasFocus() or self.session.disposed or self.session.dialog then self:Release();return end
        if input.mouseMode==MM_RELATIVE and input.mouseLocked then
            self.pending=false;self.captured=true;self.ready=false;self.skip=true
        else
            self.lockWait=self.lockWait+dt
            -- A denied/cooldown request must leave the overlay clickable. A
            -- new click retries; never request lock automatically from Update.
            if self.lockWait>=2 then self:Release() end
            return
        end
    end
    if not self.captured then return end
    if self.session.touch then
        if not self.session:HasFocus() then self:Release() end
        return
    end
    if not self.session:HasFocus() or input.mouseMode~=MM_RELATIVE or (self.web and not input.mouseLocked) then self:Release();return end
    self:Sample({dx=input.mouseMoveX,dy=input.mouseMoveY,left=input:GetMouseButtonDown(MOUSEB_LEFT),
        right=input:GetMouseButtonDown(MOUSEB_RIGHT),middle=input:GetMouseButtonDown(MOUSEB_MIDDLE),wheel=input:GetMouseMoveWheel()},dt)
end
return M
