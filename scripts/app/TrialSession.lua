-- Same app, separate scene lifetime. Loaded only when entering the trial.
local DriveMaps=require("app.DriveMaps")
local TouchPreferences=require("controls.TouchPreferences")
local TouchMode=require("controls.TouchMode")
local DrivePointer=require("controls.DrivePointer")
local Run=require("salvage.Run")
local Mission=require("story.Mission")
local BattleController=require("combat.BattleController")
local PracticeSession=require("app.PracticeSession")
local CameraFeedback=require("controls.CameraFeedback")
local SoundPreparation=require("audio.SoundPreparation")
local WeaponAudio=require("audio.WeaponAudio")
local DrivingAudio=require("audio.DrivingAudio")
local CombatFeedbackAudio=require("audio.CombatFeedbackAudio")
local CollisionAudio=require("audio.CollisionAudio")
local RestoreFlash=require("render.RestoreFlash")
local SpeedFov=require("controls.SpeedFov")
local BoundaryFx=require("render.BoundaryFx")
local AimLines=require("render.AimLines")
local DrillSpeed=require("render.DrillSpeed")
local SafeReset=require("controls.SafeReset")
local MatchMapShot=require("render.MatchMapShot")
local MatchIntro=require("app.MatchIntro")
local CameraObstacles=require("controls.CameraObstacles")
local Wheel=require("controls.Wheel")
local KillImpact=require("combat.KillImpact")
local MatchActions=require("combat.MatchActions")
local DriveAim=require("controls.DriveAim")
local RotorMotion=require("drive.RotorMotion")
local ReticleState=require("ui.ReticleState")
local NodeVisibility=require("render.NodeVisibility")
local StoryStomp=require("render.StoryStomp")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local ChaseCamera=require 'controls.ChaseCamera'
local ChaseState=require 'controls.ChaseState'
local DriveView=require "render.DriveView"
local Input=require "controls.DriveInput"
local Hud=require "ui.DriveHud"
local WeaponView=require "render.WeaponView"
local Effects=require "render.CombatEffects"
local CombatView=require "render.CombatView"
local Coord=require "core.Coord"
local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local TargetFeedback=require 'render.TargetFeedback'
local Quality=require 'render.Quality'
local M={};M.__index=M
function M.New(scene,bp,app,map,preparedWorld,checkpoint,retain,combatFactory)
    local self=setmetatable({disposed=false,app=app,name=bp.name,follow=false,lookIdle=0,scope=false,details=false,map=map or DriveMaps.trial},M)
    if retain then retain(self) end
    local ok,err=pcall(self.init,self,scene,bp,preparedWorld,checkpoint,combatFactory)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(scene,bp,preparedWorld,checkpoint,combatFactory)
    TouchPreferences.Get(self.app)
    local function Progress(p,stage) if checkpoint then checkpoint(p,stage) end end
    self.touch=TouchMode.Enabled()
    self.scene=scene;self.controls=Input.New();self.accumulator=0;self.fixedSteps=0;self.droppedTime=0
    self.pointer=DrivePointer.New(self)
    self.world=preparedWorld or DeferredModules[self.map.world].New(scene)
    Progress(.05,'world')
    -- Cinematic actors must exist before shared views are built; constructing
    -- a practice car first duplicates its rigid body and every part visual.
    if combatFactory then
        self.combat=combatFactory(self,bp,function(p,stage) Progress(.05+p*.4,stage or 'units') end)
        self.vehicle=self.combat.player.vehicle
    elseif self.map.endless then
        self.endless=DeferredModules['app.EndlessSession'].New(self,bp,self.map.endlessSaved);self.vehicle=self.endless.player.vehicle
    elseif self.map.salvage then
        self.salvage=Run.New(self,bp);self.vehicle=self.salvage.player.vehicle
    elseif self.map.storyLevel then
        self.story=Mission.New(self,bp,{prepareViews=true,retain=function(story) self.story=story;self.combat=story end,
            checkpoint=function(p) Progress(.05+p*.4,'story-effects') end});self.vehicle=self.story.player.vehicle
    elseif self.map.battleMode then
        self.battle=BattleController.New(self,bp,function(p) Progress(.05+p*.4,'units') end);self.vehicle=self.battle.player.vehicle
    else
        self.practice=PracticeSession.New(self,bp);self.vehicle=self.practice.player.vehicle
    end
    self.combat=self.combat or self.battle or self.story or self.salvage or self.endless or self.practice
    Progress(.45,'units')
    self.world.feedbackPlayer=self.combat and self.combat.player
    if self.map.environment then self.environment=DeferredModules[self.map.environment].New(scene,self.world.layout) end
    Progress(.5,'environment')
    self.ReleaseAssets=DeferredModules[self.map.assets].Release
    if #self.world.targets>0 then self.targetFeedback=TargetFeedback.New(self.world.root,self.world.targets) end
    self.weapons=self.combat.player.weapons;self.vehicle.drill=self.weapons.drill
    self.effects=Effects.New(scene,function(x,z) return self.world:GroundAt(x,z) end)
    self.cameraFeedback=CameraFeedback.New(self)
    self.effects.onEvent=function(e,remote)
        if not self.combat or self.combat.player.alive then self.cameraFeedback:Queue(e,remote) end
    end
    SoundPreparation.Prepare(function(p,stage) Progress(.5+p*.09,stage) end)
    self.weaponAudio=WeaponAudio.New(scene)
    self.drivingAudio=DrivingAudio.New(scene)
    self.feedbackAudio=CombatFeedbackAudio.New(scene)
    self.collisionAudio=CollisionAudio.New()
    Progress(.6,'audio')
    self.combatView=CombatView.New(scene,self.combat.spawnViewCache)
    self.combatView:Consume(self.world,function(p) Progress(.6+p*.25,'unit-views') end)
    Progress(.85,'player-view')
    self.view=DriveView.New(scene,self.combat.player.bp,self.vehicle,function(p) Progress(.85+p*.1,'player-view') end,
        function(view) self.view=view end);self.target=scene:CreateChild("FollowTarget")
    self.restoreFlash=RestoreFlash.New(scene)
    Progress(.95,'camera')
    self.chase=ChaseState.New();self.chase.minY=self.map.id=='trial' and .35 or -math.huge
    self.speedFov=SpeedFov.New();self.currentFov=48
    self.camera=ChaseCamera.Create(scene,2600)
    local boundary=BoundaryFx
    local boundaryMap=self.map.world=='drive.CraterWorld' and 'crater' or self.map.id
    local boundarySpec=boundary.ForWorld(self.world,boundaryMap)
    if boundarySpec then self.boundary=boundary.New(scene,boundarySpec,function(x,z) return self.world:GroundAt(x,z) end) end
    if self.combat then self.aimLines=AimLines.New(scene) end
    self.fxContext={camera=self.camera:GetNode(),time=0,fov=60}
    self.drillSpeed=DrillSpeed.New()
    self.safeReset=SafeReset.New(self)
    self.yaw=0;self.pitch=0;self.teleport=1;self.wantsReturn=false;self.disposed=false;self.hud=nil
    if self.combat then self.yaw=-self.combat.player.spawnAt.yaw*180/math.pi;self.view:ResetPose();self.view:Update(1);self:ResetCamera()
    else self:Reset() end
    if self.battle then self.battle.objectives:Update(0) end
    self:PostUpdate(1)
    if self.battle then
        self.mapCapture=MatchMapShot.New(scene,self.map)
        if checkpoint and coroutine.isyieldable() then
            while not self.mapCapture.ready do
                self.mapCapture:Update()
                Progress(.96+.039*(self.mapCapture.progress or 0),'minimap')
                if not self.mapCapture.captured then coroutine.yield() end
            end
            local texture,half=self.mapCapture:Take()
            self.mapCapture:Dispose();self.mapCapture=nil
            self.mapBase={texture=texture,half=half}
        end
    end
    Progress(1,'session-ready')
