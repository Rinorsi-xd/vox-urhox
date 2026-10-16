local VehicleSpec=require("drive.VehicleSpec")

local Defs=require('parts.Defs')
local BP=require('construction.Blueprint')
local Config=require('Config')
local C=require('endless.Data').config
local Roles=require('endless.Data').roles
local M={NO_LIMIT={id=5,name='不限阶位',budget=99999,mass=999999,parts=9999,decor=9999,weapons=99}}
function M.Limits(tier) return C.tierLimits and Config.TIERS[math.max(1,math.min(5,type(tier)=='table' and tier.id or tier))] or M.NO_LIMIT end
function M.Blueprint(source) return source.List and source or BP.New():Load(source) end
function M.Limited(id) local p=Defs.PARTS[id];return p and (p.cat=='weapon' or p.cat=='movement' or p.cat=='function') or false end
function M.Count(source)
    local out={};for _,p in ipairs(M.Blueprint(source):List()) do if M.Limited(p.type) then out[p.type]=(out[p.type] or 0)+1 end end;return out
end
function M.Remaining(owned,source)
    local out={};for k,v in pairs(owned) do out[k]=v end
    for k,v in pairs(M.Count(source)) do out[k]=(out[k] or 0)-v end;return out
end
function M.Initial(source)
    local out=M.Count(source);out.laser1=(out.laser1 or 0)+1;out.steer1=(out.steer1 or 0)+2;out.drive1=(out.drive1 or 0)+2;return out
end
function M.Validate(source,tier,owned)
    local bp=M.Blueprint(source);local diagnosis=bp:Diagnose(M.Limits(tier));local spec=VehicleSpec.Build(bp);local errors={};local seen={}
    local function Add(s) if not seen[s] then errors[#errors+1]=s;seen[s]=true end end
    for _,d in ipairs(diagnosis.list) do if d.level=='error' or d.level=='block' then Add(d.text) end end
    if not spec.ok then Add(spec.reason) else
        if #spec.weapons==0 then Add('至少需要一把武器') end
        if not (spec.motion.topSpeed>0 or (spec.motion.thrusterSpeed or 0)>0) then Add('至少需要一个能工作的移动零件') end
    end
    local remaining=M.Remaining(owned or {},bp)
    for k,v in pairs(remaining) do if v<0 then Add((Defs.PARTS[k].name or k)..' 超过本局仓库数量 '..(-v)..' 件') end end
    return {ok=#errors==0,errors=errors,diagnosis=diagnosis,remaining=remaining}
end
function M.Tier(id) local p=Defs.PARTS[id];return p and (p.wtier or tonumber((p.unlock or ''):match('T(%d)')) or 1) or 1 end
function M.Price(id) return math.max(10,math.floor((Defs.PARTS[id].budget or 0)*C.credits.priceScale/5+.5)*5) end
function M.Credits(meta) return math.floor((Roles[meta.role] or Roles.assault).cost*C.credits.perCost*C.credits.tierMult[math.max(1,math.min(5,meta.tier or 1))]*(meta.elite and C.credits.elite or 1)+.5) end
function M.Drops(meta,parts,random)
    local pool={};for _,p in ipairs(parts or {}) do if M.Limited(p.type) and (not p.hp or p.hp>0) then pool[#pool+1]=p end end
    if #pool==0 or not meta.elite and random()>(Roles[meta.role] or Roles.assault).dropChance then return {} end
    local out={};for i=1,meta.role=='boss' and 2 or 1 do if #pool==0 then break end
        local index=1
        if meta.elite then for j,p in ipairs(pool) do if Defs.PARTS[p.type].budget>Defs.PARTS[pool[index].type].budget then index=j end end
        else index=math.min(#pool,math.floor(random()*#pool)+1) end
        local p=table.remove(pool,index);out[#out+1]={type=p.type,partId=p.id}
    end;return out
end
local function Weighted(pool,weight,random)
    local total=0;for _,p in ipairs(pool) do total=total+weight(p) end
    local pick=random()*total;for _,p in ipairs(pool) do pick=pick-weight(p);if pick<=0 then return p end end;return pool[#pool]
end
function M.Supplies(tier,wave,inventory,source,drought,random)
    local owned={};for k,v in pairs(inventory) do owned[k]=v end
    for k,v in pairs(M.Count(source)) do owned[k]=math.max(owned[k] or 0,v) end
    local boss=wave%C.bossEvery==0;local cats={}
    for _,cat in ipairs({'weapon','movement','function','repair'}) do
        local valid=cat=='repair' or not boss;for _,p in ipairs(Defs.LIST) do if p.cat==cat and (p.wtier or 1)==tier then valid=true end end
        if valid then cats[#cats+1]=cat end
    end
    local order={};local mandatory=(drought>=3 or wave==1) and 'weapon' or wave==2 and 'movement'
    if mandatory then for _,c in ipairs(cats) do if c==mandatory then order[1]=c end end end
    while #order<3 do local pool={};for _,c in ipairs(cats) do local exists=false;for _,o in ipairs(order) do if o==c then exists=true end end;if not exists then pool[#pool+1]=c end end
        if #pool==0 then break end
        order[#order+1]=Weighted(pool,function(cat) if cat=='repair' then return 1 end;for k,n in pairs(owned) do if n>0 and Defs.PARTS[k].cat==cat then return 1 end end;return 2 end,random)
    end
    local out={};for _,cat in ipairs(order) do
        local repair={id='repair',kind='repair',category='repair',name='战地维修',description='获得一次 V 原地修满',tier=tier,gold=boss}
        if cat=='repair' then out[#out+1]=repair else
            local pickTier=boss and tier or math.max(1,tier-(random()<.3 and 1 or 0));local pool={}
            for _,p in ipairs(Defs.LIST) do if p.cat==cat and (p.wtier or 1)==pickTier then pool[#pool+1]=p end end
            if #pool==0 and not boss then for _,p in ipairs(Defs.LIST) do if p.cat==cat and (p.wtier or 1)<=tier then pool[#pool+1]=p end end end
            if #pool==0 then out[#out+1]=repair else local p=Weighted(pool,function(d) return (owned[d.id] or 0)>=3 and .3 or 1 end,random)
                out[#out+1]={id=p.id,type=p.id,kind='part',category=cat,name=p.name,tier=p.wtier or 1,gold=boss}
            end
        end
    end;return out
end
return M
