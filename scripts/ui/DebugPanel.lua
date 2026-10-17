-- Existing debug commands, opened from the shared settings card.
local TouchMode=require("controls.TouchMode")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Actions=require 'app.DebugActions'
local Page=UI.Widget:Extend('VoxDebugPanel')
local M={};M.__index=M
local cyan={110,214,255,255};local white={219,231,239,255};local muted={159,179,194,255};local ink={4,14,24,235}
local function Inside(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
local function ValidPosition(p) return type(p)=='table' and type(p[1])=='number' and type(p[2])=='number' and p[1]>=0 and p[1]<=1 and p[2]>=0 and p[2]<=1 end
function M.New(app)
    local self=setmetatable({},M);self:init(app);return self
end
function M:init(app)
    self.app=app;self.open=false;self.disposed=false;self.scroll=0;self.maxScroll=0;self.fps=60;self.clock=0;self.refresh=0
    self.state={god=false};self.buttons={};self.savedPosition=app.store:Read('debug-position',ValidPosition)
    self.page=Page{pointerEvents='auto',focusable=false};self.page.owner=self
    UI.RegisterGlobalComponent('vox-debug',self.page)
    self:Refresh();print('[Debug] 设置 → 调试 / 性能')
end
function M:OpenSettings(owner,onClose)
    self.settingsOwner=owner;self.settingsGeneration=self.app.generation;self.onSettingsClose=onClose;self:SetOpen(true)
end
function M:CloseSettings()
    local owner,close,generation=self.settingsOwner,self.onSettingsClose,self.settingsGeneration
    self:SetOpen(false)
    if close and owner and not owner.disposed and generation==self.app.generation and
        (owner==self.app.trial or owner==self.app.build or not self.app.trial and not self.app.build) then close() end
end
function M:Refresh()
    self.sections,self.contextName,self.context=Actions.Sections(self.app,self.state)
    self.status=Actions.Status(self.app,self.fps,self.state);self.refresh=0
end
function M:SetOpen(on)
    if self.disposed then return end
    self.open=on;self.drag=nil
    if not on then
        UI.PopOverlay(self.page);self.settingsOwner=nil;self.settingsGeneration=nil;self.onSettingsClose=nil
    end
    if on then
        UI.ClearFocus();if self.app.trial then self.app.trial:Pause() end
        if self.app.build and self.app.build.buildCamera then self.app.build.buildCamera:Release() end
        input.mouseMode=MM_ABSOLUTE;self:Refresh()
        UI.PopOverlay(self.page);UI.PushOverlay(self.page)
    end
end
function M:Update(dt)
    if self.disposed then return end
    local elapsed=math.max(0,dt);self.clock=self.clock+elapsed;self.refresh=self.refresh+elapsed
    if dt>0 then self.fps=self.fps+(1/dt-self.fps)*.05 end
    -- The QA bootstrap owns F8 for compact snapshots, never user debug actions.
    local qa=rawget(_G,'VOX_SKIP_TUTORIAL')==true and rawget(_G,'VOX_CLOUD_VALIDATION')==true
    if not qa and input:GetKeyPress(KEY_F8) then if self.open then self:CloseSettings() else self:SetOpen(true) end end
    Actions.Update(self.app,self.state,elapsed)
    if self.open and self.refresh>=.25 then
        local context=Actions.Context(self.app);if context~=self.context then self.scroll=0 end;self:Refresh()
    end
end
function M:Activate(id)
    local keepOpen=id=='perfVisible' or id=='perfMark'
    if not keepOpen then self:SetOpen(false) end
    local ok,result,err=pcall(Actions.Execute,self.app,self.state,id)
    if not ok or result==false then
        local message=not ok and tostring(result) or err or '当前状态不能执行此操作'
        self.app.toasts:Push('[调试] '..message,'bad');self:SetOpen(true)
    end
    self:Refresh()
end
function M:Layout()
    local w,h=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets();local bw,bh=70,44
    local touch=TouchMode.Enabled()
    local x,y=w-math.max(12,safe.right or 0)-bw,64+(safe.top or 0)
    if touch then x=math.max(12,safe.left or 0);y=h/2-bh/2 end
    if self.savedPosition then x=self.savedPosition[1]*w;y=self.savedPosition[2]*h end
    if self.dragPosition then x=self.dragPosition[1];y=self.dragPosition[2] end
    x=math.max(4,math.min(w-bw-4,x));y=math.max(4,math.min(h-bh-4,y))
    self.toggleRect={x=x,y=y,w=bw,h=bh}
    local left=math.max(12,safe.left or 0);local right=w-math.max(12,safe.right or 0)
    -- Leave the existing performance panel accessible even after toggling it on.
    if self.app.performanceControls then right=right-math.max(1,math.min(274,w*.44-math.max(12,safe.right or 0)))-12 end
    local pw=math.max(1,math.min(330,right-left));local ph=math.min(760,h-math.max(12,safe.top or 0)-math.max(12,safe.bottom or 0))
    self.panelRect={x=math.max(left,math.min((w-pw)/2,right-pw)),y=math.max(12,(h-ph)/2),w=pw,h=ph}
    return w,h
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest(x,y)
    local o=self.owner;if o.disposed then return false end;o:Layout()
    return o.open and Inside(o.panelRect,x,y)
end
function Page:OnPointerDown(e)
    local o=self.owner;o:Layout()
    o.drag={id=e.pointerId,kind=e.pointerType,x=e.x,y=e.y,dx=e.x-o.toggleRect.x,dy=e.y-o.toggleRect.y,
        toggle=false,scroll=o.scroll,moved=false}
    return true
end
function Page:OnPointerMove(e)
    local o=self.owner;local drag=o.drag;if not drag or drag.id~=e.pointerId then return true end
    local dx,dy=e.x-drag.x,e.y-drag.y
    if not drag.moved and dx*dx+dy*dy<36 then return true end;drag.moved=true
    if drag.toggle then o.dragPosition={e.x-drag.dx,e.y-drag.dy};o:Layout()
    else o.scroll=math.max(0,math.min(o.maxScroll,drag.scroll-dy)) end;return true
end
function Page:OnPointerUp(e)
    local o=self.owner;local drag=o.drag;if not drag or drag.id~=e.pointerId then return true end
    o.drag=nil;o.suppressClickUntil=o.clock+.4
    if drag.moved then
        if drag.toggle then local w,h=o:Layout();local r=o.toggleRect;o.savedPosition={r.x/w,r.y/h};o.dragPosition=nil
            local ok,err=o.app.store:Write('debug-position',o.savedPosition,ValidPosition);if not ok then o.app.toasts:Push('[调试] '..tostring(err),'bad') end
        end
    elseif drag.toggle then o:SetOpen(not o.open)
    else self:ActivateAt(e.x,e.y) end
    return true
end
function Page:OnPointerCancel() self.owner.drag=nil;return true end
function Page:ActivateAt(x,y)
    local o=self.owner
    for _,row in ipairs(o.buttons) do if Inside(row,x,y) then if row.id=='close' then o:CloseSettings() else o:Activate(row.id) end;return true end end
    return true
end
function Page:OnClick(e)
    local o=self.owner;if o.clock<(o.suppressClickUntil or 0) then return true end
    if e then self:ActivateAt(e.x,e.y) end;return true
end
function Page:OnWheel(_,dy)
    local amount=GetPlatform and GetPlatform()=='Web' and .4 or 40
    local o=self.owner;if o.open then o.scroll=math.max(0,math.min(o.maxScroll,o.scroll-dy*amount)) end;return true
end
function Page:Render(vg)
    local o=self.owner;if o.disposed or not o.open then return end
    D.Begin(vg);o:Layout();o.buttons={}
    local p=o.panelRect;D.Rect(vg,p.x,p.y,p.w,p.h,ink)
    D.Rect(vg,p.x,p.y,p.w,1,{214,240,255,71})
    D.Text(vg,'DEBUG',p.x+16,p.y+10,15,cyan,'vox-display')
    D.Text(vg,o.contextName,p.x+85,p.y+12,12,white,'vox-title')
    D.Text(vg,'×',p.x+p.w-25,p.y+8,20,white,'vox-body')
    o.buttons[1]={id='close',x=p.x+p.w-36,y=p.y,w=36,h=34}
    local top=p.y+38
    for _,line in ipairs(o.status) do D.Text(vg,line,p.x+16,top,11,muted,'vox-code');top=top+18 end
    top=top+8;local contentTop=top
    nvgSave(vg);nvgIntersectScissor(vg,p.x,contentTop,p.w,p.y+p.h-contentTop)
    local y=contentTop-o.scroll
    for _,section in ipairs(o.sections) do
        D.Rect(vg,p.x+12,y,p.w-24,1,{110,214,255,31});y=y+9
        D.Text(vg,section.title,p.x+16,y,13,white,'vox-title');y=y+24
        local x=p.x+16;local last=0
        for _,button in ipairs(section.buttons) do
            local bw=math.min(p.w-32,D.Width(vg,button.label,12,'vox-title')+18)
            if x>p.x+16 and x+bw>p.x+p.w-12 then x=p.x+16;y=y+31 end
            if y+26>=contentTop and y<=p.y+p.h then
                D.Rect(vg,x,y,bw,26,{110,214,255,26});D.Rect(vg,x,y,bw,1,{110,214,255,77})
                local size=12;while size>8 and D.Width(vg,button.label,size,'vox-title')>bw-12 do size=size-1 end
                D.Text(vg,button.label,x+8,y+(26-size)/2,size,white,'vox-title')
                if y>=contentTop and y+26<=p.y+p.h then o.buttons[#o.buttons+1]={id=button.id,x=x,y=y,w=bw,h=26} end
            end
            x=x+bw+5;last=31
        end
        y=y+last+10
    end
    nvgRestore(vg)
    local viewport=p.y+p.h-contentTop;o.maxScroll=math.max(0,y+o.scroll-contentTop-viewport);o.scroll=math.min(o.scroll,o.maxScroll)
    if o.maxScroll>0 then
        local thumb=math.max(16,viewport*viewport/(viewport+o.maxScroll));local sy=contentTop+(viewport-thumb)*o.scroll/o.maxScroll
        D.Rect(vg,p.x+p.w-4,sy,2,thumb,{70,200,255,85})
    end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.open=false;self.settingsOwner=nil;self.onSettingsClose=nil
    if self.drag then UI.CancelPointer(self.drag.id,self.drag.kind);self.drag=nil end
    UI.PopOverlay(self.page);UI.UnregisterGlobalComponent('vox-debug');self.page:Destroy();self.app=nil
end
return M