end
function M:Activate(onReturn)
    self.onReturn=onReturn;self.enteredTime=0
    self.hud=Hud.Create(self)
    if self.battle then self.battle.sounds:Play('battle_enter') end
    if self.touch then self:Resume() end
    input.mouseMode=MM_ABSOLUTE
    self.app.graphicsSettings:Show(self.scene,self.camera:GetCamera())
end
function M:StartIntro()
    if self.battle and not self.disposed then
        self.weaponAudio:SetActive(false)
        self.drivingAudio:SetActive(false)
        self.feedbackAudio:SetActive(false)
        if self.intro then self.intro:Dispose() end
        self.intro=MatchIntro.New(self)
    end
end
function M:Reset()
    if self.practice and not self.practice.player.alive then
        self.practice.player.spawnAt=self.world.layout.teleports[self.teleport];self.practice.player:Spawn();self.practice:SyncPlayer()
    end
    self.weapons.drill:Cancel()
    if self.drillSpeed then self.drillSpeed:Clear() end
    local spawn=self.world.layout.teleports[self.teleport]
    self.vehicle:Place(spawn.pos,spawn.yaw);self.yaw=-spawn.yaw*180/math.pi
    self.controls:Clear();if self.hud then self.hud.Clear() end
    self.accumulator=0;self.prevZ=nil;self.view:ResetPose();self.view:Update(1)
    self:ResetCamera()
end
function M:CameraCenter()
    local root=self.view.view.root
    -- root is CELL-scaled; com is already metres, so rotate without rescaling.
    local center=root.position+root.rotation*Coord.Vec(table.unpack(self.vehicle.com))
    return {-center.x,center.y,center.z}
