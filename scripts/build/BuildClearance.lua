-- Source activity envelopes in blueprint cells. These are separate from solid
-- masks: [mount][turret sweep] rejects body cells in either placement order;
-- weapon/weapon and leg/leg may share sweeps. Ignored selection IDs never block.
-- Exhaust and hover reach are warnings only, never physical collision shapes.
local Defs=require('parts.Defs').PARTS
local Rot=require 'core.Rotations'
local zones=require('core.ResourceData').Read('Parts/BuildRules.json').zones
local M={}
function M.SameKind(a,b) return a.weapon and b.weapon or a.leg and b.leg end
function M.Name(def) return def.clearKind=='leg' and '摆动范围' or '转动范围' end
function M.Cells(type,pos,rot)
    local cells=Defs[type].clear;if not cells then return nil end
    local out={}
    for i,c in ipairs(cells) do local r=Rot.ApplyRot(rot,c);out[i]={pos[1]+r[1],pos[2]+r[2],pos[3]+r[3]} end
    return out
end
function M.Blockers(bp,def,cells,index,ignore)
    local ids,seen={},{}
    for _,c in ipairs(cells or {}) do for _,id in ipairs(index[bp.Key(table.unpack(c))] or {}) do
        if not seen[id] and not (ignore and ignore[id]) and not M.SameKind(def,Defs[bp.parts[id].type]) then
            seen[id]=true;ids[#ids+1]=id
        end
    end end
    return ids
end
function M.Conflict(bp,type,pos,rot,cells,ignore)
    local def=Defs[type]
    local ids=M.Blockers(bp,def,M.Cells(type,pos,rot),bp.cellIds,ignore)
    if #ids>0 then return {reason=M.Name(def)..'里有 '..#ids..' 个零件，'..(def.leg and '腿摆不过去' or '转不过去'),ids=ids} end
    ids=M.Blockers(bp,def,cells,bp.clearIds,ignore)
    if #ids>0 then local owner=Defs[bp.parts[ids[1]].type];return {reason='会挡住'..owner.name..'的'..M.Name(owner),ids=ids} end
end
function M.Diagnostics(bp,parts,push)
    for _,p in ipairs(parts) do
        local def=Defs[p.type];local ids=M.Blockers(bp,def,p._clear,bp.cellIds)
        if #ids>0 then
            push('error',def.name..'的'..M.Name(def)..'里有 '..#ids..' 个零件（'..(def.leg and '腿摆过去会穿进去' or '炮管会穿进去')..'），请挪开',{p.id,table.unpack(ids)})
        end
    end
    for _,p in ipairs(parts) do
        local variants=zones[p.type=='thruster' and 'thrusterUp2' or p.type]
        local zone=variants and variants[p.rot+1]
        if zone then
            local ids,seen={},{}
            for _,c in ipairs(zone.cells or {}) do
                local key=bp.Key(c[1]+p.pos[1],c[2]+p.pos[2],c[3]+p.pos[3])
                for _,id in ipairs(bp.cellIds[key] or {}) do if id~=p.id and not seen[id] then seen[id]=true;ids[#ids+1]=id end end
            end
            if #ids>0 then
                local name=Defs[p.type].name
                push('warn',zone.kind=='exhaust' and (name..'的尾焰范围要留空：有 '..#ids..' 个零件挡在尾焰里') or
                    (name..'正下方悬浮高度内有 '..#ids..' 个零件，悬浮时会先擦地'),{p.id,table.unpack(ids)})
            end
        end
    end
end
return M
