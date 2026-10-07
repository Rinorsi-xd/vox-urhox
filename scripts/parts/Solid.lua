-- Source-generated 4x4x4 occupancy masks, exactly 64 bits (hex avoids JSON rounding).
-- Cube cell: [-.5,.5]^3, samples at -.375,-.125,.125,.375.
-- Purpose: complementary slopes may share a cell; swept tires cannot intersect armor.
-- Full cells have no mask; a zero mask is empty and must NOT become a full cell.
local Data=require "core.ResourceData"
local masks=Data.Read("Parts/SolidMasks.json")
local M={}
function M.Map(type,position,rotation)
    local result={}
    for _,m in ipairs(masks[type] and masks[type][rotation+1] or {}) do
        local c=m.c
        local key=(position[1]+c[1])..","..(position[2]+c[2])..","..(position[3]+c[3])
        result[key]=assert(tonumber(m.mask,16))
    end
    return result
end
function M.Overlap(a,b) return a==nil or b==nil or (a & b)~=0 end
return M
