-- Equipment presentation consumes physical output/contact; never issues rays or forces.
local V=require "core.Math3"
local Coord=require "core.Coord"
local State=require "render.EquipmentState"
local Resources=require "render.EquipmentResources"
local Batch=require "render.EffectBatch"
local Quality=require("render.Quality").current
local CELL=require("Config").CELL
local DIR='Shaders/BLGL/Equipment/'
local M={};M.__index=M
local function Native(p) return Coord.Vec(table.unpack(p)) end
local function Source(p) return {-p.x,p.y,p.z} end
local function Basis(n)
    local r=V.Normalize(V.Cross(math.abs(n[2])<.9 and {0,1,0} or {1,0,0},n))
    return r,V.Cross(n,r)
end
local function Emission(item,value)
    for _,model in ipairs(item.vis.emissionModels) do model.instanceCustomData=Vector4(value,0,0,0) end
end
function M.New(scene)
    return setmetatable({scene=scene,items={},particles={},batches={},random=317,disposed=false},M)
end
function M:Random()
    self.random=(self.random*48271)%2147483647;return self.random/2147483647
end
function M:Root()
    if not self.root then self.root=self.scene:CreateChild('EquipmentEffects');Resources.Acquire() end
    return self.root
end
function M:Batch(kind,limit)
    if not self.batches[kind] then
        local b=Batch.New(self:Root(),kind,limit,DIR);self.batches[kind]=b
        if kind=='Flare' then b.material:SetSurfaceTexture('flow_map',Resources.Flow()) end
    end
    return self.batches[kind]
