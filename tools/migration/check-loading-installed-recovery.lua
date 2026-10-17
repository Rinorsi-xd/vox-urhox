-- Execute the actual flow/app methods; scene construction and engine UI are adapters.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function eq(a,b,label)
    assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1
end
for name in APP_SOURCE:gmatch("require%s*%(?%s*['\"]([^'\"]+)['\"]") do
    package.loaded[name]=setmetatable({}, {__index=function(_,key)
        error('unused dependency accessed: '..name..'.'..tostring(key))
    end})
end
for _,name in ipairs({'audio.BattleFlow','render.SceneWarmup','render.CombatWarmup',
    'render.HangarFxWarmup','scene.HangarAtmosphere','ui.CommsWarmup','story.TutorialFirstLine','ui.MatchLobby'}) do
    package.loaded[name]=setmetatable({}, {__index=function(_,key)
        error('unused warmup dependency accessed: '..name..'.'..tostring(key))
    end})
end
package.loaded['urhox-libs/UI']={}
package.loaded['urhox-libs/UI/Core/ImageCache']={Release=function()end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return false end}
package.loaded['app.ResourceGate']={New=function()return {Cancel=function()end,Start=function(_,_,done)done(true)end}end}
package.loaded['ui.LoadingPage']={New=function()return {Open=function()end,Close=function()end,Dispose=function()end}end}
package.loaded['scene.HangarResources']={For=function()return {}end}
package.loaded['ui.GarageHud']={SetMode=function()end}
Time={GetSystemTime=function()return 100 end}
local Flow=assert(load(FLOW_SOURCE,'@scripts/app/LoadingFlow.lua'))()
package.loaded['app.LoadingFlow']=Flow
local App=assert(load(APP_SOURCE,'@scripts/app/HangarApp.lua'))()
local function fresh(kind)
    local calls={reload=0,load=0,cancel=0,pause=0,resume=0,begin=0,intro=0,restore=0,preview=0,dispose=0}
    local app=setmetatable({ownsScene=true,scene={},mode='trial',blueprint={List=function()return {}end}},App)
    app.graphicsSettings={SetSceneVisible=function()end}
    app.DeferAssetRelease=function(self,release)self.pendingAssetRelease=release end
    app.vehicleGate={Cancel=function()end}
    app.toasts={Push=function()end}
    app.mapTransition={PrepareRecovery=function()end,Restored=function()calls.restore=calls.restore+1 end}
    app.loader={state='ready',Cancel=function()calls.cancel=calls.cancel+1;app.pendingMap=nil end,
        Load=function(self,_,ready,failed)
            calls.load=calls.load+1;self.ready=ready;self.failed=failed;self.state='loading'
        end}
    app.trial={touch=true,Pause=function()calls.pause=calls.pause+1 end,
        Resume=function()calls.resume=calls.resume+1 end,StartIntro=function()calls.intro=calls.intro+1 end}
    if kind=='story' or kind=='salvage' then app.trial[kind]={Begin=function()calls.begin=calls.begin+1 end} end
    app.Install=function(self)
        self.trial=nil;self.mode='hangar';self.scene={};self.loader.state='ready'
    end
    local flow=Flow.New(app);app.loadingFlow=flow
    flow:Open({id='crater'},function()app:CancelMapLoad(true)end)
    flow.scenePrepared=true;flow:Finish();flow.phase='loading'
    local reload=App.Reload
    app.Reload=function(self)calls.reload=calls.reload+1;return reload(self)end
    return app,flow,calls
