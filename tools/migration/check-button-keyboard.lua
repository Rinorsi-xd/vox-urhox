package.path='scripts/?.lua;?.lua;'..package.path
KEY_RETURN=13;KEY_KP_ENTER=271;KEY_SPACE=32;KEY_ESCAPE=27;KEY_F=102;KEY_H=104;KEY_F1=282
MOUSEB_LEFT=0;MOUSEB_MIDDLE=1;MOUSEB_RIGHT=2
time={frameNumber=1};input={focus=true,minimized=false,keys={},held={}}
function input:GetKeyPress(key) return self.keys[key] or false end
function input:GetKeyDown(key) return self.held[key] or false end
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local Widget={};Widget.__index=Widget
assert(load('local Widget=...;'..ENGINE_EXTEND..';return Widget'))(Widget)
YGNodeNew=function()return {}end
assert(load('local Widget=...;local Style={NormalizeColorProps=function()end};local SCROLL_UPGRADEABLE_={};'..
    ENGINE_SETTERS..';'..ENGINE_NEW))(Widget)
function Widget:SetState(values) for k,v in pairs(values) do self.state[k]=v end end
local function dispatchEvent(self,name) self.notifications[name]=(self.notifications[name] or 0)+1 end
assert(load('local Widget,dispatchEvent=...;'..ENGINE_FOCUS))(Widget,dispatchEvent)
function Widget:OnPointerCancel() end
function Widget:DispatchEvent(name) self.notifications[name]=(self.notifications[name] or 0)+1 end
local UI={Panel=Widget,Button=false}
package.preload['urhox-libs/UI']=function()return UI end
package.preload['urhox-libs/UI/Core/Widget']=function()return Widget end
for _,name in ipairs({'Theme','Style','Transition','ImageCache'}) do package.preload['urhox-libs/UI/Core/'..name]=function()return {} end end
local Base=require 'urhox-libs/UI/Widgets/Button';UI.Button=Base
local PointerEvent=require 'urhox-libs/UI/Core/PointerEvent'
local root={props={},actionButtonKeys=function()return true end}
function UI.GetRoot()return root end
assert(load('local UI=...;local focusedWidget_;local enabled_=true;'..ENGINE_HANDLERS))(UI)
if TEST_ACTION_OVERRIDE then package.preload['ui.ActionButton']=assert(load(TEST_ACTION_OVERRIDE)) end
local Action=require 'ui.ActionButton'
local TestAction=Action:Extend('KeyboardTestAction')
function TestAction:Init()end
local function Instance(parent,callback)
    local b=TestAction:new({onClick=callback or function(self)self.clicks=self.clicks+1 end,
        onBlur=function(self)self.blurCallback=self.blurCallback+1 end})
    b.parent=parent or root;b.notifications={};b.clicks=0;b.blurCallback=0;b.TransitionToStateBgColor=function()end
    return b
end
local function Next()time.frameNumber=time.frameNumber+1;input.keys={} end
local function Down(key)input.keys[key]=true;input.held[key]=true;UI.HandleKeyDown(key)end
local function Up(key)input.keys[key]=nil;input.held[key]=nil;UI.HandleKeyUp(key)end
local function Focus(button)
    UI.SetFocus(button);input.held={};Next()
    for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER,KEY_SPACE})do Action.KeyConsumed(key)end
end
local function Event(button)return PointerEvent.new('PointerDown',{pointerType='mouse',button=button,isPrimary=true,pointerId=0,x=0,y=0})end
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER}) do
    local b=Instance();Focus(b)
    for i=1,4 do Down(key);Check(b.clicks==i,'Enter activates on keydown and repeats');Check(Action.KeyConsumed(key),'Enter records frame consumption');Next()end
    Up(key);Check(b.clicks==4,'Enter keyup no duplicate')
end
local b=Instance();Focus(b);Down(KEY_SPACE)
Check(b.clicks==0 and b.state.pressed,'Space arms without click')
for _=1,5 do Next();Down(KEY_SPACE);Check(b.clicks==0 and b.state.pressed,'Space repeats never click')end
Up(KEY_SPACE);Check(b.clicks==1 and not b.state.pressed and not b.keyboardSpace,'Space release activates once')
Up(KEY_SPACE);Check(b.clicks==1,'Unarmed Space up never clicks')
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER,KEY_SPACE})do
    local disabled=Instance();disabled.props.disabled=true;Focus(disabled);Down(key)
    Check(disabled.clicks==0 and Action.KeyConsumed(key),'Disabled focused button consumes without activation')
    Up(key)
