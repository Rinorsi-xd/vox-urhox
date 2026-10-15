-- Immutable shell variants retain every property of the exact base material.
-- Repaint replaces a lease; it never changes a material another part owns.
local Materials=require 'parts.Materials'
local Config=require 'Config'
local Xray=require 'render.BuildXray'
local M={}
local pools={}
local function Acquire(base,hex)
    local colors=pools[base]
    local lease=colors and colors[hex]
    if lease then lease.refs=lease.refs+1;return lease end
    local color=Config.HexLinear(hex)
    local material=base:Clone()
    local ok,err=pcall(material.SetShaderParameter,material,'base_color',Variant(color))
    if not ok then material:Dispose();error(err) end
    lease={base=base,color=hex,material=material,refs=1}
    if not colors then colors={};pools[base]=colors end
    colors[hex]=lease;return lease
end
local function Release(lease)
    assert(lease.refs>0,'Shell material lease already released')
    lease.refs=lease.refs-1
    if lease.refs>0 then return end
    local colors=pools[lease.base];colors[lease.color]=nil
    if next(colors)==nil then pools[lease.base]=nil end
    lease.material:Dispose()
end
function M.Release(vis)
    local lease,material=vis.shellLease,vis.shellMaterial
    vis.shellLease=nil;vis.shellMaterial=nil
    if lease then Release(lease)
    elseif material then material:Dispose() end -- Existing visuals from a script reload.
end
function M.Apply(vis,hex)
    local base=Materials.Get('armorWhite')
    local previous=vis.shellLease
    if previous and previous.base==base and previous.color==hex then return end
    if not previous and not vis.shellMaterial and hex==nil then return end
    local lease=hex~=nil and Acquire(base,hex) or nil
    local material=lease and lease.material or base
    local oldMaterial=vis.shellMaterial or base
    local ok,err=pcall(function()
        for _,slot in ipairs(vis.shellSlots) do Xray.SetBase(vis,slot.model,slot.index,material) end
    end)
    if not ok then
        for _,slot in ipairs(vis.shellSlots) do pcall(Xray.SetBase,vis,slot.model,slot.index,oldMaterial) end
        if lease then Release(lease) end
        error(err)
    end
    M.Release(vis)
    vis.shellLease=lease;vis.shellMaterial=lease and material or nil
end
return M
