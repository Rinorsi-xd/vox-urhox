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
function M.New(scene,bp,app,map,preparedWorld)
    local self=setmetatable({disposed=false,app=app,name=bp.name,follow=true,lookIdle=0,scope=false,details=false,map=map or require('app.DriveMaps').trial},M)
    local ok,err=pcall(self.init,self,scene,bp,preparedWorld)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(scene,bp,preparedWorld)
    self.touch=require('controls.TouchMode').Enabled()
    self.scene=scene;self.controls=Input.New();self.accumulator=0;self.fixedSteps=0;self.droppedTime=0
    self.pointer=require('controls.DrivePointer').New(self)
    self.world=preparedWorld or require(self.map.world).New(scene);self.vehicle=Vehicle.New(self.world.space,Spec.Build(bp))
    if self.map.environment then self.environment=require(self.map.environment).New(scene,self.world.layout) end
    self.ReleaseAssets=require(self.map.assets).Release
    if #self.world.targets>0 then self.targetFeedback=TargetFeedback.New(self.world.root,self.world.targets) end
    self.weapons=Weapons.New(self.vehicle.spec);self.effects=Effects.New(scene,function(x,z) return self.world:GroundAt(x,z) end)
    self.combatView=CombatView.New(scene);self.world:SetUnits(bp);self.combatView:Consume(self.world)
    self.view=DriveView.New(scene,bp,self.vehicle);self.target=scene:CreateChild("FollowTarget")
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
    self.yaw=0;self.pitch=30;self.teleport=1;self.wantsReturn=false;self.disposed=false;self.hud=nil
    self:Reset();self:PostUpdate(1)
end
function M:Activate(onReturn)
    self.onReturn=onReturn;self.enteredTime=0
    self.hud=Hud.Create(self)
    if self.touch then self:Resume() end
    input.mouseMode=MM_ABSOLUTE
    self.app.graphicsSettings:Show(self.scene,self.camera:GetCamera())
end
function M:Reset()
    local spawn=self.world.layout.teleports[self.teleport]
    self.vehicle:Place(spawn.pos,spawn.yaw);self.yaw=-spawn.yaw*180/math.pi
    self.controls:Clear();if self.hud then self.hud.Clear() end
    self.accumulator=0;self.prevZ=nil;self.view:ResetPose();self.view:Update(1)
    -- A teleport cancels shots in flight and transient feedback, not energy/cooldowns.
    self.weapons.projectiles={};self.weapons.wasFiring=false;self.effects:Clear()
end
function M:HasFocus() return input.focus and not input.minimized end
function M:Resume() return self.pointer:Capture() end
function M:Zoom(wheel)
    if wheel==0 then return end
    self.cameraDistance=math.max(self.minCameraDistance,math.min(self.maxCameraDistance,self.cameraDistance*math.exp(-wheel*.12)))
    -- The library interpolates only across distinct modes. Alternate two public
    -- mode configurations instead of mutating its private interpolation state.
    local mode=self.camera:GetMode()=='zoomA' and 'zoomB' or 'zoomA'
    self.camera:SetModeConfig(mode,{distance=self.cameraDistance,offset=self.cameraOffset,fov=48})
    self.camera:SetMode(mode)
end
function M:Pause() self.pointer:Release() end
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
    local p=self.vehicle.body.translation();local yaw=self.vehicle:Yaw()
    self.vehicle:Place({p.x,p.y+self.vehicle.spec.bounds.radius*.6,p.z},yaw)
    self.controls:Clear();if self.hud then self.hud.Clear() end
    self.accumulator=0;self.prevZ=nil;self.view:ResetPose();self.view:Update(1)
end
function M:ResetAll()
    self.world:Reset();self.combatView:Consume(self.world);self.teleport=1;self:Reset()
    if self.hud then self.hud.overlay:Clear() end
    self.app.toasts:Push(self.map.id=='crater' and '已返回我方要塞，复原车辆' or '已复原：车辆、靶子、靶车、锥桶')
end
function M:NextArea()
    self.teleport=self.teleport%#self.world.layout.teleports+1;self:Reset()
    self.app.toasts:Push('传送：'..self.world.layout.teleports[self.teleport].name)
end
local digitKeys={KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0}
local actionKeys={KEY_ESCAPE,KEY_T,KEY_R,KEY_BACKSPACE,KEY_I,KEY_C,KEY_N}
function M:KeyPressed(key) return input:GetKeyPress(key) end
function M:HandleKey(key)
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
    if typing or self.dialog or not self:HasFocus() then return end
    for _,key in ipairs(actionKeys) do if self:KeyPressed(key) then self:HandleKey(key) end end
    for _,key in ipairs(digitKeys) do if self:KeyPressed(key) then self:HandleKey(key) end end
end
function M:Aim()
    local ray=self.camera:GetCamera():GetScreenRay(.5,.5)
    local p,d=ray.origin,ray.direction
    local origin,direction={-p.x,p.y,p.z},{-d.x,d.y,d.z}
    local hit=self.world:CastRay(origin,direction,500,self.vehicle.body)
    self.aimHit=hit
    return hit and hit.point or {origin[1]+direction[1]*500,origin[2]+direction[2]*500,origin[3]+direction[3]*500}
