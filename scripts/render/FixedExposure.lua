-- Fixed linear exposure through the runtime's serialized Zone attributes.
-- Lua numbers become Double Variants; these attributes explicitly require Float.
local M={}
function M.Apply(zone,exposure)
    zone:SetAttribute('Auto Exposure Enable',Variant(true))
    zone:SetAttribute('Auto Exposure Plus Enable',Variant(true))
    zone:SetAttribute('Auto Exposure Extended Luminance Range',Variant(false))
    zone:SetAttribute('Auto Exposure Force Target',Variant(true))
    for name,value in pairs({['Auto Exposure Min Brightness']=1,['Auto Exposure Max Brightness']=1,
        ['Auto Exposure Bias']=math.log(exposure,2),['Auto Exposure Curve Bias']=0}) do
        assert(zone:SetAttribute(name,Variant(VAR_FLOAT,tostring(value))),'Unsupported exposure attribute: '..name)
    end
end
return M
