-- Scene preparation and UI lifetime are separate: the overlay survives SetRoot.
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
    self.artGate=require('app.ResourceGate').New();self.artReady=false
    self.page=require('ui.LoadingPage').New(self)
end
function M:Open(map,onBack)
    self:Close()
    self.generation=self.generation+1;self.active=true;self.phase='cover';self.time=0;self.elapsed=0
    self.map=map;self.onBack=onBack;self.finished=false;self.failed=false;self.error=''
    self.artReady=false;self.cancelled=false
    local generation=self.generation
    if not map.boot then self.artGate:Start({map.loadingArt or 'UI/Modes/crater.jpg'},function(ok)
        if not self.active or self.generation~=generation then return end
        self.artReady=ok
        if ok then require('urhox-libs/UI/Core/ImageCache').Release(map.loadingArt or 'UI/Modes/crater.jpg') end
    end) end
    self.steps={};self.current=1;self.progress=0;self.warmFrames=0;self.readyTime=0;self.pageFrames=0;self.pageDrawn=false
    for i,id in ipairs(phases) do self.steps[i]={id=id,label=labels[i],state=i==1 and 'run' or 'wait',elapsed=0,note=''} end
    self.page:Open();print('[LoadingFlow] Open '..map.id)
    if map.boot then self.pageVisible=true;self.phase='loading' end
end
function M:QueueBattle(mode,bp)
    local cfg=require('combat.ArenaData').modes[mode]
    local tier=bp:Stats().fitTier
    if not tier then self.app.toasts:Push('这辆车超出了 T5 的限制，改装后才能出战','bad');return false end
    local roster=require('combat.Matchmaker').Find(self.app.store,cfg.size,tier.id)
    local map={};for key,value in pairs(require('app.DriveMaps').crater) do map[key]=value end
    map.loadingBrand=cfg.name;map.loadingSub=cfg.size..'V'..cfg.size;map.loadingTips=cfg.rules
    self:Open(map,function() self.app:CancelMapLoad(true) end)
    self.match={cfg=cfg,roster=roster,tier=tier.id,wait=roster.wait,carName=bp.name,stage='queue',age=0}
    self.sounds=require('audio.BattleFlow').New();self.sounds:Prepare(true);self.sounds:Queue(true)
    local paths=require('ui.MatchLobby').Dependencies(roster);local generation=self.generation
    self.artGate:Start(paths,function(ok)
        if not self.active or self.generation~=generation then return end
        self.artReady=ok
        if ok then
            local images=require 'urhox-libs/UI/Core/ImageCache'
            for _,path in ipairs(paths) do images.Release(path) end
        end
    end)
    return true
end
function M:Observe(loader,dt)
    if not self.active or self.failed then return end
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
    if self.app.scene and require('urhox-libs.Platform.PlatformUtils').IsWebPlatform() then
        if self.renderWarmup then self.renderWarmup:Restore() end
        local viewport=renderer:GetViewport(0)
        self.renderWarmup=require('render.SceneWarmup').New(self.app.scene,nil,viewport and viewport.camera)
        print('[LoadingFlow] Render warm-up drawables='..#self.renderWarmup.items..' outside='..self.renderWarmup.skipped)
        self.combatWarmupPending=self.app.trial~=nil
    end
    print('[LoadingFlow] Scene installed; awaiting rendered frames')
end
function M:Rendered()
    if not self.active or self.failed then return end
    if self.renderWarmup then
        if self.renderWarmup:Rendered() then
            print('[LoadingFlow] Render warm-up batches='..self.renderWarmup.batches)
            self.renderWarmup=nil
        end
        return
    end
    if self.combatWarmupPending then
        self.combatWarmupPending=false
        local trial=self.app.trial
        if trial and not trial.disposed then
            local ok,warmup=pcall(function() return require('render.CombatWarmup').New(trial) end)
            if not ok then self:Fail(warmup);return end
            self.combatWarmup=warmup
        end
        return
    end
    if self.combatWarmup then
        local ok,done=pcall(self.combatWarmup.Presented,self.combatWarmup)
        if not ok then self:Fail(done);return end
        if done then self.combatWarmup=nil end
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
    self.combatWarmupPending=false
    if self.combatWarmup then self.combatWarmup:Dispose();self.combatWarmup=nil end
    if self.renderWarmup then self.renderWarmup:Restore();self.renderWarmup=nil end
    self.failed=true;self.error=tostring(message or '加载失败');self.steps[self.current].state='fail'
    print('[LoadingFlow] Failed '..self.error)
end
function M:Back()
    if not self.active or self.phase=='exit-cover' or self.phase=='exit-reveal' then return end
    if self.map.boot then return end
    if self.finished and not self.failed or self.match and self.match.stage=='found' then return end
    local back=self.onBack;self.onBack=nil
    if back then back() end
    self.phase='exit-cover';self.time=0;self.cancelled=true
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
    if self.match and self.phase=='loading' and not self.failed then
        local match=self.match;match.age=match.age+elapsed
        if match.stage=='queue' and match.age>=match.wait then match.stage='found';match.age=0;self.sounds:Found()
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
    self.combatWarmupPending=false
    if self.combatWarmup then self.combatWarmup:Dispose();self.combatWarmup=nil end
    if self.renderWarmup then self.renderWarmup:Restore();self.renderWarmup=nil end
    self.active=false;self.pageVisible=false;self.phase='closed';self.onBack=nil
    if self.artGate then self.artGate:Cancel() end
    if self.sounds then self.sounds:Dispose();self.sounds=nil end
    if self.page then self.page:Close() end
    if wasActive then
        self.app.graphicsSettings:SetSceneVisible(true)
        local trial=self.app.trial
        if trial and trial.salvage and self.finished and not self.cancelled and not self.failed then trial.salvage:Begin();if trial.touch then trial:Resume() end
        elseif trial and trial.story and self.finished and not self.cancelled and not self.failed then trial.story:Begin();if trial.touch then trial:Resume() end
        elseif trial and self.match and self.finished and not self.cancelled and not self.failed then trial:StartIntro()
        elseif trial and trial.touch then trial:Resume() end
        print('[LoadingFlow] Closed')
    end
    self.match=nil
end
function M:Snapshot()
    return {active=self.active,phase=self.phase,visible=self.pageVisible,progress=self.progress,
        failed=self.failed,error=self.error,map=self.map and self.map.id,steps=self.steps,warmFrames=self.warmFrames,
        pageFrames=self.pageFrames,match=self.match and {stage=self.match.stage,age=self.match.age,wait=self.match.wait,mode=self.match.cfg.id}}
end
function M:Dispose()
    if self.disposed then return end;self:Close();self.disposed=true;self.page:Dispose();self.page=nil
end
return M
