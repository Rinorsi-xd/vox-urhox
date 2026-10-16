-- shared/build/livery.js; keep the H5 grid-space interchange contract.
local ResourceData=require("core.ResourceData")

local M={MAX=48,MIN_SIZE=1,MAX_SIZE=30}
local function Number(v,default)
    local n=tonumber(v);return n and n==n and math.abs(n)<math.huge and n or default or 0
end
local function Round(v) return math.floor(v*1000+.5)/1000 end
function M.Clean(list)
    local out={};if type(list)~='table' then return out end
    for _,d in ipairs(list) do
        if type(d)=='table' and type(d.s)=='string' and #d.s<=100 and type(d.p)=='table' and type(d.n)=='table' then
            local n={Number(d.n[1]),Number(d.n[2]),Number(d.n[3])};local len=math.sqrt(n[1]^2+n[2]^2+n[3]^2);if len==0 then len=1 end
            local item={s=d.s,p={},n={},r=Round(Number(d.r)),w=Round(math.max(1,math.min(30,Number(d.w,4))))}
            for i=1,3 do item.p[i]=Round(Number(d.p[i]));item.n[i]=Round(n[i]/len) end
            if type(d.c)=='table' then
                item.c={};for i=1,math.min(2,#d.c) do
                    local color=d.c[i];item.c[i]=math.floor(math.max(0,math.min(0xffffff,type(color)=='string' and tonumber(color:gsub('^#',''),16) or Number(color))))
                end
            end
            if d.f and d.f~=0 and d.f~=cjson.null then item.f=1 end
            if d.m and d.m~=0 and d.m~=cjson.null then item.m=math.floor(Number(d.m)) end
            out[#out+1]=item;if #out==M.MAX then break end
        end
    end
    return out
end
function M.Clone(list)
    local out={};for _,d in ipairs(list) do
        local q={s=d.s,p={table.unpack(d.p)},n={table.unpack(d.n)},r=d.r,w=d.w,f=d.f,m=d.m}
        if d.c then q.c={table.unpack(d.c)} end;out[#out+1]=q
    end;return out
end
function M.Mirror(d,sticker)
    local q=M.Clone({d})[1];q.p[1]=-q.p[1];q.n[1]=-q.n[1];q.r=-q.r
    if not sticker or sticker.group~='文字' then q.f=d.f and d.f~=0 and 0 or 1 end
    return q
end
function M.OnCenter(d) return math.abs(d.p[1])<.3 and math.abs(d.n[1])<.2 end
function M.Catalog()
    if not M.catalog then
        local data=ResourceData.Read('Livery/Catalog.json');M.catalog={list=data.stickers,byId={}}
        for _,s in ipairs(data.stickers) do M.catalog.byId[s.id]=s end
    end;return M.catalog
end
return M