end
b=Instance();Focus(b);Down(KEY_SPACE);b.props.disabled=true;Up(KEY_SPACE)
Check(b.clicks==0 and not b.state.pressed,'Disabled after Space down cancels')
b=Instance();Focus(b);Down(KEY_SPACE);UI.ClearFocus();Up(KEY_SPACE)
Check(b.clicks==0 and not b.state.pressed and b.blurCallback==1 and b.notifications.blur==1,'Native blur callback/event preserved and cancels Space')
Focus(b);Down(KEY_SPACE);input.focus=false;UI.ClearFocus();Up(KEY_SPACE);input.focus=true
Check(b.clicks==0 and not b.keyboardSpace,'Window focus loss cancels through actual ClearFocus')
for _,spec in ipairs({'hidden','detached','wrong-root','wrong-tab','unfocused','minimized','no-window-focus'})do
    local parent={props={},parent=root};b=Instance(parent);Focus(b)
    if spec=='hidden' then parent.props.visible=false
    elseif spec=='detached' then parent.parent=nil
    elseif spec=='wrong-root' then root={props={},actionButtonKeys=function()return true end}
    elseif spec=='wrong-tab' then root.actionButtonKeys=function()return false end
    elseif spec=='unfocused' then UI.ClearFocus()
    elseif spec=='minimized' then input.minimized=true
    else input.focus=false end
    Down(KEY_RETURN);Down(KEY_SPACE);Up(KEY_SPACE)
    Check(b.clicks==0,'Inactive scope does not activate '..spec)
    root={props={},actionButtonKeys=function()return true end};input.minimized=false;input.focus=true
end
for _,button in ipairs({MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT})do
    b=Instance();Focus(b);Down(KEY_SPACE);b:OnPointerDown(Event(button));b:OnPointerUp(Event(button));b:OnClick(Event(button));Up(KEY_SPACE)
    Check(b.clicks==1,'Pointer and armed keyboard activation do not double click')
end
b=Instance();Focus(b);b:OnClick(nil);Check(b.clicks==1,'Programmatic click retained')

-- Load actual GarageHud.Update; adapt only scene/layout/background dependencies.
local log={};local function Mark(name)log[#log+1]=name end
package.preload['ui.SourceButton']=function()return Action end
package.preload['ui.VoxTheme']=function()return {} end
package.preload['ui.GarageLayout']=function()return {} end
package.preload['ui.GarageDialogs']=function()return {Help=function()Mark('help')end,Close=function()Mark('close')end}end
package.preload['Config']=function()return {}end
package.preload['controls.TouchMode']=function()return {Update=function()end}end
package.preload['ui.DialogHost']=function()return {Update=function()end}end
package.preload['ui.PauseMenu']=function()return {Open=function()Mark('pause')end}end
package.preload['ui.HomeBattle']=function()return {Start=function()Mark('match')end}end
for _,name in ipairs({'Workshop','StoryPage','LiveryPage','SalvagePage'})do
    package.preload['ui.'..name]=function()return {Update=function()end,Key=function()Mark(name);return true end}end
end
function UI.GetViewportSize()return 1920,1080 end
function UI.GetSafeAreaInsets()return {}end
local Hud=require 'ui.GarageHud'
local s={tab='hangar',width=1920,height=1080,revision=1,tier=1,
    app={bays={revision=1},tier=1,EnterBuild=function()Mark('edit')end,HomeView=function()end},
    previews={Update=function()end},CancelInput=function()Mark('cancel')end,
    SetTab=function(tab)Mark(tab)end,SetNew=function()Mark('new-close')end}
for i=1,30 do local name=debug.getupvalue(Hud.Update,i);if not name then break end;if name=='state' then debug.setupvalue(Hud.Update,i,s);break end end
root={props={},actionButtonKeys=function()return s.tab=='hangar' and not s.dialog and not s.musicBox end}
local function Route(key,focus,tab)
    Next();log={};s.tab=tab or 'hangar';UI.SetFocus(focus);input.keys={[key]=true};Hud.Update(.016);return table.concat(log,',')
end
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER})do
    Check(Route(key,nil)=='edit','Unfocused Enter retains global build route')
    Check(Route(key,nil,'battle')=='match','Battle Enter retains battle start')
    b=Instance();Check(Route(key,b)=='','Focused button takes priority even if key dispatch follows Update')
    Check(Route(key,{OnTextInput=function()end,OnFocus=function()end,OnBlur=function()end})=='','Text input never routes Enter')
