-- QA only: share original instance nodes and resources; never reparent geometry.
local M={}
M.fields={'drawDistance','shadowDistance','lodBias','viewMask','lightMask','shadowMask','zoneMask','maxLights',
    'castShadows','occluder','occludee','occlusionLodLevel','useInstanceColor','instanceColor','useInstanceCustomData','instanceCustomData'}
local axes={'m00','m01','m02','m03','m10','m11','m12','m13','m20','m21','m22','m23'}
local function Matrix(node)
    local value=node.worldTransform;local out={}
    for i,key in ipairs(axes)do out[i]=value[key]end
    return out
end
local function SameMatrix(node,value)
    local actual=Matrix(node)
    for i,v in ipairs(value)do assert(math.abs(actual[i]-v)<.00001,'Instance world transform changed')end
end
local function CopyFields(group,fields)
    for _,key in ipairs(M.fields)do group[key]=fields[key]end
    -- Native color/custom setters enable their flags; restore source flags last.
    group.useInstanceColor=fields.useInstanceColor
    group.useInstanceCustomData=fields.useInstanceCustomData
end
function M.Snapshot(groups,path)
    local records={};local count=0;local ids={}
    for _,group in ipairs(groups)do if group.model and group.model.name==path then
        local record={group=group,id=group.ID,node=group.node,nodeMatrix=Matrix(group.node),enabled=group.enabled,
            model=group.model,materials={},fields={},instances={}}
        for _,key in ipairs(M.fields)do record.fields[key]=group[key]end
        for i=1,group.numGeometries do record.materials[i]=assert(group:GetMaterial(i-1),'Missing source material')end
        for i=1,group.numInstanceNodes do
            local node=assert(group:GetInstanceNode(i-1),'Missing registered instance')
            assert(not ids[node.ID],'Duplicate source instance');ids[node.ID]=true
            record.instances[i]={node=node,id=node.ID,matrix=Matrix(node),position=node.worldPosition}
            count=count+1
        end
        records[#records+1]=record
    end end
    assert(#records>0 and count>0,'Target scatter model absent')
    return records,count
end
function M.Partition(record,size)
    assert(size>0,'Invalid cell size');local cells={};local keys={}
    for _,instance in ipairs(record.instances)do
        local p=instance.position;local key=math.floor(p.x/size)..':'..math.floor(p.z/size)
        if not cells[key]then cells[key]={};keys[#keys+1]=key end
        local bucket=cells[key];bucket[#bucket+1]=instance
    end
    table.sort(keys);local ordered={}
    for _,key in ipairs(keys)do ordered[#ordered+1]={key=key,instances=cells[key]}end
    return ordered
end
function M.Build(records,size)
    local variant={size=size,groups={},roots={}}
    for _,record in ipairs(records)do
        local root=record.node:CreateChild('QA_Scatter_'..size);variant.roots[#variant.roots+1]=root
        -- Identity child inherits the complete parent affine transform, including shear.
        SameMatrix(root,record.nodeMatrix)
        for _,cell in ipairs(M.Partition(record,size))do
            local node=root:CreateChild(cell.key);local group=node:CreateComponent('StaticModelGroup')
            group.enabled=false;group.model=record.model
            for i,material in ipairs(record.materials)do group:SetMaterial(i-1,material)end
            CopyFields(group,record.fields)
            for _,instance in ipairs(cell.instances)do group:AddInstanceNode(instance.node)end
            variant.groups[#variant.groups+1]={group=group,record=record,cell=cell.key,instances=cell.instances}
        end
    end
    return variant
end
function M.Validate(records,variant)
    local expected,seen={},{};local expectedCount=0;local actualCount=0
    for _,record in ipairs(records)do
        SameMatrix(record.node,record.nodeMatrix)
        for _,instance in ipairs(record.instances)do
            SameMatrix(instance.node,instance.matrix);assert(instance.node.ID==instance.id,'Instance identity changed')
            expected[instance.id]=instance;expectedCount=expectedCount+1
        end
    end
    for _,item in ipairs(variant.groups)do
        local group,record=item.group,item.record
        assert(group.model==record.model,'Model resource changed');SameMatrix(group.node,record.nodeMatrix)
        for _,key in ipairs(M.fields)do assert(group[key]==record.fields[key],'Drawable property changed '..key)end
        assert(group.numGeometries==#record.materials,'Geometry slots changed')
        for i,material in ipairs(record.materials)do assert(group:GetMaterial(i-1)==material,'Material resource changed')end
        assert(group.numInstanceNodes==#item.instances,'Registration count changed')
        for i=1,group.numInstanceNodes do
            local node=group:GetInstanceNode(i-1);local original=assert(expected[node.ID],'Unexpected instance')
            assert(node==original.node and not seen[node.ID],'Instance replaced or duplicated')
            SameMatrix(node,original.matrix);seen[node.ID]=true;actualCount=actualCount+1
        end
    end
    assert(actualCount==expectedCount,'Instance coverage changed')
    return actualCount
end
function M.Select(records,variants,selected,unlimited)
    for _,record in ipairs(records)do
        record.group.enabled=selected=='original'and record.enabled or false
        record.group.drawDistance=unlimited and 0 or record.fields.drawDistance
    end
    for name,variant in pairs(variants)do for _,item in ipairs(variant.groups)do
        item.group.enabled=selected==name and item.record.enabled or false
        item.group.drawDistance=unlimited and 0 or item.record.fields.drawDistance
    end end
end
function M.Restore(records,variants)
    for _,variant in pairs(variants)do for _,node in ipairs(variant.roots)do node:Dispose()end end
    for _,record in ipairs(records)do
        record.group.enabled=record.enabled
        CopyFields(record.group,record.fields)
        SameMatrix(record.node,record.nodeMatrix)
        for _,instance in ipairs(record.instances)do SameMatrix(instance.node,instance.matrix)end
    end
end
M.Matrix=Matrix
return M