end
function M:ResetCamera()
    if self.cameraFeedback then self.cameraFeedback:Reset() end
    self.pitch=self.chase:Reset(self:CameraCenter(),self.vehicle.spec.bounds.radius)
    self.cameraDistance=self.chase.dist*self.chase.zoom
end
function M:CameraObstacle(origin,direction,distance)
    -- target o -- other car/cone -- opaque wall | .4 m boom clearance.
    -- Exclude only our own body; keep precise camera-only building surfaces.
    local hit=self.world:CastRay(origin,direction,distance,self.vehicle.body)
    local nearest=hit and hit.dist or distance
    local surface=self.world.space.world:RaycastSingle(Ray(Coord.Vec(table.unpack(origin)),Coord.Vec(table.unpack(direction))),
        nearest,CameraObstacles.LAYER)
    if surface.body then return math.min(nearest,surface.distance) end
    return hit and hit.dist or nil
end
function M:HasFocus() return input.focus and not input.minimized end
function M:Resume() if self.battle and self.battle.rules.state=='over' or (self.story or self.salvage) and self.combat.rules.finished or self.endless and (self.endless.run.state=='editing' or self.endless.rules.finished) then return false end;return self.pointer:Capture() end
function M:Zoom(wheel)
    if self.details and self.hud and self.hud.readouts then
        self.hud.readouts:ScrollDetails(Wheel.Pixels(wheel));return
    end
    self:ZoomPixels(Wheel.Pixels(wheel))
end
function M:ZoomPixels(delta)
    if delta==0 then return end
    self.chase:Zoom(delta);self.cameraDistance=self.chase.dist*self.chase.zoom
end
function M:ConfirmKill(target) KillImpact.Confirm(self,target) end
function M:Pause()
    if self.safeReset then self.safeReset:Clear() end
    if self.weapons then self.weapons.drill:Cancel() end
    if self.drillSpeed then self.drillSpeed:Clear() end
    self.pendingRotorStep=false;self.pointer:Release();self.weaponAudio:SetActive(false);self.drivingAudio:SetActive(false);self.feedbackAudio:SetActive(false)
    if self.salvage and self.salvage.audio then self.salvage.audio:SetActive(false) end
end
function M:Escape()
    if self.dialog and self.dialog.unifiedSettings then
        Host.Close(self);self:Resume()
    else
        -- One Escape opens the same menu as the HUD settings button. Child
        -- settings return here instead of exposing the old click-to-drive layer.
        DeferredModules['ui.GameSettings'].Open(self)
    end
end
function M:PollPointer(dt)
    local controlling=self.pointer.captured or self.pointer.pending
    self.pointer:Poll(dt)
    -- Browsers may consume Escape themselves and only report lock loss.
    -- Explicit Pause/Release already cleared controlling before this poll.
    if controlling and not self.pointer.captured and not self.pointer.pending and not self.dialog and self:HasFocus() then
        DeferredModules['ui.GameSettings'].Open(self)
    end
end
function M:GoTo(name)
    for i,spot in ipairs(self.world.layout.teleports) do if spot.name==name then self.teleport=i;self:Reset();return true end end
    return false
end
function M:Flip()
    return self.safeReset:Begin()
end
function M:ApplyResetSpot(spot)
    self.vehicle:Place(spot.pos,spot.yaw)
    self.view:ResetPose();self.view:Update(1)
end
function M:ResetAll()
    if not self.practice then return end
    self.world:Reset();self.practice:SyncPlayer()
    if self.hud then self.hud.overlay:Consume(self.world.viewEvents) end
    self.combatView:Consume(self.world);self.teleport=1;self:Reset()
    self.weapons.projectiles={};self.effects:Clear()
    if self.hud then self.hud.overlay:Clear() end
    self.app.toasts:Push(self.map.id=='crater' and '已返回我方要塞，复原车辆' or '已复原：车辆、靶子、靶车、锥桶')
end
function M:NextArea()
    if not self.practice then return end
    self.teleport=self.teleport%#self.world.layout.teleports+1;self:Reset()
    self.app.toasts:Push('传送：'..self.world.layout.teleports[self.teleport].name)
