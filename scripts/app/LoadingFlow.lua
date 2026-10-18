-- Scene preparation and UI lifetime are separate: the overlay survives SetRoot.
local ResourceGate=require("app.ResourceGate")
local ResourceData=require("core.ResourceData")
local LoadingPage=require("ui.LoadingPage")
local ImageCache=require("urhox-libs/UI/Core/ImageCache")
local ArenaData=require("combat.ArenaData")
local Matchmaker=require("combat.Matchmaker")
local DriveMaps=require("app.DriveMaps")
local BattleFlow=require("audio.BattleFlow")
local MatchLobby=require("ui.MatchLobby")
local PlatformUtils=require("urhox-libs.Platform.PlatformUtils")
local SceneWarmup=require("render.SceneWarmup")
local CombatWarmup=require("render.CombatWarmup")
local StoryPrefetch=require("app.StoryPrefetch")
local HangarAtmosphere=require("scene.HangarAtmosphere")
local HangarFxWarmup=require 'render.HangarFxWarmup'
local CommsWarmup=require 'ui.CommsWarmup'
local TutorialFirstLine=require 'story.TutorialFirstLine'

local UI=require 'urhox-libs/UI'
local M={};M.__index=M
local phases={'download','resources','scene','prepare','environment','activate'}
local labels={'下载场地与战车资源','准备贴图','载入场景','搭建碰撞体','准备环境','装配战车与渲染'}
function M.New(app)
    local self=setmetatable({},M);self:init(app);return self
end
function M:init(app)
    self.app=app;self.active=false;self.pageVisible=false;self.time=0;self.phase='closed'
    self.generation=0;self.steps={};self.disposed=false
    self.artGate=ResourceGate.New();self.artReady=false
    self.page=LoadingPage.New(self)
end
function M:Open(map,onBack)
    self:Close();StoryPrefetch.Cancel()
    self.generation=self.generation+1;self.active=true;self.phase='cover';self.time=0;self.elapsed=0
    self.map=map;self.onBack=onBack;self.finished=false;self.failed=false;self.error=''
    self.artReady=false;self.cancelled=false;self.scenePrepared=false;self.keepSceneVisible=false
    local generation=self.generation
    if not map.boot then self.artGate:Start({map.loadingArt or 'UI/Modes/crater.jpg'},function(ok)
        if not self.active or self.generation~=generation then return end
        self.artReady=ok
        if ok then ImageCache.Release(map.loadingArt or 'UI/Modes/crater.jpg') end
    end) end
    self.steps={};self.current=1;self.progress=0;self.warmFrames=0;self.readyTime=0;self.pageFrames=0;self.pageDrawn=false
    self.warmupTimes={};self.worldRestoredAt=nil
    for i,item in ipairs(map.loadingSteps or phases) do
        local id=type(item)=='table' and item[1] or item
        self.steps[i]={id=id,label=type(item)=='table' and item[2] or labels[i],state=i==1 and 'run' or 'wait',elapsed=0,note=''}
    end
    self.page:Open();print('[LoadingFlow] Open '..map.id)
    if map.boot then self.pageVisible=true;self.phase='loading' end
