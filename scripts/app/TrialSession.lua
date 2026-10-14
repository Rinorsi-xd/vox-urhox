-- Same app, separate scene lifetime. Loaded only when entering the trial.
local ThirdPerson=require "urhox-libs.Camera.ThirdPersonCamera"
local Vehicle=require "drive.Vehicle"
local Spec=require "drive.VehicleSpec"
local DriveView=require "render.DriveView"
local Input=require "controls.DriveInput"
local Hud=require "ui.DriveHud"
local Weapons=require "combat.WeaponSystem"
local WeaponView=require "render.WeaponView"
local Effects=require "render.CombatEffects"
local CombatView=require "render.CombatView"
local Coord=require "core.Coord"
local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local TargetFeedback=require 'render.TargetFeedback'
local M={};M.__index=M
function M.New(scene,bp,app,map,preparedWorld,checkpoint,retain)
    local self=setmetatable({disposed=false,app=app,name=bp.name,follow=true,lookIdle=0,scope=false,details=false,map=map or require('app.DriveMaps').trial},M)
    if retain then retain(self) end
    local ok,err=pcall(self.init,self,scene,bp,preparedWorld,checkpoint)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(scene,bp,preparedWorld,checkpoint)
    local function Progress(p,stage) if checkpoint then checkpoint(p,stage) end end
    self.touch=require('controls.TouchMode').Enabled()
    self.scene=scene;self.controls=Input.New();self.accumulator=0;self.fixedSteps=0;self.droppedTime=0
    self.pointer=require('controls.DrivePointer').New(self)
    self.world=preparedWorld or require(self.map.world).New(scene)
    Progress(.05,'world')
    if self.map.salvage then
        self.salvage=require('salvage.Run').New(self,bp);self.vehicle=self.salvage.player.vehicle
    elseif self.map.storyLevel then
        self.story=require('story.Mission').New(self,bp);self.vehicle=self.story.player.vehicle
    elseif self.map.battleMode then
        self.battle=require('combat.BattleController').New(self,bp,function(p) Progress(.05+p*.4,'units') end);self.vehicle=self.battle.player.vehicle
    else self.vehicle=Vehicle.New(self.world.space,Spec.Build(bp)) end
    self.combat=self.battle or self.story or self.salvage
    Progress(.45,'units')
    self.world.feedbackPlayer=self.combat and self.combat.player
    if self.map.environment then self.environment=require(self.map.environment).New(scene,self.world.layout) end
    Progress(.5,'environment')
    self.ReleaseAssets=require(self.map.assets).Release
    if #self.world.targets>0 then self.targetFeedback=TargetFeedback.New(self.world.root,self.world.targets) end
    self.weapons=self.combat and self.combat.player.weapons or Weapons.New(self.vehicle.spec);self.vehicle.drill=self.weapons.drill
    self.effects=Effects.New(scene,function(x,z) return self.world:GroundAt(x,z) end)
    self.weaponAudio=require('audio.WeaponAudio').New(scene)
    self.drivingAudio=require('audio.DrivingAudio').New(scene)
    self.feedbackAudio=require('audio.CombatFeedbackAudio').New(scene)
    Progress(.6,'audio')
    self.combatView=CombatView.New(scene);if not self.combat then self.world:SetUnits(bp) end
    self.combatView:Consume(self.world,function(p) Progress(.6+p*.25,'unit-views') end)
    Progress(.85,'player-view')
    self.view=DriveView.New(scene,bp,self.vehicle);self.target=scene:CreateChild("FollowTarget")
    Progress(.95,'camera')
    self.cameraOffset=self.vehicle.legMode and Vector3.ZERO or Vector3(0,math.max(3.8,(self.vehicle.spec.bounds.max[2]-self.vehicle.spec.bounds.min[2])*.65),0)
    self.minCameraDistance=math.max(8,self.vehicle.spec.bounds.radius*1.5)
    self.cameraDistance=math.max(24,self.vehicle.spec.bounds.radius*3.4)
    self.maxCameraDistance=math.max(65,self.cameraDistance*2.5)
    -- Side view: wall |<- 0.50 m sign ->|< .35 m clearance > camera -> car.
    -- Authored collision hulls omit decorative trim. The old .20 m padding
    -- put the camera inside the fortress sign at yaw=0 (its back face filled
    -- the screen). Keep the near plane in front of trim at grazing angles too.
    self.camera=ThirdPerson.Create(scene,{modes={normal={distance=self.cameraDistance,offset=self.cameraOffset,fov=48}},collisionMask=1 | require('controls.CameraObstacles').LAYER,collisionPadding=.85,farClip=2600})
    self.fxContext={camera=self.camera:GetNode(),time=0,fov=60}
    self.drillSpeed=require('render.DrillSpeed').New()
    self.yaw=0;self.pitch=30;self.teleport=1;self.wantsReturn=false;self.disposed=false;self.hud=nil
    if self.combat then self.yaw=-self.combat.player.spawnAt.yaw*180/math.pi;self.view:ResetPose();self.view:Update(1)
    else self:Reset() end
    if self.battle then self.battle.objectives:Update(0) end
    self:PostUpdate(1)
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
        self.intro=require('app.MatchIntro').New(self)
    end