end
function M:Bind(view,vehicle)
    self.vehicle=vehicle;local retained={}
    for id,vis in pairs(view.visuals) do
        local s=vis.data.segments
        if s and s~=cjson.null and (s.thruster or s.hover or s.leg or s.mech) then
            local old=self.items[id]
            local item=old and old.vis==vis and old or {id=id,vis=vis,power=0,credit=0,seed=(id*.61803398875)%1,proxies={},origins={}}
            retained[id]=item
            if s.mech then
                local info=s.info;local nozzles={}
                for _,n in ipairs(info.nozzles) do nozzles[#nozzles+1]={p=V.Sub(n.p,info.joints.knee),radius=n.radius} end
                item.jetInfo={nozzles=nozzles,exhaustDir=info.nozzles[1] and info.nozzles[1].dir or {0,-1,0},family='mech',tier=info.tier}
                self:Batch('Flare',256);self:Batch('Mote',Quality.exhaustParticles)
            elseif s.thruster then self:Batch('Flare',256);self:Batch('Mote',Quality.exhaustParticles)
            elseif s.hover then self:Batch('Spot',256)
            else self:Batch('Contact',256) end
        end
    end
    for id,item in pairs(self.items) do if retained[id]~=item then
        for _,proxy in pairs(item.proxies) do proxy.node:Dispose() end
    end end
    self.items=retained
end
function M:Proxy(item,index,kind)
    local p=item.proxies[index]
    if not p then
        local node=self:Root():CreateChild(kind..item.id..'_'..index)
        local model=node:CreateComponent('StaticModel');model.model=Resources.Box();model.material=Resources.Material(kind)
        model.castShadows=false;model.drawDistance=Quality.equipmentFar
        p={node=node,model=model};item.proxies[index]=p
    end
    return p
end
function M:Reset()
    self.particles={}
    for _,item in pairs(self.items) do
        item.power=0;item.credit=0;item.origins={};item.planted=false
        Emission(item,item.vis.emissionDefault)
        for _,p in pairs(item.proxies) do p.model.enabled=false end
    end
    for _,b in pairs(self.batches) do b.count=0;b.mesh.enabled=false end
end
function M:Thruster(item,dt,time,camera,right,up)
    local mech=item.vis.data.segments.mech
    local info=item.jetInfo or item.vis.data.segments.info
    local state=mech and self.vehicle.mechStates[item.id]
    local target=mech and (state and state.jet or 0) or self.vehicle.thrusterOutputs[item.id] or 0
    item.power=State.Power(item.power,target,dt)
    if not mech then Emission(item,1.5+item.power*.85) end
    local housing=mech and item.vis.rig.mech.shin or item.vis.rig.housing
    local axis=(housing.worldRotation*Native(info.exhaustDir)):Normalized()
    local distance=(housing.worldPosition-camera):Length();local visible=distance<Quality.equipmentFar and item.power>0
    local steps=distance>Quality.equipmentLod and math.max(6,math.floor(Quality.thrusterSteps*.5)) or Quality.thrusterSteps
    local jets={}
    for i,nozzle in ipairs(info.nozzles) do
        local base=housing:LocalToWorld(Native(nozzle.p));local old=item.origins[i]
        local velocity=old and dt>0 and (base-old)/dt or Vector3.ZERO
        if velocity:Length()>100 then velocity=Vector3.ZERO end
        item.origins[i]=base
        local dimensions=State.Jet(info,nozzle,item.power,time,item.seed)
        local radius,length=dimensions.radius*CELL,dimensions.length*CELL*(mech and 2.4 or 1)
        if visible then
            local p=self:Proxy(item,i,'Thruster');p.model.enabled=true
            p.node.position=base+axis*(length*.5);p.node.rotation=Quaternion(Vector3.FORWARD,axis):Normalized()
            p.node:SetScale(Vector3(radius*2,radius*2,length))
            p.model.instanceCustomData=Vector4(dimensions.power,item.seed+(i-1)*.19,length/radius,steps)
            local axial=V.Clamp((math.abs(axis:DotProduct(self.cameraForward))-.65)/.33,0,1)
            axial=axial*axial*(3-2*axial)
            local pos=Source(base+axis*(nozzle.radius*CELL*.3));local half=nozzle.radius*CELL*1.05
            local r,u=V.Scale(right,half),V.Scale(up,half)
            self.batches.Flare:Quad({V.Sub(V.Sub(pos,r),u),V.Add(V.Sub(pos,u),r),V.Add(V.Sub(pos,r),u),V.Add(V.Add(pos,r),u)},
                {{-1,-1},{1,-1},{-1,1},{1,1}},{1,1,1},1,{dimensions.power,item.seed+(i-1)*.19,axial})
            jets[#jets+1]={base=Source(base),axis=Source(axis),velocity=Source(velocity),length=length,radius=nozzle.radius*CELL}
        elseif item.proxies[i] then item.proxies[i].model.enabled=false end
    end
    item.credit=visible and math.min(2,item.credit+dt*(target>0 and item.power or 0)*28) or 0
    local count=0;for _,p in ipairs(self.particles) do if p.owner==item.id then count=count+1 end end
    while item.credit>=1 and #jets>0 and count<48 and #self.particles<Quality.exhaustParticles do
        item.credit=item.credit-1;count=count+1
        local jet=jets[math.min(#jets,1+math.floor(self:Random()*#jets))];local r,u=Basis(jet.axis)
        local pos=V.Add(jet.base,V.Scale(jet.axis,jet.length*.62))
        pos=V.Add(pos,V.Add(V.Scale(r,(self:Random()-.5)*jet.radius*.3),V.Scale(u,(self:Random()-.5)*jet.radius*.3)))
        self.particles[#self.particles+1]={owner=item.id,pos=pos,velocity=V.Add(V.Scale(jet.axis,3+info.tier*.35),jet.velocity),age=0,life=.16+self:Random()*.12}
    end
end
function M:Hover(item,time,camera)
    local s=self.vehicle.hoverStates[item.id];local power=s and s.force>0 and s.G or 0
    item.power=power;Emission(item,power*1.65)
    local vis=item.vis;local distance=(vis.node.worldPosition-camera):Length()
    local steps=distance>Quality.equipmentLod and math.max(4,math.floor(Quality.hoverSteps*.5)) or Quality.hoverSteps
    for i,e in ipairs(vis.data.segments.info.emits) do
        local hit=s and s.emitHits[i]
        if power>.002 and hit and distance<Quality.equipmentFar then
            local a,b=vis.node:LocalToWorld(Native(e.p)),Native(hit.point);local delta=a-b;local length=delta:Length()
            if length>.0001 then
                local radius=e.radius*CELL*1.22;local p=self:Proxy(item,i,'Hover');p.model.enabled=true
                p.node.position=(a+b)*.5;p.node.rotation=Quaternion(Vector3.UP,delta/length):Normalized()
                p.node:SetScale(Vector3(radius*2,length,radius*2));p.model.instanceCustomData=Vector4(power,0,0,steps)
                local r,u=Basis(hit.normal)
                self.batches.Spot:Disc(V.Add(hit.point,V.Scale(hit.normal,.012)),radius*2*1.45,{1,1,1},power,r,u)
            elseif item.proxies[i] then item.proxies[i].model.enabled=false end
        elseif item.proxies[i] then item.proxies[i].model.enabled=false end
    end
end
function M:Leg(item,time,camera)
    local s=self.vehicle.legStates[item.id]
    Emission(item,2.8+(s and s.jumpGlow or 0)*5)
    local planted=s and s.grounded and s.contact and s.foot
    if planted and not item.planted then item.at=time end
    item.planted=not not planted
    if not planted or (Native(s.foot)-camera):Length()>Quality.equipmentFar then return end
    local normal=s.contact.normal;local r,u=Basis(normal);local pulse=math.max(0,1-(time-item.at)/.16)
    self.batches.Contact:Disc(V.Add(s.foot,V.Scale(normal,.012)),.27*(1+pulse*.5),{.1714,.7231,.7758},
        (normal[2]<.7 and .6 or .32)+pulse*.2,r,u)
end
function M:Update(dt,context)
    if not context or not self.root then return end
    local camera=context.camera.worldPosition;local time=context.time
    self.cameraForward=context.camera.worldRotation*Vector3.FORWARD
    local right,up=Source(context.camera.worldRotation*Vector3.RIGHT),Source(context.camera.worldRotation*Vector3.UP)
    for _,b in pairs(self.batches) do b:Begin(Source(camera),time) end
    for _,item in pairs(self.items) do
        local s=item.vis.data.segments
        if s.thruster or s.mech then self:Thruster(item,dt,time,camera,right,up)
        elseif s.hover then self:Hover(item,time,camera)
        else self:Leg(item,time,camera) end
    end
    -- World-space residual exhaust outlives power cutoff; teleports clear it.
    local i=1;local projection=2*math.tan(math.rad(context.fov or 60)*.5)/math.max(1,graphics:GetHeight())
    while i<=#self.particles do
        local p=self.particles[i];p.age=p.age+dt
        if p.age>=p.life then self.particles[i]=self.particles[#self.particles];self.particles[#self.particles]=nil
        else
            p.pos=V.Add(p.pos,V.Scale(p.velocity,dt))
            local z=context.camera:WorldToLocal(Native(p.pos)).z;local fade=(1-p.age/p.life)^2
            if z>0 then
                local pixels=V.Clamp(36*graphics:GetDPR()*fade/math.max(1,z),1,7)
                self.batches.Mote:Disc(p.pos,pixels*z*projection,{.08,.65,1.5},fade,right,up)
            end
            i=i+1
        end
    end
    Resources.Clock(time)
    for _,b in pairs(self.batches) do b:Finish() end
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    for _,b in pairs(self.batches) do b:Dispose() end
    if self.root then self.root:Dispose();Resources.Release() end
    self.items={};self.particles={};self.batches={}
end
return M
