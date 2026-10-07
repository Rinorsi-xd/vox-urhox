-- Clone per scene so runtime uniforms never modify authored material resources.
local M={}
function M.Set(material,key,value) material:SetShaderParameter(key,Variant(value)) end
function M.Bind(root)
    local clones,list={},{}
    local function clone(source)
        assert(source,"Missing authored hangar material")
        if not clones[source] then
            clones[source]=source:Clone()
            list[#list+1]=clones[source]
        end
        return clones[source]
    end
    for _,sm in ipairs(root:GetComponents("StaticModel",true)) do
        for i=0,sm.numGeometries-1 do sm:SetMaterial(i,clone(sm:GetMaterial(i))) end
    end
    for _,cg in ipairs(root:GetComponents("CustomGeometry",true)) do cg:SetMaterial(clone(cg:GetMaterial())) end
    return list
end
function M.Update(materials,time)
    for _,material in ipairs(materials) do M.Set(material,"hangar_time",time) end
end
return M
