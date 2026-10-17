-- Real QA suffix, CombatWarmup and LoadingFlow; native drawing and app reload are adapters.
COMBAT_WARMUP_TEST_HELPERS=true
local helpers=assert(loadfile('tools/migration/check-combat-warmup.lua'))()
local Warm=helpers.Warm
local actualNew=Warm.New
local checks=0
local function eq(a,b,label)assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function check(value,label)assert(value,label);checks=checks+1 end
for name in FLOW_SOURCE:gmatch("require%s*%(?%s*['\"]([^'\"]+)['\"]")do
    if not package.loaded[name]then package.loaded[name]=setmetatable({},{__index=function(_,key)
        error('unused flow constructor dependency accessed: '..name..'.'..key)
    end})end
end
package.loaded['urhox-libs/UI']={GetViewportSize=function()return 1920,1080 end}
package.loaded['urhox-libs/UI/Core/ImageCache']={Release=function()end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return false end}
package.loaded['app.ResourceGate']={New=function()return {Cancel=function()end,Start=function(_,_,done)done(true)end}end}
package.loaded['ui.LoadingPage']={New=function()return {Open=function()end,Close=function()end,Dispose=function()end}end}
local clock=100;Time={GetSystemTime=function()clock=clock+1;return clock end}
KEY_F8=8;input={GetKeyPress=function()return true end}
local record
package.loaded.cjson={encode=function(value)record=value;return 'adapter-record'end}
local Flow=assert(load(FLOW_SOURCE,'@scripts/app/LoadingFlow.lua'))()
local s=helpers.session();s.world={};s.view={};s.hud={};s.combatView={}
local app={trial=s,scene=s.scene,mode='trial',tab='battle',loader={state='ready'}}
app.graphicsSettings={SetSceneVisible=function()end}
function s:Dispose()
    self.disposed=true;self.scene=nil;self.world=nil;self.effects=nil;self.view=nil;self.hud=nil;self.combatView=nil
end
local flow=Flow.New(app);app.loadingFlow=flow
local calls={cancel=0,reload=0,postUpdate=0}
function app:Reload()
    calls.reload=calls.reload+1
    flow:Open({id='hangar'},function()end)
    return 'actual-reload-result',nil,17
end
function app:CancelMapLoad(fromFlow)
    calls.cancel=calls.cancel+1
    return self:Reload()
end
local originalCancel=app.CancelMapLoad;local originalReload=app.Reload;local originalDispose=s.Dispose
HandlePostUpdate=function()calls.postUpdate=calls.postUpdate+1 end
VOX_TRIAL={session=s,app=app};VOX_HANGAR=nil
assert(load(QA_SOURCE,'@tools/migration/qa-loading-failure.lua'))()
HandlePostUpdate()
eq(record.armed,true,'suffix starts armed');eq(record.injected,false,'suffix does not fail hall/startup')
check(Warm.New~=actualNew,'temporary real constructor hook installed')
flow:Open({id='crater'},function()app:CancelMapLoad(true)end)
flow:Advance(.551);flow:Advance(.591);flow.scenePrepared=true;flow:Finish()
eq(flow.pageVisible,true,'real cover already revealed loading page')
local before={};for _,d in ipairs(s.scene:GetComponents('StaticModel',true))do before[d]=d.viewMask end
local oldEffects=s.effects
local owner=Warm.New(s,{batchSize=4})
eq(owner.effects,oldEffects,'original constructor returns real effect owner')
eq(owner.phase,'effects-instanced','actual warmup geometry is constructed before fault')
eq(oldEffects.missiles.view.count,4,'actual warmup submitted instanced geometry')
eq(Warm.New,actualNew,'constructor hook restored after eligible installation')
flow.combatWarmup=owner
flow:Rendered()
eq(flow.failed,true,'real Flow.Rendered catches controlled Presented failure')
check(flow.error:find('VOX_QA_CONTROLLED_POST_INSTALL_WARMUP_FAILURE',1,true),'controlled marker preserved')
eq(owner.disposed,true,'actual warmup Dispose ran');eq(flow.combatWarmup,nil,'actual Fail cleared owner')
for d,mask in pairs(before)do eq(d.viewMask,mask,'actual world masks restored after injected failure')end
flow.page.backRect={x=900,y=700,w=112,h=46}
HandlePostUpdate()
eq(record.injected,true,'controlled fault recorded');eq(record.constructorRestored,true,'constructor restoration observable')
eq(record.install.finished,true,'finished installation boundary recorded');eq(record.install.pendingMap,false,'no pending loader ownership')
eq(record.injection.covered,true,'error occurs behind actual cover');eq(record.warmupDisposes,1,'real warmup disposal counted once')
eq(record.warmupCleanup.disposed,true,'cleanup state observed after actual Dispose')
eq(record.flow.failed,true,'actual fail state observed');eq(record.failedObserved,true,'failed event observed')
eq(record.backRect.w,112,'rendered public return rect passed through')
flow:Back()
eq(calls.cancel,1,'actual callback passes through CancelMapLoad adapter')
eq(calls.reload,1,'real wrapped Reload called once')
eq(flow.phase,'cover','real Back preserves replacement recovery phase')
local a,b,c=app:CancelMapLoad(false)
eq(a,'actual-reload-result','wrapper preserves first return');eq(b,nil,'wrapper preserves nil return');eq(c,17,'wrapper preserves third return')
-- The extra return-value check is isolated from the required one-click route.
HandlePostUpdate()
eq(record.cancelCalls,2,'all real method calls are honestly counted')
eq(record.reloadCalls,2,'all reload calls are honestly counted')
s:Dispose()
eq(s.Dispose~=originalDispose,true,'old Dispose wrapper remains until recovery finishes')
app.trial=nil;app.mode='hangar';app.tab='hangar';app.scene={}
VOX_TRIAL=nil;VOX_HANGAR={app=app};flow.scenePrepared=true;flow:Finish()
flow:Advance(.551);flow:Advance(.591);flow:Rendered();flow:Rendered()
flow:Advance(.01);flow:Advance(.451);flow:Advance(.551);flow:Advance(.591)
HandlePostUpdate()
eq(record.returned,true,'actual normal hall flow close observed')
eq(record.flow.active,false,'actual hall loading overlay closed');eq(record.flow.map,'hangar','replacement flow observed')
eq(record.retiredTrial.disposed,true,'old trial disposal observation retained')
for _,key in ipairs({'scene','world','effects','view','hud','combatView'})do eq(record.retiredTrial[key],false,'retired adapter no longer owns '..key)end
eq(app.CancelMapLoad,originalCancel,'CancelMapLoad instance hook removed')
eq(app.Reload,originalReload,'Reload instance hook removed')
eq(s.Dispose,originalDispose,'old trial Dispose hook removed')
eq(owner.Dispose,rawget(getmetatable(owner),'Dispose'),'warmup Dispose hook removed')
eq(record.globalTrialPresent,false,'old global cleared observed');eq(record.globalHangarPresent,true,'real hall global observed')
check(calls.postUpdate>=4,'previous PostUpdate chain always executed')
local again=helpers.session();local nextOwner=Warm.New(again)
eq(pcall(nextOwner.Presented,nextOwner),true,'subsequent real constructor is not injected')
nextOwner:Dispose()
return {result='PASS',checks=checks,
    boundary='Actual fault suffix, CombatWarmup and Flow.Rendered/Fail/Back/Advance/Close with native drawing and explicit app reload/dispose adapters. App full integration and public button are reserved for the same-build Web runner.'}
