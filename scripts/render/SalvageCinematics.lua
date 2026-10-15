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
    end
    self:Hide();return self
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
    return {ship={-p.x,p.y,p.z},holder={-h.x,h.y,h.z},shipVisible=self.nodes.ship.enabled,frameVisible=self.nodes.holder.enabled,batches=#Data.models,triangles=5720}
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.root:Dispose()
    for _,m in ipairs(self.materials) do m:Dispose() end;self.materials={};self.nodes={};self.root=nil
end
return M
