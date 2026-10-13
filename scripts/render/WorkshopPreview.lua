-- Reuse the active hall and camera. Only one optional vehicle exists, and its
-- model creation is spread across frames rather than opening another renderer.
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local View=require 'render.VehicleView'
local M={};M.__index=M
function M.New(app) return setmetatable({app=app,auto=true,gate=require('app.ResourceGate').New()},M) end
function M:Show(id)
    self:Clear()
    self.bp=Prefab.Create(BP.New(),id);self.parts=self.bp:List();self.cursor=1
    local host=self.app.car.root
    self.hostVisible=host.enabled
    self.view=View.New(self.app.scene,'WorkshopVehicle');self.app.car:SetVisible(false)
    self.view.root.worldPosition=host.worldPosition
    self.view.root.worldRotation=host.worldRotation
    self.framing=nil;self.rise=nil;self.complete=false
    self.ready=false
    self.gate:Start(require('parts.Dependencies').For(self.parts),function(ok,message)
        self.ready=ok
        if not ok then self:Clear();self.app.toasts:Push(message,'bad') end
    end)
end
function M:Reset(duration)
    if not self.framing then return end
    self.framing.spin=self.auto
    self.app.camera:FlyTo(self.framing,duration or .5)
end
function M:Frame()
    local box=self.view:GetWorldBounds()
    if not box:Defined() then return end
    local center,size=box.center,box.size
    local radius=math.sqrt(size.x^2+size.y^2+size.z^2)*.5
    local theta=.75
    local dist=math.min(math.max(radius*2.3+3,5),self.app.camera.maxDist*.85)
    local side=dist*.2
    -- Source target shifts left in Three.js; mirror that X shift at this boundary.
    self.framing={target={center.x+math.cos(theta)*side,center.y,center.z+math.sin(theta)*side},
        dist=dist,yaw=180-math.deg(theta),pitch=90-math.deg(1.24),fov=48,spin=self.auto}
    self:Reset(.75)
    self.rise={elapsed=0,position=self.view.root.worldPosition,drop=math.max(2,size.y*.6)}
end
function M:SetAuto(value)
    self.auto=value
    if self.app.camera.flight then self.app.camera.flight.spin=value else self.app.camera.autoSpin=value end
end
function M:Update(dt)
    if not self.view or not self.ready then return end
    if not self.complete then
        local limit=require('render.Quality').current.name=='mobile' and 12 or 24
        for _=1,limit do
            local part=self.parts[self.cursor];if not part then break end
            local ok,err=pcall(self.view.AddPart,self.view,part)
            if not ok then self:Clear();self.app.toasts:Push('预制车加载失败：'..tostring(err),'bad');return end
            self.cursor=self.cursor+1
        end
        if self.cursor>#self.parts then self.view.joined:Update();self.view.livery:Set(self.bp.livery);self.view.livery:Update();self.complete=true;self:Frame() end
    end
    local rise=self.rise
    if rise then
        rise.elapsed=math.min(.65,rise.elapsed+dt)
        self.view.root.worldPosition=rise.position-Vector3(0,rise.drop*(1-rise.elapsed/.65)^3,0)
        if rise.elapsed>=.65 then self.rise=nil end
    end
end
function M:Clear()
    self.gate:Cancel();self.ready=false
    if self.view then self.view:Dispose();self.view=nil end
    self.parts={};self.framing=nil;self.rise=nil;self.complete=false
    if self.hostVisible~=nil then self.app.car:SetVisible(self.hostVisible);self.hostVisible=nil end
end
function M:Dispose() self:Clear() end
return M
