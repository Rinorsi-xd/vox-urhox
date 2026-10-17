package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label)assert(ok,label);checks[#checks+1]=label end
local W,H=1920,1080
local stack,globals={},{}
local Widget={};Widget.__index=Widget
function Widget:Extend(name)
    local class={_className=name};class.__index=class
    return setmetatable(class,{__index=self,__call=function(c,p)return setmetatable({props=p or {},children={}},c)end})
end
function Widget:AddChild(c)self.children[#self.children+1]=c end
function Widget:AddContent(c)self:AddChild(c)end
function Widget:SetHeight(h)self.props.height=h end
function Widget:Destroy()self.destroyed=true;if self.props.onDispose then self.props.onDispose(self)end end
function Widget:Open()self.isOpen_=true end
function Widget:Close(immediate)
    self.isOpen_=false;if self.props.onClose then self.props.onClose(self)end
    if immediate then self:Destroy()end
end
local Panel=Widget:Extend('Panel')
local function Button(p)return Panel(p)end
local UI={Widget=Widget,Panel=Panel,ScrollView=Button,GetScale=function()return 1 end,
    GetViewportSize=function()return W,H end,GetSafeAreaInsets=function()return {}end,
    RegisterGlobalComponent=function(k,v)globals[k]=v end,UnregisterGlobalComponent=function(k)globals[k]=nil end,
    PushOverlay=function(p)for _,w in ipairs(stack)do assert(w~=p,'duplicate overlay')end;stack[#stack+1]=p end,
    PopOverlay=function(p)for i=#stack,1,-1 do if stack[i]==p then table.remove(stack,i);return end end end,
    ClearFocus=function()end,CancelPointer=function()end}
package.loaded['urhox-libs/UI']=UI
local draws=0
package.loaded['ui.SourceDraw']={Begin=function()draws=draws+1 end,Rect=function()end,Text=function()end,Width=function(_,s,n)return #s*n*.5 end}
package.loaded['ui.SourceModal']=setmetatable({},{__call=function(_,p)return Panel(p)end})
package.loaded['ui.SourceButton']=Button
package.loaded['ui.SourceHint']=Button
package.loaded['ui.EndlessWidgets']={Button=Button};package.loaded['ui.DriveChrome']=Button
package.loaded['controls.TouchMode']={Enabled=function()return false end}
package.loaded['combat.MatchActions']={};package.loaded['ui.GarageDialogs']={}
package.loaded['combat.Matchmaker']={ResetIntro=function()return true end}
package.loaded['ui.GraphicsPanel']={};package.loaded['ui.TouchSettings']={}
local Host=require 'ui.DialogHost'
local home={tab='hangar'}
package.loaded['ui.GarageHud']={GetState=function()return home end}
package.loaded['story.MissionData']={levels={}}
local pressed={};KEY_F8='F8';KEY_ESCAPE='ESC';MM_ABSOLUTE='absolute'
input={GetKeyPress=function(_,key)return pressed[key]==true end}
graphics={GetWidth=function()return W end,GetHeight=function()return H end,GetDPR=function()return 1 end}
function GetPlatform()return 'Web'end
function nvgSave()end;function nvgRestore()end;function nvgIntersectScissor()end
local Settings=require 'ui.GameSettings'
local app={generation=3,debugEnabled=false,store={Read=function()end},toasts={Push=function()end}}
local marked,visible=0,true
local env=setmetatable({app=app,PlayerMarker=require 'diagnostics.PlayerMarker',performance={enabled=true,Marker=function(_,kind,context)assert(kind=='user-mark' and context.app==app and context.playerMarker.schema==1);marked=marked+1 end},
    PerformanceBindings={Context=function(a)return {app=a}end},performancePanel={SetVisible=function(_,v)visible=v end},showPerformance=true},{__index=_G})
assert(load(performanceControlsSource,'@actual-main-performance-controls','t',env))()
local panel
for _,kind in ipairs({'home','build','trial'})do
    local paused,resumed=0,0
    local owner={app=app,Pause=function()paused=paused+1 end,Resume=function()resumed=resumed+1 end}
    app.trial=kind=='trial' and owner or nil;app.build=kind=='build' and owner or nil
    if kind=='trial'then owner.combat={};owner.world={layout={teleports={}}}end
    if kind=='build'then owner.editor={}end
    local modal=Settings.Open(owner)
    Check(modal.actions.debug and paused==1,'public settings has mouse debug entry '..kind)
    modal.actions.debug.props.onClick();panel=app.debugPanel
    Check(panel and panel.open and owner.dialog==nil and owner.closingDialog==nil and modal.destroyed and #stack==1 and stack[1]==panel.page,'one actual debug overlay replaces and destroys settings without frozen close '..kind)
    Check(input.mouseMode==MM_ABSOLUTE and resumed==0,'debug keeps absolute mouse and never auto-resumes '..kind)
    local found={};for _,section in ipairs(panel.sections)do for _,b in ipairs(section.buttons)do found[b.id]=true end end
    Check(found.perfVisible and found.perfMark and found.clrProfile,'original commands plus mouse performance controls exist '..kind)
    local old=app.performanceControls.IsVisible();panel:Activate('perfVisible')
    Check(panel.open and app.performanceControls.IsVisible()~=old and visible==not old,'actual performance button reuses existing panel '..kind)
    panel:Activate('perfMark');Check(panel.open and marked>0,'actual performance marker does not close settings debug '..kind)
    panel.page:Render(1);local close=panel.buttons[1]
    local event={pointerId=0,pointerType='mouse',x=close.x+2,y=close.y+2}
    panel.page:OnPointerDown(event);panel.page:OnPointerUp(event)
    Check(not panel.open and #stack==0 and owner.dialog and owner.dialog.unifiedSettings,'actual mouse close returns unified settings '..kind)
    Check(resumed==0,'return to settings does not capture or resume '..kind)
    Check(not panel.page:HitTest(1840,70),'closed debug has no floating hit target '..kind)
    local count=draws;panel.page:Render(1);Check(draws==count,'closed debug does not render '..kind)
    local same=app.debugPanel;owner.dialog.actions.debug.props.onClick();Check(app.debugPanel==same,'reopen reuses one debug owner '..kind)
    local back=Settings.Open(owner);Check(not panel.open and #stack==0 and back.unifiedSettings,'settings opener cannot stack debug and pause '..kind)
    back.actions.resume.props.onClick();Check(resumed==(kind=='trial' and 1 or 0),'explicit resume owns gameplay capture '..kind)
end
local owner={app=app};app.trial=nil;app.build=nil
local m=Settings.Open(owner);m.actions.debug.props.onClick();app.generation=4;panel:CloseSettings()
Check(owner.dialog==nil and #stack==0,'stale hall generation cannot reopen dead settings owner')
m=Settings.Open(owner);m.actions.debug.props.onClick();owner.disposed=true;panel:CloseSettings()
Check(owner.dialog==nil,'disposed owner cannot receive return callback')
for _,vp in ipairs({{1920,1080},{2400,1080},{960,432},{800,360}})do
    W,H=table.unpack(vp);panel:SetOpen(true);panel:Layout();panel.page:Render(1);local r=panel.panelRect
    Check(r.x>=0 and r.y>=0 and r.x+r.w<=W and r.y+r.h<=H,'existing debug panel fits landscape '..W..'x'..H)
    local perfLeft=W-12-math.min(274,W*.44-12)
    Check(r.x+r.w+12<=perfLeft,'debug including close never overlaps restored PERF '..W..'x'..H)
end
panel:SetOpen(false);local page=panel.page;panel:Dispose();panel:Dispose()
Check(not globals['vox-debug'] and #stack==0 and page.destroyed,'idempotent dispose releases global and overlay')
env.performance.enabled=false
local ok,err=app.performanceControls.Mark();Check(not ok and err=='性能监控未开启','disabled monitor reports actual mark unavailability')
return checks