end
function M:Tick(dt,command)
    -- Fixed 60 Hz on both desktop and 30 Hz mobile. Bound catch-up after pauses.
    local elapsed=math.min(math.max(dt,0),.1);self.droppedTime=self.droppedTime+math.max(0,dt-elapsed)
    self.accumulator=self.accumulator+elapsed
    local aim=command.aim or self:Aim()
    self.aimPoint=aim;self.firing=command.firing==true
    while self.accumulator>=1/60 do
        self.vehicle:Step(command,1/60)
        local body=self.vehicle.body;local p,v=body.translation(),body.linvel()
        self.weapons:Step(1/60,{firing=command.firing==true,aim=aim,pos={p.x,p.y,p.z},quat=body.rotation(),
            vel={v.x,v.y,v.z},body=body},self.world.env)
        -- WeaponSystem reuses its event array: consume every fixed step immediately.
        self.effects:Consume(self.weapons.fx)
        self.world:Step(1/60);self.view:SavePose()
        local center=self.vehicle.body.center()
        self.world.metrics:Timing(self.world.time,{center.x,center.y,center.z},self.vehicle.speed,self.prevZ);self.prevZ=center.z
        self.combatView:Consume(self.world);self.combatView:SavePose()
        self.effects:Consume(self.world.fx);self.world.fx={}
        self.accumulator=self.accumulator-1/60;self.fixedSteps=self.fixedSteps+1
    end
    self.fxContext.time=self.world.time
    self.view:Update(self.accumulator*60,elapsed,self.fxContext)
    if self.targetFeedback then self.targetFeedback:Update(self.world.targets,self.world.time,self.camera:GetNode(),elapsed) end
    WeaponView.Update(self.view.view,self.weapons,self.accumulator*60,elapsed,self.world.time,self.effects)
    self.view.view:UpdateWeaponEffects(elapsed,self.fxContext,self.effects)
    self.combatView:Update(self.accumulator*60,elapsed,self.fxContext)
    self.effects:Update(elapsed,self.weapons.projectiles,self.camera:GetNode())
    if self.hud then self.hud.Update(self,elapsed) end
end
function M:Update(dt)
    if self.disposed then return end
    Host.Update(self,dt)
    self.enteredTime=(self.enteredTime or 0)+math.max(0,dt)
    local width,height=UI.GetViewportSize()
    if self.hud and (width~=self.hud.width or height~=self.hud.height) then
        self:Pause();self.hud.Dispose();self.hud=Hud.Create(self)
    end
    if self.dialogTick then self.dialogTick(dt) end
    local focus=UI.GetFocus();local typing=focus and focus.OnTextInput~=nil
    self:PollKeys(typing)
    if self.wantsReturn then self.wantsReturn=false;self:Pause();self.onReturn();return end
    if self.dialog or typing or not self:HasFocus() then self:Pause() end
    self.pointer:Poll(dt)
    if not self.touch and not self.pointer.captured and not self.dialog and not typing and self:HasFocus() then
        self:Zoom(input:GetMouseMoveWheel())
        if input:GetMouseButtonDown(MOUSEB_RIGHT) then
            self.yaw=self.yaw+input.mouseMoveX*.2;self.pitch=math.max(-10,math.min(65,self.pitch+input.mouseMoveY*.2));self.lookIdle=0
        end
    end
    local blocked=self.dialog~=nil or typing or not self.pointer.captured
    if blocked then
        if self.hud then self.hud.Clear() else self.controls:Clear() end
        -- Source pointer-unlocked mode keeps world physics alive with neutral
        -- commands; menus never propel the vehicle or fire held weapons.
        self:Tick(dt,{throttle=0,steer=0});return
    end
    local command=self.controls:Read();local dx,dy=self.controls:TakeLook()
    local sensitivity=self.camera:GetCamera().fov/48
    self.yaw=self.yaw+dx*.2*sensitivity;self.pitch=math.max(-10,math.min(65,self.pitch+dy*.2*sensitivity))
    self.lookIdle=(dx~=0 or dy~=0) and 0 or self.lookIdle+dt
    if self.follow and self.lookIdle>1.2 and not command.firing and self.vehicle.speed>3 then
        local difference=(-self.vehicle:Yaw()*180/math.pi-self.yaw+180)%360-180
        self.yaw=self.yaw+difference*math.min(1,dt*1.5)
    end
    if self.vehicle.body.translation().y < -30 then self:Reset() end
    self:Tick(dt,command)
end
function M:PostUpdate(dt)
    if self.disposed then return end
    local root=self.view.view.root;local p=root.position
    -- A wall-walking chassis rotates its entire local height axis. Ground-only
    -- bounds offsets aim above it and crop the feet; follow its displayed COM.
    if self.vehicle.legMode then self.target.position=p+root.rotation*Coord.Vec(table.unpack(self.vehicle.com))
    else self.target.position=Vector3(p.x,p.y+self.vehicle.spec.bounds.min[2],p.z) end
    self.camera:Update(dt,self.target,self.yaw,self.pitch)
    local c=self.camera:GetCamera();local targetFov=self.scope and 24 or 48+math.min(1,math.abs(self.vehicle.speed)/28)*6
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
    if self.environment then self.environment:Update(dt,self.camera:GetNode()) end
end
function M:Dispose()
    if self.disposed then return end
    self.disposed=true;Host.Dispose(self)
    if self.pointer then self.pointer:Release() end
    if self.hud then self.hud.Dispose();self.hud=nil end
    if self.controls then self.controls:Clear() end
    if self.effects then self.effects:Dispose() end
    if self.combatView then self.combatView:Dispose() end
    self.weapons=nil;self.aimHit=nil
    if self.view then self.view:Dispose() end
    if self.vehicle then self.vehicle:Dispose() end
    if self.targetFeedback then self.targetFeedback:Dispose() end
    if self.environment then self.environment:Dispose();self.environment=nil end
    if self.world then self.world:Dispose() end
    if self.camera then self.camera:GetNode():Dispose() end
    if self.target then self.target:Remove() end
end
return M