end
Check(Route(KEY_SPACE,Instance())=='','Focused Space never routes to global actions')
Check(Route(KEY_F,Instance())=='battle','Unrelated source hotkeys remain enabled with focused button')
Check(Route(KEY_ESCAPE,nil)=='pause','Unfocused Escape retains pause')
Check(Route(KEY_H,nil)=='help','Unfocused H retains help')
for _,tab in ipairs({'story','workshop','salvage'})do Check(Route(KEY_RETURN,nil,tab)==({story='StoryPage',workshop='Workshop',salvage='SalvagePage'})[tab],'Page-specific Enter stays owned by '..tab)end
Next();s.tab='hangar';log={};b=Instance(root,function()Mark('button');s.tab='battle';UI.ClearFocus()end);UI.SetFocus(b)
Down(KEY_RETURN);Hud.Update(.016)
Check(table.concat(log,',')=='button','Consumed Enter cannot enter newly selected page again in same frame')
Up(KEY_RETURN);Next();log={};Hud.Update(.016);Check(#log==0,'Consumption expires after physical hold and polling pulse clear')
Next();s.tab='hangar';log={};b=Instance(root,function()Mark('button');UI.ClearFocus()end);UI.SetFocus(b)
Down(KEY_RETURN);Hud.Update(.016);Check(table.concat(log,',')=='button','Focus cleared in callback does not trigger global Enter')

-- Reproduce the real 195 Web order: KeyDown callback at N; input pulse is
-- polled by App.Update at N+1 after the callback changed hangar to battle.
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER})do
    Focus(nil);s.tab='hangar';log={}
    b=Instance(root,function()Mark('button');s.tab='battle';UI.ClearFocus()end);UI.SetFocus(b)
    Down(key);time.frameNumber=time.frameNumber+1;Hud.Update(.016)
    Check(table.concat(log,',')=='button','Cross-frame consumed key must not start a match after focused button changes tab')
    for _=1,4 do Next();Hud.Update(.016);Check(table.concat(log,',')=='button','Held Enter remains owned after frame/pulse changes')end
    input.keys[KEY_H]=true;Hud.Update(.016)
    Check(table.concat(log,',')=='button,help','Holding consumed Enter must not suppress another source shortcut')
    log={'button'};input.keys[KEY_H]=nil
    input.keys[key]=true;time.frameNumber=time.frameNumber+1;Hud.Update(.016)
    Check(table.concat(log,',')=='button','Held repeated Enter pulse remains consumed outside original focus scope')
    Up(key);Next();Hud.Update(.016)
    Check(table.concat(log,',')=='button','Release and clear polling pulse retire ownership without side effects')
    Check(Route(key,nil,'battle')=='match','Next distinct unfocused Enter starts a match without sticky consumption')
end
-- Press and release can both arrive before Update; the press pulse still owns
-- the callback even though GetKeyDown is already false.
Focus(nil);s.tab='hangar';log={};b=Instance(root,function()Mark('button');s.tab='battle';UI.ClearFocus()end);UI.SetFocus(b)
Down(KEY_RETURN);Up(KEY_RETURN);input.keys[KEY_RETURN]=true;time.frameNumber=time.frameNumber+1;Hud.Update(.016)
Check(table.concat(log,',')=='button','Released key with a remaining press pulse is still consumed')
Next();Hud.Update(.016);Check(Route(KEY_RETURN,nil,'battle')=='match','Released-pulse consumption clears before a later independent Enter')
return {checks=checks,result='PASS'}
