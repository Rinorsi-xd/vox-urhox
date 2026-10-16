-- Frozen salvageLoot.js. RNG is injected so source fixtures exercise real rules.
local Items=require('core.ResourceData').Read('UI/Outgame.json').items
local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local M={CAPACITY=20}
-- H5 cargo is a Map: equal-price swaps discard the first acquired item.
-- Keep that order outside the numeric cargo record (HUD, saves and settlement
-- iterate its item counts); weak keys release it with the raid's cargo table.
local cargoOrders=setmetatable({},{__mode='k'})
local function Order(cargo)
    local order=cargoOrders[cargo]
    if not order then
        order={}
        for id in pairs(cargo) do order[#order+1]=id end
        -- Pre-populated compatibility callers have no acquisition history.
        table.sort(order);cargoOrders[cargo]=order
    end
    return order
end
function M.Stack(id) return Items[id].cat=='material' and 20 or 5 end
function M.Size(id) return (Items[id].size or 1)>=2 and 2 or 1 end
function M.Slots(id,n) return math.ceil(n/M.Stack(id))*M.Size(id) end
function M.Used(cargo) local n=0;for id,count in pairs(cargo) do n=n+M.Slots(id,count) end;return n end
function M.Room(cargo,id,n)
    local have=cargo[id] or 0;local base=M.Used(cargo)-M.Slots(id,have)
    while n>0 and base+M.Slots(id,have+n)>M.CAPACITY do n=n-1 end;return n
end
function M.Price(id) return math.max(1,math.floor(Items[id].price*.6)) end
function M.Value(cargo) local n=0;for id,count in pairs(cargo) do n=n+M.Price(id)*count end;return n end
function M.Mass(cargo) local n=0;for id,count in pairs(cargo) do n=n+(Items[id].mass or 1)*count end;return n end
function M.Container(tier,id)
    local hash=0;for i=1,#id do hash=(hash*31+id:byte(i)) & 0xffffffff end
    if hash>=0x80000000 then hash=hash-0x100000000 end
    local odd=math.abs(hash)%2==1
    return ({'supply',odd and 'armory' or 'supply',odd and 'electronics' or 'armory','vault'})[tier+1] or 'supply'
end
local function Sort(out)
    for i,item in ipairs(out) do item.order=i end
    table.sort(out,function(a,b) return a.r==b.r and a.order<b.order or a.r<b.r end);return out
end
function M.FromTable(list,rand)
    local out={}
    for _,row in ipairs(list) do if rand()<(row[4] or 1) then
        local n=row[2]+math.floor(rand()*(row[3]-row[2]+1))
        if n>0 then local r=Items[row[1]].rarity or 0;out[#out+1]={id=row[1],n=n,r=r,t=Data.revealTime[r+1],state='hidden'} end
    end end
    return Sort(out)
end
function M.Roll(kind,rand,state,op,region)
    local cfg=Data.containers[kind] or Data.containers.supply;local counts,order={},{}
    local function Take(r)
        for k=r,0,-1 do if k~=5 or state.red<2 then
            local pool={};for _,id in ipairs(cfg.pool) do if Items[id] and Items[id].rarity==k then pool[#pool+1]=id end end
            if #pool>0 then
                local id=pool[math.floor(rand()*#pool)+1];local item=Items[id]
                local n=item.cat=='material' and (k==0 and 2+math.floor(rand()*5) or 1+math.floor(rand()*(k>=2 and 2 or 3))) or 1
                if not counts[id] then order[#order+1]=id end;counts[id]=(counts[id] or 0)+n
                if k==5 then state.red=state.red+1 end;return k
            end
        end end;return -1
    end
    local n=cfg.count[1]+math.floor(rand()*(cfg.count[2]-cfg.count[1]+1));local best=-1
    local sum=0;for _,weight in ipairs(cfg.weights) do sum=sum+weight end
    for _=1,n do
        local roll=rand()*sum;local r=0
        for i,weight in ipairs(cfg.weights) do roll=roll-weight;if roll<0 then r=i-1;break end end
        if r<4 and rand()<((op.bonus or 0)+(Data.regionRisk[region or ''] or 0)*.06) then r=r+1 end
        best=math.max(best,Take(r))
    end
    if cfg.guarantee and best<cfg.guarantee then Take(cfg.guarantee) end
    if cfg.red and rand()<(op.red or cfg.red) then Take(5) end
    local out={};for _,id in ipairs(order) do local r=Items[id].rarity;out[#out+1]={id=id,n=counts[id],r=r,t=Data.revealTime[r+1],state='hidden'} end
    return Sort(out)
end
function M.Take(cargo,id,n)
    local k=M.Room(cargo,id,n)
    if k>0 then
        local order=Order(cargo)
        if cargo[id]==nil then order[#order+1]=id end
        cargo[id]=(cargo[id] or 0)+k
    end
    return k
end
function M.Swap(cargo,it)
    local dropped={};local order=Order(cargo)
    for _=1,20 do
        if M.Room(cargo,it.id,it.left)>=it.left then break end
        local best,price=false,math.huge
        for _,id in ipairs(order) do local n=cargo[id];if n and id~=it.id then
            local k=math.min(n,5);local p=M.Price(id)*k/M.Slots(id,k)
            if p<price then best=id;price=p end
        end end
        if not best then break end
        local n=math.min(cargo[best],M.Stack(best));cargo[best]=cargo[best]-n
        if cargo[best]==0 then
            cargo[best]=nil
            for i,id in ipairs(order) do if id==best then table.remove(order,i);break end end
        end
        dropped[#dropped+1]={best,n,n}
    end
    local k=M.Take(cargo,it.id,it.left);it.left=it.left-k;if it.left==0 then it.state='shown' end
    return dropped
end
return M
