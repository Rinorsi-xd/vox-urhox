-- Match DOM button activation without changing the engine's pointer ownership.
local Base=require 'urhox-libs/UI/Widgets/Button'
local UI=require 'urhox-libs/UI'
local Button=Base:Extend('VoxActionButton')
local consumed={}

local function ActivationKey(key) return key==KEY_RETURN or key==KEY_KP_ENTER or key==KEY_SPACE end
function Button:KeyboardRoot()
    if UI.GetFocus()~=self or not input.focus or input.minimized then return nil end
    local widget=self;local scope=nil ---@type table|nil
    while widget do
        if widget.props and widget.props.visible==false then return nil end
        if widget.actionButtonKeys then scope=widget end
        widget=widget.parent
    end
    if scope and scope==UI.GetRoot() and scope.actionButtonKeys() then return scope end
    return nil
end
function Button.HasKeyboardFocus(widget)
    return widget and type(widget.KeyboardRoot)=='function' and widget:KeyboardRoot()~=nil
end
function Button.KeyConsumed(key)
    if not consumed[key] then return false end
    -- KeyDown callbacks precede App.Update and can belong to the previous frame.
    -- Keep ownership until both the physical hold and its polling pulse clear.
    local pressed=input:GetKeyPress(key)
    if not input:GetKeyDown(key) and not pressed then consumed[key]=nil end
    return pressed
end
function Button:CancelKeyboardPress()
    if not self.keyboardSpace then return end
    self.keyboardSpace=false;self:SetState({pressed=false});self:TransitionToStateBgColor()
end
function Button:OnKeyDown(key)
    if not ActivationKey(key) or not self:KeyboardRoot() then return end
    consumed[key]=true
    if self.props.disabled then self:CancelKeyboardPress();return true end
    if key==KEY_SPACE then
        if not self.keyboardSpace then
            self.keyboardSpace=true;self:SetState({pressed=true});self:TransitionToStateBgColor()
        end
    else
        self:OnClick(nil)
    end
    return true
end
function Button:OnKeyUp(key)
    if key~=KEY_SPACE then return end
    local pressed=self.keyboardSpace
    self:CancelKeyboardPress()
    if pressed and self:KeyboardRoot() and not self.props.disabled then
        consumed[key]=true;self:OnClick(nil);return true
    end
end
function Button:OnBlur()
    self:CancelKeyboardPress()
    return Base.OnBlur(self)
end
function Button:OnPointerDown(event)
    if event and event:IsPrimaryAction() then self:CancelKeyboardPress() end
    return Base.OnPointerDown(self,event)
end

function Button:OnClick(event)
    -- Keyboard and programmatic activation have no PointerEvent.
    if event and type(event.IsPrimaryAction)=='function' and not event:IsPrimaryAction() then return end
    return Base.OnClick(self,event)
end

return Button
