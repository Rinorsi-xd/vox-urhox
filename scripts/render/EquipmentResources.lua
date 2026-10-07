-- Lazily acquired shared volume materials and the original approved Mivo flow.
-- Refcounts span player/target vehicles; last owner releases GPU resource refs.
local M={users=0,materials={}}
local DIR='Shaders/BLGL/Equipment/'
function M.Acquire() M.users=M.users+1;return M end
function M.Flow()
    if not M.flow then M.flow=assert(cache:GetResource('Texture2D','Equipment/plasma-flow.png')) end
    return M.flow
end
function M.Material(kind)
    if not M.materials[kind] then
        local material=Material:new();assert(material:SetSurfaceShader(DIR..kind..'.shader'))
        material:SetSurfaceTexture('flow_map',M.Flow());material.renderOrder=141;M.materials[kind]=material
    end
    return M.materials[kind]
end
function M.Box()
    if not M.box then M.box=assert(cache:GetResource('Model','Models/Box.mdl')) end
    return M.box
end
function M.Clock(time)
    for _,material in pairs(M.materials) do material:SetShaderParameter('clock',Variant(time)) end
end
function M.Release()
    M.users=M.users-1;assert(M.users>=0,'equipment resource ownership underflow')
    if M.users~=0 then return end
    for _,material in pairs(M.materials) do material:Dispose() end
    M.materials={};M.box=nil;M.flow=nil;cache:ReleaseResource('Texture2D','Equipment/plasma-flow.png',false)
end
return M
