-- Original storyView meshes exported offline; animations move nodes, not vertices.
local Data=require('story.MissionData').view
local Coord=require 'core.Coord'
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
function M.Dependencies()
    local out={};for _,model in ipairs(Data.models) do out[#out+1]=model.path end
    for _,name in ipairs({'Body','Unlit','Holo','Beam','Ring'}) do out[#out+1]='Shaders/BLGL/Story/Mission'..name..'.shader' end
    return out
end
function M.New(scene)
    local self=setmetatable({root=scene:CreateChild('StoryMissionObjects'),objects={},intel={},collectors={},time=0},M)
    self.beacon=self:Rig(Data.beacon);self.beacon.root.enabled=false
    self.zone=self.root:CreateChild('InstallZone');local sm=self.zone:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[Data.zone].path))
    self.zoneMaterial=self:Material({shader='Ring',color={1,106/255,19/255},alpha=1});sm.material=self.zoneMaterial;sm.castShadows=false;self.zone.enabled=false
    return self
end
function M:Material(data)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/Story/Mission'..data.shader..'.shader'))
    m:SetShaderParameter('uColor',Variant(Vector3(table.unpack(data.color))))
    m:SetShaderParameter('opacity',Variant(data.alpha));m:SetShaderParameter('roughness',Variant(data.roughness or .5));m:SetShaderParameter('metalness',Variant(data.metalness or 0))
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
    self.zone.enabled=step and step.kind=='install' or false
    if self.zone.enabled then self.zone.position=Vec({step.pos[1],step.pos[2]+.3,step.pos[3]});self.zone.scale=Vector3(step.r,1,step.r) end
    self.beacon.root.enabled=target~=nil and step.kind~='pickup';self.beacon.born=self.time
    if target then self.beacon.root.position=Vec(target) end
    local color=step and step.kind=='install' and Vector3(1,106/255,19/255) or Vector3(70/255,200/255,1)
    for _,m in ipairs(self.beacon.materials) do m.material:SetShaderParameter('uColor',Variant(color)) end
end
function M:Collector(pos)
    local obj=self:Rig(Data.collector);obj.root.position=Vec(pos);obj.root.rotation=Quaternion(math.random()*360,Vector3.UP);obj.born=self.time
    self.collectors[#self.collectors+1]=obj
end
function M:Update(dt,rules)
    self.time=self.time+dt;local t=self.time
    for _,obj in ipairs(self.objects) do for _,m in ipairs(obj.materials) do if m.data.shader=='Beam' then m.material:SetShaderParameter('uTime',Variant(t)) end end end
    self.zoneMaterial:SetShaderParameter('uTime',Variant(t));self.zoneMaterial:SetShaderParameter('uProgress',Variant(math.min(1,rules.install/2.4)))
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
    self.objects={};self.intel={};self.collectors={}
end
return M
