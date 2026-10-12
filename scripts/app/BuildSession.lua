-- Composition boundary: pure commands -> incremental view, bounded ghost,
-- native input/UI and debounced storage. The app retains the editor across scenes.
local UI=require 'urhox-libs/UI'
local Ghost=require 'render.BuildGhost'
local Controls=require 'controls.BuildInput'
local Hud=require 'ui.BuildHud'
local Config=require 'Config'
local M={};M.__index=M
function M.New(app)
    local self=setmetatable({app=app,editor=app.editor,camera=app.camera,car=app.car,slot=app.bays.active or 1,message='',disposed=false,refreshTime=0},M)
    self.controls=Controls.New(self);self.ghost=Ghost.New(app.scene);self.camera.autoSpin=false
    self.inspection=require('app.BuildInspection').New(self)
    self.buildCamera=require('controls.BuildCamera').New(self)
    app.inventory=app.inventory or require('construction.Inventory').New(app.store:LoadBuildSettings())
    self.inventory=app.inventory
    self:ApplyHotbar()
    self.car.root.position=Vector3.ZERO
    if self.buildCamera.touch then self.buildCamera:Focus() end
    self.car:SetXray(app.buildXray==true)
    self.hud=Hud.Create(self);self:Refresh();return self
end
function M:ApplyHotbar()
    local type=self.inventory:Current()
    if type then self.editor:SelectType(type) else self.editor.emptySlot=true;self.editor.preview=nil end
    self.controls:Cancel()
end
function M:SaveSettings()
    local ok,err=self.app.store:SaveBuildSettings(self.inventory:Settings())
    if not ok then self:Notify(err,'bad') end
end
function M:Notify(text,kind)
    self.message=text or ''
    self.app.toasts:Push(self.message,kind)
end
function M:SelectHotbar(slot) self.selecting=false;self.inventory:Select(slot);self:ApplyHotbar();self:SaveSettings() end
function M:AssignHotbar(slot,type) self.inventory:Assign(slot,type);self:ApplyHotbar();self:SaveSettings() end
function M:PickHotbar(type) self.inventory:Pick(type);self:ApplyHotbar();self:SaveSettings() end
function M:ClearHotbar(slot) self.inventory:Clear(slot);self:ApplyHotbar();self:SaveSettings() end
function M:OpenInventory()
    if self.dialog then return end
    return require('ui.InventoryPanel').Open(self)
end
function M:OpenLibrary(mode) return require('ui.BlueprintLibrary').Open(self,mode) end
function M:OpenPause() return require('ui.PauseMenu').Open(self) end
function M:ToggleXray()
    self.app.buildXray=not self.app.buildXray;self.car:SetXray(self.app.buildXray);self:Refresh()
end
function M:Escape()
    self.controls:Cancel()
    if self.buildCamera.captured then self.buildCamera:Release();self:Refresh();return end
    if self.dialog then self.dialog:Close()
    elseif self.inventoryPanel then self.inventoryPanel:Close()
    elseif self.hud.colorOpen then self.hud.SetColor(false)
    elseif self.editor.pasting then self.editor.pasting=false;self.editor.preview=nil
    elseif next(self.editor.selection) then self.editor.selection={}
    else self:OpenPause() end
    self:Refresh()
end
function M:Trace(x,y)
    local width,height=UI.GetViewportSize()
    if self.buildCamera.mode=='fp' then x,y=width*.5,height*.5 end
    local ray=self.camera.camera:GetScreenRay(x/math.max(1,width),y/math.max(1,height))
    local p,d=ray.origin,ray.direction;local f=self.camera.node.rotation*Vector3.FORWARD
    self.editor.forward={-f.x,0,f.z}
    self.editor:Trace({-p.x,p.y,p.z},{-d.x,d.y,d.z})
end
function M:MoveSelection(forward,right,up)
    local f=self.camera.node.rotation*Vector3.FORWARD
    local axis=require('core.Rotations').SnapDir(-f.x,0,f.z);local x,z=axis[1],axis[3]
    return self.editor:MoveSelection({x*forward-z*right,up,z*forward+x*right})