end
local scenarios=0
for _,kind in ipairs({'story','salvage','match'}) do
    local app,flow,c=fresh(kind)
    if kind=='match' then flow.match={stage='roster'} end
    flow.combatWarmup={Presented=function()error('intentional post-install warmup failure')end,
        Dispose=function()c.dispose=c.dispose+1 end}
    flow:Rendered()
    eq(flow.failed,true,'real Presented failure reaches loading error')
    eq(c.dispose,1,'failed warmup owner disposed exactly once')
    eq(app.pendingMap,nil,'installed map no longer has pending loader ownership')
    flow:Back()
    eq(c.reload,1,'post-install failure returns through real hall reload')
    eq(c.load,1,'hall resource load requested once')
    eq(flow.map.id,'hangar','return opens hall loading flow')
    eq(flow.phase,'cover','old Back must not overwrite replacement transition')
    eq(flow.cancelled,false,'new recovery flow starts uncancelled')
    eq(flow.failed,false,'new recovery flow clears previous error')
    eq(flow.active,true,'hall recovery remains covered')
    eq(c.pause,1,'installed trial stays paused during return')
    eq(c.resume,0,'failed installed trial is never resumed')
    eq(c.begin,0,'failed story or salvage never begins')
    eq(c.intro,0,'failed battle never starts its cinematic')
    flow:Advance(.551);flow:Advance(.591)
    eq(flow.phase,'loading','recovery scene waits behind the normal cover')
    app.loader.ready({})
    eq(app.mode,'hangar','hall installation callback completes')
    eq(app.trial,nil,'hall install boundary removes failed trial')
    eq(c.restore,1,'map transition recovery is completed')
    for _=1,2 do flow:Rendered()end
    flow:Advance(.01);flow:Advance(.451);flow:Advance(.551);flow:Advance(.591)
    eq(flow.active,false,'recovered hall releases loading overlay')
    scenarios=scenarios+1
end
do
    local app,flow,c=fresh('story')
    flow:Fail('first failure');flow:Back()
    app.loader.state='failed';app.loader.failed('hall download failed')
    eq(flow.failed,true,'hall recovery download error stays visible')
    flow:Back()
    eq(c.reload,2,'failed hall recovery can retry returning to hall')
    eq(c.load,2,'retry actually starts another hall load')
    eq(flow.map.id,'hangar','retry remains a hall recovery')
    eq(flow.phase,'cover','second retry keeps its new transition')
    eq(c.resume,0,'repeated failure never resumes unfinished story')
    scenarios=scenarios+1
end
do
    local app,flow,c=fresh('story')
    app.mode='hangar';app.trial=nil;app.pendingMap={id='crater'};flow.finished=false
    flow:Back();flow:Back()
    eq(c.cancel,1,'pending load cancellation remains exactly once')
    eq(c.reload,0,'pending cancellation does not reload retained hall')
    eq(flow.phase,'exit-cover','pending cancellation retains normal exit')
    eq(flow.cancelled,true,'pending load is marked cancelled')
    scenarios=scenarios+1
end
do
    local app,flow,c=fresh('story')
    app.trial=nil;app.mode='hangar'
    app.mapPreview={Return=function()c.preview=c.preview+1;app.mapPreview=nil end}
    flow:Fail('preview first draw failed');flow:Back();flow:Back()
    eq(c.preview,1,'installed preview returns exactly once')
    eq(c.reload,0,'preview reuses retained hall')
    eq(flow.phase,'exit-cover','preview completes ordinary covered return')
    scenarios=scenarios+1
end
do
    local app,flow,c=fresh('story')
    app.trial=nil;app.mode='hangar';flow.finished=false;flow.match={stage='found'}
    flow:Fail('match audio preparation failed');flow:Back()
    eq(flow.phase,'exit-cover','failed found match can return')
    eq(flow.cancelled,true,'found failure cancelled')
    eq(c.load,0,'failed queue does not invent a scene load')
    scenarios=scenarios+1
end
for _,kind in ipairs({'story','salvage','match'}) do
    local app,flow,c=fresh(kind)
    if kind=='match' then flow.match={stage='roster'} end
    flow:Back()
    eq(flow.cancelled,false,'successful installed warmup is not cancellable')
    eq(c.reload,0,'successful warmup does not trigger recovery')
    flow:Close()
    eq(kind=='match' and c.intro or c.begin,1,'normal successful session still begins once')
    scenarios=scenarios+1
end
return {checks=checks,scenarios=scenarios}