end
local digitKeys={KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}
local actionKeys={KEY_ESCAPE,KEY_T,KEY_R,KEY_BACKSPACE,KEY_I,KEY_C,KEY_N,KEY_E,KEY_F,KEY_G,KEY_V,KEY_RETURN,KEY_KP_ENTER,KEY_SPACE,KEY_TAB,KEY_A,KEY_D,KEY_LEFT,KEY_RIGHT}
local resultKeys={KEY_RETURN,KEY_ESCAPE,KEY_T}
function M:KeyPressed(key) return input:GetKeyPress(key) end
function M:HandleKey(key)
    if self.story and self.story.epilogue and self.story.epilogue.active then self.story.epilogue:Key(key);return end
    if self.endless and self.endless:HandleKey(key) then return end
    if self.story and self.story.boss and self.story.boss:Key(key,0) then return end
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then
        if key==KEY_ESCAPE or key==KEY_RETURN or key==KEY_SPACE then self.battle.mvpShow:Skip() end
        return
    end
    if self.salvage and self.salvage:Key(key) then return end
    if self.battle and MatchActions.Key(self.battle,key) then return end
    if self.story and self.story.rules.finished then
        if key==KEY_R then self.app.restartStory=self.map.id;self.wantsReturn=true
        elseif key==KEY_ESCAPE or key==KEY_RETURN or key==KEY_T then self.wantsReturn=true end
        return
    end
    if self.story and key==KEY_RETURN then self.story.voice:SkipLine();return end
    if not self.practice and (key==KEY_N or key==KEY_BACKSPACE) then return end
    if self.combat and not self.combat.player.alive and key==KEY_R then return end
    if self.story and self.story.rules.choice then
        for i,digit in ipairs(digitKeys) do if key==digit then self.story.rules:Choose(i);self.story:Events();return end end
    end
    if key==KEY_ESCAPE then self:Escape()
    elseif key==KEY_T then if self.enteredTime>.4 then self.wantsReturn=true end
    elseif key==KEY_R then self:Flip()
    elseif key==KEY_BACKSPACE then self:ResetAll()
    elseif key==KEY_I then self.details=not self.details
    elseif key==KEY_C then
        self.follow=not self.follow
        self.app.toasts:Push(self.follow and '镜头跟车：开（不动鼠标时镜头慢慢回到车尾）' or '镜头跟车：关（镜头只跟鼠标）')
    elseif key==KEY_N then self:NextArea()
    else for i,digit in ipairs(digitKeys) do if key==digit then self.weapons:Select(i);break end end end
end
function M:PollKeys(typing)
    if typing or not self:HasFocus() then return end
    -- A completed salvage run owns the result overlay. Its exit keys must
    -- reach the commit gate even while that overlay blocks driving input.
    if self.salvage and self.salvage.result then
        for _,key in ipairs(resultKeys) do
            if self:KeyPressed(key) then self.wantsReturn=true;break end
        end
        return
    end
    if self.dialog then
        if self:KeyPressed(KEY_ESCAPE) then self:Escape() end
        return
    end
    for _,key in ipairs(actionKeys) do if self:KeyPressed(key) then
        self:HandleKey(key)
        if key==KEY_ESCAPE or self.dialog then return end
    end end
    for _,key in ipairs(digitKeys) do if self:KeyPressed(key) then self:HandleKey(key) end end
end
function M:Aim()
    if self.combat and not self.combat.player.alive then return self.aimPoint or self.combat.player:Position() end
    local ray=self.camera:GetCamera():GetScreenRay(.5,.5)
    local p,d=ray.origin,ray.direction
    local origin,direction={-p.x,p.y,p.z},{-d.x,d.y,d.z}
    local hit=self.world:CastRay(origin,direction,500,self.vehicle.body)
    self.aimHit=hit
    return DriveAim.Resolve(self,origin,direction,hit) or (hit and hit.point or {origin[1]+direction[1]*500,origin[2]+direction[2]*500,origin[3]+direction[3]*500})
end
function M:ConsumeWorldEvents()
    self.feedbackAudio:Consume(self.world.viewEvents,self.combat and self.combat.player)
    self.restoreFlash:Consume(self.combat.player,self.view.view,self.world.viewEvents)
    if self.hud then self.hud.overlay:Consume(self.world.viewEvents) end
    self.combatView:Consume(self.world);self.combatView:SavePose()
    self.effects:Consume(self.world.fx);self.world.fx={}
end
function M:ScopePivot()
    local group=self.weapons:Group()
    local w=self.scope and group and group.weapons[1]
    return w and (w.pivot or w.muzzle),group
