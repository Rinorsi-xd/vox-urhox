-- Frozen warehouse geometry and lighting; owns only its optional scene group.
local Data=require('core.ResourceData').Read('Warehouse/Manifest.json')
local M={};M.__index=M
local function V(p) return Vector3(-p[1],p[2],p[3]) end
function M.New(app) local self=setmetatable({},M);self:init(app);return self end
function M:init(app)
    self.app=app;self.root=app.scene:CreateChild('SalvageWarehouse');self.root.enabled=false
    self.cursor=1;self.ready=false;self.materials={};self.disposed=false
    self.gate=require('app.ResourceGate').New()
    local paths={'Shaders/BLGL/Warehouse/Surface.shader','Shaders/BLGL/Warehouse/Decal.shader','Shaders/BLGL/Hangar/Deck.shader','Shaders/BLGL/Hangar/Beam.shader'}
    for _,m in ipairs(Data.models) do paths[#paths+1]=m.model end
    for _,m in ipairs(Data.materials) do if m.map then paths[#paths+1]='Warehouse/texture-'..m.map..'.png' end end
    self.gate:Start(paths,function(ok,message) if not self.disposed then self.downloaded=ok;if not ok then app.toasts:Push(message,'bad') end end end)
end
function M:Material(index)
    if self.materials[index] then return self.materials[index] end
    local d=Data.materials[index];local m=Material:new()
    if d.name=='WarehouseDeck' then
        assert(m:SetSurfaceShader('Shaders/BLGL/Hangar/Deck.shader'))
        m:SetShaderParameter('uRingR',Variant(6.4));m:SetShaderParameter('uGrid',Variant(0.0));m:SetShaderParameter('uFrame',Variant(0.0));m:SetShaderParameter('refl_strength',Variant(.32))
        self.deck=m;self.materials[index]=m;return m
    elseif d.name=='ShaderMaterial' then
        assert(m:SetSurfaceShader('Shaders/BLGL/Hangar/Beam.shader'))
        m:SetShaderParameter('uColor',Variant(Vector3(table.unpack(d.color))));m:SetShaderParameter('uStrength',Variant(.016));m:SetShaderParameter('uPow',Variant(2.0))
        self.materials[index]=m;return m
    end
    assert(m:SetSurfaceShader('Shaders/BLGL/Warehouse/'..(d.unlit and 'Decal' or 'Surface')..'.shader'))
    m:SetShaderParameter('tint',Variant(Vector4(d.color[1],d.color[2],d.color[3],d.opacity)))
    m:SetShaderParameter('emission_color',Variant(Vector3(table.unpack(d.emission))))
    m:SetShaderParameter('roughness_value',Variant(d.roughness));m:SetShaderParameter('metallic_value',Variant(d.metallic))
    if d.map then m:SetSurfaceTexture('albedo_map',assert(cache:GetResource('Texture2D','Warehouse/texture-'..d.map..'.png')));m:SetShaderParameter('has_map',Variant(1.0)) end
    if d.unlit then m.renderOrder=130 end
    self.materials[index]=m;return m
end
function M:Activate()
    for _,d in ipairs(Data.lights) do if d.type~='HemisphereLight' then
        local node=self.root:CreateChild(d.type);node.position=V(d.position)
        local light=node:CreateComponent('Light');light.color=Color(table.unpack(d.color));light.range=d.range;light.castShadows=d.shadow
        if d.type=='RectAreaLight' then
            -- Cross-platform fill: rectangular lights are dropped on mobile.
            light.lightType=LIGHT_POINT;light.brightness=d.intensity*d.width*d.height
        else
            light.lightType=LIGHT_SPOT;light.brightness=d.intensity;light.fov=math.deg(d.angle*2)
            light.innerConeAngle=math.deg(d.angle*(1-d.penumbra));light.outerConeAngle=math.deg(d.angle)
            node:LookAt(V(d.target));light.shadowBias=BiasParameters(.0004,1)
        end
    end end
    self.app.hangar.root:SetDeepEnabled(false);self.root:SetEnabledRecursive(true)
    self.oldLights={}
    for _,light in ipairs(self.app.scene:GetComponents('Light',true)) do if light.node.parent~=self.root then self.oldLights[#self.oldLights+1]={light=light,enabled=light.enabled};light.enabled=false end end
    self.previousLimit=self.app.camera.roomLimit;self.app.camera.roomLimit=Data.limit
    local hall=self.app.hangar;self.previousPad=hall.padMat;hall.padMat=self.deck
    hall.reflMats[#hall.reflMats+1]=self.deck;hall.reflFilter:Bind(self.deck)
    for index,d in ipairs(Data.models) do if Data.materials[d.material+1].name=='WarehouseDeck' then self.root:GetChild('Batch'..index):GetComponent('StaticModel').viewMask=2 end end
    self.ready=true;self.app:HomeView('salvage')
    print('[Warehouse] Frozen scene ready batches='..#Data.models)
end
function M:Update()
    if self.disposed or not self.downloaded then return end
    if self.ready then
        for _,m in pairs(self.materials) do m:SetShaderParameter('hangar_time',Variant(self.app.hangar.time)) end
        require('scene.HangarAtmosphere').Update(self.app.hangar,self.app.camera.node,self.app.camera.camera,self.app.hangar.time)
        return
    end
    for _=1,4 do
        local index=self.cursor;local d=Data.models[index];if not d then self:Activate();break end
        local node=self.root:CreateChild('Batch'..index);local mesh=node:CreateComponent('StaticModel')
        mesh.model=assert(cache:GetResource('Model',d.model));mesh.material=self:Material(d.material+1);mesh.castShadows=d.shadow
        self.cursor=index+1
    end
    if not self.ready then self.root:SetDeepEnabled(false) end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true;self.gate:Cancel()
    if self.ready then
        local hall=self.app.hangar;hall.padMat=self.previousPad;table.remove(hall.reflMats)
        hall.root:ResetDeepEnabled();for _,entry in ipairs(self.oldLights) do entry.light.enabled=entry.enabled end;self.app.camera.roomLimit=self.previousLimit
    end
    self.root:Dispose();for _,m in pairs(self.materials) do m:Dispose() end;self.materials={}
end
return M