end
function M:Reset()
    self.weapons.drill:Cancel()
    if self.drillSpeed then self.drillSpeed:Clear() end
    local spawn=self.world.layout.teleports[self.teleport]
    self.vehicle:Place(spawn.pos,spawn.yaw);self.yaw=-spawn.yaw*180/math.pi
    self.controls:Clear();if self.hud then self.hud.Clear() end
    self.accumulator=0;self.prevZ=nil;self.view:ResetPose();self.view:Update(1)
    -- A teleport cancels shots in flight and transient feedback, not energy/cooldowns.
    self.weapons.projectiles={};self.weapons.wasFiring=false;self.effects:Clear();self.weaponAudio:Stop()
    self.drivingAudio:Stop()
    self.feedbackAudio:Stop()
end
function M:HasFocus() return input.focus and not input.minimized end
function M:Resume() if self.battle and self.battle.rules.state=='over' or (self.story or self.salvage) and self.combat.rules.finished then return false end;return self.pointer:Capture() end
function M:Zoom(wheel)
    self:ZoomPixels(require('controls.Wheel').Pixels(wheel))
end
function M:ZoomPixels(delta)
    if delta==0 then return end
    self.cameraDistance=math.max(self.minCameraDistance,math.min(self.maxCameraDistance,self.cameraDistance*1.0012^delta))
    -- The library interpolates only across distinct modes. Alternate two public
    -- mode configurations instead of mutating its private interpolation state.
    local mode=self.camera:GetMode()=='zoomA' and 'zoomB' or 'zoomA'
    self.camera:SetModeConfig(mode,{distance=self.cameraDistance,offset=self.cameraOffset,fov=48})
    self.camera:SetMode(mode)
end
function M:Pause()
    if self.weapons then self.weapons.drill:Cancel() end
    if self.drillSpeed then self.drillSpeed:Clear() end
    self.pendingRotorStep=false;self.pointer:Release();self.weaponAudio:SetActive(false);self.drivingAudio:SetActive(false);self.feedbackAudio:SetActive(false)
    if self.salvage and self.salvage.audio then self.salvage.audio:SetActive(false) end
end
function M:Escape()
    if self.dialog then Host.Close(self);self:Pause()
    elseif self.pointer.captured then self:Pause()
    else self.wantsReturn=true end
end
function M:GoTo(name)
    for i,spot in ipairs(self.world.layout.teleports) do if spot.name==name then self.teleport=i;self:Reset();return true end end
    return false
end
function M:Flip()
    if self.combat and not self.combat.player.alive then return end
    self.weapons.drill:Cancel()
    self.drillSpeed:Clear()
    local p=self.vehicle.body.translation();local yaw=self.vehicle:Yaw()
    self.vehicle:Place({p.x,p.y+self.vehicle.spec.bounds.radius*.6,p.z},yaw)
    self.controls:Clear();if self.hud then self.hud.Clear() end
    self.accumulator=0;self.prevZ=nil;self.view:ResetPose();self.view:Update(1)
end
function M:ResetAll()
    if self.combat then return end
    self.world:Reset();self.combatView:Consume(self.world);self.teleport=1;self:Reset()
    if self.hud then self.hud.overlay:Clear() end
    self.app.toasts:Push(self.map.id=='crater' and '已返回我方要塞，复原车辆' or '已复原：车辆、靶子、靶车、锥桶')
