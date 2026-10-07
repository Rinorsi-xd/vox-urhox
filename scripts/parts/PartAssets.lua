local Data=require "core.ResourceData"
local Mounts=require "parts.Mounts"
local M={}
local rigs=setmetatable({},{__mode="v"})
local swept=setmetatable({},{__mode='k'})
local rotating={spinSteel=true,spinGlow=true,holoPaint=true}
M.HoverInfo=Mounts.HoverInfo
function M.Key(type,rotation)
    if type=="thruster" then type="thrusterUp2" end
    local info=M.HoverInfo(type,rotation)
    return info and info.mount=="side" and type.."Side" or type
end
function M.Get(type,rotation)
    local key=M.Key(type,rotation)
    local data=rigs[key]
    if not data then data=Data.Read("Parts/Rigs/"..key..".json");rigs[key]=data end
    return data
end
-- Shader rotation must remain inside the CPU culling/shadow bounds. Enlarge
-- the shared model once, before attaching it; geometry and collision stay exact.
function M.Model(layer)
    local model=assert(cache:GetResource('Model',layer.model),layer.model)
    local prepared=swept[model]
    if not prepared or model.boundingBox~=prepared then
        for _,slot in ipairs(layer.slots) do if rotating[slot] then
            local box=model.boundingBox;local lo,hi=box.min,box.max
            local x=math.max(math.abs(lo.x),math.abs(hi.x));local z=math.max(math.abs(lo.z),math.abs(hi.z))
            local radius=math.sqrt(x*x+z*z)
            local bounds=BoundingBox(Vector3(-radius,lo.y,-radius),Vector3(radius,hi.y,radius))
            model:SetBoundingBox(bounds);swept[model]=BoundingBox(bounds);break
        end end
    end
    return model
end
-- Other cars sharing the resource must remain valid.
function M.Release(models)
    local names={}
    for _,name in ipairs(models) do names[name]=true end
    for name in pairs(names) do cache:ReleaseResource("Model",name,false) end
end
return M
