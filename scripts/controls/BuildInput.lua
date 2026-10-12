-- Pointer ownership originates on the playfield. No global mouse-down editing;
-- cancellation, leaving the field, focus loss and scene switches release holds.
local M={};M.__index=M
function M.New(session) return setmetatable({session=session,pointer=nil,inside=false,dirty=true},M) end
function M:Cancel() self.pointer=nil;self.inside=false;self.dirty=true;self.selectionBox=nil end
function M:Position(e)
    if self.session.dialog or self.session.inventoryPanel then self:Cancel();return end
    self.x,self.y=e.x,e.y;self.inside=true;self.dirty=true
end
function M:Down(e)
    if self.session.dialog or self.session.inventoryPanel then self:Cancel();return end
    local fly=self.session.buildCamera
    if fly.mode=='fp' then
        if not fly.captured then fly:Capture();return end
        if not fly.touch then return end
    end
    self:Position(e)
    if self.pointer then self:Cancel();return end
    self.session:Trace(e.x,e.y)
    local kind=e:IsTouch() and 'left' or e:IsSecondaryButton() and 'right' or e:IsPrimaryButton() and 'left' or 'middle'
    self.pointer={id=e.pointerId,kind=kind,x=e.x,y=e.y,startX=e.x,startY=e.y,travel=0,held=0,nextRepeat=.3,touch=e:IsTouch(),select=input:GetKeyDown(KEY_SHIFT) or self.session.selecting,orbit=kind=='left' and input:GetKeyDown(KEY_SPACE)}
    self.pointer.add=input:GetKeyDown(KEY_CTRL)
    if self.pointer.orbit then self.pointer.select=false end
    -- Desktop left paints/builds immediately; touch waits to distinguish a tap
    -- from orbiting. Holding follows source 300 ms then 100 ms repeat cadence.
    if kind=='left' and not e:IsTouch() and not self.pointer.select and not self.pointer.orbit then self.session:Act() end
end
function M:Move(e)
    if self.session.dialog or self.session.inventoryPanel then self:Cancel();return end
    self:Position(e);local p=self.pointer
    if not p or p.id~=e.pointerId then return end
    local dx,dy=e.x-p.x,e.y-p.y;p.x,p.y=e.x,e.y;p.travel=p.travel+math.abs(dx)+math.abs(dy)
    local fly=self.session.buildCamera
    if fly.mode=='fp' then if fly.touch then fly.dx=fly.dx+dx;fly.dy=fly.dy+dy end;return end
    if p.select and p.kind=='left' then
        self.selectionBox={x0=p.startX,y0=p.startY,x1=e.x,y1=e.y,add=p.add};return
    end
    if p.kind=='right' or p.kind=='middle' or p.orbit or p.touch and p.travel>=8 then
        local camera=self.session.camera
        if p.kind=='middle' or input:GetKeyDown(KEY_SHIFT) then
            local rot=Quaternion(camera.cur.pitch,camera.cur.yaw,0);local scale=camera.dist*.0016
            camera.target=camera.target-rot*Vector3.RIGHT*(dx*scale)+rot*Vector3.UP*(dy*scale)
        else camera.yaw=camera.yaw+dx*.25;camera.pitch=math.max(-65,math.min(85,camera.pitch+dy*.2)) end
    end
end
function M:Up(e)
    if self.session.dialog or self.session.inventoryPanel then self:Cancel();return end
    if self.session.buildCamera.mode=='fp' and not self.session.buildCamera.touch then return end
    local p=self.pointer;if not p or p.id~=e.pointerId then return end
    self.pointer=nil;self:Position(e);self.session:Trace(e.x,e.y)
    if p.select and p.kind=='left' and p.travel>=8 then
        self.session:BoxSelect({x0=p.startX,y0=p.startY,x1=e.x,y1=e.y,add=p.add})
    elseif p.travel<8 then
        local editor=self.session.editor
        if p.select and p.kind=='left' then if editor.hit then editor:ToggleSelect(editor.hit.partId) end
        elseif p.kind=='right' and editor.tool~='paint' then editor:Remove()
        elseif p.kind=='middle' then if editor.tool=='paint' then editor:Eyedrop(editor.hit) else editor:Pick(editor.hit) end
        elseif p.touch then self.session:Act() end
    end
    self.selectionBox=nil
    self.session:Refresh()
end
function M:FirstPerson(dt)
    local fly=self.session.buildCamera;local e=self.session.editor
    local UI=require 'urhox-libs/UI';local w,h=UI.GetViewportSize()
    self.x,self.y=w*.5,h*.5;self.inside=fly.captured
    if not fly.captured or fly.touch then return end
    if not fly.buttonsReady then
        fly.buttonsReady=not (input:GetMouseButtonDown(MOUSEB_LEFT) or input:GetMouseButtonDown(MOUSEB_RIGHT) or input:GetMouseButtonDown(MOUSEB_MIDDLE));return
    end
    self.session:Trace(self.x,self.y)
    local left,right=input:GetMouseButtonDown(MOUSEB_LEFT),input:GetMouseButtonDown(MOUSEB_RIGHT)
    if input:GetMouseButtonPress(MOUSEB_MIDDLE) then e:Pick(e.hit) end
    local kind=left and 'left' or right and e.tool~='paint' and 'right' or nil
    if not kind then self.pointer=nil;return end
    local function Act() if kind=='right' then e:Remove() else self.session:Act() end end
    if not self.pointer or self.pointer.kind~=kind then
        self.pointer={kind=kind,held=0,nextRepeat=.3}
        if left and (input:GetKeyDown(KEY_SHIFT) or self.session.selecting) then if e.hit then e:ToggleSelect(e.hit.partId) end;self.pointer.select=true else Act() end
    else
        local p=self.pointer;p.held=p.held+dt
        if not p.select and p.held>=p.nextRepeat then p.nextRepeat=p.held+.1;Act() end
    end
end
function M:Update(dt)
    if not input.focus or input.minimized then self:Cancel();return end
    if self.session.buildCamera.mode=='fp' then
        self:FirstPerson(dt)
        if self.inside and input.mouseMoveWheel~=0 then self.session:Wheel(input.mouseMoveWheel) end
        return
    end
    local p=self.pointer
    if p and p.kind=='left' and not p.touch and not p.select and not p.orbit then
        p.held=p.held+dt
        if p.held>=p.nextRepeat then
            p.nextRepeat=p.held+.1;self.session:Trace(self.x,self.y);self.session:Act()
        end
    end
    if self.inside then
        local camera=self.session.camera;local wheel=input.mouseMoveWheel
        if wheel~=0 then self.session:Wheel(wheel);self.dirty=true end
    end
end
return M