end
function M:NextArea()
    if self.combat then return end
    self.teleport=self.teleport%#self.world.layout.teleports+1;self:Reset()
    self.app.toasts:Push('传送：'..self.world.layout.teleports[self.teleport].name)
end
local digitKeys={KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}
local actionKeys={KEY_ESCAPE,KEY_T,KEY_R,KEY_BACKSPACE,KEY_I,KEY_C,KEY_N,KEY_E,KEY_F,KEY_RETURN,KEY_SPACE}
local resultKeys={KEY_RETURN,KEY_ESCAPE,KEY_T}
function M:KeyPressed(key) return input:GetKeyPress(key) end
function M:HandleKey(key)
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then
        if key==KEY_ESCAPE or key==KEY_RETURN or key==KEY_SPACE then self.battle.mvpShow:Skip() end
        return
    end
    if self.salvage and self.salvage:Key(key) then return end
    if self.story and self.story.rules.finished then
        if key==KEY_R then self.app.restartStory=self.map.id;self.wantsReturn=true
        elseif key==KEY_ESCAPE or key==KEY_RETURN or key==KEY_T then self.wantsReturn=true end
        return
    end
    if self.combat and (key==KEY_N or key==KEY_BACKSPACE) then return end
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
    if self.dialog then return end
    for _,key in ipairs(actionKeys) do if self:KeyPressed(key) then self:HandleKey(key) end end
    for _,key in ipairs(digitKeys) do if self:KeyPressed(key) then self:HandleKey(key) end end
end
function M:Aim()
    if self.combat and not self.combat.player.alive then return self.aimPoint or self.combat.player:Position() end
    local ray=self.camera:GetCamera():GetScreenRay(.5,.5)
    local p,d=ray.origin,ray.direction
    local origin,direction={-p.x,p.y,p.z},{-d.x,d.y,d.z}
    local hit=self.world:CastRay(origin,direction,500,self.vehicle.body)
    self.aimHit=hit
    return hit and hit.point or {origin[1]+direction[1]*500,origin[2]+direction[2]*500,origin[3]+direction[3]*500}
