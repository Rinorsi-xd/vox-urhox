-- Source grid DDA, in right-handed world metres. No scene/physics dependencies.
-- A full cell is a cube; partial cells use 4^3 solid masks, including shared cells.
-- Rays through a slope's empty half continue behind it. An interior sub-face
-- offers the same cell first, then its adjacent cell as a placement fallback.
local CELL=require('Config').CELL
local Key=require('build.Blueprint').Key
local M={}
local function Copy(a) return {a[1],a[2],a[3]} end
local function March(o,d,t,cell,sub)
    local index,step,maximum,delta={},{},{},{}
    for a=1,3 do
        local p=sub and (o[a]+d[a]*t-cell[a])*4 or o[a]
        index[a]=sub and math.min(3,math.max(0,math.floor(p))) or math.floor(p)
        local ds=d[a]*(sub and 4 or 1);step[a]=0;maximum[a]=math.huge;delta[a]=math.huge
        if ds>0 then step[a]=1;maximum[a]=t+(index[a]+1-p)/ds;delta[a]=1/ds
        elseif ds<0 then step[a]=-1;maximum[a]=t+(index[a]-p)/ds;delta[a]=-1/ds end
    end
    return index,step,maximum,delta
end
local function Axis(maximum)
    local a=1;if maximum[2]<maximum[a] then a=2 end;if maximum[3]<maximum[a] then a=3 end;return a
end
local function SubMarch(bp,key,cell,o,d,t0,t1,normal)
    local index,step,maximum,delta=March(o,d,t0,cell,true);local t=t0
    for _=1,13 do
        for _,id in ipairs(bp.cellIds[key] or {}) do
            local p=bp.parts[id];local mask=p._masks[key]
            if mask==nil or ((mask>>(index[1]+index[2]*4+index[3]*16))&1)~=0 then
                return {id=id,sub=Copy(index),normal=normal,t=t}
            end
        end
        local a=Axis(maximum);if maximum[a]>t1 then break end
        t=maximum[a];maximum[a]=maximum[a]+delta[a];index[a]=index[a]+step[a]
        if index[a]<0 or index[a]>=4 then break end
        normal={0,0,0};normal[a]=-step[a]
    end
end
function M.Cast(origin,direction,bp,maxDist,floorBounds)
    maxDist=maxDist or 60
    local o={origin[1]/CELL+.5,origin[2]/CELL,origin[3]/CELL+.5}
    local d={direction[1]/CELL,direction[2]/CELL,direction[3]/CELL}
    if d[1]==0 and d[2]==0 and d[3]==0 then return {hit=false} end
    local cell,step,maximum,delta=March(o,d,0);local floorT=math.huge
    if floorBounds~=false and direction[2]<0 and origin[2]>0 then
        floorT=-origin[2]/direction[2]
        if floorBounds then
            local x,z=(origin[1]+direction[1]*floorT)/CELL,(origin[3]+direction[3]*floorT)/CELL
            if math.abs(x)>floorBounds.x or math.abs(z)>floorBounds.z then floorT=math.huge end
        end
    end
    local t,normal=0,nil;local start=Key(table.unpack(cell))
    for iter=0,2047 do
        if t>maxDist then break end
        local key=Key(table.unpack(cell));local ids=bp.cellIds[key]
        if (key~=start or iter>0) and ids and normal then
            if floorT<t then break end
            for _,id in ipairs(ids) do if bp.parts[id]._masks[key]==nil then
                return {hit=true,partId=id,cell=Copy(cell),normal=normal,place={cell[1]+normal[1],cell[2]+normal[2],cell[3]+normal[3]},dist=t}
            end end
            local h=SubMarch(bp,key,cell,o,d,t,math.min(table.unpack(maximum)),normal)
            if h then
                if floorT<h.t then break end
                local out,inside={},true
                for a=1,3 do out[a]=cell[a]+h.normal[a];local n=h.sub[a]+h.normal[a];inside=inside and n>=0 and n<4 end
                return {hit=true,partId=h.id,cell=Copy(cell),normal=h.normal,place=inside and Copy(cell) or out,
                    alt=inside and out or nil,inCell=inside,sub=h.sub,dist=h.t}
            end
        end
        local a=Axis(maximum);t=maximum[a];maximum[a]=maximum[a]+delta[a];cell[a]=cell[a]+step[a]
        normal={0,0,0};normal[a]=-step[a]
    end
    if floorT<=maxDist then
        local x=math.floor((origin[1]+direction[1]*floorT)/CELL+.5)
        local z=math.floor((origin[3]+direction[3]*floorT)/CELL+.5)
        return {hit=true,cell={x,-1,z},normal={0,1,0},place={x,0,z},dist=floorT,floor=true}
    end
    return {hit=false}
end
return M
