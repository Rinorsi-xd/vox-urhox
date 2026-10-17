package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local Widget={}
Widget.__index=Widget
function Widget:Extend(name)
    local base=self;local class={_className=name};class.__index=class
    return setmetatable(class,{__index=base,__call=function(c,props)
        return setmetatable({props=props or {},children={},node=true,onClose_=props and props.onClose},c)
    end})
end
function Widget:IsVisible() return not self.destroyed end
function Widget:GetAbsoluteLayoutForHitTest() return {x=10,y=10,w=200,h=40} end
function Widget:Destroy() self.destroyed=true;self.node=nil end
function Widget:DispatchEvent() end
local stack,globals={},{}
local UI={Widget=Widget,GetViewportSize=function() return 1920,1080 end,GetSafeAreaInsets=function() return {} end,
 GetTopOverlay=function() return stack[#stack] end,GetOverlayStack=function() return stack end,
 PushOverlay=function(w) stack[#stack+1]=w end,PopOverlay=function(w) for i=#stack,1,-1 do if stack[i]==w then table.remove(stack,i);return end end end,
 RegisterGlobalComponent=function(id,w) globals[id]=w end,UnregisterGlobalComponent=function(id) globals[id]=nil end,
 GetFocus=function() end,ClearFocus=function() end,GetPressedWidgetForPointer=function() end,CancelPointer=function() end}
package.loaded['urhox-libs/UI']=UI
package.loaded['controls.TouchMode']={Enabled=function() return false end}
package.loaded['app.DebugActions']={Sections=function() return {},'home','home' end,Status=function() return {} end}
package.loaded['ui.SourceDraw']={}
package.loaded['ui.SourceRelief']={}
package.loaded['ui.SourceButtonMotion']={Ease=function(v) return v end}
package.loaded['ui.SourceButton']={};package.loaded['ui.SourceHint']={}
package.loaded['ui.SourceModalVisual']={New=function() return {Dispose=function(self) self.disposed=true end} end}
local BaseModal=Widget:Extend('EngineModalAdapter')
function BaseModal:Open() self.isOpen_=true;self.animProgress_=1;UI.PushOverlay(self);return self end
function BaseModal:Update() end
package.loaded['urhox-libs/UI/Widgets/Modal']=BaseModal
local Debug=require 'ui.DebugPanel'
local app={store={Read=function() end}}
input={};MM_ABSOLUTE='absolute'
app.debugPanel=Debug.New(app);app.debugPanel:Layout()
local Snapshot=assert(load('local UI=require "urhox-libs/UI"\n'..overlaySnapshotSource..'\nreturn OverlayState'))()
local state=Snapshot(app)
Check(not state.present and #stack==0,'Closed debug no longer retains a floating overlay')
app.debugPanel:SetOpen(true);state=Snapshot(app)
Check(state.present and state.className=='VoxDebugPanel' and state.owner=='app.debugPanel' and state.registeredName=='vox-debug','Actual DebugPanel is identified by instance ownership and class')
Check(not app.debugPanel.page:HitTest(601,44) and not app.debugPanel.page:HitTest(320,44),'Actual DebugPanel HitTest passes original garage/loadout nav centers')
Check(not app.debugPanel.page:HitTest(1840,70),'Debug has no obsolete floating toggle target')
state=Snapshot(app);Check(state.open==true,'Opened debug is observed rather than treated as passive')
local Host=require 'ui.DialogHost'
local owner={};app.trial=owner;local closed=0
local modal=Host.Open(owner,'行动失败',function() closed=closed+1 end,{width=780})
modal.contentContainer_=setmetatable({props={},children={setmetatable({props={text='回大厅',onClick=function() end},children={}},Widget)}},Widget)
state=Snapshot(app)
Check(state.owner=='app.trial.dialog' and state.title=='行动失败' and state.open and state.stackTotal==2,'Actual DialogHost modal is not confused with underlying debug')
Check(#state.buttons==1 and state.buttons[1].text=='回大厅','Actual detached modal content button is included')
Host.Close(owner);state=Snapshot(app)
Check(owner.dialog==nil and owner.closingDialog==modal and closed==1 and state.owner=='app.debugPanel','Actual SourceModal.Close immediately pops result and releases owning dialog')
Host.Update(owner,.2)
Check(owner.closingDialog==nil and modal.sourceDestroyed and #stack==1,'Actual close retirement destroys result shell without removing debug')
local second=Host.Open(owner,'撤离成功',nil,{width=780});Host.Dispose(owner)
Check(owner.dialog==nil and owner.closingDialog==nil and second.sourceDestroyed and UI.GetTopOverlay()==app.debugPanel.page,'Actual session modal dispose leaves only legitimate debug')
local lookalike=setmetatable({props={},children={}},getmetatable(app.debugPanel.page));UI.PushOverlay(lookalike)
state=Snapshot(app);Check(state.className=='VoxDebugPanel' and state.owner=='unknown','Matching class without application ownership is not certified')
UI.PopOverlay(lookalike)
local performanceRoot=setmetatable({props={pointerEvents='box-none'},children={}},Widget)
performanceRoot.HitTest=function() return false end
performancePanel={app=app,root=performanceRoot,visible=true,disposed=false}
UI.PushOverlay(performanceRoot);state=Snapshot(app)
Check(state.owner=='main.performancePanel' and state.registeredName==nil and state.hitTestBound and state.panelVisible and not state.disposed,
 'Exact main owner root identifies performance overlay without fabricating registration evidence')
local fakePerformanceRoot=setmetatable({props={pointerEvents='box-none',text='PERF'},children={}},Widget)
UI.PushOverlay(fakePerformanceRoot);state=Snapshot(app)
Check(state.owner=='unknown' and state.registeredName==nil,'Panel class and PERF text cannot impersonate actual performance owner')
UI.PopOverlay(fakePerformanceRoot)
performancePanel.app={};state=Snapshot(app)
Check(state.owner=='unknown','Performance root owned by another app is not certified')
UI.PopOverlay(performanceRoot);performancePanel=nil
local huge=setmetatable({props={title='large modal'},children={}},Widget)
for i=1,1000 do huge.children[i]=setmetatable({props={text='row '..i,onClick=function() end},children={}},Widget) end
UI.PushOverlay(huge);state=Snapshot(app)
Check(state.visited==64 and state.truncated and #state.buttons==12 and #state.texts==16,'Read-only overlay traversal is bounded at 64 nodes, 12 buttons and 16 texts')
UI.PopOverlay(huge)
app.debugPanel:Dispose();state=Snapshot(app)
Check(not state.present and #stack==0 and globals['vox-debug']==nil,'Actual debug disposal clears its registered overlay')
return checks
