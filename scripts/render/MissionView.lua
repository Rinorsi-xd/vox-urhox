-- Original storyView meshes exported offline; animations move nodes, not vertices.
local EffectBatch=require("render.EffectBatch")

local Data=require('story.MissionData').view
local Coord=require 'core.Coord'
local Visibility=require 'render.NodeVisibility'
local M={};M.__index=M
local function Vec(p) return Coord.Vec(table.unpack(p)) end
local function Linear(v) local c=v/255;return c<=.04045 and c/12.92 or ((c+.055)/1.055)^2.4 end
local function Color(r,g,b) return Vector3(Linear(r),Linear(g),Linear(b)) end
function M.Dependencies()
    local out={};for _,model in ipairs(Data.models) do out[#out+1]=model.path end
    for _,name in ipairs({'Body','Unlit','Holo','Beam','Ring','Flag','Text'}) do out[#out+1]='Shaders/BLGL/Story/Mission'..name..'.shader' end
    for _,name in ipairs({'pirate','company','graffiti'}) do out[#out+1]='Story/Mission/'..name..'.png' end
    out[#out+1]='Shaders/BLGL/Story/Glow.shader'
    return out
end
function M.New(scene)
    local self=setmetatable({root=scene:CreateChild('StoryMissionObjects'),objects={},intel={},collectors={},sites={},time=0},M)
    self.beacon=self:Rig(Data.beacon);self:HideBeacon();self.alarm=self:Rig(Data.alarm);self.alarmOn=true
    self.glow=EffectBatch.New(self.root,'Glow',64,'Shaders/BLGL/Story/')
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
    local obj={nodes={},materials={},materialByNode={},definition=def,glows={},glowByNode={},lights={}};local mats={}
    for id,d in ipairs(def.nodes) do
        local parent=d.parent==0 and self.root or obj.nodes[d.parent];local n=parent:CreateChild('StoryPart'..id);obj.nodes[id]=n
        n.position=Vec(d.position);n.scale=Vector3(table.unpack(d.scale));local q=d.quaternion;n.rotation=Quaternion(q[4],q[1],-q[2],-q[3]);n.enabled=d.visible
        if d.model or d.lines then
            local sm=nil ---@type StaticModel|CustomGeometry|nil
            if d.lines then
                local lines=n:CreateComponent('CustomGeometry');lines:BeginGeometry(0,LINE_LIST)
                for index=1,#d.lines,3 do lines:DefineVertex(Coord.Vec(d.lines[index],d.lines[index+1],d.lines[index+2]));lines:DefineColor(_G.Color.WHITE) end
                lines:Commit();sm=lines
            else sm=n:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',Data.models[d.model].path)) end
            if not mats[d.material] then local m=self:Material(Data.materials[d.material]);mats[d.material]=m;obj.materials[#obj.materials+1]={material=m,data=Data.materials[d.material],uses=0} end
            for _,entry in ipairs(obj.materials) do if entry.material==mats[d.material] then entry.uses=entry.uses+1;break end end
            sm:SetMaterial(mats[d.material]);sm.castShadows=d.shadow==true;obj.materialByNode[id]=mats[d.material]
        end
        if d.glow then local g={node=n,data=d.glow,opacity=d.glow.opacity};obj.glows[#obj.glows+1]=g;obj.glowByNode[id]=g end
        if d.light then
            local light=n:CreateComponent('Light');light.lightType=LIGHT_POINT;light.color=_G.Color(table.unpack(d.light.color))
            light.useTemperature=false;light.range=d.light.range;light.brightness=d.light.intensity;light.castShadows=false
            obj.lights[id]=light
        end
    end
    obj.root=obj.nodes[1]
    for id=#def.nodes,1,-1 do if not def.nodes[id].visible then Visibility.Set(obj.nodes[id],false) end end
    self.objects[#self.objects+1]=obj;return obj
end
function M:AddIntel(id,pos)
    local obj=self:Rig(Data.intel);obj.root.position=Vec(pos);self.intel[id]=obj
end
function M:TakeIntel(id) local obj=self.intel[id];if obj then obj.taken=self.time end end
function M:Objective(step,target)
    self.zone.enabled=step and (step.kind=='install' or step.kind=='hold' or step.kind=='capture') or false
    if self.zone.enabled then local radius=step.r or step.healR
        self.zone.position=Vec({step.pos[1],step.pos[2]+.3,step.pos[3]});self.zone.scale=Vector3(radius,1,radius)
        self.zoneMaterial:SetShaderParameter('uColor',Variant(step.kind=='hold' and Color(70,200,255) or step.kind=='capture' and Color(255,59,70) or Color(255,106,19)))
        self.zoneMaterial:SetShaderParameter('uProgress',Variant(0))
    end
    Visibility.Set(self.beacon.root,target~=nil and step.kind~='pickup' and step.kind~='escort');self.beacon.born=self.time;self.beacon.fade=1
    if target then self.beacon.root.position=Vec(target) end
    local color=step and step.kind=='install' and Color(255,106,19) or step and step.kind=='capture' and Color(255,59,70) or Color(70,200,255)
    for _,m in ipairs(self.beacon.materials) do if not m.data.line then m.material:SetShaderParameter('uColor',Variant(color)) end end
end
function M:HideBeacon() Visibility.Set(self.beacon.root,false) end
function M:AlarmOff() self.alarmOn=false end
function M:Collector(pos,instant)
    local obj=self:Rig(Data.collector);obj.root.position=Vec(pos);obj.root.rotation=Quaternion(math.random()*360,Vector3.UP);obj.born=self.time
    obj.born=instant and self.time-10 or self.time;obj.landed=instant==true;self.collectors[#self.collectors+1]=obj
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
    self.zoneMaterial:SetShaderParameter('uColor',Variant(Color(70,200,255)))
end
function M:Scrub(id) local s=self.sites[id];if s then s.scrubbed=self.time end end
function M:Truck(convoy) self.truck=self:Rig(Data.truck);self.truck.convoy=convoy;self.truck.roll=0 end
function M:Update(dt,rules,camera)
    self.time=self.time+dt;local t=self.time
    for id,node in ipairs(self.alarm.nodes) do
        local light=self.alarm.lights[id]
        if light then local desired=self.alarmOn and 900*(.5+.5*math.sin(t*7)) or 0;light.brightness=light.brightness+(desired-light.brightness)*math.min(1,dt*6)
        elseif id>1 then node.rotation=Quaternion(-t*5*180/math.pi,Vector3.UP) end
    end
    if self.truck then local obj=self.truck;local c=obj.convoy
        obj.root.position=Vec(c.pos);obj.root.rotation=Quaternion(-c.yaw*180/math.pi,Vector3.UP)
        obj.roll=obj.roll+c.v*dt/.85
        for _,id in ipairs(Data.truck.wheels) do
            obj.nodes[id].rotation=Quaternion(obj.roll*180/math.pi,Vector3.RIGHT)*Quaternion(-90,Vector3.FORWARD)
        end
        obj.nodes[Data.truck.lamp].rotation=Quaternion(-t*6.25*180/math.pi,Vector3.UP)
        Visibility.Set(obj.nodes[Data.truck.glow],c.v>.2 or math.sin(t*6)>0)
        for _,entry in ipairs(obj.materials) do if entry.data==Data.materials[Data.truck.flash] then
            local k=math.max(0,1-(t-(obj.hitAt or -99))*4);entry.material:SetShaderParameter('emission',Variant(Vector3(k*.9,k*.15,k*.1)))
        end end
    end
    for _,obj in ipairs(self.objects) do for _,m in ipairs(obj.materials) do if m.data.shader=='Beam' then m.material:SetShaderParameter('uTime',Variant(t)) end end end
    local step=rules:StepSpec();local progress=rules.install/2.4
    -- The hold ring stays static; capture keeps its completed arc while scrubbing.
    if step and step.kind=='hold' then progress=0
    elseif step and step.kind=='capture' then progress=rules.cap and rules.cap.p or 0 end
    self.zoneMaterial:SetShaderParameter('uTime',Variant(t));self.zoneMaterial:SetShaderParameter('uProgress',Variant(math.min(1,progress)))
    for _,site in pairs(self.sites) do
        site.cloth.rotation=Quaternion(-math.sin(t*1.7+site.wave)*.18*180/math.pi,Vector3.UP)
        if camera then site.text.worldRotation=camera.node.worldRotation end
        if site.scrubbed then local k=math.min(1,(t-site.scrubbed)/.8)
            site.textMaterial:SetShaderParameter('opacity',Variant(1-k));site.text:SetScale(math.exp((t-site.scrubbed)*.6));site.text.enabled=k<1
        end
    end
    local b=self.beacon;local k=math.min(1,(t-(b.born or 0))/.6);b.root.scale=Vector3(1,.2+.8*k,1)
    if b.root.enabled then
        local fadeTo=step and step.kind=='install' and rules.inside and .25 or 1
        b.fade=(b.fade or 1)+(fadeTo-(b.fade or 1))*.08
        for _,m in ipairs(b.materials) do
            if m.data.shader=='Beam' or m.data==Data.materials[Data.beacon.nodes[Data.beacon.gem].material] then
                m.material:SetShaderParameter('opacity',Variant(m.data.alpha*b.fade))
            end
        end
    end
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
        obj.glowByNode[Data.intel.halo].opacity=.45+.15*math.sin(t*4)
        if obj.taken then local fade=math.min(1,(t-obj.taken)/.55);obj.root:SetScale(1+fade*1.6)
            for _,m in ipairs(obj.materials) do local opacity=m.material:GetShaderParameter('opacity'):GetFloat();m.material:SetShaderParameter('opacity',Variant(opacity*.86^m.uses)) end
            for _,g in ipairs(obj.glows) do g.opacity=g.opacity*.86 end
            if fade>=1 then Visibility.Set(obj.root,false) end
        end
    end
    for _,obj in ipairs(self.collectors) do local n=obj.nodes;local r=Data.collector.rig;local age=t-obj.born;local fall=math.min(1,age/.9)
        n[r.body].position=Vector3(0,70*(1-fall*fall),0);Visibility.Set(n[r.flame],fall<1)
        n[r.flame].scale=Vector3(1,.8+.4*math.random(),1)
        if fall>=1 and not obj.landed then obj.landed=true;if self.onLand then local p=obj.root.position;self.onLand({-p.x,p.y+.3,p.z},1) end end
        local dep=math.min(1,math.max(0,(age-1.2)/.6));local e=1-(1-dep)^3
        for _,id in ipairs(r.legs) do n[id].rotation=Quaternion((1.2*(1-e)-.1*e)*180/math.pi,Vector3.RIGHT) end
        n[r.halo]:SetScale(.2+.8*e);Visibility.Set(n[r.halo],dep>0);Visibility.Set(n[r.up],dep>0);Visibility.Set(n[r.glow],dep>0)
        n[r.rings[1]].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(-t*1.4*180/math.pi,Vector3.FORWARD)
        n[r.rings[2]].rotation=Quaternion(-90,Vector3.RIGHT)*Quaternion(t*.9*180/math.pi,Vector3.FORWARD)
        obj.materialByNode[r.up]:SetShaderParameter('opacity',Variant(.55*e))
        n[r.drill].rotation=Quaternion(-t*9*e*180/math.pi,Vector3.UP);n[r.drill].position=Vector3(0,.2-.3*e*(.5+.5*math.sin(t*5)),0)
        local lightness=.5+.25*math.sin(t*4);local a=lightness<=.5 and lightness*2 or 1;local low=lightness>.5 and lightness*2-1 or 0
        obj.materialByNode[r.lamp]:SetShaderParameter('uColor',Variant(Vector3(low,low+(a-low)*.76,a)))
        obj.glowByNode[r.glow].opacity=(.45+.2*math.sin(t*4))*e
    end
    self:Glows(camera)
end
function M:Glows(camera)
    if not camera then self.glow.mesh.enabled=false;return end
    local node=camera.node;local p=node.worldPosition
    local right=node.worldRotation*Vector3.RIGHT;local up=node.worldRotation*Vector3.UP
    local r,u={-right.x,right.y,right.z},{-up.x,up.y,up.z};self.glow:Begin({-p.x,p.y,p.z},self.time)
    for _,obj in ipairs(self.objects) do if obj.root.enabled then for _,g in ipairs(obj.glows) do if g.node.enabled then
        local at=g.node.worldPosition;local size=g.node.worldScale.x
        self.glow:Disc({-at.x,at.y,at.z},size,g.data.color,g.opacity,r,u)
    end end end end
    self.glow:Finish()
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.glow:Dispose()
    self.root:Dispose();self.zoneMaterial:Dispose()
    for _,obj in ipairs(self.objects) do for _,m in ipairs(obj.materials) do m.material:Dispose() end end
    for _,site in pairs(self.sites) do site.textMaterial:Dispose() end
    self.objects={};self.intel={};self.collectors={};self.sites={}
    self.onLand=nil;self.alarm=nil;self.beacon=nil;self.truck=nil
    self.root=nil;self.zone=nil;self.zoneMaterial=nil;self.glow=nil
end
return M
