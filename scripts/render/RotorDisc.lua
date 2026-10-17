-- H5 applies local X reflection after the disc's authored yaw, including rebinds.
local Rotors=require 'construction.Rotors'
local Defs=require('parts.Defs').PARTS
local M={}
function M.Update(vis,angle,sign)
    vis.rotorAngle=angle;vis.rotorSign=sign
    vis.head.rotation=Quaternion(-(angle*sign+(vis.rotorOffset or 0))*180/math.pi,Vector3.UP)
end
function M.Bind(vis,part)
    local def=Defs[part.type]
    if not vis.head or not def or not def.rotor then return end
    vis.rotorOffset=def.rotor=='aim' and Rotors.AimOffset(part) or 0
    local sign=part.pos[1]<0 and -1 or 1
    vis.head.scale=Vector3(sign,1,1)
    M.Update(vis,vis.rotorAngle or 0,sign)
end
return M
