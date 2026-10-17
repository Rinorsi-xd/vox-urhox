-- Loading-only shader representatives. Unknown native layouts keep their old group.
local M={}
local stateKeys={'viewMask','lightMask','shadowMask','zoneMask','castShadows','maxLights',
    'useInstanceColor','useInstanceCustomData','drawDistance','shadowDistance','lodBias',
    'occluder','occludee','occlusionLodLevel'}
local function Layout(model)
    if model.numMorphs~=0 or not model.skeleton or model.skeleton.numBones~=0
        or not model.numGeometries or model.numGeometries<1 then return nil,'morph-bones-or-geometry-count' end
    local key={tostring(model.numGeometries)}
    for slot=0,model.numGeometries-1 do
        if model:GetNumGeometryLodLevels(slot)~=1 then return nil,'geometry-lod' end
        local geometry=model:GetGeometry(slot,0)
        if not geometry or geometry.empty~=false or geometry.primitiveType==nil
            or not geometry.numVertexBuffers or geometry.numVertexBuffers<1 then return nil,'geometry-layout' end
        key[#key+1]=tostring(geometry.primitiveType)
        key[#key+1]=tostring(geometry.numVertexBuffers)
        for stream=0,geometry.numVertexBuffers-1 do
            local buffer=geometry:GetVertexBuffer(stream)
            if not buffer or not buffer.vertexSize or buffer.vertexSize<1 then return nil,'vertex-buffer' end
            local elements=buffer:GetElements()
            if type(elements)~='table' or #elements<1 then return nil,'vertex-elements-not-table' end
            for index in pairs(elements) do
                if type(index)~='number' or index%1~=0 or index<1 or index>#elements then return nil,'non-array-elements' end
            end
            key[#key+1]=tostring(buffer.vertexSize)
            key[#key+1]=tostring(#elements)
            for elementIndex=1,#elements do
                local element=elements[elementIndex]
                if not element then return nil,'sparse-elements' end
                for _,field in ipairs({'type','semantic','index','perInstance','offset'}) do
                    local value=element[field]
                    if value==nil then return nil,'unknown-element-'..field end
                    key[#key+1]=tostring(value)
                end
                -- User instance streams, skinning and morphing need native selection evidence.
                if element.perInstance then return nil,'user-instance-stream' end
            end
        end
    end
    return table.concat(key,':')
end
local function Candidate(group,layouts,allowGroup)
    if group.kind~='StaticModel' and not (allowGroup and group.kind=='StaticModelGroup') then return nil,nil,'kind-'..group.kind end
    local drawable=group.items[1].drawable
    local model=drawable.model
    if not model then return nil,nil,'missing-model' end
    if not drawable.zone then return nil,nil,'missing-zone' end
    if drawable.outlineEnabled~=false then return nil,nil,'outline-'..tostring(drawable.outlineEnabled) end
    local cached=layouts[model]
    if not cached then
        local layout,reason=Layout(model)
        cached={layout=layout,reason=reason};layouts[model]=cached
    end
    if not cached.layout then return nil,nil,cached.reason end
    local layout=cached.layout
    local key={'shader-layout',layout,tostring(drawable.zone)}
    for _,name in ipairs(stateKeys) do
        local value=drawable[name]
        if value==nil then return nil,nil,'unknown-state-'..name end
        key[#key+1]=tostring(value)
    end
    local singles={}
    for slot=0,model.numGeometries-1 do
        local material=drawable:GetMaterial(slot)
        if not material then return nil,nil,'missing-material' end
        -- Ordinary materials can choose another technique by distance/quality.
        if not material:GetSurfaceShader() and material:GetNumTechniques()~=1 then return nil,nil,'material-technique-lod' end
        -- Same actual material retains every surface/technique/pass/define/texture choice.
        key[#key+1]=tostring(material)
        singles[#singles+1]=tostring(model:GetGeometry(slot,0))..'|'..tostring(material)
    end
    return table.concat(key,'|'),singles
end
function M.GroupProbeCandidate(group,layouts)
    if group.kind~='StaticModelGroup' then return nil,nil,'kind-'..group.kind end
    return Candidate(group,layouts or {},true)
end
function M.Compact(groups)
    local result,keyed,layouts={},{},{}
    local stats={eligible=0,rejected=0,errors=0}
    for _,group in ipairs(groups) do
        local ok,key,singles,reason=pcall(Candidate,group,layouts)
        if not ok or not key then
            result[#result+1]=group
            if not ok then
                stats.errors=stats.errors+1
                stats.firstError=stats.firstError or tostring(key):gsub('[\r\n]',' '):sub(1,160)
            else
                stats.rejected=stats.rejected+1;stats.firstReject=stats.firstReject or reason
            end
        else
            stats.eligible=stats.eligible+1
            local existing=keyed[key]
            if not existing then
                existing={key=key,kind=group.kind,items=group.items,singleKeys=singles}
                keyed[key]=existing;result[#result+1]=existing
            elseif #group.items>#existing.items then
                -- Keep one original same-model atom, never combine different models as instances.
                existing.items=group.items;existing.singleKeys=singles
            end
        end
    end
    table.sort(result,function(a,b)return a.key<b.key end)
    return result,stats
end
function M.CanAppend(group,used,count)
    if count==0 then return true end
    if not group.singleKeys then return not used.known end
    if used.unknown then return false end
    for _,key in ipairs(group.singleKeys) do if used[key] then return false end end
    return true
end
function M.Mark(group,used)
    if not group.singleKeys then used.unknown=true
    else
        used.known=true
        for _,key in ipairs(group.singleKeys) do used[key]=true end
    end
end
return M
