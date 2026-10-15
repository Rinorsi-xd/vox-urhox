-- PC source pointer-lock semantics. Sampling is separate from the OS adapter so
-- capture edges, right-click toggle/hold, and focus loss can be replayed exactly.
local M={};M.__index=M
local Platform=require 'urhox-libs.Platform.PlatformUtils'
function M.New(session) return setmetatable({session=session,web=Platform.IsWebPlatform(),captured=false,pending=false,lockWait=0,ready=false,skip=false,right=false,scopeHold=false,heldTime=0},M) end
function M:SetMouseMode(mode) input.mouseMode=mode end
function M:Listen()
    if self.session.touch or self.eventNode then return end
    self.eventNode=Node()
    local receiver=self.eventNode:CreateScriptObject('LuaScriptObject')
    receiver:SubscribeToEvent('MouseButtonDown',function(_,_,data) self:Button(data:GetInt('Button'),true,Time:GetSystemTime()) end)
    receiver:SubscribeToEvent('MouseButtonUp',function(_,_,data) self:Button(data:GetInt('Button'),false,Time:GetSystemTime()) end)
end
function M:Button(button,down,now)
    local s=self.session
    if not self.captured or self.skip or not self.ready or s.disposed or s.dialog or not s:HasFocus() then return end
    if input.mouseMode~=MM_RELATIVE or self.web and not input.mouseLocked then return end
    if button==MOUSEB_LEFT then s.controls.held.fire=down;return end
    if button~=MOUSEB_RIGHT then return end
    if down and not self.right then
        self.scopeHold=not s.scope;self.scopeAt=now;self.heldTime=0;s.scope=not s.scope
    elseif not down and self.right then
        if self.scopeHold and now-(self.scopeAt or now)>250 then s.scope=false end
        self.scopeHold=false;self.scopeAt=nil;self.heldTime=0
    end
    self.right=down
end
function M:Capture()
    local s=self.session;if s.disposed or s.dialog then return false end
    if self.pending or self.captured then return true end
    if self.web and not s.touch and input.mouseLocked and input.mouseMode~=MM_RELATIVE then
        self:SetMouseMode(MM_ABSOLUTE);return false
    end
    -- Browser pointer lock completes after this click handler, often on the
    -- next frame. Do not enable driving or treat the old mode as lock loss.
    self.pending=self.web and not s.touch;self.lockWait=0
    s.controls:Clear();self.captured=not self.pending;self.ready=false;self.skip=true;self.right=false;self.scopeHold=false;self.scopeAt=nil;self.heldTime=0
    self:Listen()
    if not s.touch then self:SetMouseMode(MM_RELATIVE) end;return true
end
function M:Release()
    if self.eventNode then self.eventNode:Dispose();self.eventNode=nil end
    if (self.captured or self.pending) and not self.session.touch then self:SetMouseMode(MM_ABSOLUTE) end
    self.captured=false;self.pending=false;self.lockWait=0;self.ready=false;self.right=false;self.scopeHold=false;self.scopeAt=nil;self.heldTime=0
    local s=self.session;s.scope=false;s.firing=false;s.controls:Clear()
    if s.touch and s.hud then s.hud.Clear() end
end
function M:Suppress() self.ready=false;self.right=false;self.scopeHold=false;self.scopeAt=nil;self.heldTime=0;self.session.controls:Clear() end
function M:Sample(sample,dt)
    if not self.captured then return end
    if self.skip then self.skip=false;return end
    if not self.ready then self.ready=not (sample.left or sample.right or sample.middle);return end
    local s=self.session;s.controls:Look(sample.dx or 0,sample.dy or 0);s.controls.held.fire=sample.left==true
    if sample.wheel and sample.wheel~=0 then s:Zoom(sample.wheel) end
    -- Real input edges preserve clicks that begin/end between rendered frames.
    -- Sample-only callers keep their deterministic replay path.
    if not self.eventNode then
        if sample.right and not self.right then
            self.scopeHold=not s.scope;self.heldTime=0;s.scope=not s.scope
        elseif sample.right then self.heldTime=self.heldTime+dt
        elseif self.right and self.scopeHold and self.heldTime+dt>.25 then s.scope=false end
        self.right=sample.right==true
    end
end
function M:Poll(dt)
    if self.pending then
        if not self.session:HasFocus() or self.session.disposed or self.session.dialog then self:Release();return end
        if input.mouseMode==MM_RELATIVE and input.mouseLocked then
            self.pending=false;self.captured=true;self.ready=false;self.skip=true
        else
            -- Count responsive processing time: a blocked browser frame must
            -- not cancel its own still-undelivered pointer-lock completion.
            self.lockWait=self.lockWait+math.min(.1,math.max(0,dt))
            -- A denied/cooldown request must leave the overlay clickable. A
            -- new click retries; never request lock automatically from Update.
            if self.lockWait>=2 then self:Release() end
            return
        end
    end
    if not self.captured then
        if self.web and not self.session.touch and input.mouseMode==MM_RELATIVE and input.mouseLocked then self:SetMouseMode(MM_ABSOLUTE) end
        return
    end
    if self.session.touch then
        if not self.session:HasFocus() then self:Release() end
        return
    end
    if not self.session:HasFocus() or input.mouseMode~=MM_RELATIVE or (self.web and not input.mouseLocked) then self:Release();return end
    self:Sample({dx=input.mouseMoveX,dy=input.mouseMoveY,left=input:GetMouseButtonDown(MOUSEB_LEFT),
        right=input:GetMouseButtonDown(MOUSEB_RIGHT),middle=input:GetMouseButtonDown(MOUSEB_MIDDLE),wheel=input:GetMouseMoveWheel()},dt)
end
return M
