-- One loading-only draw uses the live weapon Glow vertex format, without RNG.
local Batch=require 'render.EffectBatch'
local M={};M.__index=M
local shader='Shaders/BLGL/WeaponFx/Glow.shader'
local function Source(p)return {-p.x,p.y,p.z}end

function M.New(scene,camera)
    assert(scene and camera and camera.node,'HangarFxWarmup requires a live scene and camera')
    assert(camera.node:GetScene()==scene,'HangarFxWarmup camera belongs to another scene')
    assert(cache:Exists(shader),'HangarFxWarmup missing '..shader)
    local self=setmetatable({scene=scene,disposed=false,completed=false,frames=0},M)
    local ok,err=pcall(self.init,self,camera)
    if not ok then self:Dispose();error(err) end
    return self
end

function M:init(camera)
    local near=math.max(.001,camera.nearClip)
    assert(camera.farClip>near*2,'HangarFxWarmup requires a nonempty camera range')
    local distance=math.min(camera.farClip*.5,math.max(8,near*2))
    local node=camera.node;local rotation=node.worldRotation
    local point=node.worldPosition+rotation*Vector3.FORWARD*distance
    self.root=self.scene:CreateChild('HangarFxWarmupProbe')
    self.batch=Batch.New(self.root,'Glow',4,'Shaders/BLGL/WeaponFx/')
    self.batch:Begin(Source(node.worldPosition),0)
    self.batch:Disc(Source(point),.6,{.25,.5,1},1,
        Source(rotation*Vector3.RIGHT),Source(rotation*Vector3.UP))
    self.batch:Finish()
end

-- The owner calls this only after a frame containing the probe was rendered.
function M:Presented()
    if self.disposed then return self.completed end
    self.frames=self.frames+1;self.completed=true;self:Dispose();return true
end

-- Close/Fail must dispose this owner before disposing its scene.
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.batch then self.batch:Dispose();self.batch=nil end
    if self.root then self.root:Dispose();self.root=nil end
    self.scene=nil
end
return M
