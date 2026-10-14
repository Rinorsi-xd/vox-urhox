local Motion=require 'combat.MvpMotion'
local stage='boot';local app=nil ---@type HangarApp?
local co=nil ---@type thread?
local startMatch=false
engine.maxInactiveFps=120
local function Logic()
    local Board=require('ui.MatchScoreboard');local layer={};local rules={state='live'};local battle={rules=rules}
    Board.Update(layer,battle,true,0);V.assert(layer.boardAlpha==0,'scoreboard starts source entry transparent')
    Board.Update(layer,battle,true,.1);V.assert(layer.boardAlpha>.5 and layer.boardAlpha<1,'scoreboard uses source CSS ease-out halfway')
    Board.Update(layer,battle,true,.1);V.assert(layer.boardAlpha==1,'scoreboard settles after source two hundred milliseconds')
    Board.Update(layer,battle,false,.1);Board.Update(layer,battle,true,0);V.assert(layer.boardAlpha==0,'reopening Tab restarts entry animation')
    rules.state='over';battle.result={};Board.Update(layer,battle,true,0);V.assert(layer.boardAlpha==0,'result replaces Tab and restarts entry once')
    local source=require('core.ResourceData').Read('tools/migration/source-mvp.json')
    for _,q in ipairs(source.samples) do
        V.assert(math.abs(Motion.PodY(q.t,q.S,q.h)-q.y)<1e-8,'source platform height')
        V.assert(math.abs(Motion.PodRot(q.t)-q.rot)<1e-8,'source platform rotation')
        local p,look=Motion.Camera(q.t,q.S,q.h)
        for i=1,3 do V.assert(math.abs(p[i]-(i==1 and -q.camera[i] or q.camera[i]))<1e-8,'source camera position') end
        local v=Vector3(look[1]-p[1],look[2]-p[2],look[3]-p[3]):Normalized()
        for i,n in ipairs({v.x,v.y,v.z}) do V.assert(math.abs(n-(i==1 and -q.look[i] or q.look[i]))<1e-6,'source camera look float32 tolerance') end
    end
