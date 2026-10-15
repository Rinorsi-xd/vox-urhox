-- 车库环绕相机（对应 H5 shared/controls/cameraRig.js 的 orbit 模式）
-- 原网页首页左/右键旋转、中键/Shift+拖动平移；建造输入由 BuildControls 管理。

---@class OrbitCamera
---@field node Node
---@field camera Camera
---@field target Vector3
---@field dist number
---@field yaw number
---@field pitch number
---@field cur { target: Vector3, dist: number, yaw: number, pitch: number }
---@field autoSpin boolean
---@field minDist number
---@field maxDist number
local OrbitCamera = {}
OrbitCamera.__index = OrbitCamera

---@param scene Scene
---@return OrbitCamera
function OrbitCamera.New(scene, existingNode)
    local c = setmetatable({}, OrbitCamera)
    c:init(scene, existingNode)
    return c --[[@as OrbitCamera]]
end

---@param scene Scene
function OrbitCamera:init(scene, existingNode)
    -- PIE may already hold this camera. Preserve the authored node and component.
    self.node = existingNode or scene:CreateChild("Camera")
    local cam = self.node:GetComponent("Camera") or self.node:CreateComponent("Camera") --[[@as Camera]]
    cam.fov = 48.0
    cam.nearClip = 0.05
    cam.farClip = 320.0
    self.camera = cam
    self.target = Vector3(0, 1.1, 0)
    self.dist = 11.0
    self.yaw = 180-math.deg(.7)
    self.pitch = 90-math.deg(1.24)
    self.cur = { target = self.target, dist = self.dist, yaw = self.yaw, pitch = self.pitch }
    self.dragButton=false
    self.dragMode=false
    self.autoSpin = true
    self.minDist = 2.5
    self.maxDist = 60.0
    self.panMaxY=20
    self.flight=false
    self:Apply()
end

--- 平滑地把镜头移到新的观察点
---@param target Vector3
---@param dist number|nil
function OrbitCamera:Focus(target, dist)
    self.flight=false
    self.target = target
    if dist then self.dist = dist end
end

-- Use the source's cubic ease-in-out, measured in seconds and shortest yaw arc.
function OrbitCamera:FlyTo(pose,duration)
    local c=self.cur
    local delta=pose.yaw-c.yaw
    delta=delta-math.floor(delta/360+.5)*360
    self.autoSpin=false
    self.flight={elapsed=0,duration=duration or .65,spin=pose.spin,
        from={target=c.target,dist=c.dist,yaw=c.yaw,pitch=c.pitch},
        to={target=Vector3(table.unpack(pose.target)),dist=pose.dist,yaw=c.yaw+delta,pitch=pose.pitch}}
    self.camera.fov=pose.fov
end

function OrbitCamera:Step(dt)
    local c=self.cur;local f=self.flight
    if f then
        f.elapsed=math.min(f.duration,f.elapsed+dt)
        local t=f.duration>0 and f.elapsed/f.duration or 1
        local k=t<.5 and 4*t*t*t or 1-(2-2*t)^3/2
        self.target=f.from.target+(f.to.target-f.from.target)*k
        self.dist=f.from.dist+(f.to.dist-f.from.dist)*k
        self.yaw=f.from.yaw+(f.to.yaw-f.from.yaw)*k
        self.pitch=f.from.pitch+(f.to.pitch-f.from.pitch)*k
        c.target=self.target;c.dist=self.dist;c.yaw=self.yaw;c.pitch=self.pitch
        if t>=1 then self.flight=false;self.autoSpin=f.spin==true end
    else
        if self.autoSpin then self.yaw=self.yaw-math.deg(dt*.05) end
        local k=1-math.exp(-dt*9)
        c.target=c.target+(self.target-c.target)*k
        c.dist=c.dist+(self.dist-c.dist)*k
        c.yaw=c.yaw+(self.yaw-c.yaw)*k
        c.pitch=c.pitch+(self.pitch-c.pitch)*k
    end
    self:Apply()
end

function OrbitCamera:Apply()
    local c = self.cur
    -- Match the H5 CameraRig spherical-coordinate position exactly.
    -- H5 uses +X for the authored scene while UrhoX mirrors that axis at
    -- the presentation boundary, so the horizontal X offset is negated.
    -- Keeping this calculation explicit avoids Euler-order differences from
    -- Quaternion(pitch, yaw, 0) changing the initial framing.
    local theta=math.rad(180-c.yaw)
    local phi=math.rad(90-c.pitch)
    local sp=math.sin(phi)
    local p=c.target+Vector3(-c.dist*sp*math.sin(theta),c.dist*math.cos(phi),c.dist*sp*math.cos(theta))
    local limit=self.roomLimit
    if self.safety then p=self.safety:Resolve(c.target,p)
    elseif limit then p=Vector3(math.max(-limit.x,math.min(limit.x,p.x)),math.max(limit.y0,math.min(limit.y1,p.y)),math.max(limit.z0,math.min(limit.z1,p.z))) end
    self.node.position=p
    self.node:LookAt(c.target)
end

---@param dt number
---@param blockMouse boolean 鼠标在界面上时不响应拖动 / 滚轮
function OrbitCamera:Update(dt, blockMouse, viewOnly)
    local dragR = input:GetMouseButtonDown(MOUSEB_RIGHT)
    local dragM = input:GetMouseButtonDown(MOUSEB_MIDDLE)
    local dragL = viewOnly and input:GetMouseButtonDown(MOUSEB_LEFT)
    local button=dragM and MOUSEB_MIDDLE or dragR and MOUSEB_RIGHT or dragL and MOUSEB_LEFT or false
    if button~=self.dragButton then
        self.dragButton=button
        self.dragMode=not blockMouse and button and ((dragM or input:GetKeyDown(KEY_SHIFT)) and 'pan' or 'rotate') or false
        if self.dragMode then self.flight=false;self.autoSpin=false end
    end
    if blockMouse then self.dragMode=false end
    local mx, my = input.mouseMoveX, input.mouseMoveY
    if self.dragMode then
        if self.dragMode=='pan' then
            -- Source basis is recomputed after clamping the actual camera position.
            local rot = self.node.rotation
            local scale = self.dist * 0.0014
            local right = rot * Vector3.RIGHT
            local up = rot * Vector3.UP
            self.target = self.target - right * (mx * scale) + up * (my * scale)
            self.target=Vector3(self.target.x,math.max(0,math.min(self.panMaxY,self.target.y)),self.target.z)
        else
            self.yaw = self.yaw + math.deg(mx*.005)
            self.pitch = math.max(90-math.deg(1.62), math.min(90-math.deg(.12), self.pitch + math.deg(my*.004)))
        end
    end
    local wheel = input.mouseMoveWheel
    if not blockMouse and wheel ~= 0 then
        self.flight=false;self.autoSpin=false
        self.dist = require('controls.Wheel').Zoom(self.dist,wheel,self.minDist,self.maxDist)
    end

    self:Step(dt)
end

return OrbitCamera
