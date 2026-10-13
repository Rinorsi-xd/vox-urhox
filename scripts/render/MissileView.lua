-- Frozen projectile meshes, shared materials and a scene-owned bounded pool.
local Coord=require 'core.Coord'
local V=require 'core.Math3'
local Data=require('core.ResourceData').Read('Combat/MissileView.json')
local M={};M.__index=M
function M.Dependencies()
    return {Data.resources.body.path,Data.resources.glow.path,'Shaders/BLGL/Combat/MissileBody.shader','Shaders/BLGL/Combat/MissileGlow.shader'}
end
function M.New(root,limit)
    local self=setmetatable({root=root:CreateChild('MissileBodies'),slots={},limit=limit,count=0,models={},materials={}},M)
    for _,name in ipairs({'body','glow'}) do
        self.models[name]=assert(cache:GetResource('Model',Data.resources[name].path))
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/Combat/Missile'..(name=='body' and 'Body' or 'Glow')..'.shader'))
        self.materials[name]=material
    end
    return self
end
function M:Begin() self.count=0 end
function M:Add(p)
    if self.count>=self.limit then return end
    self.count=self.count+1;local node=self.slots[self.count]
    if not node then
        node=self.root:CreateChild('Missile'..self.count)
        for _,name in ipairs({'body','glow'}) do local sm=node:CreateComponent('StaticModel');sm.model=self.models[name];sm.material=self.materials[name];sm.castShadows=false end
        self.slots[self.count]=node
    end
    local size=Data.sizes[tostring(p.s.tier)];local dir=V.Normalize(p.vel);local tail=V.Sub(p.pos,V.Scale(dir,size.l))
    node.enabled=true;node.position=Coord.Vec(table.unpack(tail));node.rotation=Quaternion(Vector3.FORWARD,Coord.Vec(table.unpack(dir)))
    node.scale=Vector3(size.r,size.r,size.l)
end
function M:Finish() for i=self.count+1,#self.slots do self.slots[i].enabled=false end end
function M:Clear() self.count=0;self:Finish() end
function M:Dispose()
    self.root:Dispose();for _,material in pairs(self.materials) do material:Dispose() end
    self.slots={};self.models={}
end
return M
