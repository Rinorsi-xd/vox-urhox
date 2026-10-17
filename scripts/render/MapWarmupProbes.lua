-- Only measured missing ordinary Scatter variants; preserve each native layout/material/state.
local Signature=require('render.WarmupSignature')
local M={}
local scatter='Shaders/BLGL/Crater/Scatter.shader'
local function Candidate(group,layouts)
    local source=group.items[1].drawable
    local model=source.model
    if not model then return nil,nil,'missing-model' end
    for slot=0,model.numGeometries-1 do
        local material=source:GetMaterial(slot)
        local shader=material and material:GetSurfaceShader()
        if not shader or shader.name~=scatter then return nil,nil,'not-measured-scatter' end
    end
    return Signature.GroupProbeCandidate(group,layouts)
end
function M.Collect(groups)
    local probes,keyed,layouts={},{},{}
    local stats={sources=0,probes=0,rejected=0,errors=0}
    for _,group in ipairs(groups) do if group.kind=='StaticModelGroup' then
        stats.sources=stats.sources+1
        local ok,key,singles,reason=pcall(Candidate,group,layouts)
        if not ok then
            stats.errors=stats.errors+1
            stats.firstError=stats.firstError or tostring(key):gsub('[\r\n]',' '):sub(1,160)
        elseif not key then
            stats.rejected=stats.rejected+1;stats.firstReject=stats.firstReject or reason
        elseif not keyed[key] then
            local probe={key='map-probe|'..key,kind='StaticModel',items={group.items[1]},
                singleKeys=singles,singleVolumeOnly=true}
            keyed[key]=probe;probes[#probes+1]=probe
        end
    end end
    table.sort(probes,function(a,b)return a.key<b.key end)
    stats.probes=#probes
    return probes,stats
end
return M
