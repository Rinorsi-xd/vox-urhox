-- Source-compatible legacy replacements. Preserve existing authored structure;
-- upgraded hovers reserve remaining space only after every non-hover row loads.
local Defs=require 'parts.Defs'
local Rot=require 'core.Rotations'
local Mounts=require 'parts.Mounts'
local M={}
function M.Load(bp,data)
    bp:Clear();bp.name=data.name and data.name~='' and data.name or '未命名战车'
    bp.dropped=0;bp.migrationWarnings={}
    local ordered,oldWheels={},{};local migratedHovers,droppedHovers=0,0
    for _,row in ipairs(data.parts or {}) do if row[1]~='hover' then ordered[#ordered+1]=row end end
    for _,row in ipairs(data.parts or {}) do if row[1]=='hover' then ordered[#ordered+1]=row end end
    for _,row in ipairs(ordered) do
        local legacyWheel=Mounts.RetiredWheels[row[1]];local legacyHover=row[1]=='hover'
        local type=Defs.RETIRED_TYPES[row[1]] or row[1];local pos={row[2],row[3],row[4]};local rot=row[5]
        if not Defs.PARTS[type] or not Rot.ROTATIONS[rot] then bp.dropped=bp.dropped+1
        elseif (legacyWheel or legacyHover) and bp:Overlaps(type,pos,rot) then
            bp.dropped=bp.dropped+1;if legacyHover then droppedHovers=droppedHovers+1 end
        else
            local p=bp:Add({type=type,pos=pos,rot=rot,color=row[6],shellColor=row[7]})
            if legacyWheel then oldWheels[#oldWheels+1]=p end
            if legacyHover then migratedHovers=migratedHovers+1 end
        end
    end
    if migratedHovers>0 then bp.migrationWarnings[#bp.migrationWarnings+1]=migratedHovers..' 个旧悬浮器已换成 T2（3×2 格）' end
    if droppedHovers>0 then bp.migrationWarnings[#bp.migrationWarnings+1]=droppedHovers..' 个旧悬浮器升级 T2 后放不下，已跳过；请重新安装' end
    local front,back=-math.huge,math.huge
    for _,p in ipairs(oldWheels) do front=math.max(front,p.pos[3]);back=math.min(back,p.pos[3]) end
    if front>back then for _,p in ipairs(oldWheels) do if p.pos[3]==front then p.type=p.type:gsub('drive','steer') end end end
    return bp
end
return M
