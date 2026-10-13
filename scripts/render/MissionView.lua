-- Original storyView meshes exported offline; animations move nodes, not vertices.
local Data=require('story.MissionData').view
local Coord=require 'core.Coord'
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
function M.Dependencies()
    local out={};for _,model in ipairs(Data.models) do out[#out+1]=model.path end
    for _,name in ipairs({'Body','Unlit','Holo','Beam','Ring','Flag','Text'}) do out[#out+1]='Shaders/BLGL/Story/Mission'..name..'.shader' end
    for _,name in ipairs({'pirate','company','graffiti'}) do out[#out+1]='Story/Mission/'..name..'.png' end
    return out
end
function M.New(scene)
    local self=setmetatable({root=scene:CreateChild('StoryMissionObjects'),objects={},intel={},collectors={},sites={},time=0},M)
    self.beacon=self:Rig(Data.beacon);self.beacon.root.enabled=false
    self.zone=self.root:CreateChild('InstallZone');local sm=self.zone:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[Data.zone].path))
    self.zoneMaterial=self:Material({shader='Ring',color={1,106/255,19/255},alpha=1});sm.material=self.zoneMaterial;sm.castShadows=false;self.zone.enabled=false
    return self
end
function M:Material(data)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Story/Mission'..data.shader..'.shader'))
    m:SetShaderParameter('uColor',Variant(Vector3(table.unpack(data.color))))
    m:SetShaderParameter('opacity',Variant(data.alpha));m:SetShaderParameter('roughness',Variant(data.roughness or .5));m:SetShaderParameter('metalness',Variant(data.metalness or 0))
    if data.shader=='Body' then m:SetShaderParameter('emission',Variant(Vector3(table.unpack(data.emission or {0,0,0})))) end
    if data.shader=='Beam' or data.shader=='Holo' or data.shader=='Ring' then m.renderOrder=144 end
    return m
end
function M:Rig(def)
    local obj={nodes={},materials={},materialByNode={},definition=def};local mats={}
    for id,d in ipairs(def.nodes) do
        local parent=d.parent==0 and self.root or obj.nodes[d.parent];local n=parent:CreateChild('StoryPart'..id);obj.nodes[id]=n
        n.position=Vec(d.position);n.scale=Vector3(table.unpack(d.scale));local q=d.quaternion;n.rotation=Quaternion(q[4],q[1],-q[2],-q[3]);n.enabled=d.visible
        if d.model then
            local sm=n:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[d.model].path))
            if not mats[d.material] then local m=self:Material(Data.materials[d.material]);mats[d.material]=m;obj.materials[#obj.materials+1]={material=m,data=Data.materials[d.material]} end
            sm.material=mats[d.material];sm.castShadows=d.shadow;obj.materialByNode[id]=sm.material
        end
    end
    obj.root=obj.nodes[1];self.objects[#self.objects+1]=obj;return obj
end
function M:AddIntel(id,pos)
    local obj=self:Rig(Data.intel);obj.root.position=Vec(pos);self.intel[id]=obj
end
function M:TakeIntel(id) local obj=self.intel[id];if obj then obj.taken=self.time end end
function M:Objective(step,target)
    self.zone.enabled=step and (step.kind=='install' or step.kind=='hold' or step.kind=='capture') or false
    if self.zone.enabled then local radius=step.r or step.healR
        self.zone.position=Vec({step.pos[1],step.pos[2]+.3,step.pos[3]});self.zone.scale=Vector3(radius,1,radius)
        self.zoneMaterial:SetShaderParameter('uColor',Variant(step.kind=='hold' and Vector3(70/255,200/255,1) or step.kind=='capture' and Vector3(1,59/255,70/255) or Vector3(1,106/255,19/255)))
    end
    self.beacon.root.enabled=target~=nil and step.kind~='pickup' and step.kind~='escort';self.beacon.born=self.time
    if target then self.beacon.root.position=Vec(target) end
    local color=step and step.kind=='install' and Vector3(1,106/255,19/255) or Vector3(70/255,200/255,1)
    for _,m in ipairs(self.beacon.materials) do m.material:SetShaderParameter('uColor',Variant(color)) end
end
function M:Collector(pos,instant)
    local obj=self:Rig(Data.collector);obj.root.position=Vec(pos);obj.root.rotation=Quaternion(math.random()*360,Vector3.UP);obj.born=self.time
    obj.born=instant and self.time-10 or self.time;self.collectors[#self.collectors+1]=obj
end
function M:AddSite(id,pos)
    self:Collector({pos[1]+5,pos[2],pos[3]},true)
    local flag=self:Rig(Data.site);flag.root.position=Vec({pos[1]-4,pos[2],pos[3]+2})
    local material=flag.materialByNode[Data.site.cloth]
    assert(material:SetSurfaceShader('Shaders/BLGL/Story/MissionFlag.shader'))
    material:SetSurfaceTexture('flag_map',assert(cache:GetResource('Texture2D','Story/Mission/pirate.png')))
    local text=self.root:CreateChild('StoryGraffiti'..id);text.position=Vec({pos[1]+5,pos[2]+10.5,pos[3]})
    local sm=text:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[Data.graffiti].path))
    local textMaterial=Material:new();assert(textMaterial:SetSurfaceShader('Shaders/BLGL/Story/MissionText.shader'))
    textMaterial:SetSurfaceTexture('text_map',assert(cache:GetResource('Texture2D','Story/Mission/graffiti.png')))
    sm.material=textMaterial;sm.castShadows=false
    self.sites[id]={flag=flag,cloth=flag.nodes[Data.site.cloth],flagMaterial=material,text=text,textMaterial=textMaterial,wave=math.random()*6}
end
function M:SiteCaptured(id)
    local s=self.sites[id];if not s then return end;s.captured=true
    s.flagMaterial:SetSurfaceTexture('flag_map',assert(cache:GetResource('Texture2D','Story/Mission/company.png')))
    s.flagMaterial:SetShaderParameter('uColor',Variant(Vector3(1,1,1)))
    self.zoneMaterial:SetShaderParameter('uColor',Variant(Vector3(70/255,200/255,1)))
end
function M:Scrub(id) local s=self.sites[id];if s then s.scrubbed=self.time end end
function M:Truck(convoy) self.truck=self:Rig(Data.truck);self.truck.convoy=convoy;self.truck.roll=0 end
function M:Update(dt,rules,camera)
    self.time=self.time+dt;local t=self.time
    if self.truck then local obj=self.truck;local c=obj.convoy
        obj.root.position=Vec(c.pos);obj.root.rotation=Quaternion(-c.yaw*180/math.pi,Vector3.UP)
        obj.roll=obj.roll+c.v*dt/.85
        for _,id in ipairs(Data.truck.wheels) do
            obj.nodes[id].rotation=Quaternion(obj.roll*180/math.pi,Vector3.RIGHT)*Quaternion(-90,Vector3.FORWARD)
        end
        obj.nodes[Data.truck.lamp].rotation=Quaternion(-t*6.25*180/math.pi,Vector3.UP)
        for _,entry in ipairs(obj.materials) do if entry.data==Data.materials[Data.truck.flash] then
            local k=math.max(0,1-(t-(obj.hitAt or -99))*4);entry.material:SetShaderParameter('emission',Variant(Vector3(k*.9,k*.15,k*.1)))
        end end
    end
    for _,obj in ipairs(self.objects) do for _,m in ipairs(obj.materials) do if m.data.shader=='Beam' then m.material:SetShaderParameter('uTime',Variant(t)) end end end
    local step=rules:StepSpec();local progress=step and (step.kind=='hold' or step.kind=='capture') and rules.progress or rules.install/2.4
    self.zoneMaterial:SetShaderParameter('uTime',Variant(t));self.zoneMaterial:SetShaderParameter('uProgress',Variant(math.min(1,progress)))
    for _,site in pairs(self.sites) do
        site.cloth.rotation=Quaternion(-math.sin(t*1.7+site.wave)*.18*180/math.pi,Vector3.UP)
        if camera then site.text.worldRotation=camera.node.worldRotation end
        if site.scrubbed then local k=math.min(1,(t-site.scrubbed)/.8)
            site.textMaterial:SetShaderParameter('opacity',Variant(1-k));site.text:SetScale(math.exp((t-site.scrubbed)*.6));site.text.enabled=k<1
        end
    end
    local b=self.beacon;local k=math.min(1,(t-(b.born or 0))/.6);b.root.scale=Vector3(1,.2+.8*k,1)
    b.nodes[Data.beacon.gem].position=Vector3(0,7+math.sin(t*2)*.5,0);b.nodes[Data.beacon.gem].rotation=Quaternion(-t*1.4*180/math.pi,Vector3.UP)
    b.nodes[Data.beacon.ring2].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(t*.6*180/math.pi,Vector3.FORWARD)
    local pulse=1+.12*math.sin(t*4);b.nodes[Data.beacon.ring].scale=Vector3(pulse,pulse,1)
    for _,obj in pairs(self.intel) do local n=obj.nodes
        n[Data.intel.float].position=Vector3(0,3.4+math.sin(t*2.2)*.4,0)
        n[Data.intel.core].rotation=Quaternion(t*.7*180/math.pi,Vector3.RIGHT)*Quaternion(-t*.9*180/math.pi,Vector3.UP)
        n[Data.intel.inner].rotation=Quaternion(-t*1.3*180/math.pi,Vector3.RIGHT)*Quaternion(-t*2*180/math.pi,Vector3.UP)
        for i,id in ipairs(Data.intel.rings) do
            local q=Data.intel.nodes[id].quaternion
            n[id].rotation=Quaternion(q[4],q[1],-q[2],-q[3])*Quaternion((i==1 and -t*1.2 or t*.9)*180/math.pi,Vector3.FORWARD)
        end
        n[Data.intel.shards].rotation=Quaternion(-t*.8*180/math.pi,Vector3.UP)
        for _,id in ipairs(Data.intel.shardNodes) do n[id].rotation=Quaternion(t*2*180/math.pi,Vector3.RIGHT)*Quaternion(-t*1.4*180/math.pi,Vector3.UP) end
        n[Data.intel.pad2].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(t*.7*180/math.pi,Vector3.FORWARD)
        if obj.taken then local fade=math.min(1,(t-obj.taken)/.55);obj.root:SetScale(1+fade*1.6)
            for _,m in ipairs(obj.materials) do m.material:SetShaderParameter('opacity',Variant(m.data.alpha*(1-fade))) end
            if fade>=1 then obj.root.enabled=false end
        end
    end
    for _,obj in ipairs(self.collectors) do local n=obj.nodes;local r=Data.collector.rig;local age=t-obj.born;local fall=math.min(1,age/.9)
        n[r.body].position=Vector3(0,70*(1-fall*fall),0);n[r.flame].enabled=fall<1
        local dep=math.min(1,math.max(0,(age-1.2)/.6));local e=1-(1-dep)^3
        for _,id in ipairs(r.legs) do n[id].rotation=Quaternion((1.2*(1-e)-.1*e)*180/math.pi,Vector3.RIGHT) end
        n[r.halo]:SetScale(.2+.8*e);n[r.halo].enabled=dep>0;n[r.up].enabled=dep>0
        n[r.rings[1]].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(-t*1.4*180/math.pi,Vector3.FORWARD)
        n[r.rings[2]].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(t*.9*180/math.pi,Vector3.FORWARD)
        obj.materialByNode[r.up]:SetShaderParameter('opacity',Variant(.55*e))
        n[r.drill].rotation=Quaternion(-t*9*e*180/math.pi,Vector3.UP);n[r.drill].position=Vector3(0,.2-.3*e*(.5+.5*math.sin(t*5)),0)
    end
end
function M:Dispose()
    self.root:Dispose();self.zoneMaterial:Dispose()
    for _,obj in ipairs(self.objects) do for _,m in ipairs(obj.materials) do m.material:Dispose() end end
    for _,site in pairs(self.sites) do site.textMaterial:Dispose() end
    self.objects={};self.intel={};self.collectors={};self.sites={}
end
return M
