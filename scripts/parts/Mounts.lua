-- Placement metadata only. Build rules must not depend on model cache ownership.
local Rot=require 'core.Rotations'
local variants=require('core.ResourceData').Read('Parts/HoverMounts.json')
local rules=require('core.ResourceData').Read('Parts/BuildRules.json')
local M={}
M.RetiredWheels={}
for _,name in ipairs(rules.retiredWheels) do M.RetiredWheels[name]=true end
function M.LegStance(type,pos,rotation)
    local cells=rules.legStances[type];if not cells then return nil end
    local result={}
    for i,c in ipairs(cells) do local p=Rot.ApplyRot(rotation,c);result[i]={p[1]+pos[1],p[2]+pos[2],p[3]+pos[3]} end
    return result
end
function M.HoverInfo(type,rotation)
    local mounts=variants[type]
    if not mounts then return nil end
    return mounts[(rotation==nil or Rot.ROTATIONS[rotation].up[2]<0) and 'bottom' or 'side']
end
return M