end
function M:Wheel(delta)
    if self.dialog or self.inventoryPanel then return end
    if input:GetKeyDown(KEY_SHIFT) or input:GetKeyDown(KEY_CTRL) then
        if self.buildCamera.mode=='orbit' then self.camera.dist=math.max(self.camera.minDist,math.min(self.camera.maxDist,self.camera.dist*(1-delta*.1))) end
    elseif self.editor.tool=='paint' then self.editor.paintChannel=self.editor.paintChannel=='shell' and 'accent' or 'shell'
    else
        local direction=delta>0 and -1 or 1
        for i=1,10 do local slot=(self.inventory.active-1+direction*i)%10+1
            if self.inventory.hotbar[slot] then self:SelectHotbar(slot);break end
        end
    end
end
function M:Refresh()
    if self.disposed then return end
    self.inspection:Get()
    if not self.editor.emptySlot and self.editor.type~=self.inventory:Current() then self.inventory:Pick(self.editor.type);self:SaveSettings() end
    if self.inventoryPanel or self.dialog then self.controls:Cancel() end
    if self.controls.inside then self:Trace(self.controls.x,self.controls.y) end
    self.ghost:Refresh(self.editor,self.controls.inside and not self.selecting)
    self.hud.Refresh();self.editor.dirty=false
end
function M:BoxSelect(rect)
    local width,height=UI.GetViewportSize()
    self.editor:BoxSelect(rect,function(c)
        local world=Vector3(-c[1]*Config.CELL,(c[2]+.5)*Config.CELL,c[3]*Config.CELL)
        local projected=self.camera.camera:WorldToScreenPoint(world)
        local forward=self.camera.node.worldRotation*Vector3.FORWARD
        return projected.x*width,projected.y*height,(world-self.camera.node.worldPosition):DotProduct(forward)>0
    end)
end
function M:Act()
    if self.dialog or self.inventoryPanel or self.hud.colorOpen then return false end
    local ok,err=self.editor:Act()
    if not ok and err then self:Notify(err,'bad') elseif ok then self.message='' end
    self:Refresh();return ok
end
function M:SaveSlot()
    local ok,err,reason=self.app.bays:Save()
    if ok then self.slot=self.app.bays.active end
    self:Notify(ok and ('已保存到车位 '..self.slot) or err,ok and 'ok' or 'bad')
    self.app.store:Flush()
    if not ok and reason=='full' then self:OpenLibrary('save') end
    return ok,err
end
function M:LoadSlot()
    local ok,err=self.app.bays:Restore(self.slot)
    require('ui.DialogHost').Notify(self,ok and ('已读取车位 '..self.slot) or err)
    return ok,err
end
function M:Keys()
    if self.dialog then if input:GetKeyPress(KEY_ESCAPE) then self:Escape() end;return end
    if self.inventoryPanel then self.inventoryPanel:Keys();return end
    local focus=UI.GetFocus();if focus and focus.OnTextInput and focus~=self.hud.playfield then return end
    local e=self.editor;local ctrl=input:GetKeyDown(KEY_CTRL);local shift=input:GetKeyDown(KEY_SHIFT)
    local function Press(k) return input:GetKeyPress(k) end
    if ctrl then
        if Press(KEY_Z) then if shift then e:Redo() else e:Undo() end end
        if Press(KEY_Y) then e:Redo() end
        if Press(KEY_A) then e:SelectAll() end
        if Press(KEY_C) then e:Copy() end
        if Press(KEY_V) then e:StartPaste() end
        if Press(KEY_S) then self:SaveSlot() end
    else
        for i,k in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}) do if Press(k) then self:SelectHotbar(i) end end
        if Press(KEY_TAB) then self.hud.SetColor(false);self.buildCamera:Toggle();self:Refresh();return end
        if Press(KEY_F) then self:Notify('连块功能尚未迁移','bad') end
        if Press(KEY_L) then self.buildCamera:Focus() end
        if Press(KEY_V) then self:ToggleXray() end
        if Press(KEY_R) then if input:GetKeyDown(KEY_ALT) then e:Tilt(shift and -1 or 1) else e:Rotate(shift and -1 or 1) end end
        if Press(KEY_M) then e.mirror=not e.mirror end
        if Press(KEY_P) then self.controls:Cancel();e:SetTool(e.tool=='paint' and 'build' or 'paint') end
        if Press(KEY_X) then self.controls:Cancel();e:SetTool(e.tool=='erase' and 'build' or 'erase') end
        if Press(KEY_Q) then self.controls:Cancel();self.selecting=not self.selecting;e:SetTool('build') end
        if Press(KEY_C) and e:Eyedrop(e.hit) then self.controls:Cancel();e:SetTool('paint') end
        if Press(KEY_B) then self:OpenInventory();return end
        if Press(KEY_H) or Press(KEY_F1) then require('ui.GarageDialogs').Help(self);return end
        if Press(KEY_G) and self.inventory:CycleBlock() then self:ApplyHotbar();self:SaveSettings() end
        if Press(KEY_DELETE) or Press(KEY_BACKSPACE) then if next(e.selection) then e:DeleteSelection() else e:Remove() end end
        if Press(KEY_PAGEUP) then if next(e.selection) then self:MoveSelection(0,0,1) else e:Lift(1) end end
        if Press(KEY_PAGEDOWN) then if next(e.selection) then self:MoveSelection(0,0,-1) else e:Lift(-1) end end
        if Press(KEY_LEFT) then self:MoveSelection(0,-1,0) end
        if Press(KEY_RIGHT) then self:MoveSelection(0,1,0) end
        if Press(KEY_UP) then self:MoveSelection(1,0,0) end
        if Press(KEY_DOWN) then self:MoveSelection(-1,0,0) end
        if Press(KEY_ESCAPE) then self:Escape() end
    end
