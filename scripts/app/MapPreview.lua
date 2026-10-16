-- Owns presentation only. No vehicle, physics world, combat or pointer lock.
local OrbitCamera=require("controls.OrbitCamera")
local SourceButton=require("ui.SourceButton")
local GarageHud=require("ui.GarageHud")
-- Load optional/cyclic dependencies once, without changing first-use order.
local DeferredModules=setmetatable({},{__index=function(modules,name)
    local module=require(name)
    rawset(modules,name,module)
    return module
end})

local UI=require 'urhox-libs/UI'
local M={};M.__index=M
function M.New(app,scene,map)
    local self=setmetatable({app=app,scene=scene,map=map,disposed=false},M)
    self.camera=OrbitCamera.New(scene)
    local c=self.camera;c.minDist=10;c.maxDist=1400;c.camera.farClip=4000;c.autoSpin=false
    c.target=map.id=='crater' and Vector3(0,24,0) or Vector3(0,0,35)
    c.dist=map.id=='crater' and 460 or 120;c.yaw=145;c.pitch=48;c.cur={target=c.target,dist=c.dist,yaw=c.yaw,pitch=c.pitch};c:Apply()
    if map.environment then self.environment=DeferredModules[map.environment].New(scene) end
    self.root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    local Button=SourceButton
    self.root:AddChild(Button{text='返回',icon='back',sourceKind='flat',position='absolute',left=24,top=24,width=120,height=52,onClick=function() self:Return() end})
    self.root:AddChild(UI.Label{text=map.name,fontFamily='vox-title',fontSize=26,fontColor='#edf6ff',position='absolute',left=160,top=34,width=360,height=48})
    for i,p in ipairs({{'拉近',.8},{'拉远',1.25}}) do self.root:AddChild(Button{text=p[1],icon=i==1 and 'plus' or 'minus',sourceKind='flat',position='absolute',right=24+(i-1)*108,bottom=24,width=96,height=52,onClick=function() c.dist=math.max(c.minDist,math.min(c.maxDist,c.dist*p[2])) end}) end
    -- The hangar tree is reused on return; replacing it must not destroy it.
    UI.SetRoot(self.root);app.graphicsSettings:Apply(scene);app.graphicsSettings:Show(scene,c.camera)
    return self
end
function M:Return()
    if self.disposed then return end
    self:Dispose();self.app.mapPreview=nil
    local home=GarageHud.GetState();home.root:SetVisible(true);UI.SetRoot(home.root)
    self.app.graphicsSettings:Apply(self.app.scene);self.app.graphicsSettings:Show(self.app.scene,self.app.camera.camera)
    self.app:DeferAssetRelease(function() cache:ReleaseAllResources(false) end)
end
function M:Update(dt)
    if input:GetKeyPress(KEY_ESCAPE) then self:Return();return end
    self.camera:Update(dt,UI.IsPointerOverUI(),true)
    if self.environment then self.environment:Update(dt,self.camera.node) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.environment then self.environment:Dispose() end
    if UI.GetRoot()==self.root then UI.SetRoot(nil) end
    self.root:Destroy();self.scene:Dispose()
end
return M