end
function M:QueueBattle(mode,bp)
    local cfg=ArenaData.modes[mode]
    local tier=bp:Stats().fitTier
    if not tier then self.app.toasts:Push('这辆车超出了 T5 的限制，改装后才能出战','bad');return false end
    local roster=Matchmaker.Find(self.app.store,cfg.size,tier.id)
    local map={};for key,value in pairs(DriveMaps.crater) do map[key]=value end
    map.loadingBrand=cfg.name;map.loadingSub=cfg.size..'V'..cfg.size;map.loadingTips=cfg.rules
    self:Open(map,function() self.app:CancelMapLoad(true) end)
    self.match={cfg=cfg,roster=roster,tier=tier.id,wait=roster.wait,carName=bp.name,stage='queue',age=0}
    self.sounds=BattleFlow.New();self.sounds:Prepare(true);self.sounds:Queue(true)
    -- The queue/loading mask absorbs the first battle track's download.
    if self.app.music and self.app.music.Prefetch then self.app.music:Prefetch('drive-combat') end
    -- The 6-14 s queue used to idle the network. Start the map download now;
    -- the native cache dedupes it with the loader's own request after roster.
    -- The baked minimap is outside the map manifest, so fetch it here too.
    local mapPaths=ResourceData.Read(map.resources)
    mapPaths[#mapPaths+1]=map.scene
    mapPaths[#mapPaths+1]='Crater/Minimap.json';mapPaths[#mapPaths+1]='Crater/Minimap.bin'
    self.mapPrefetch=self.mapPrefetch or ResourceGate.New()
    local prefetchStarted=Time:GetSystemTime()
    self.mapPrefetch:Start(mapPaths,function(ok,failure)
        print('[LoadingFlow] Map prefetch '..(ok and 'ready' or 'failed '..tostring(failure))..' after '..(Time:GetSystemTime()-prefetchStarted)..'ms')
    end)
    local paths=MatchLobby.Dependencies(roster);local generation=self.generation
    self.artGate:Start(paths,function(ok)
        if not self.active or self.generation~=generation then return end
        self.artReady=ok
        if ok then
            local images=ImageCache
            for _,path in ipairs(paths) do images.Release(path) end
        end
    end)
    return true
end
function M:Observe(loader,dt)
    if not self.active or self.failed then return end
    if self.map.loadingSteps then return end
    for _,step in ipairs(self.steps) do
        if loader.phaseTimes and loader.phaseTimes[step.id] then
            local measured=loader.phaseTimes[step.id]
            step.elapsed=self.finished and step.id=='activate' and math.max(step.elapsed,measured) or measured
        end
    end
    if self.finished then return end
    if self.match and self.match.stage~='roster' then return end
    local index=1
    for i,id in ipairs(phases) do if loader.phase==id then index=i;break end end
    if loader.phase=='ready' then index=#phases end
    for i,step in ipairs(self.steps) do
        if i==index and not (loader.phaseTimes and loader.phaseTimes[step.id]) then step.elapsed=step.elapsed+math.max(0,dt) end
        if i<index and step.state~='done' then step.state='done';step.note=string.format('%.1fs',step.elapsed) end
        if i==index then
            step.state='run'
            if i==1 and loader.gate.total>0 then step.note=loader.gate.completed..' / '..loader.gate.total
            elseif step.id=='resources' and loader.options and loader.options.webWarmup then
                step.note=math.min(loader.warmIndex-1,#loader.options.webWarmup)..' / '..#loader.options.webWarmup
            elseif step.elapsed>15 then step.note='仍在加载…' end
        end
    end
    self.current=index;self.progress=(index-1)/#self.steps
end
function M:Finish()
    if not self.active then return end
    self.finished=true;self.current=#self.steps;self.installedAt=Time:GetSystemTime()
    self.steps[self.current].state='run'
    for i,step in ipairs(self.steps) do
        if i<#self.steps then step.state='done';step.note=string.format('%.1fs',step.elapsed) end
    end
    if not self.scenePrepared then self:PrepareScene() end
    print('[LoadingFlow] Scene installed; awaiting rendered frames')
end
function M:PrepareScene()
    self.scenePrepared=true
    if self.app.scene and PlatformUtils.IsWebPlatform() then
        if self.renderWarmup then self.renderWarmup:Restore() end
        local hangar=self:VisibleHangar()
        if hangar then
            -- Apply the current grid visibility before disabled drawables are
            -- filtered. Zero dt leaves grid/frame interpolation unchanged.
            hangar:UpdateGrid(0)
        end
        local viewport=renderer:GetViewport(0)
        self.sceneWarmupAt=Time:GetSystemTime()
        self.renderWarmup=SceneWarmup.New(self.app.scene,nil,viewport and viewport.camera)
        self.warmupTimes.drawables=#self.renderWarmup.items
        self.warmupTimes.outside=self.renderWarmup.skipped
        self.warmupTimes.disabled=self.renderWarmup.disabled or 0
        print('[LoadingFlow] Render warm-up drawables='..#self.renderWarmup.items..' outside='..self.renderWarmup.skipped..' disabled='..self.warmupTimes.disabled)
        self.combatWarmupPending=self.app.trial~=nil
    end
end
function M:VisibleHangar()
    local app=self.app;local hangar=app.hangar;local camera=app.camera
    if hangar and not hangar.disposed and hangar.scene==app.scene and hangar.root and hangar.root.enabled
        and camera and camera.node and camera.camera then return hangar end
end
function M:PrepareHangarWarmup()
    if not self:VisibleHangar() then return end
    local ok,warmup=pcall(HangarFxWarmup.New,self.app.scene,self.app.camera.camera)
    if not ok then self:Fail(warmup);return end
    self.hangarFxWarmup=warmup;self.hangarFxWarmupAt=Time:GetSystemTime()
    local who,face=TutorialFirstLine.Pick(self.app.tutorial,self.app)
    if who then
        local started,portrait,message=pcall(CommsWarmup.Begin,who,face)
        if not started or not portrait then self:Fail(started and message or portrait);return end
        self.commsWarmup=portrait;self.commsWarmupAt=Time:GetSystemTime()
    end
end
function M:ClearHangarWarmup()
    if self.hangarFxWarmup then self.hangarFxWarmup:Dispose();self.hangarFxWarmup=nil end
    if self.commsWarmup then self.commsWarmup:Dispose();self.commsWarmup=nil end
end
function M:Rendered()
    if not self.active or self.failed then return end
    if self.renderWarmup then
        if self.renderWarmup:Rendered() then
            self.worldRestoredAt=Time:GetSystemTime()
            self.warmupTimes.sceneMs=math.max(0,self.worldRestoredAt-self.sceneWarmupAt)
            self.warmupTimes.batches=self.renderWarmup.batches
            print('[LoadingFlow] Render warm-up batches='..self.renderWarmup.batches..' elapsedMs='..self.warmupTimes.sceneMs)
            self.renderWarmup=nil
            local hangar=self:VisibleHangar()
            if hangar and hangar.reflTex and hangar.reflFilter then
                -- Batched warmup hides off-camera geometry. Render the real
                -- reflected view once more after every original mask returns.
                local camera=self.app.camera
                hangar.nextReflection=hangar.time
                HangarAtmosphere.Update(hangar,camera.node,camera.camera,hangar.time)
            end
            self:PrepareHangarWarmup()
        end
        return
    end
    if self.hangarFxWarmup then
        local ok,done=pcall(self.hangarFxWarmup.Presented,self.hangarFxWarmup)
        if not ok then self:Fail(done);return end
        if done then
            self.warmupTimes.hangarFxMs=math.max(0,Time:GetSystemTime()-self.hangarFxWarmupAt)
            print('[LoadingFlow] Hangar FX warm-up elapsedMs='..self.warmupTimes.hangarFxMs)
            self.hangarFxWarmup=nil
        end
        return
    end
    if self.commsWarmup then
        local ok,done,message=pcall(self.commsWarmup.Presented,self.commsWarmup)
        if not ok or message then self:Fail(ok and message or done);return end
        if done then
            self.warmupTimes.commsMs=math.max(0,Time:GetSystemTime()-self.commsWarmupAt)
            print('[LoadingFlow] Communications warm-up elapsedMs='..self.warmupTimes.commsMs)
            self.commsWarmup:Dispose();self.commsWarmup=nil
        end
        return
    end
    if self.combatWarmupPending then
        self.combatWarmupPending=false
        local started=Time:GetSystemTime()
        self.warmupTimes.restoredWorldMs=self.worldRestoredAt and math.max(0,started-self.worldRestoredAt) or 0
        local trial=self.app.trial
        if trial and not trial.disposed then
            local ok,warmup=pcall(function() return CombatWarmup.New(trial) end)
            if not ok then self:Fail(warmup);return end
            self.combatWarmup=warmup
            self.combatWarmupAt=Time:GetSystemTime()
            self.warmupTimes.combatConstructMs=math.max(0,self.combatWarmupAt-started)
            print('[LoadingFlow] Combat warm-up restoredWorldMs='..self.warmupTimes.restoredWorldMs..' constructMs='..self.warmupTimes.combatConstructMs)
        end
        return
    end
    if self.combatWarmup then
        local ok,done=pcall(self.combatWarmup.Presented,self.combatWarmup)
        if not ok then self:Fail(done);return end
        if done then
            self.warmupTimes.combatMs=math.max(0,Time:GetSystemTime()-self.combatWarmupAt)
            print('[LoadingFlow] Combat warm-up elapsedMs='..self.warmupTimes.combatMs)
            self.combatWarmup=nil
        end
        return
    end
    if self.active and self.finished and not self.failed then self.warmFrames=self.warmFrames+1 end
end
function M:PageRendered()
    if self.active and self.pageVisible then self.pageDrawn=true end
end
function M:FramePresented()
    if self.pageDrawn then
        self.pageFrames=self.pageFrames+1;self.pageDrawn=false
        if self.map.boot and self.pageFrames==2 then print('[LoadingFlow] Boot page presented') end
    end
end
function M:CanStartLoad()
    return not self.active or self.phase=='loading' and self.pageFrames>=2
end
function M:Fail(message)
    if not self.active then return end
    self:ClearHangarWarmup()
    self.combatWarmupPending=false
    if self.combatWarmup then self.combatWarmup:Dispose();self.combatWarmup=nil end
    if self.renderWarmup then self.renderWarmup:Restore();self.renderWarmup=nil end
    self.failed=true;self.error=tostring(message or '加载失败');self.steps[self.current].state='fail'
    -- BattleFlow:Update would otherwise restart the looped search cue under the failure page.
    if self.sounds then self.sounds:Queue(false) end
    print('[LoadingFlow] Failed '..self.error)
end
function M:Back()
    if not self.active or self.phase=='exit-cover' or self.phase=='exit-reveal' then return end
    if self.map.boot then return end
    if not self.failed and (self.finished or self.match and self.match.stage=='found') then return end
    self:ClearHangarWarmup()
    local back=self.onBack;self.onBack=nil
    -- Recovery can open a replacement flow; never overwrite it after callback.
    self.phase='exit-cover';self.time=0;self.cancelled=true
    if back then back() end
end
function M:Retry()
    if self.active and self.failed and self.map.boot then self.app:Reload() end
end
function M:Advance(dt)
    if not self.active then return end
    local elapsed=math.max(0,dt);self.time=self.time+elapsed;self.elapsed=self.elapsed+elapsed
    if self.finished and self.phase=='loading' then
        local step=self.steps[#self.steps]
        step.elapsed=math.max(step.elapsed,math.max(0,Time:GetSystemTime()-self.installedAt)/1000)
    end
    if self.sounds then self.sounds:Update(elapsed) end
    if self.sounds and self.sounds.failure then self:Fail(self.sounds.failure);return end
    if self.match and self.phase=='loading' and not self.failed then
        local match=self.match;match.age=match.age+elapsed
        if match.stage=='queue' and match.age>=match.wait and self.sounds.ready then match.stage='found';match.age=0;self.sounds:Found()
        elseif match.stage=='found' and match.age>=1.1 then
            match.stage='roster';match.age=0
            if not self.app:EnterTrial('crater',match.cfg.id,match.roster,true) then self:Fail('对局未能启动') end
        end
    end
    if self.phase=='cover' and self.time>=.55 then
        self.pageVisible=true;self.phase='reveal';self.time=0
    elseif self.phase=='reveal' and self.time>=.59 then self.phase='loading';self.time=0
    elseif self.phase=='loading' and self.finished and not self.failed and self.warmFrames>=2 and (not self.match or self.match.age>=4) then
        local step=self.steps[#self.steps]
        step.state='done';step.note=string.format('%.1fs',step.elapsed)
        self.progress=1;self.phase='ready';self.time=0
    elseif self.phase=='ready' and self.time>=.45 then self.phase=self.map.boot and 'boot-exit' or 'exit-cover';self.time=0
    elseif self.phase=='boot-exit' and self.time>=.9 then self:Close()
    elseif self.phase=='exit-cover' and self.time>=.55 then self.pageVisible=false;self.phase='exit-reveal';self.time=0
    elseif self.phase=='exit-reveal' and self.time>=.59 then self:Close() end
end
function M:Close()
    local wasActive=self.active
    self:ClearHangarWarmup()
    self.combatWarmupPending=false
    if self.combatWarmup then self.combatWarmup:Dispose();self.combatWarmup=nil end
    if self.renderWarmup then self.renderWarmup:Restore();self.renderWarmup=nil end
    self.active=false;self.pageVisible=false;self.phase='closed';self.onBack=nil
    if self.artGate then self.artGate:Cancel() end
    if self.mapPrefetch then self.mapPrefetch:Cancel() end
    if self.sounds then self.sounds:Dispose();self.sounds=nil end
    if self.page then self.page:Close() end
    if wasActive then
        self.app.graphicsSettings:SetSceneVisible(true)
        local trial=self.app.trial
        if trial and trial.salvage and self.finished and not self.cancelled and not self.failed then trial.salvage:Begin();if trial.touch then trial:Resume() end
        elseif trial and trial.story and self.finished and not self.cancelled and not self.failed then trial.story:Begin();if trial.touch then trial:Resume() end
        elseif trial and self.match and self.finished and not self.cancelled and not self.failed then trial:StartIntro()
        elseif trial and trial.touch and not self.failed then trial:Resume() end
        print('[LoadingFlow] Closed')
    end
    self.match=nil
end
function M:Snapshot()
    return {active=self.active,phase=self.phase,visible=self.pageVisible,progress=self.progress,
        failed=self.failed,error=self.error,map=self.map and self.map.id,steps=self.steps,warmFrames=self.warmFrames,
        pageFrames=self.pageFrames,warmupTimes=self.warmupTimes,
        match=self.match and {stage=self.match.stage,age=self.match.age,wait=self.match.wait,mode=self.match.cfg.id}}
end
function M:Dispose()
    if self.disposed then return end;self:Close();self.disposed=true;self.page:Dispose();self.page=nil
end
return M
