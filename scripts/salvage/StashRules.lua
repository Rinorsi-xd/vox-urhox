local Data=require('core.ResourceData').Read('UI/Outgame.json')
local M={}
local Count=require('storage.RecordNumbers').Count
function M.Valid(d)
    if type(d)~='table' or not Count(d.v) or d.v~=1 or not Count(d.credits) or type(d.items)~='table' then return false end
    for id,n in pairs(d.items) do if not Data.items[id] or not Count(n) then return false end end
    if d.op~=nil and (not Count(d.op) or d.op<1 or d.op>#Data.ops) then return false end
    if d.lastRun~=nil and (type(d.lastRun)~='string' or #d.lastRun>128) then return false end
    if d.lastStartedRun~=nil and (type(d.lastStartedRun)~='string' or #d.lastStartedRun>128) then return false end
    if d.stats~=nil then
        if type(d.stats)~='table' then return false end
        for _,k in ipairs({'raids','extracted','lost'}) do if d.stats[k]~=nil and not Count(d.stats[k]) then return false end end
    end
    return true
end
function M.Need(parts)
    local out={};for _,p in ipairs(parts) do local t=p.type or p[1];if t~='core' then local id='part:'..t;out[id]=(out[id] or 0)+1 end end;return out
end
function M.Shortfall(owned,usage)
    local out={};for id,n in pairs(usage) do if n>(owned[id] or 0) then out[id]=n-(owned[id] or 0) end end;return out
end
function M.Price(list)
    local cost=0
    for id,n in pairs(list) do
        if not Data.items[id] or not Count(n) then return nil,'数量无效' end
        cost=cost+Data.items[id].price*n
    end
    return cost
end
function M.Buy(data,list)
    local cost,reason=M.Price(list);if not cost then return {ok=false,reason=reason} end
    if cost>data.credits then return {ok=false,cost=cost,reason='信用点不够（还差 '..(cost-data.credits)..'）'} end
    local out={};for k,v in pairs(data) do out[k]=v end;out.items={};for id,n in pairs(data.items) do out.items[id]=n end
    out.credits=data.credits-cost
    for id,n in pairs(list) do if n>0 then out.items[id]=(out.items[id] or 0)+n end end
    -- Source buyAll deliberately does not apply loose-stack capacity: purchases
    -- for an installed car are immediately consumed by its aggregate usage.
    return {ok=true,cost=cost,data=out}
end
return M