end
local function Exercise(s)
    -- Hidden native validation windows have no focus; production Web focus is
    -- tested separately. Drive the deterministic cinematic clock here.
    s.HasFocus=function() return true end
    local b=s.battle;local player=b.player;local enemy=b.entries[4].unit;local ally=b.entries[2].unit
    s:Pause();b.rules.state='live'
    s.world.attacker=ally;s.world:RecordDamage(enemy,150,enemy:Position());s.world.time=s.world.time+.1
    s.world.attacker=player;s.world:RecordDamage(enemy,300,enemy:Position());s.world.attacker=nil;s.world:RecordKill(enemy,enemy:Position())
    V.assert(b.stats[player].kills==1 and b.stats[ally].assists==1,'real kill awards source ten second assist once')
    s.world.time=s.world.time+11;s.world:RecordKill(enemy,enemy:Position())
    V.assert(b.stats[player].kills==1,'expired hits cannot award stale kills')
    b.stats[player].kills=12;b.stats[player].damage=28640;b.stats[player].assists=5
    s.app.music:SetPaused(true)
    b.rules.state='over';b.rules.winner='blue';b.rules.events={{type='matchOver',winner='blue'}}
    -- Engine event subscriptions are registered on the main Lua state. Start
    -- the real match event there; the coroutine only advances test fixtures.
    startMatch=true;while not b.mvpShow do coroutine.yield() end
    V.assert(b.mvp.unit==player,'MVP uses actual source weighted score');V.assert(b.result.xp==410,'MVP adds original fifty XP once')
    V.assert(b.banner==nil,'match result clears frozen round announcement')
    local show=b.mvpShow
    while show.preparing do coroutine.yield() end
    V.assert(not show.failed and show.stage~=nil,'production resource gate builds actual stage')
    V.assert(#show.stage.carMaterials>0,'real source vehicle uses deform shader material variants')
    local clock=s.world.time;local steps=s.fixedSteps
    for i=1,145 do show:Update(1/60);if i%5==0 then coroutine.yield() end end
    V.assert(show.fired.pop and show.flashAt and show.stage.confettiUploads==1,'natural celebration fires once with one GPU geometry upload')
    V.assert(show.stage.smoke.enabled and show.stage.smokeUploads==1,'source cannon smoke uses a single static GPU upload')
    V.assert(show.stage.awardBanner.bound and show.stage.awardBanner.renders==1,'awarded name canvas renders only once')
    s:Tick(.1,{throttle=1,firing=true});V.assert(s.world.time==clock and s.fixedSteps==steps,'MVP freezes combat and physics')
    show:Skip();show:Update(1/60);s.hud.Update(s,.01);coroutine.yield()
    V.assert(show.jumped and show.t>=7.1 and not show.done,'first skip reaches showcase without leaving match')
    V.assert(show.stage.nodes.flag.enabled and show.stage.nodes.column.enabled,'first skip reveals real banner and spiral')
    V.assert(not s.hud.match.back:IsVisible() and s.hud.mvp:IsVisible(),'MVP masks scoreboard and owns UI')
    coroutine.yield();coroutine.yield()
    local image=Image:new()
    V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/mvp-native-title.png'),'native banner and title visual evidence')
    image:Dispose()
    local viewport=renderer:GetViewport(0);V.assert(viewport.scene==show.scene,'MVP owns independent render scene')
    V.assert(not s:Resume(),'result cannot recapture driving pointer')
    show:Skip();show:Update(.4);s.hud.Update(s,.01);coroutine.yield();coroutine.yield();s.hud.Update(s,.01)
    V.assert(show.done and show.cleared and show.music.disposed,'continue disposes stage music and scene')
    V.assert(s.app.music.userPaused,'cinematic restores previous user music pause preference')
    V.assert(s.hud.match.back:IsVisible() and s.hud.match.retry:IsVisible(),'source result controls appear after cinematic fade')
    V.assert(not s.hud.match.exit:IsVisible(),'source result hides the gameplay leave action')
    V.assert(s.hud.match.layer.boardRows.blue[1].entry.unit==player,'actual scoreboard sorts players by source weighted score')
    local resultRect=s.hud.match.layer.resultRect
    V.assert(math.abs(resultRect.h/resultRect.scale-839.796875)<.001,'result height matches measured original six-player layout')
    s.hud.Update(s,.2)
    for _=1,4 do coroutine.yield();s.hud.Update(s,.01) end
    local resultImage=Image:new()
    V.assert(graphics:TakeScreenShot(resultImage) and resultImage:SavePNG('docs/migration/evidence/mvp-native-result.png'),'native complete result visual evidence')
    resultImage:Dispose()
    V.assert(renderer:GetViewport(0).scene==s.scene,'battle render restored after cinematic')
    local Gate=require('app.ResourceGate');local createGate=Gate.New;local cancelled=false
    Gate.New=function() return {Start=function(_,_,callback) callback(false,'injected download failure') end,Cancel=function() cancelled=true end} end
    local ok,failed=pcall(require('app.MvpShow').New,s,b.mvp,b.stats[player]);Gate.New=createGate
    V.assert(ok and failed.failed and failed.done and failed.cleared and failed.scene==nil and cancelled,'failed cinematic resource gate releases scene immediately')
    V.assert(renderer:GetViewport(0).scene==s.scene and s.app.music.userPaused,'failed gate preserves battle viewport and music preference')
    b:Restart();V.assert(b.mvpShow==nil and player.alive and b.rules.state=='prep','replay resets cinematic and actual combat')
    s.wantsReturn=true;stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('trial','elimination'),'production match load');stage='load'
    elseif stage=='load' and app.trial and not app.loadingFlow.active then co=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then
        if startMatch then startMatch=false;app.trial.battle:AfterStep(0) end
        local ok,err=coroutine.resume(co);if not ok then V.assert(false,tostring(err));stage='fail';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then V.assert(app.car~=nil,'returns to real hall');stage='done';V.finish() end
end
for i=40,800 do V.atFrame(i,Poll) end
V.atFrame(805,function() V.assert(stage=='done','MVP lifecycle complete');V.finish() end)
