-- Imported source geometry/materials; shared by authoring and runtime dynamics.
local Data=require("core.ResourceData").Read("Track/Manifest.json")
local M={data=Data}
function M.MakeMaterials()
    local materials={}
    for i,d in ipairs(Data.materials) do
        local m=Material:new()
        assert(m:SetSurfaceShader("Shaders/BLGL/Track/"..(d.alpha and "Mark" or "Surface")..".shader"))
        -- Shader vec4 parameters must serialize as Vector4, not Variant(Color).
        m:SetShaderParameter("tint",Variant(Vector4(d.color[1],d.color[2],d.color[3],d.opacity)))
        m:SetShaderParameter("roughness_value",Variant(d.rough));m:SetShaderParameter("metallic_value",Variant(d.metal))
        m:SetShaderParameter("emission_strength",Variant(d.emission));m:SetShaderParameter("normal_strength",Variant(d.normalScale))
        for key,sampler in pairs({map="albedo_map",normal="normal_map",roughMap="rough_map"}) do
            local t=d[key]
            if type(t)=="table" then
                m:SetSurfaceTexture(sampler,assert(cache:GetResource("Texture2D",t.path)))
                m:SetShaderParameter(key=="map" and "albedo_repeat" or "detail_repeat",Variant(Vector2(table.unpack(t["repeat"]))))
            end
        end
        if d.order>0 then m.depthBias=BiasParameters(-.00001*d.order, -1) end
        m.renderOrder=128+d.order
        materials[i]=m
    end
    return materials
end
function M.Attach(node,items)
    local models={}
    for _,d in ipairs(items) do
        local model=node:CreateComponent("StaticModel")
        model.model=assert(cache:GetResource("Model",d.model),d.model)
        model.material=assert(cache:GetResource("Material","Track/material-"..d.material..".xml"))
        model.castShadows=d.shadow
        models[#models+1]=model
    end
    return models
end
function M.Release()
    for _,list in ipairs({Data.statics,Data.cones,Data.targetBase,Data.targetBoard}) do
        for _,d in ipairs(list) do cache:ReleaseResource("Model",d.model) end
    end
    for i,d in ipairs(Data.materials) do
        cache:ReleaseResource("Material","Track/material-"..i..".xml")
        for _,key in ipairs({"map","normal","roughMap"}) do
            local t=d[key];if type(t)=="table" then cache:ReleaseResource("Texture2D",t.path) end
        end
    end
end
return M
