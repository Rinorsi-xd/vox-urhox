-- testDrive._syncPlayer -> VehicleView.paintFlash: restored parts get the
-- original additive cyan shell (.34s) and non-joined parts pop for .2s.
local Coord=require 'core.Coord'
local Surface=require 'render.JoinedSurface'
local M={};M.__index=M
local OMIT={beamCyan=true,beamOrange=true,beamPaint=true,holoPaint=true}
local function Layers(data,out)
    if type(data)~='table' then return end
    if data.model and data.slots then out[data.model]=data.slots;return end
    for _,value in pairs(data) do if type(value)=='table' then Layers(value,out) end end
end
function M.New(scene,options)
    local self=setmetatable({},M);self:init(scene,options);return self
end
function M:init(scene,options)
    options=options or {}
    self.root=scene:CreateChild('PlayerRestoreFlashes');self.items={};self.time=0;self.disposed=false
    self.pool={};self.poolSize=options.poolSize or 0
    self.copyCache={};self.copyOwners={}
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/RestoreFlash.shader'))
    self.material.depthBias=BiasParameters(-.00004,-1);self.material.renderOrder=134
    if options.whiteBase then self.material:SetShaderParameter('flash_color',Variant(Vector3(1,1,1))) end
end
function M:AcquireCopy(model,selected)
    local key=table.concat(selected,',');local entries=self.copyCache[model]
    if not entries then entries={};self.copyCache[model]=entries end
    local entry=entries[key]
    if not entry or entry.bounds~=model.boundingBox then
        local copy=Model:new();copy:SetNumGeometries(#selected);copy:SetBoundingBox(model.boundingBox)
        for i,index in ipairs(selected) do copy:SetNumGeometryLodLevels(i-1,1);copy:SetGeometry(i-1,0,model:GetGeometry(index,0)) end
        entry={copy=copy,refs=0,source=model,key=key,bounds=BoundingBox(model.boundingBox)}
        entries[key]=entry;self.copyOwners[copy]=entry
    end
    entry.refs=entry.refs+1;return entry.copy
end
function M:ReleaseCopy(copy)
    local entry=self.copyOwners[copy];entry.refs=entry.refs-1
    if entry.refs>0 then return end
    local entries=self.copyCache[entry.source]
    if entries then
        if entries[entry.key]==entry then entries[entry.key]=nil end
        if next(entries)==nil then self.copyCache[entry.source]=nil end
    end
    self.copyOwners[copy]=nil;copy:Dispose()
end
function M:Destroy(item)
    local current=self.view and self.view.visuals[item.id]
    if current==item.vis and item.pop then current.node.scale=item.baseScale end
    item.node:Dispose();item.models={}
    for _,model in ipairs(item.copies) do self:ReleaseCopy(model) end
    item.copies={};if item.material then item.material:Dispose();item.material=nil end
end
function M:Drop(item)
    if self.poolSize>0 and not self.clearing and self.view.visuals[item.id]==item.vis then
        require('render.NodeVisibility').Set(item.node,false,true)
        if #self.pool>=self.poolSize then self:Destroy(table.remove(self.pool,1)) end
        self.pool[#self.pool+1]=item
    else self:Destroy(item) end
end
function M:Clear()
    self.clearing=true
    for _,item in ipairs(self.items) do self:Drop(item) end
    for _,item in ipairs(self.pool) do self:Destroy(item) end
    self.items={};self.pool={};self.clearing=false
end
function M:Bind(view)
    if self.view~=view or self.generation~=view.visuals then self:Clear();self.view=view;self.generation=view.visuals end
end
function M:Activate(item,options)
    item.t0=self.time;item.color=options.color or {1,1,1};item.pop=options.pop~=false and not item.vis.joined
    item.node.position=item.vis.node.position;item.node.rotation=item.vis.node.rotation
    require('render.NodeVisibility').Set(item.node,true)
    if item.sources then
        local localFromWorld=item.vis.node.worldTransform:Inverse()
        for _,entry in ipairs(item.sources) do entry.node:SetTransform(localFromWorld*entry.source.node.worldTransform) end
    end
    if item.material then item.material:SetShaderParameter('joined_color',Variant(Vector3(table.unpack(item.color)))) end
    self.root:SetTransform(self.view.root.worldPosition,self.view.root.worldRotation,self.view.root.worldScale)
    self:Apply(item)
end
function M:Add(part,options)
    options=options or {}
    local vis=self.view.visuals[part.id];if not vis then return end
    if self.poolSize>0 then
        for i=#self.pool,1,-1 do local item=self.pool[i];if item.id==part.id and item.vis==vis then
            table.remove(self.pool,i);self.items[#self.items+1]=item;self:Activate(item,options);return
        end end
    end
    if self.poolSize==0 then
        for i=#self.items,1,-1 do if self.items[i].id==part.id then self:Drop(self.items[i]);table.remove(self.items,i) end end
    end
    local node=self.root:CreateChild('Restored'..part.id)
    node.position=vis.node.position;node.rotation=vis.node.rotation
    local item={id=part.id,vis=vis,node=node,models={},copies={},sources={},baseScale=vis.node.scale}
    if vis.joined then
        local shape=Surface.Shape(part);local geometry=node:CreateComponent('CustomGeometry')
        geometry:BeginGeometry(0,TRIANGLE_LIST)
        for i=1,#shape.position,9 do for _,offset in ipairs({0,6,3}) do local j=i+offset
            geometry:DefineVertex(Coord.Vec(shape.position[j],shape.position[j+1],shape.position[j+2]))
            geometry:DefineNormal(Coord.Vec(shape.normal[j],shape.normal[j+1],shape.normal[j+2]))
        end end
        item.material=self.material:Clone()
        geometry:Commit();geometry:SetMaterial(item.material);geometry.castShadows=false
        item.geometry=geometry
    else
        local slots={};Layers(vis.data,slots)
        local localFromWorld=vis.node.worldTransform:Inverse()
        for _,source in ipairs(vis.models) do
            local model=source.model;local list=slots[model.name] or {}
            -- Each geometry retains the source rig pose at restoration. Beam
            -- and hologram slots are omitted, as in source NO_SHADOW_SLOTS.
            local selected={};for i=0,model.numGeometries-1 do if not OMIT[list[i+1]] then selected[#selected+1]=i end end
            if #selected>0 then
                -- Geometry is immutable; share wrappers only while shells live.
                local copy=self:AcquireCopy(model,selected)
                local n=node:CreateChild('Shell');n:SetTransform(localFromWorld*source.node.worldTransform)
                local mesh=n:CreateComponent('StaticModel');mesh.model=copy;mesh.material=self.material;mesh.castShadows=false
                item.models[#item.models+1]=mesh
                item.copies[#item.copies+1]=copy
                item.sources[#item.sources+1]={node=n,source=source}
            end
        end
    end
    self.items[#self.items+1]=item
    self:Activate(item,options)
end
function M:Apply(item)
    local k=math.min(1,math.max(0,(self.time-item.t0)/.34))
    local alpha=1.1*(1-k)^1.5;item.alpha=alpha
    item.node.scale=item.baseScale*(1+.14*(1-(1-k)^3))
    for _,mesh in ipairs(item.models) do mesh.instanceColor=Color(item.color[1],item.color[2],item.color[3],alpha) end
    if item.geometry then
        item.material:SetShaderParameter('joined_alpha',Variant(alpha))
    end
    local current=self.view.visuals[item.id]
    if current==item.vis and item.pop then
        local pop=math.min(1,math.max(0,(self.time-item.t0)/.2))
        current.node.scale=item.baseScale*(1+.07*math.sin(math.pi*pop))
    end
end
function M:Consume(player,view,events)
    if self.disposed then return end
    self:Bind(view)
    local ids={}
    for _,event in ipairs(events) do if event.unit==player then
        if event.type=='unitKilled' or event.type=='unitRemoved' then self:Clear();ids={}
        elseif event.type=='partRestored' then ids[#ids+1]=event.id end
    end end
    if player.alive then
        -- Re-adding an id removes its earlier shell, so keep last-event order.
        local seen,keep={},{}
        for i=#ids,1,-1 do local id=ids[i];if not seen[id] then seen[id]=true;keep[#keep+1]=id end end
        for i=#keep,1,-1 do local part=player.bp.parts[keep[i]];if part then self:Add(part) end end
    end
end
function M:Update(dt)
    if self.disposed or not self.view then return end
    if self.generation~=self.view.visuals then self:Clear();self.generation=self.view.visuals end
    for i=#self.pool,1,-1 do local item=self.pool[i]
        if self.view.visuals[item.id]~=item.vis then self:Destroy(item);table.remove(self.pool,i) end
    end
    self.time=self.time+math.max(0,dt or 0)
    if #self.items==0 then return end
    self.root:SetTransform(self.view.root.worldPosition,self.view.root.worldRotation,self.view.root.worldScale)
    require('render.NodeVisibility').Set(self.root,self.view.root.enabled,true)
    for i=#self.items,1,-1 do local item=self.items[i]
        if self.time-item.t0>=.34 or self.view.visuals[item.id]~=item.vis then self:Drop(item);table.remove(self.items,i)
        else self:Apply(item) end
    end
end
function M:Dispose()
    if self.disposed then return end
    self:Clear();self.disposed=true;self.root:Dispose();self.material:Dispose();self.view=nil;self.generation=nil
end
return M
