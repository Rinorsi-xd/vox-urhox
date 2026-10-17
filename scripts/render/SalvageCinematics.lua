-- Original ship/frame meshes, merged per material and nearest moving joint.
local Data=require('core.ResourceData').Read('SalvageCine/Manifest.json')
local M={};M.__index=M
local function V(p) return Vector3(-p.x,p.y,p.z) end
local function Enable(node,value) if node.enabled~=value then node:SetEnabledRecursive(value) end end
function M.Rotation(x,y,z)
    return Quaternion(math.deg(x),Vector3.RIGHT)*Quaternion(-math.deg(y),Vector3.UP)*Quaternion(-math.deg(z),Vector3.FORWARD)
end
function M.Dependencies()
    local paths={'SalvageCine/Manifest.json','SalvageCine/smoke-0.png','SalvageCine/smoke-1.png','Shaders/BLGL/Salvage/CineFlame.shader','Shaders/BLGL/Salvage/CineGlass.shader','Shaders/BLGL/Salvage/CineUnlit.shader','Shaders/BLGL/Salvage/CineDeath.shader','Shaders/BLGL/Salvage/CineDust.shader','Shaders/BLGL/Warehouse/Surface.shader'}
    for _,d in ipairs(Data.models) do paths[#paths+1]=d.model end
    for _,d in ipairs(Data.materials) do if d.map then paths[#paths+1]='SalvageCine/texture-'..d.map..'.png' end end
    return paths
end
function M.Release()
    for _,d in ipairs(Data.models) do cache:ReleaseResource('Model',d.model) end
    for _,path in ipairs(M.Dependencies()) do if path:match('%.png$') then cache:ReleaseResource('Texture2D',path) end end
end
function M.New(scene)
    local self=setmetatable({},M);self.root=scene:CreateChild('SalvageCinematics');self.nodes={};self.materials={}
    for _,d in ipairs(Data.motion) do
        local n=(d.parent and assert(self.nodes[d.parent]) or self.root):CreateChild(d.id);local p,q,s=d.position,d.quaternion,d.scale
        n.position=Vector3(-p[1],p[2],p[3]);n.rotation=Quaternion(q[4],q[1],-q[2],-q[3]);n.scale=Vector3(table.unpack(s));self.nodes[d.id]=n
    end
    for i,d in ipairs(Data.materials) do
        local m=Material:new();self.materials[i]=m
        local shader=d.additive and 'Salvage/CineFlame' or d.opacity<1 and 'Salvage/CineGlass' or d.unlit and 'Salvage/CineUnlit' or 'Warehouse/Surface'
        assert(m:SetSurfaceShader('Shaders/BLGL/'..shader..'.shader'))
        m:SetShaderParameter('tint',Variant(Vector4(d.color[1],d.color[2],d.color[3],d.opacity)))
        if not d.unlit then
            m:SetShaderParameter('emission_color',Variant(Vector3(table.unpack(d.emission))))
            m:SetShaderParameter('roughness_value',Variant(d.roughness));m:SetShaderParameter('metallic_value',Variant(d.metallic))
        end
        if d.map then m:SetSurfaceTexture('albedo_map',assert(cache:GetResource('Texture2D','SalvageCine/texture-'..d.map..'.png')));m:SetShaderParameter('has_map',Variant(1.0)) end
    end
    for _,d in ipairs(Data.models) do
        local mesh=assert(self.nodes[d.motion]):CreateChild('Batch'):CreateComponent('StaticModel')
        mesh.model=assert(cache:GetResource('Model',d.model));mesh.material=self.materials[d.material+1];mesh.castShadows=d.shadow
        if d.motion=='frame' and d.model=='SalvageCine/model-15.bin' then self:InitHookGuard(mesh) end
    end
    self:Hide();return self
end
---@param mesh StaticModel
function M:InitHookGuard(mesh)
    self.hookMesh=mesh;self.hookMin=mesh.model.boundingBox.min;self.hookMax=mesh.model.boundingBox.max;self.hookHidden=false
end
---@param cameraNode Node
---@param active boolean
function M:GuardCamera(cameraNode,active)
    local mesh=self.hookMesh;if not mesh then return false end
    local hidden=false
    if active and self.nodes.holder.enabled then
        -- This batch has an identity transform under the axis-scaled frame.
        -- World distance to its box bounds the mask at corners as well as faces.
        local p=mesh.node:WorldToLocal(cameraNode.worldPosition);local s=mesh.node.worldScale
        local a,b=self.hookMin,self.hookMax
        local dx=math.max(a.x-p.x,0,p.x-b.x)*math.abs(s.x)
        local dy=math.max(a.y-p.y,0,p.y-b.y)*math.abs(s.y)
        local dz=math.max(a.z-p.z,0,p.z-b.z)*math.abs(s.z)
        local clearance=self.hookHidden and .6 or .4
        hidden=dx*dx+dy*dy+dz*dz<=clearance*clearance
    end
    if hidden~=self.hookHidden then mesh:SetEnabled(not hidden);self.hookHidden=hidden end
    return hidden
end
function M:HideShip() Enable(self.nodes.ship,false) end
function M:Hide() self:HideShip();Enable(self.nodes.holder,false) end
function M:Ship(r,fire)
    local n=self.nodes;Enable(n.ship,true);n.ship.position=V(r.ship);n.ship.rotation=M.Rotation(r.rx,r.ry,r.rz)
    for i=1,4 do Enable(n['shipFlame'..i],true);n['shipFlame'..i].scale=Vector3(1,fire or .75,1) end
end
function M:Drop(r,yaw,bounds)
    self:Ship(r,.6+math.random()*.3);local n=self.nodes
    Enable(n.holder,true);n.holder.position=V(r.holder);n.holder.rotation=M.Rotation(0,yaw-math.pi/2,0)
    local a,b=bounds.min,bounds.max
    n.frame.scale=Vector3(math.max(1,(b[3]-a[3]+1.6)/7),math.max(1,(b[2]-a[2]+1.2)/5),math.max(1,(b[1]-a[1]+1.4)/5.2))
    for i=1,4 do
        n['door'..i].rotation=M.Rotation(r.door,0,0)
        Enable(n['frameFlame'..i],r.frameFire);n['frameFlame'..i].scale=Vector3(1,.7+math.random()*.6,1)
    end
end
function M:Snapshot()
    local p=self.nodes.ship.position;local h=self.nodes.holder.position
    return {ship={-p.x,p.y,p.z},holder={-h.x,h.y,h.z},shipVisible=self.nodes.ship.enabled,frameVisible=self.nodes.holder.enabled,hookVisible=self.hookMesh and self.hookMesh.enabled,hookGuarded=self.hookHidden==true,batches=#Data.models,triangles=5720}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.root:Dispose()
    for _,m in ipairs(self.materials) do m:Dispose() end;self.materials={};self.nodes={};self.root=nil;self.hookMesh=nil;self.hookMin=nil;self.hookMax=nil
end
return M