end
function M:Update(dt)
    if self.disposed then return end
    require('controls.TouchMode').Update('build')
    require('ui.DialogHost').Update(self,dt)
    local width,height=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets();local old=self.hud.safe
    if width~=self.hud.width or height~=self.hud.height or safe.left~=old.left or safe.right~=old.right or safe.top~=old.top or safe.bottom~=old.bottom then
        -- UI-only replacement: keep blueprint/history/camera and modal drafts.
        self.buildCamera:Release();self.controls:Cancel()
        local colorOpen=self.hud.colorOpen;local viewState=self.hud.ViewState();local inventory=self.inventoryPanel
        local inventoryState=inventory and inventory:ViewState()
        if inventory then inventory:Close() end
        -- Modal auto-mounts under the current HUD root. Detach it before that
        -- root is destroyed, then reattach the same tree to preserve drafts.
        local dialog=self.dialog;local focus=UI.GetFocus()
        if dialog and dialog.parent then dialog.parent:RemoveChild(dialog) end
        self.hud.Dispose();self.hud=Hud.Create(self);self.hud.RestoreView(viewState);self.hud.SetColor(colorOpen)
        if dialog then
            self.hud.root:AddChild(dialog);dialog.autoMountParent_=self.hud.root
            if focus and focus.node then UI.SetFocus(focus) end
        end
        if inventory then require('ui.InventoryPanel').Open(self,inventoryState) end
        self:Refresh()
        return -- Do not reuse presses/deltas sampled before the resize.
    end
    local hadDialog=self.dialog~=nil
    if self.dialog then self.controls:Cancel();if self.dialogTick then self.dialogTick(dt) end
    elseif self.inventoryPanel then self.controls:Cancel();self.inventoryPanel:Update(dt)
    elseif self.hud.colorOpen then self.controls:Cancel() else self.controls:Update(dt) end
    -- A dialog closing on H consumes the press before normal build shortcuts.
    if input.focus and not input.minimized and (not hadDialog or self.dialog) then self:Keys() end
    local focus=UI.GetFocus();self.buildCamera:Update(dt,self.dialog or self.inventoryPanel or self.hud.colorOpen or focus and focus.OnTextInput~=nil)
    -- Picking and ghost geometry are capped at 30 Hz; shaders animate on GPU.
    self.refreshTime=self.refreshTime+dt
    if self.editor.dirty or self.refreshTime>=1/30 then self.refreshTime=0;self:Refresh() end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    require('ui.DialogHost').Dispose(self)
    if self.inventoryPanel then self.inventoryPanel:Close() end
    require('ui.VoxTheme').TrimThumbnails({})
    self.buildCamera:Dispose()
    self.car:SetXray(false)
    self.controls:Cancel();self.ghost:Dispose();self.app.store:Flush()
    self.inspection:Dispose()
    if self.hud then self.hud.Dispose() end
end
return M