end
function M:Tick(dt,command)
    if self.battle and self.battle.rules.state=='over' then if self.hud then self.hud.Update(self,dt) end;return end
    self.weaponAudio:SetActive(self.pointer.captured and (not self.battle or self.battle.rules.state=='live') and (not self.story or not self.story.rules.finished) and (not self.salvage or self.salvage.begun and not self.salvage.rules.finished))
    self.weaponAudio:Update(dt,self.weapons,self.camera:GetNode(),self.combat and self.combat.entries,self.combat and self.combat.voice.card~=nil)
    self.drivingAudio:SetActive(self.weaponAudio.active)
    self.feedbackAudio:SetActive(self.weaponAudio.active)
    if self.salvage then self.salvage.audio:SetActive(self.weaponAudio.active) end
    self.feedbackAudio:Update(dt,self.camera:GetNode(),self.combat and self.combat.voice.card~=nil)
    local alive=not self.combat or self.combat.player.alive
    self.drivingAudio:Update(dt,alive and self.vehicle or nil,command,self.camera:GetNode(),self.combat and self.combat.entries,self.combat and self.combat.voice.card~=nil)
    if (self.story or self.salvage) and self.combat.rules.finished then if self.hud then self.hud.Update(self,dt) end;return end
    -- Fixed 60 Hz on both desktop and 30 Hz mobile. Bound catch-up after pauses.
    local elapsed=math.min(math.max(dt,0),.1);self.droppedTime=self.droppedTime+math.max(0,dt-elapsed)
    self.accumulator=self.accumulator+elapsed
    self.pendingRotorStep=self.pendingRotorStep or command.rotorStep==true
    command.rotorStep=self.pendingRotorStep
    local aim=command.aim or self:Aim()
    self.aimPoint=aim;self.firing=command.firing==true
    local rotorStepped=false
    while self.accumulator>=1/60 do
        if self.combat then self.combat:BeforeStep(1/60,command,aim)
        else
            self.vehicle:StepRotors(aim,command.rotorStep and not rotorStepped,1/60)
            rotorStepped=true
            require('drive.RotorMotion').Weapons(self.vehicle.rotors,self.weapons)
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
        self.world:Step(1/60)
        if self.combat then self.combat:AfterStep(1/60);self.combat:SyncPlayer() end
        if self.combat then
            for _,entry in ipairs(self.combat.entries) do if entry.unit.alive then self.drivingAudio:Observe(entry.unit.vehicle,1/60,entry.unit~=self.combat.player) end end
        else self.drivingAudio:Observe(self.vehicle,1/60,false) end
        if not self.combat or self.combat.player.alive then
            if self.weapons.drill:ControlsBody() then self.vehicle:SyncDrillPose() end
            self.view:SavePose();local center=self.vehicle.body.center()
            self.world.metrics:Timing(self.world.time,{center.x,center.y,center.z},self.vehicle.speed,self.prevZ);self.prevZ=center.z
        end
        self.feedbackAudio:Consume(self.world.viewEvents,self.combat and self.combat.player)
        if self.hud then self.hud.overlay:Consume(self.world.viewEvents) end
        self.combatView:Consume(self.world);self.combatView:SavePose()
        self.effects:Consume(self.world.fx);self.world.fx={}
        self.accumulator=self.accumulator-1/60;self.fixedSteps=self.fixedSteps+1
        if self.battle and self.battle.rules.state=='over' or (self.story or self.salvage) and self.combat.rules.finished then self.accumulator=0;break end
    end
    self.fxContext.time=self.world.time
    local alive=not self.combat or self.combat.player.alive
    if alive then self.view:Update(self.weapons.drill:Latched() and 1 or self.accumulator*60,elapsed,self.fxContext) end
    if self.targetFeedback then self.targetFeedback:Update(self.world.targets,self.world.time,self.camera:GetNode(),elapsed) end
    if alive then
        WeaponView.Update(self.view.view,self.weapons,self.accumulator*60,elapsed,self.world.time,self.effects)
        self.view.view:UpdateWeaponEffects(elapsed,self.fxContext,self.effects)
    end
    self.combatView:Update(self.accumulator*60,elapsed,self.fxContext)
    if self.combat then
        local shots={};for _,entry in ipairs(self.combat.entries) do if entry.unit.alive then for _,shot in ipairs(entry.unit.weapons.projectiles) do shots[#shots+1]=shot end end end
        self.effects:Update(elapsed,shots,self.camera:GetNode())
    else self.effects:Update(elapsed,self.weapons.projectiles,self.camera:GetNode()) end
    if self.hud then self.hud.Update(self,elapsed) end
end
function M:Update(dt)
    if self.disposed then return end
    if self.app.loadingFlow and self.app.loadingFlow.active then return end
    if self.battle then self.battle.sounds:Update(dt);self.battle.voice:Update(dt) end
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then
        self:Pause()
        for _,key in ipairs({KEY_SPACE,KEY_RETURN,KEY_ESCAPE}) do if input:GetKeyPress(key) then self.battle.mvpShow:Skip();break end end
        self.battle.mvpShow:Update(dt)
        if self.hud then self.hud.Update(self,dt) end
        return
    end
    if self.story then self.story:Update(dt) end
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
        if not self.salvage or self.salvage:Return() then self:Pause();self.onReturn();return end
    end
    if self.dialog or typing or not self:HasFocus() then self:Pause() end
    self.pointer:Poll(dt)
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
            self.yaw=self.yaw+input.mouseMoveX*.2;self.pitch=math.max(-10,math.min(65,self.pitch+input.mouseMoveY*.2));self.lookIdle=0
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
    local sensitivity=self.camera:GetCamera().fov/48
    self.yaw=self.yaw+dx*.2*sensitivity;self.pitch=math.max(-10,math.min(65,self.pitch+dy*.2*sensitivity))
    self.lookIdle=(dx~=0 or dy~=0) and 0 or self.lookIdle+dt
    local alive=not self.combat or self.combat.player.alive
    if alive and self.follow and self.lookIdle>1.2 and not command.firing and self.vehicle.speed>3 then
        local difference=(-self.vehicle:Yaw()*180/math.pi-self.yaw+180)%360-180
        self.yaw=self.yaw+difference*math.min(1,dt*1.5)
    end
    if alive and not self.combat and self.vehicle.body.translation().y < -30 then self:Reset() end
    self:Tick(dt,command)
end
function M:PostUpdate(dt)
    if self.disposed then return end
    if self.battle and self.battle.mvpShow and not self.battle.mvpShow.done then self.battle.mvpShow:Camera();return end
    if self.intro and not self.intro.done then
        self.intro:Camera();if self.environment then self.environment:Update(dt,self.camera:GetNode()) end;return
    end
    local root=self.view.view.root;local p=root.position
    if self.combat and not self.combat.player.alive then
        self.drillSpeed:Clear()
        local watched=false
        for _,entry in ipairs(self.combat.entries) do if entry.unit.team=='blue' and entry.unit.alive then watched=entry.unit;break end end
        if watched then p=Coord.Vec(table.unpack(watched:Position())) end
        self.target.position=p;self.camera:Update(dt,self.target,self.yaw,self.pitch)
        if self.salvage then self.salvage.cine:Camera() end
        if self.environment then self.environment:Update(dt,self.camera:GetNode()) end;return
    end
    -- A wall-walking chassis rotates its entire local height axis. Ground-only
    -- bounds offsets aim above it and crop the feet; follow its displayed COM.
    if self.vehicle.legMode then self.target.position=p+root.rotation*Coord.Vec(table.unpack(self.vehicle.com))
    else self.target.position=Vector3(p.x,p.y+self.vehicle.spec.bounds.min[2],p.z) end
    self.camera:Update(dt,self.target,self.yaw,self.pitch)
    local group=self.weapons:Group()
    self.drillSpeed:Update(dt,self.camera:GetCamera(),self.weapons,self.pointer.captured and (not self.combat or self.combat.player.alive))
    local c=self.camera:GetCamera();local targetFov=self.scope and require('ui.ReticleState').ScopeFov(48,group and group.kind) or 48+math.min(1,math.abs(self.vehicle.speed)/28)*6
    if not self.scope then targetFov=targetFov+self.drillSpeed.rush*28-(self.weapons.drill.held and self.weapons.drill.held.windup or 0)*3 end
    if not self.scope then
        -- Ceilings shorten the camera boom. Widen the lens only while blocked
        -- so the car remains framed instead of filling/cropping the screen.
        local aim=self.target.position+Quaternion(self.yaw,Vector3.UP)*self.cameraOffset
        local actualDistance=(self.camera:GetNode().position-aim):Length()
        local ratio=math.max(1,self.cameraDistance/math.max(1,actualDistance))
        targetFov=math.min(76,2*math.atan(math.tan(targetFov*math.pi/360)*ratio)*180/math.pi)
    end
    self.currentFov=(self.currentFov or 48)+(targetFov-(self.currentFov or 48))*math.min(1,dt*8)
    c.fov=self.currentFov;self.fxContext.fov=c.fov
    if self.salvage then self.salvage.cine:Camera();self.fxContext.fov=c.fov end
    if self.environment then self.environment:Update(dt,self.camera:GetNode()) end
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;Host.Dispose(self)
    if self.intro then self.intro:Dispose();self.intro=nil end
    if self.pointer then self.pointer:Release() end
    if self.hud then self.hud.Dispose();self.hud=nil end
    if self.controls then self.controls:Clear() end
    if self.drillSpeed then self.drillSpeed:Dispose() end
    if self.effects then self.effects:Dispose() end
    if self.weaponAudio then self.weaponAudio:Dispose() end
    if self.drivingAudio then self.drivingAudio:Dispose() end
    if self.feedbackAudio then self.feedbackAudio:Dispose() end
    if self.combatView then self.combatView:Dispose() end
    self.weapons=nil;self.aimHit=nil
    if self.view then self.view:Dispose() end
    if self.combat then self.combat:Dispose() elseif self.vehicle then self.vehicle:Dispose() end
    if self.targetFeedback then self.targetFeedback:Dispose() end
    if self.environment then self.environment:Dispose();self.environment=nil end
    if self.world then self.world:Dispose() end
    if self.camera then self.camera:GetNode():Dispose() end
    if self.target then self.target:Remove() end
end
return M
