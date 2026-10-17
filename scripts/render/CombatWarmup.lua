-- Loading-only draws use the live effect owner without simulation events or RNG.
-- Call Presented only after a rendered frame; Dispose before disposing the scene.
local FlashWarmup=require("render.FlashWarmup")
local EquipmentWarmup=require('render.EquipmentWarmup')
local MapWarmupProbes=require('render.MapWarmupProbes')

local M={};M.__index=M
local WarmupSignature=require('render.WarmupSignature')
local kinds={'StaticModel','StaticModelGroup','AnimatedModel','CustomGeometry','BillboardSet','Terrain','Skybox'}
local function Source(p) return {-p.x,p.y,p.z} end
local function NodeState(node)
    return {node=node,position=node.position,rotation=node.rotation,scale=node.scale,enabled=node.enabled}
end
local function RestoreNode(s)
    s.node.position=s.position;s.node.rotation=s.rotation;s.node.scale=s.scale;s.node.enabled=s.enabled
end
local function Signature(drawable,kind)
    if kind~='StaticModel' then return kind..':'..tostring(drawable) end
    local model=drawable.model;if not model then return kind..':'..tostring(drawable) end
    local key={kind,tostring(model),tostring(drawable.zone),tostring(drawable.viewMask),tostring(drawable.lightMask),
        tostring(drawable.shadowMask),tostring(drawable.zoneMask),tostring(drawable.castShadows),tostring(drawable.maxLights),
        tostring(drawable.useInstanceColor),tostring(drawable.useInstanceCustomData)}
    for i=0,model.numGeometries-1 do key[#key+1]=tostring(drawable:GetMaterial(i)) end
    return table.concat(key,'|')
end
function M.New(session,options)
    local self=setmetatable({session=session,effects=session.effects,all={},batchStates={},chipStates={},missileStates={},
        groups={},proxies={},exposed={},effectItems={},frames=0,index=0,disposed=false,completed=false},M)
    local ok,err=pcall(self.init,self,options or {})
    if not ok then self:Dispose();error(err) end
    return self
end
function M:init(options)
    local fx=self.effects;assert(fx and not fx.disposed,'CombatWarmup requires a live trial effect owner')
    -- Rewriting geometry is valid only before the new session has emitted FX.
    for _,name in ipairs({'beams','flares','rings','particles','smoke','flashes','zaps','trails'}) do
        assert(#fx[name]==0,'CombatWarmup must run before combat starts: '..name)
    end
    for _,slot in ipairs(fx.chips.slots) do assert(not slot.active,'CombatWarmup cannot replace live chips') end
    assert(not fx.missiles.view or fx.missiles.view.count==0,'CombatWarmup cannot replace live missiles')
    self.camera=self.session.camera:GetCamera();self.batchSize=math.max(4,math.floor(options.batchSize or 8))
    if self.session.aimLines then
        local lines=self.session.aimLines
        self.aimMasks={{drawable=lines.mesh,mask=lines.mesh.viewMask},{drawable=lines.glow.mesh,mask=lines.glow.mesh.viewMask}}
    end
    self.lightState={node=NodeState(fx.light.node),range=fx.light.light.range,brightness=fx.light.light.brightness,enabled=fx.light.light.enabled}
    fx:Reserve({arc=true,chips=options.chips or 32,missiles=options.missiles or 4})
    for _,batch in pairs(fx.batches) do
        assert(batch.count==0,'CombatWarmup cannot replace committed live FX')
        self.batchStates[#self.batchStates+1]={batch=batch,count=batch.count,enabled=batch.mesh.enabled,
            clock=Variant(batch.material:GetShaderParameter('clock')),camera=batch.camera}
    end
    for _,slot in ipairs(fx.chips.slots) do
        self.chipStates[#self.chipStates+1]={slot=slot,node=NodeState(slot.node),enabled=slot.model.enabled,
            color=slot.model.instanceColor,useInstanceColor=slot.model.useInstanceColor}
    end
    self.missileCount=fx.missiles.view.count
    for _,node in ipairs(fx.missiles.view.slots) do self.missileStates[#self.missileStates+1]=NodeState(node) end
    local owned={}
    for _,kind in ipairs(kinds) do for _,d in ipairs(fx.root:GetComponents(kind,true)) do owned[d]=true end end
    local keyed,seen={},{};local frustum=self.camera.frustum
    for _,kind in ipairs(kinds) do for _,d in ipairs(self.session.scene:GetComponents(kind,true)) do
        if not seen[d] then
        seen[d]=true
        local item={drawable=d,mask=d.viewMask};self.all[#self.all+1]=item
        if owned[d] then self.effectItems[#self.effectItems+1]=item end
        if d.viewMask~=0 and d.enabledEffective and not owned[d] and kind~='Skybox'
            and frustum:IsInsideFast(d.worldBoundingBox)~=OUTSIDE then
            local key=Signature(d,kind);local group=keyed[key]
            if not group then group={key=key,kind=kind,items={}};keyed[key]=group;self.groups[#self.groups+1]=group end
            if #group.items<4 then group.items[#group.items+1]={drawable=d,mask=d.viewMask} end
        end
        end
    end end
    table.sort(self.groups,function(a,b)return a.key<b.key end)
    self.originalGroups=#self.groups
    if options.groupEquivalent~=false then self.groups,self.signatureStats=WarmupSignature.Compact(self.groups) end
    self.volumeGroups={}
    for _,group in ipairs(self.groups) do self.volumeGroups[#self.volumeGroups+1]=group end
    local mapProbes;mapProbes,self.mapProbeStats=MapWarmupProbes.Collect(self.groups)
    for _,group in ipairs(mapProbes) do self.volumeGroups[#self.volumeGroups+1]=group end
    self.owned=owned
    self.flashWarmup=FlashWarmup.New(self.session)
    self.equipmentWarmup=EquipmentWarmup.New(self.session)
    self:Effects(4);self.phase='effects-instanced'
    local stats=self.signatureStats or {eligible=0,rejected=0,errors=0}
    print('[CombatWarmup] begin groups='..#self.groups..' originalGroups='..self.originalGroups..' chips='..#fx.chips.slots..' missiles='..#fx.missiles.view.slots
        ..' signatureEligible='..stats.eligible..' signatureRejected='..stats.rejected..' signatureErrors='..stats.errors
        ..' firstReject='..tostring(stats.firstReject)..' firstError='..tostring(stats.firstError)
        ..' mapSingleProbes='..self.mapProbeStats.probes..' mapProbeRejected='..self.mapProbeStats.rejected
        ..' mapProbeErrors='..self.mapProbeStats.errors..' mapProbeFirstReject='..tostring(self.mapProbeStats.firstReject)
        ..' mapProbeFirstError='..tostring(self.mapProbeStats.firstError))
end
function M:Hide()
    if not self.hidden then
        for _,item in ipairs(self.all) do item.drawable.viewMask=0 end
        self.hidden=true
    else
        for i,item in ipairs(self.exposed) do item.drawable.viewMask=0;self.exposed[i]=nil end
    end
    if self.session.aimLines then self.session.aimLines:Hide() end
    for _,proxy in ipairs(self.proxies) do proxy.node.enabled=false end
    if self.flashWarmup then self.flashWarmup:Show(0) end
    if self.equipmentWarmup then self.equipmentWarmup:Show(0) end
end
function M:Expose(item)
    item.drawable.viewMask=item.mask
    if item.mask~=0 then self.exposed[#self.exposed+1]=item end
end
function M:Flashes(copies)
    self:Hide();self.effects.light.light.enabled=false
    self.flashWarmup:Show(copies)
    self.phase=copies>1 and 'flash-instanced' or 'flash-single'
end
function M:Equipment(copies)
    self:Hide();self.effects.light.light.enabled=false
    self.equipmentWarmup:Show(copies)
    self.phase=copies>1 and 'equipment-instanced' or 'equipment-single'
end
function M:WorldStart()
    if self.equipmentWarmup then self:Equipment(4);return false end
    return self:WorldContinue()
end
function M:WorldContinue()
    if #self.groups==0 then self.completed=true;self:Dispose();return true end
    self:LightBatch();return false
end
function M:Effects(copies,pointLight)
    self:Hide()
    local fx=self.effects;local camera=self.camera.node;local rotation=camera.worldRotation
    local native=camera.worldPosition+rotation*Vector3.FORWARD*8
    local at=Source(native);local right=Source(rotation*Vector3.RIGHT);local up=Source(rotation*Vector3.UP)
    local eye=Source(camera.worldPosition)
    for _,batch in pairs(fx.batches) do
        batch:Begin(eye,fx.time);batch:Disc(at,.6,{.25,.5,1},1,right,up);batch:Finish()
    end
    for i,state in ipairs(self.chipStates) do
        local slot=state.slot;slot.node.enabled=i<=copies
        if i<=copies then
            slot.node.position=native+rotation*Vector3.RIGHT*((i-2.5)*.45)
            slot.node.rotation=Quaternion.IDENTITY;slot.node:SetScale(.2);slot.model.enabled=true
            slot.model.instanceColor=Color(.3,.6,1,1)
        end
    end
    local view=fx.missiles.view;view:Begin()
    for i=1,math.min(copies,#view.slots) do
        local p=native+rotation*Vector3.UP*.7+rotation*Vector3.RIGHT*((i-2.5)*.45)
        view:Add({pos=Source(p),vel=Source(rotation*Vector3.FORWARD),s={tier=3}})
    end
    view:Finish()
    if pointLight then self:EnableLight() else fx.light.light.enabled=false end
    for _,item in ipairs(self.effectItems) do self:Expose(item) end
    if self.aimMasks then
        self.session.aimLines:Warmup(self.camera,fx.time)
        for _,item in ipairs(self.aimMasks) do self:Expose(item) end
    end
end
function M:EnableLight()
    local fx=self.effects;local light=fx.light.light
    fx.light.node.position=self.camera.node.worldPosition
    light.range=math.max(self.lightState.range,self.camera.farClip*2);light.brightness=140;light.enabled=true
end
function M:LightBatch()
    self:Hide();self:EnableLight()
    local count=0;local used={}
    while self.index<#self.groups do
        local group=self.groups[self.index+1]
        local copies=self.singleWorld and math.min(1,#group.items) or #group.items
        if count>0 and count+copies>self.batchSize then break end
        if self.singleWorld and not WarmupSignature.CanAppend(group,used,count) then break end
        self.index=self.index+1
        WarmupSignature.Mark(group,used)
        for i=1,copies do self:Expose(group.items[i]);count=count+1 end
    end
    self.phase=self.singleWorld and 'point-light-single' or 'point-light-instanced';return count
end
function M:VolumeBatch()
    self:Hide()
    local camera=self.camera.node;local rotation=camera.worldRotation
    local center=camera.worldPosition+rotation*Vector3.FORWARD*8
    local light=self.effects.light.light
    -- An eye-centred, far-clip-sized light bypasses the native stencil volume.
    self.effects.light.node.position=center;light.range=4;light.brightness=140;light.enabled=true
    if not self.proxyRoot then self.proxyRoot=self.session.scene:CreateChild('CombatWarmupProbes') end
    local count=0;local used={}
    while self.index<#self.volumeGroups do
        local group=self.volumeGroups[self.index+1]
        local copies=group.kind=='StaticModel' and (self.singleVolume and 1 or not group.singleVolumeOnly and 4 or 0) or 0
        if count>0 and count+copies>self.batchSize then break end
        if copies>0 and self.singleVolume and not WarmupSignature.CanAppend(group,used,count) then break end
        self.index=self.index+1
        if copies>0 then
            WarmupSignature.Mark(group,used)
            local source=group.items[1].drawable;local model=source.model
            local box=model.boundingBox;local size=box.size
            local scale=.6/math.max(.001,size.x,size.y,size.z)
            for i=1,copies do
                count=count+1;local proxy=self.proxies[count]
                if not proxy then
                    local node=self.proxyRoot:CreateChild('Probe'..count)
                    proxy={node=node,drawable=node:CreateComponent('StaticModel')};self.proxies[count]=proxy
                end
                local d=proxy.drawable;d.model=model
                for j=0,model.numGeometries-1 do d:SetMaterial(j,source:GetMaterial(j)) end
                for _,key in ipairs({'viewMask','lightMask','shadowMask','zoneMask','castShadows','maxLights',
                    'instanceColor','instanceCustomData','useInstanceColor','useInstanceCustomData'}) do d[key]=source[key] end
                -- The source is masked while warming; retain its pre-warm view mask.
                d.viewMask=group.items[1].mask
                proxy.node.rotation=Quaternion.IDENTITY;proxy.node:SetScale(scale)
                proxy.node.position=center+rotation*Vector3.RIGHT*((count-(self.batchSize+1)*.5)*.7)-box.center*scale
                proxy.node.enabled=true
            end
        end
    end
    self.phase=self.singleVolume and 'point-volume-single' or 'point-volume-instanced'
    return count
end
function M:Presented()
    if self.disposed then return self.completed end
    local ok,done=pcall(self.Advance,self)
    if not ok then self:Dispose();error(done) end
    return done
end
function M:Advance()
    self.frames=self.frames+1
    if self.phase=='effects-instanced' then self:Effects(1);self.phase='effects-single'
    elseif self.phase=='effects-single' then self:Effects(4,true);self.phase='effects-point-instanced'
    elseif self.phase=='effects-point-instanced' then self:Effects(1,true);self.phase='effects-point-single'
    elseif self.phase=='effects-point-single' then
        if self.flashWarmup then self:Flashes(4)
        else return self:WorldStart() end
    elseif self.phase=='flash-instanced' then self:Flashes(1)
    elseif self.phase=='flash-single' then
        return self:WorldStart()
    elseif self.phase=='equipment-instanced' then self:Equipment(1)
    elseif self.phase=='equipment-single' then return self:WorldContinue()
    elseif self.phase=='point-volume-instanced' or self.phase=='point-volume-single' then
        if self.index<#self.volumeGroups then self:VolumeBatch()
        elseif not self.singleVolume then self.singleVolume=true;self.index=0;self:VolumeBatch()
        else self.completed=true;self:Dispose();return true end
    elseif self.index<#self.groups then self:LightBatch()
    elseif not self.singleWorld then self.singleWorld=true;self.index=0;self:LightBatch()
    else self.index=0;self:VolumeBatch() end
    return false
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    if self.session.aimLines then self.session.aimLines:Hide() end
    if self.flashWarmup then self.flashWarmup:Dispose();self.flashWarmup=nil end
    if self.equipmentWarmup then self.equipmentWarmup:Dispose();self.equipmentWarmup=nil end
    if self.proxyRoot then self.proxyRoot:Dispose();self.proxyRoot=nil end
    for _,item in ipairs(self.all) do item.drawable.viewMask=item.mask end
    for _,state in ipairs(self.batchStates) do
        local batch=state.batch;batch.count=state.count;batch.mesh.enabled=state.enabled;batch.camera=state.camera
        if state.clock.type==VAR_NONE then batch.material:RemoveShaderParameter('clock')
        else batch.material:SetShaderParameter('clock',state.clock) end
    end
    for _,state in ipairs(self.chipStates) do
        RestoreNode(state.node);state.slot.model.enabled=state.enabled;state.slot.model.instanceColor=state.color
        state.slot.model.useInstanceColor=state.useInstanceColor
    end
    for _,state in ipairs(self.missileStates) do RestoreNode(state) end
    if self.missileCount then self.effects.missiles.view.count=self.missileCount end
    if self.lightState then
        local light=self.effects.light.light;RestoreNode(self.lightState.node)
        light.range=self.lightState.range;light.brightness=self.lightState.brightness;light.enabled=self.lightState.enabled
    end
    print('[CombatWarmup] restored completed='..tostring(self.completed)..' frames='..self.frames..' groups='..#self.groups)
end
function M:Snapshot()
    return {phase=self.phase,frames=self.frames,groups=#self.groups,group=self.index,completed=self.completed,disposed=self.disposed,
        probes=#self.proxies,chips=#self.effects.chips.slots,missiles=self.effects.missiles.view and #self.effects.missiles.view.slots or 0,
        equipment=self.equipmentWarmup and self.equipmentWarmup:Snapshot(),mapProbes=self.mapProbeStats}
end
return M
