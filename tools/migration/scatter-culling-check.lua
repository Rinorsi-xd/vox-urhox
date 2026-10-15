local checks=0
local function Check(ok,message)checks=checks+1;assert(ok,message)end
local function Node(id,matrix)
    local node={ID=id,worldTransform=matrix,worldPosition={x=matrix.m03,y=matrix.m13,z=matrix.m23},children={}}
    function node:CreateChild()
        local child=Node(id+100000+#self.children,matrix);self.children[#self.children+1]=child;return child
    end
    function node:Dispose()self.disposed=true end
    function node:CreateComponent()
        local group={node=self,instances={},numInstanceNodes=0,materials={},numGeometries=1}
        function group:SetMaterial(index,material)self.materials[index+1]=material end
        function group:GetMaterial(index)return self.materials[index+1]end
        function group:AddInstanceNode(instance)self.instances[#self.instances+1]=instance;self.numInstanceNodes=#self.instances end
        function group:GetInstanceNode(index)return self.instances[index+1]end
        return group
    end
    return node
end
local model={name='Crater/mesh-293.bin'};local material={name='OriginalMaterial'};local groups={}
for _,fixture in ipairs(SCATTER_FIXTURE)do
    local node=Node(fixture.id,fixture.matrix);local group=node:CreateComponent();group.ID=fixture.id
    group.enabled=true;group.model=model;group:SetMaterial(0,material)
    for i,key in ipairs(SCATTER_CORE.fields)do group[key]=key=='castShadows'and true or i end
    group.drawDistance=220
    for _,instance in ipairs(fixture.instances)do group:AddInstanceNode(Node(instance.id,instance.matrix))end
    groups[#groups+1]=group
end
local records,count=SCATTER_CORE.Snapshot(groups,model.name)
Check(#records==36 and count==4160,'actual source hotspot 36 groups / 4160 instances')
local variants={}
for _,size in ipairs({32,64})do
    local name=tostring(size);variants[name]=SCATTER_CORE.Build(records,size)
    Check(SCATTER_CORE.Validate(records,variants[name])==4160,'all identity/affine/resource/properties preserved '..name)
    for _,item in ipairs(variants[name].groups)do
        local expected=item.cell
        for _,instance in ipairs(item.instances)do
            local p=instance.node.worldPosition
            Check(math.floor(p.x/size)..':'..math.floor(p.z/size)==expected,'instance assigned to deterministic world cell')
        end
    end
end
for _,name in ipairs({'original','32','64'})do
    SCATTER_CORE.Select(records,variants,name,false)
    for _,record in ipairs(records)do Check(record.group.enabled==(name=='original'),'exact source switch')end
    for key,variant in pairs(variants)do for _,item in ipairs(variant.groups)do
        Check(item.group.enabled==(name==key),'exact candidate switch')
        Check(item.group.drawDistance==item.record.fields.drawDistance,'visibility distance retained')
    end end
end
local variant=variants['32'];local instance=records[1].instances[1]
instance.node.worldTransform.m00=instance.node.worldTransform.m00+1
Check(not pcall(SCATTER_CORE.Validate,records,variant),'transform mutation is rejected')
instance.node.worldTransform.m00=instance.node.worldTransform.m00-1
local group=variant.groups[1].group;local originalDistance=group.drawDistance;group.drawDistance=10
Check(not pcall(SCATTER_CORE.Validate,records,variant),'visibility-distance reduction is rejected');group.drawDistance=originalDistance
local original=group.instances[1];group.instances[1]=group.instances[2]or records[2].instances[1].node
Check(not pcall(SCATTER_CORE.Validate,records,variant),'duplicate or replaced instance is rejected');group.instances[1]=original
SCATTER_CORE.Select(records,variants,'32',true)
Check(group.drawDistance==0,'unlimited range is an explicit diagnostic only')
SCATTER_CORE.Select(records,variants,'original',false)
Check(SCATTER_CORE.Validate(records,variant)==4160,'diagnostic range is restored before validation')
local boundaries={instances={}}
for _,x in ipairs({-32,-.001,0,31.999,32})do boundaries.instances[#boundaries.instances+1]={position={x=x,z=0}}end
Check(#SCATTER_CORE.Partition(boundaries,32)==3,'negative and boundary positions use floor cells')
local group32,group64=#variants['32'].groups,#variants['64'].groups
SCATTER_CORE.Restore(records,variants)
for _,record in ipairs(records)do Check(record.group.enabled and record.group.drawDistance==220,'original state restored')end
for _,candidate in pairs(variants)do for _,node in ipairs(candidate.roots)do Check(node.disposed,'candidate nodes released')end end
return{assertions=checks,instances=count,groupsOriginal=#records,groups32=group32,groups64=group64}
