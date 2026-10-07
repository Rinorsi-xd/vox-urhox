-- Source xray affects instanced structural batches only; machinery stays solid.
-- Two materials per enabled vehicle, never per part. Originals stay referenced.
local Materials=require 'parts.Materials'
local Config=require 'Config'
local M={};M.__index=M
M.paintSlots={paint=true,heavyPaint=true,glassPaint=true,neonPaint=true,framePaint=true}
function M.New()
    local self=setmetatable({},M)
    self.paint=Materials.New('BuildXray.shader');self.other=Materials.New('BuildXray.shader')
    self.paint:SetShaderParameter('tint_color',Variant(Color(1,1,1,.12)))
    self.other:SetShaderParameter('tint_color',Variant(Config.HexLinear(0x445066,.08)))
    self.other:SetShaderParameter('use_instance_color',Variant(0.0))
    self.other:SetShaderParameter('roughness_value',Variant(1.0))
    return self
end
function M:Attach(vis)
    if not vis.instanced or vis.xrayOriginals then return end
    vis.xrayOriginals={}
    for _,model in ipairs(vis.models) do
        local original={shadow=model.castShadows,materials={}}
        for i,slot in ipairs(vis.materialSlots[model]) do
            original.materials[i]=model:GetMaterial(i-1)
            model:SetMaterial(i-1,self.paintSlots[slot] and self.paint or self.other)
        end
        vis.xrayOriginals[model]=original;model.castShadows=false
    end
end
function M.Restore(vis)
    for model,original in pairs(vis.xrayOriginals or {}) do
        for i,material in ipairs(original.materials) do model:SetMaterial(i-1,material) end
        model.castShadows=original.shadow
    end
    vis.xrayOriginals=nil
end
function M.SetBase(vis,model,index,material)
    local original=vis.xrayOriginals and vis.xrayOriginals[model]
    if original then original.materials[index+1]=material else model:SetMaterial(index,material) end
end
function M:Dispose()
    self.paint:Dispose();self.other:Dispose();self.paint=nil;self.other=nil
end
return M
