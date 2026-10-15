-- Clone per scene so runtime uniforms never modify authored material resources.
local M={}
function M.Set(material,key,value) material:SetShaderParameter(key,Variant(value)) end
local staticShaders={Decal=true,Deck=true,Glass=true,Guide=true,Sign=true}
local function UsesTime(material)
    local shader=material:GetSurfaceShader()
    local name=shader and shader.name:match('^Shaders/BLGL/Hangar/(.+)%.shader$')
    if name=='Surface' then
        return material:GetShaderParameter('uPulse'):GetFloat()~=0 or material:GetShaderParameter('uBlink'):GetFloat()~=0
    end
    if name=='Glow' then return material:GetShaderParameter('blink_rate'):GetFloat()>0 end
    -- Unknown shaders retain the old update behavior until their time dependency is audited.
    return not staticShaders[name]
end
function M.Bind(root)
    local clones,list,animated={},{},{}
    local function clone(source)
        assert(source,"Missing authored hangar material")
        if not clones[source] then
            clones[source]=source:Clone()
            list[#list+1]=clones[source]
            if UsesTime(clones[source]) then animated[#animated+1]=clones[source] end
        end
        return clones[source]
    end
    for _,sm in ipairs(root:GetComponents("StaticModel",true)) do
        for i=0,sm.numGeometries-1 do sm:SetMaterial(i,clone(sm:GetMaterial(i))) end
    end
    for _,cg in ipairs(root:GetComponents("CustomGeometry",true)) do cg:SetMaterial(clone(cg:GetMaterial())) end
    return list,animated
end
function M.Update(materials,time)
    if materials.lastTime==time then return end
    local value=Variant(time)
    for _,material in ipairs(materials) do material:SetShaderParameter("hangar_time",value) end
    materials.lastTime=time
end
return M