end
function M:Tick(dt,command)
    local pivot=self:ScopePivot()
    self.effects:SetFirstPerson(pivot~=nil and pivot~=false and (not self.combat or self.combat.player.alive),self.weapons,self.view.view)
    if self.endless and (self.endless.run.state=='editing' or self.endless.run.state=='over') then self.accumulator=0;if self.hud then self.hud.Update(self,dt) end;return end
    if self.battle and self.battle.rules.state=='over' then if self.hud then self.hud.Update(self,dt) end;return end
    local speaking=self.combat and self.combat.voice and self.combat.voice.card~=nil
    local feedbackActive=self.pointer.captured and (not self.battle or self.battle.rules.state=='live') and (not self.story or not self.story.rules.finished) and (not self.salvage or self.salvage.begun and not self.salvage.rules.finished)
    self.weaponAudio:SetActive(feedbackActive and (not self.combat or self.combat.player.alive))
    self.weaponAudio:Update(dt,self.weapons,self.camera:GetNode(),self.combat and self.combat.entries,speaking)
    self.drivingAudio:SetActive(self.weaponAudio.active)
    -- H5 keeps damage voices and delayed explosions while the player is dead.
    self.feedbackAudio:SetActive(feedbackActive)
    if self.salvage then self.salvage.audio:SetActive(self.weaponAudio.active) end
    -- Source audio timers run in real time while kill impact slows simulation.
    self.feedbackAudio:Update(self.realFrameDt or dt,self.camera:GetNode(),speaking)
    local alive=not self.combat or self.combat.player.alive
    self.drivingAudio:Update(dt,alive and self.vehicle or nil,command,self.camera:GetNode(),self.combat and self.combat.entries,speaking)
    if (self.story or self.salvage) and self.combat.rules.finished then if self.hud then self.hud.Update(self,dt) end;return end
    -- Fixed 60 Hz on both desktop and 30 Hz mobile. Bound catch-up after pauses.
    local elapsed=math.min(math.max(dt,0),.1);self.droppedTime=self.droppedTime+math.max(0,dt-elapsed)
    self.accumulator=self.accumulator+elapsed
    -- Slow phones would otherwise spiral: each late frame queues more 60 Hz
    -- steps than the next frame can finish. Past the profile budget, slow down.
    local stepBudget=Quality.current.maxSimSteps/60
    if self.accumulator>stepBudget then self.droppedTime=self.droppedTime+self.accumulator-stepBudget;self.accumulator=stepBudget end
    self.pendingRotorStep=self.pendingRotorStep or command.rotorStep==true
    command.rotorStep=self.pendingRotorStep
    local aim=command.aim or self:Aim()
    command.firing=command.firing==true or DriveAim.AutoFire(self)
    self.aimPoint=aim;self.firing=command.firing==true
    local rotorStepped=false
    while self.accumulator>=1/60 do
        if self.combat then self.combat:BeforeStep(1/60,command,aim)
        else
            self.vehicle:StepRotors(aim,command.rotorStep and not rotorStepped,1/60)
            rotorStepped=true
            RotorMotion.Weapons(self.vehicle.rotors,self.weapons)
            self.vehicle:Step(command,1/60)
            local body=self.vehicle.body;local p,v=body.translation(),body.linvel()
            local eye=self.camera:GetNode().worldPosition
            self.weapons:Step(1/60,{firing=command.firing==true,aim=aim,pos={p.x,p.y,p.z},quat=body.rotation(),
                vel={v.x,v.y,v.z},body=body,eye={-eye.x,eye.y,eye.z}},self.world.env)
        end
        -- WeaponSystem reuses its event array: consume every fixed step immediately.
        if not self.combat then self.effects:Consume(self.weapons.fx);self.weaponAudio:Consume(self.weapons.fx) end
        command.rotorStep=false
        self.pendingRotorStep=false
        self.collisionAudio:BeforeStep(self.world.units,not self.combat and self or nil)
        self.world:Step(1/60)
        self.collisionAudio:AfterStep(self.world.time,self.world.viewEvents)
        if self.combat then self.combat:AfterStep(1/60);self.combat:SyncPlayer() end
        if self.combat then
            for _,entry in ipairs(self.combat.entries) do if entry.unit.alive then self.drivingAudio:Observe(entry.unit.vehicle,1/60,entry.unit~=self.combat.player) end end
        else self.drivingAudio:Observe(self.vehicle,1/60,false) end
        if not self.combat or self.combat.player.alive then
            if self.weapons.drill:ControlsBody() then self.vehicle:SyncDrillPose() end
            self.view:SavePose();local center=self.vehicle.body.center()
            self.world.metrics:Timing(self.world.time,{center.x,center.y,center.z},self.vehicle.speed,self.prevZ);self.prevZ=center.z
        end
        self:ConsumeWorldEvents()
        self.accumulator=self.accumulator-1/60;self.fixedSteps=self.fixedSteps+1
        if self.battle and self.battle.rules.state=='over' or (self.story or self.salvage) and self.combat.rules.finished or self.endless and (self.endless.run.state=='editing' or self.endless.run.state=='over') then self.accumulator=0;break end
    end
    -- UI repairs and external damage can replace bodies between fixed steps.
    -- Retire or rebind their views before a frame with no physics step renders.
    if #self.world.viewEvents>0 or #self.world.debris.events>0 or #self.world.fx>0 then
        if self.combat then self.combat:SyncPlayer() end
        self:ConsumeWorldEvents()
    end
    self.fxContext.time=self.world.time
    local alive=not self.combat or self.combat.player.alive
    if alive and self.practice and self.vehicle.body.translation().y < (self.map.id=='crater' and -60 or -30) then
        self.teleport=1;self:Reset()
    end
    if alive then self.view:Update(self.weapons.drill:Latched() and 1 or self.accumulator*60,elapsed,self.fxContext) end
    if self.targetFeedback then self.targetFeedback:Update(self.world.targets,self.world.time,self.camera:GetNode(),elapsed) end
    if alive then
        WeaponView.Update(self.view.view,self.weapons,self.accumulator*60,elapsed,self.world.time,self.effects)
        self.view.view:UpdateWeaponEffects(elapsed,self.fxContext,self.effects)
    end
    self.combatView:Update(self.accumulator*60,elapsed,self.fxContext)
    self.restoreFlash:Update(elapsed)
    if self.combat then
        local shots={};for _,entry in ipairs(self.combat.entries) do if entry.unit.alive then for _,shot in ipairs(entry.unit.weapons.projectiles) do shots[#shots+1]=shot end end end
        self.effects:Update(elapsed,shots,self.camera:GetNode())
    else self.effects:Update(elapsed,self.weapons.projectiles,self.camera:GetNode()) end
    self.safeReset:Update(elapsed)
    if self.hud then self.hud.Update(self,elapsed) end
end
function M:Update(dt)
    if self.disposed then return end
    if self.endless then self.endless:RestorePresentation() end
    if self.app.loadingFlow and self.app.loadingFlow.active then return end
    self.realFrameDt=dt;self.frameDt=dt
    if self.battle then self.battle.sounds:Update(dt);self.battle.voice:Update(dt) end
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then
        self:Pause()
        for _,key in ipairs({KEY_SPACE,KEY_RETURN,KEY_ESCAPE}) do if input:GetKeyPress(key) then self.battle.mvpShow:Skip();break end end
        self.battle.mvpShow:Update(dt)
        if self.hud then self.hud.Update(self,dt) end
        return
    end
    if not (self.endless and self.endless.run.state=='editing') and not (self.intro and not self.intro.done) then
        self.frameDt=KillImpact.Step(self,dt);dt=self.frameDt
    end
    if self.story then
        self.story:Update(dt)
        if self.story.epilogue and self.story.epilogue.active then
            for _,key in ipairs(resultKeys) do if input:GetKeyPress(key) then self.story.epilogue:Key(key) end end
            if input:GetKeyPress(KEY_SPACE) then self.story.epilogue:Key(KEY_SPACE) end
            return
        end
        local boss=self.story.boss
        if boss and boss.cinematic and input:GetKeyDown(KEY_RETURN) then
            if input:GetKeyPress(KEY_RETURN) then self.bossEnterHeld=0;self.bossEnterFlow=boss.flow
            elseif self.bossEnterFlow==boss.flow then
                self.bossEnterHeld=(self.bossEnterHeld or 0)+dt
                if self.bossEnterHeld>.9 then boss.skip=true end
            end
        else self.bossEnterHeld=0;self.bossEnterFlow=nil end
    end
    if self.endless then
        self.endless:Update(dt)
        if self.endless.run.state=='editing' then return end
    end
    if self.intro and not self.intro.done then
        self.drillSpeed:Clear()
        if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_ESCAPE) then self.intro:Finish()
        else self.intro:Update(dt) end
        return
    end
    Host.Update(self,dt)
    self.enteredTime=(self.enteredTime or 0)+math.max(0,dt)
    local width,height=UI.GetViewportSize()
    if self.hud and (width~=self.hud.width or height~=self.hud.height) then
        self:Pause();self.hud.Dispose();self.hud=Hud.Create(self)
    end
    if self.dialogTick then self.dialogTick(dt) end
    local focus=UI.GetFocus();local typing=focus and focus.OnTextInput~=nil
    self:PollKeys(typing)
    if self.wantsReturn then
        self.wantsReturn=false
        if self.story and self.map.storyLevel==5 and self.story.rules.finished and self.story.StartEpilogue then
            if self.story:StartEpilogue(self.hud.root,function() self:Pause();self.onReturn() end) then return end
        end
        if not self.salvage or self.salvage:Return() then self:Pause();self.onReturn();return end
    end
    if self.dialog or typing or not self:HasFocus() then self:Pause() end
    if self.dialog and self.dialog.matchLeave then
        self.accumulator=0
        if self.hud then self.hud.Update(self,dt) end
        return
    end
    self:PollPointer(dt)
    if self.salvage then
        self.salvage.cine:Update(dt)
        local shot=self.salvage.cine.current
        if self.salvage.cine.blocking and (shot.name~='drop' or shot.t<=8.3) then
            self.controls:Clear();self.firing=false
            self:Tick(dt,{throttle=0,steer=0});return
        end
    end
    if not self.touch and not self.pointer.captured and not self.dialog and not typing and self:HasFocus() then
        self:Zoom(input:GetMouseMoveWheel())
        if input:GetMouseButtonDown(MOUSEB_RIGHT) then
            self.yaw,self.pitch=ChaseState.Look(self.yaw,self.pitch,input.mouseMoveX,input.mouseMoveY,1,self.vehicle.spec.wings~=nil and #self.vehicle.spec.wings>0);self.lookIdle=0
        end
    end
    local blocked=self.dialog~=nil or typing or not self.pointer.captured
    if blocked then
        if self.salvage then self.salvage.tapE=false;self.salvage.tapF=false end
        if self.hud then self.hud.Clear() else self.controls:Clear() end
        -- Source pointer-unlocked mode keeps world physics alive with neutral
        -- commands; menus never propel the vehicle or fire held weapons.
        self:Tick(dt,{throttle=0,steer=0});return
    end
    local command=self.controls:Read();local dx,dy=self.controls:TakeLook()
    local group=self.weapons:Group()
    local sensitivity=(self.scope and ReticleState.ScopeFov(48,group and group.kind)/48 or 1)*DriveAim.Look(self,dt)
    self.yaw,self.pitch=ChaseState.Look(self.yaw,self.pitch,dx,dy,sensitivity,self.vehicle.spec.wings~=nil and #self.vehicle.spec.wings>0)
    if not self.combat or self.combat.player.alive then self.controls:Command(command,self.vehicle,-math.rad(self.yaw),-math.rad(self.pitch)) end
    self.lookIdle=(dx~=0 or dy~=0) and 0 or self.lookIdle+dt
    local alive=not self.combat or self.combat.player.alive
    if alive and self.follow and self.lookIdle>1.2 and not command.firing and self.vehicle.speed>3 then
        local difference=(-self.vehicle:Yaw()*180/math.pi-self.yaw+180)%360-180
        self.yaw=self.yaw+difference*math.min(1,dt*1.5)
    end
    self:Tick(dt,command)
end
function M:PostUpdate(dt)
    if self.disposed then return end
    if self.endless then self.endless:RestorePresentation() end
    if self.endless and self.endless.run.state=='editing' then return end
    if self.boundary then self.boundary:Update(self.world.time,self.combat and self.combat.player:Position() or self:CameraCenter()) end
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then self.battle.mvpShow:Camera();return end
    if self.intro and not self.intro.done then
        self.intro:Camera();if self.environment then self.environment:Update(dt,self.camera:GetNode()) end;return
    end
    dt=self.frameDt or dt
    local root=self.view.view.root;local p=root.position
    if self.combat and not self.combat.player.alive then
        self.effects:SetFirstPerson(false)
        if self.view.view.weaponEffects then self.view.view.weaponEffects:SetVisible(false) end
        self.cameraFeedback:Discard()
        self.drillSpeed:Clear()
        NodeVisibility.Set(self.restoreFlash.root,false,true)
        if self.battle then
            local node=self.camera:GetNode();local eye=node.worldPosition
            local pose=MatchActions.Pose(self.battle,{-eye.x,eye.y,eye.z},dt)
            if pose then ChaseCamera.Watch(self.camera,pose) end
            if self.aimLines then
                self.sniperWarnings=self.aimLines:Update(self.world.units,self.combat.player,function(...) return self.world:CastRay(...) end,self.camera:GetCamera(),self.world.time)
            end
            if self.environment then self.environment:Update(dt,node) end
            return
        end
        local watched=false
        for _,entry in ipairs(self.combat.entries) do if entry.unit.team=='blue' and entry.unit.alive then watched=entry.unit;break end end
        if watched then p=Coord.Vec(table.unpack(watched:Position())) end
        local pose=self.chase:Pose(dt,{-p.x,p.y,p.z},self.yaw,self.pitch,function() return nil end)
        ChaseCamera.Apply(self.camera,self.target,dt,pose,self.yaw,self.pitch)
        if self.aimLines then
            self.sniperWarnings=self.aimLines:Update(self.world.units,self.combat.player,function(...) return self.world:CastRay(...) end,self.camera:GetCamera(),self.world.time)
        end
        if self.salvage then self.salvage.cine:Camera() end
        if self.environment then self.environment:Update(dt,self.camera:GetNode()) end;return
    end
    local pivot,group=self:ScopePivot()
    local eye=self.scope and pivot and root.position+root.rotation*Coord.Vec(pivot[1],pivot[2]+.6,pivot[3])
    local pose=self.chase:Pose(dt,self:CameraCenter(),self.yaw,self.pitch,function(origin,dir,distance)
        return self:CameraObstacle(origin,dir,distance)
    end,eye and {-eye.x,eye.y,eye.z})
    ChaseCamera.Apply(self.camera,self.target,dt,pose,self.yaw,self.pitch)
    self.firstPerson=eye~=nil and eye~=false;NodeVisibility.Set(root,not self.firstPerson,true);self.weapons.aimed=self.scope and group~=nil
    self.effects:SetFirstPerson(self.firstPerson,self.weapons,self.view.view)
    if self.view.view.weaponEffects then self.view.view.weaponEffects:SetVisible(not self.firstPerson and root.enabled) end
    NodeVisibility.Set(self.restoreFlash.root,root.enabled,true)
    self.drillSpeed:Update(dt,self.camera:GetCamera(),self.weapons,self.pointer.captured and (not self.combat or self.combat.player.alive))
    local c=self.camera:GetCamera()
    self.currentFov=self.speedFov:Step(self.vehicle,dt,48,self.currentFov,{scope=self.scope and ReticleState.ScopeFov(48,group and group.kind) or nil,
        rush=self.drillSpeed.rush,charge=self.weapons.drill.held and self.weapons.drill.held.windup or 0,punch=self.fovPunch or 0})
    self.fovPunch=(self.fovPunch or 0)*math.exp(-dt*5)
    c.fov=self.currentFov;self.fxContext.fov=c.fov
    self.cameraFeedback:Flush(self:CameraCenter())
    self.cameraFeedback:Apply(dt,self.camera:GetNode(),self.vehicle,function(f,mech)
        local land=f.kind=='land'
        if f.kind~='launch' then
            local p={f.pos[1],f.pos[2]-(land and mech.standAvg or .4),f.pos[3]}
            StoryStomp.Emit(self.effects,p,land and math.min(1,f.strength*1.3) or f.strength)
        end
        self.drivingAudio:Play(f.kind=='launch' and 'mech_push' or land and 'mech_land' or 'mech_step',f.strength)
    end)
    if self.story and self.story.boss then self.story.boss:AfterCamera(dt) end
    if self.aimLines then self.sniperWarnings=self.aimLines:Update(self.world.units,self.combat.player,function(...) return self.world:CastRay(...) end,c,self.world.time) end
    if self.salvage then self.salvage.cine:Camera();self.fxContext.fov=c.fov end
    if self.environment then self.environment:Update(dt,self.camera:GetNode()) end
    -- Apply after camera targeting and scope masks; this never moves physics.
    if self.endless then self.endless:Present() end
end
function M:Dispose(checkpoint)
    if self.disposed then return end
    self.disposed=true
    if self.mapCapture then self.mapCapture:Dispose();self.mapCapture=nil end
    if self.mapBase then self.mapBase.texture:Dispose();self.mapBase=nil end
    -- Leaving the editor restores the live battle view, HUD and camera first.
    if self.endless and self.endless.edit then self.endless.edit:Leave();self.endless.edit=nil end
    Host.Dispose(self)
    if self.intro then self.intro:Dispose();self.intro=nil end
    if self.pointer then self.pointer:Release() end
    if self.hud then self.hud.Dispose();self.hud=nil end
    if self.controls then self.controls:Clear() end
    if checkpoint then checkpoint() end
    if self.safeReset then self.safeReset:Dispose();self.safeReset=nil end
    if self.restoreFlash then self.restoreFlash:Dispose();self.restoreFlash=nil end
    if self.drillSpeed then self.drillSpeed:Dispose() end
    if self.effects then self.effects:Dispose() end
    if checkpoint then checkpoint() end
    if self.weaponAudio then self.weaponAudio:Dispose() end
    if self.drivingAudio then self.drivingAudio:Dispose() end
    if self.feedbackAudio then self.feedbackAudio:Dispose() end
    if self.collisionAudio then self.collisionAudio:Dispose();self.collisionAudio=nil end
    if checkpoint then checkpoint() end
    if self.combatView then self.combatView:Dispose(checkpoint) end
    if self.aimLines then self.aimLines:Dispose() end
    if self.boundary then self.boundary:Dispose() end
    if checkpoint then checkpoint() end
    DriveAim.Clear(self)
    self.weapons=nil;self.aimHit=nil
    if self.view then self.view:Dispose() end
    if checkpoint then checkpoint() end
    if self.combat then self.combat:Dispose() elseif self.vehicle then self.vehicle:Dispose() end
    if self.targetFeedback then self.targetFeedback:Dispose() end
    if self.environment then self.environment:Dispose();self.environment=nil end
    if checkpoint then checkpoint() end
    if self.world then self.world:Dispose(checkpoint) end
    if self.camera then self.camera:GetNode():Dispose() end
    if self.target then self.target:Dispose() end
    self.combat=nil;self.battle=nil;self.story=nil;self.salvage=nil;self.endless=nil;self.practice=nil
    self.world=nil;self.scene=nil;self.vehicle=nil;self.view=nil;self.combatView=nil
    self.camera=nil;self.target=nil;self.fxContext=nil;self.effects=nil
    self.weaponAudio=nil;self.drivingAudio=nil;self.feedbackAudio=nil;self.targetFeedback=nil
    self.aimLines=nil;self.boundary=nil;self.controls=nil;self.pointer=nil
    self.cameraFeedback=nil;self.drillSpeed=nil;self.app=nil;self.onReturn=nil
end
return M
