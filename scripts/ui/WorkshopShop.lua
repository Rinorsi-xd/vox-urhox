-- Frozen workshop.js shop adapter; prices use the same immutable prefab rows
-- as construction, without constructing every preview blueprint on page entry.
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Catalog=require('parts.Defs').DATA
local Prefab=require 'construction.Prefab'
local M={}
local prices={}
function M.Active(owner) return owner.app.lobby=='salvage' and owner.app.salvageLobby~=nil end
function M.Price(id)
    if prices[id]~=nil then return prices[id] end
    local preset=assert(Catalog.presets[Prefab.keys[id]],'Unknown workshop prefab: '..tostring(id))
    local total=0
    for _,part in ipairs(preset.parts) do
        local item=part.type~='core' and Data.items['part:'..part.type]
        if item then total=total+item.price end
    end
    prices[id]=total;return total
end
function M.State(owner,id)
    if not M.Active(owner) then return nil end
    local cost=M.Price(id);local wallet=owner.app.salvageLobby.data.credits
    return {cost=cost,wallet=wallet,poor=cost>wallet}
end
function M.Label(id,detail,shop)
    if shop then return detail and id=='empty' and '免费领取' or '购买整车' end
    return detail and id=='empty' and '放进新车位，开始搭' or '放进新车位'
end
function M.Sort(list,key,stats,shop)
    local rank={};for i,p in ipairs(list) do rank[p.id]=i end
    table.sort(list,function(a,b)
        local x,y
        if key=='price' and shop then x,y=M.Price(a.id),M.Price(b.id)
        elseif key~='rec' and key~='price' then
            local field=key=='tier' and 'tier' or key=='parts' and 'parts' or 'speed'
            x,y=-(stats[a.id][field] or 0),-(stats[b.id][field] or 0)
        else x,y=0,0 end
        return x==y and rank[a.id]<rank[b.id] or x<y
    end)
    return list
end
return M
