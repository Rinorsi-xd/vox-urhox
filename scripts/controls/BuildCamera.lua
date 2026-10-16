-- Free construction camera shares the existing authored viewport; no new scene.
local TouchMode=require("controls.TouchMode")
local HangarConfig=require("scene.HangarConfig")
local PlatformUtils=require("urhox-libs.Platform.PlatformUtils")

local Flight=require 'controls.FreeFlight'
local Math=require 'core.Math3'
local Coord=require 'core.Coord'
local Config=require 'Config'
local M={};M.__index=M
function M.New(session)
    local self=setmetatable({session=session,mode='fp',captured=false,touch=TouchMode.Enabled(),held={},dx=0,dy=0},M)
    local state=session.app.buildCameraState
    local p=session.camera.node.position;local f=session.camera.node.rotation*Vector3.FORWARD
    self.flight=Flight.New(state and state.pos or {-p.x,p.y,p.z},state and state.forward or {-f.x,f.y,f.z},HangarConfig.layout.cameraLimit)
    self:Apply()
    return self
end
function M:SetMouseMode(mode) input.mouseMode=mode end
function M:Capture()
    if self.mode~='fp' or self.session.dialog or self.session.inventoryPanel then return end
    if not self.touch and PlatformUtils.IsWebPlatform() and input.mouseLocked and input.mouseMode~=MM_RELATIVE then
        self:SetMouseMode(MM_ABSOLUTE);return
    end
    self.pending=not self.touch and PlatformUtils.IsWebPlatform()
    self.session.controls:Cancel();self.captured=not self.pending;self.skipInput=true;self.buttonsReady=false
    self.avgMove=0;self.lastSpike=false;self.lockWait=0
    if not self.touch then self:SetMouseMode(MM_RELATIVE) end
    if self.session.hud then self.session.hud.Refresh() end
end
function M:Release()
    local changed=self.captured or self.pending
    if changed and not self.touch then self:SetMouseMode(MM_ABSOLUTE) end
    self.held={};self.dx=0;self.dy=0;self.touchRight=0;self.touchForward=0
    self.captured=false;self.pending=false;if self.flight then self.flight:Stop() end
    self.session.controls:Cancel()
    if changed and self.session.hud and not self.session.disposed then self.session.hud.Refresh() end
end
function M:Center()
    local st=self.session.inspection:Get().stats
    if st.count==0 then return {0,1,0},2 end
    local b=st.bb
    return {(b.minX+b.maxX)*.5*Config.CELL,((b.minY+b.maxY)*.5+.5)*Config.CELL,(b.minZ+b.maxZ)*.5*Config.CELL},
        math.sqrt(st.dims.L^2+st.dims.W^2+st.dims.H^2)*Config.CELL*.5
end
function M:Focus()
    local center,radius=self:Center();local c=self.session.camera
    local dist=Math.Clamp(radius*2.5+3.2,5,c.maxDist*.85)
    self:FocusAt(Coord.Vec(table.unpack(center)),dist)
end
function M:FocusAt(target,dist)
    self.session.camera:Focus(target,dist)
    if self.mode=='fp' then
        local center={-target.x,target.y,target.z}
        local dir=Math.Normalize({math.sin(.7),.45,math.cos(.7)})
        local pos=Math.Add(center,Math.Scale(dir,dist*.8));local forward=Math.Normalize(Math.Sub(center,pos))
        self.flight=Flight.New(pos,forward,self.flight.limit);self:Apply()
    end
end
function M:Apply()
    local f=self.flight;local node=self.session.camera.node
    node.position=Coord.Vec(table.unpack(f.pos));node:LookAt(Coord.Vec(table.unpack(Math.Add(f.pos,f:Forward()))))
end
function M:Read()
    if self.touch then
        local h=self.held;local c={dx=self.dx,dy=self.dy,forward=self.touchForward or 0,right=self.touchRight or 0,up=(h.up and 1 or 0)-(h.down and 1 or 0),speed=self.session.flyScale or 1}
        self.dx=0;self.dy=0;return c
    end
    local function Down(k) return input:GetKeyDown(k) end
    local function Axis(a,b) return (a and 1 or 0)-(b and 1 or 0) end
    local ctrl=Down(KEY_CTRL);local shift=Down(KEY_SHIFT)
    local edit=input:GetMouseButtonDown(MOUSEB_LEFT) or Down(KEY_R) or ctrl
    local dx,dy=input.mouseMoveX,input.mouseMoveY
    local magnitude=math.sqrt(dx*dx+dy*dy);local avg=self.avgMove or 0
    local spike=magnitude>120 and magnitude>avg*8+80 and not self.lastSpike
    self.lastSpike=spike
    if spike then dx,dy=0,0 else self.avgMove=avg+(magnitude-avg)*.3 end
    return {dx=dx,dy=dy,forward=Axis(Down(KEY_W),Down(KEY_S)),right=Axis(Down(KEY_D),Down(KEY_A)),
        up=Axis(Down(KEY_SPACE) or Down(KEY_E),shift and not edit),fast=Down(KEY_Z) and not ctrl,speed=self.session.flyScale or 1}
end
function M:Update(dt,blocked)
    if self.mode=='orbit' then self.session.camera:Update(dt,true);return end
    if blocked or not input.focus or input.minimized then self:Release() end
    if self.pending then
        if input.mouseMode==MM_RELATIVE and input.mouseLocked then
            self.pending=false;self.captured=true
            if self.session.hud then self.session.hud.Refresh() end
        else
            self.lockWait=self.lockWait+math.min(.1,math.max(0,dt))
            if self.lockWait>=2 then self:Release() end
            return
        end
    end
    if self.captured then
        if not self.touch and PlatformUtils.IsWebPlatform() and not input.mouseLocked then self:Release();return end
        if self.skipInput then self.skipInput=false else self.flight:Step(math.min(dt,.1),self:Read()) end
    elseif not self.touch and PlatformUtils.IsWebPlatform() and input.mouseMode==MM_RELATIVE and input.mouseLocked then
        self:SetMouseMode(MM_ABSOLUTE)
    end
    self:Apply()
end
function M:Dispose()
    self.session.app.buildCameraState=self.mode=='fp' and {pos=self.flight.pos,forward=self.flight:Forward()} or nil
    self:Release()
end
return M
