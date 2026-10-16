-- Loading-only proxies exercise the real shell shader without emitting damage.
local M={};M.__index=M
function M.New(session)
    local owner=session.restoreFlash
    if not owner or owner.disposed then return nil end
    ---@type Model?
    local source=nil
    for _,vis in pairs(session.view.view.visuals) do
        if not vis.joined and #vis.models>0 then source=vis.models[1].model;break end
    end
    local self=setmetatable({nodes={},disposed=false},M)
    local ok,err=pcall(self.init,self,session,source,owner.material)
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(session,source,material)
    self.root=session.scene:CreateChild('FlashWarmupProbes')
    local camera=session.camera:GetCamera().node
    self.root.position=camera.worldPosition+camera.worldRotation*Vector3.FORWARD*8
    self.root.rotation=camera.worldRotation
    if source then
        local bounds=source.boundingBox;local size=bounds.size
        local scale=.6/math.max(.001,size.x,size.y,size.z)
        for i=1,4 do
            local node=self.root:CreateChild('Shell'..i);self.nodes[i]=node
            node.position=Vector3((i-2.5)*.8,0,0)-bounds.center*scale;node:SetScale(scale)
            local model=node:CreateComponent('StaticModel');model.model=source;model.castShadows=false
            for index=0,source.numGeometries-1 do model:SetMaterial(index,material) end
            model.instanceColor=Color(1,1,1,1)
        end
    end
    local node=self.root:CreateChild('JoinedShell');self.joined=node
    local geometry=node:CreateComponent('CustomGeometry');geometry:BeginGeometry(0,TRIANGLE_LIST)
    for _,z in ipairs({-1,1}) do
        for _,p in ipairs({{-.4,.6,0},{.4,.6,0},{0,1.3,0}}) do
            geometry:DefineVertex(Vector3(p[1]*z,p[2],p[3]));geometry:DefineNormal(Vector3(0,0,z))
        end
    end
    self.material=material:Clone()
    self.material:SetShaderParameter('joined_alpha',Variant(1.1))
    self.material:SetShaderParameter('joined_color',Variant(Vector3(1,1,1)))
    geometry:Commit();geometry:SetMaterial(self.material);geometry.castShadows=false
    self:Show(0)
end
function M:Show(copies)
    for i,node in ipairs(self.nodes) do node.enabled=i<=copies end
    self.joined.enabled=copies>0
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.root then self.root:Dispose();self.root=nil end
    if self.material then self.material:Dispose();self.material=nil end
    self.nodes={};self.joined=nil
end
return M
