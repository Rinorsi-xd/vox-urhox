-- Frozen shared/build/turretRange.js: sampled barrel clearance in grid space.
-- Own mount cells and other weapons do not block; only the same rotor owner
-- matters. A nearby wall raises the barrel, or limits yaw above 45 degrees.
local Defs=require('parts.Defs').PARTS
local Assets=require 'parts.PartAssets'
local Rot=require 'core.Rotations'
local V=require 'core.Math3'
local DEG=math.pi/180
local M={YAW_STEP=5*DEG,PITCH_STEP=3*DEG,MAX_LIFT=45*DEG}
local N=72
local samplesByType={}
local cached=setmetatable({},{__mode='k'})
local function Hash(x,y,z) return ((x+1024)*2048+(y+1024))*2048+(z+1024) end
local function Round(x) return math.floor(x+.5) end
local function Wrap(a) return a-Round(a/(2*math.pi))*2*math.pi end
local function Samples(type)
    if samplesByType[type] then return samplesByType[type] end
    local t=Assets.Get(type,0).weapon;if not t then return nil end
    local out={}
    for _,m in ipairs(t.muzzles or {t.muzzle}) do
        local d=V.Sub(m,t.pivot);local n=math.max(2,math.ceil(V.Length(d)/.3))
        for i=1,n do
            local p=V.Scale(d,i/n);out[#out+1]=p
            for _,o in ipairs({{.2,0,0},{-.2,0,0},{0,.2,0},{0,-.2,0}}) do out[#out+1]=V.Add(p,o) end
        end
    end
    samplesByType[type]=out;return out
end
function M.Compute(parts,part,owner)
    local def=Defs[part.type]
    if not def or not def.weapon or def.drill then return nil end
    local t=Assets.Get(part.type,part.rot).weapon;local samples=Samples(part.type)
    if not t or not samples then return nil end
    local own={};for _,c in ipairs(part.cells or part._cells or {}) do own[Hash(table.unpack(c))]=true end
    local pv=V.Add(Rot.ApplyRot(part.rot,t.pivot),{part.pos[1],part.pos[2]+.5,part.pos[3]})
    local reach=0;for _,s in ipairs(samples) do reach=math.max(reach,V.Length(s)) end;reach=reach+1.5
    local occ={};local mine=owner and owner[part.id]
    for _,p in ipairs(parts) do
        if p.id~=part.id and not Defs[p.type].weapon and (not owner or owner[p.id]==mine) then
            for _,c in ipairs(p._cells) do
                if V.Length(V.Sub({c[1],c[2]+.5,c[3]},pv))<reach then
                    local h=Hash(table.unpack(c));if not own[h] then occ[h]=p.id end
                end
            end
        end
    end
    if not next(occ) then return nil end
    local m=Rot.ROTATIONS[part.rot].m;local blockers,order={},{}
    local function Hit(yaw,pitch,record)
        local cp,sp,cy,sy=math.cos(pitch),math.sin(pitch),math.cos(yaw),math.sin(yaw)
        for _,s in ipairs(samples) do
            local y1,z1=s[2]*cp+s[3]*sp,-s[2]*sp+s[3]*cp
            local x,y,z=s[1]*cy+z1*sy,y1,-s[1]*sy+z1*cy
            local id=occ[Hash(Round(m[1]*x+m[2]*y+m[3]*z+pv[1]),
                math.floor(m[4]*x+m[5]*y+m[6]*z+pv[2]),Round(m[7]*x+m[8]*y+m[9]*z+pv[3]))]
            if id then
                if record and not blockers[id] then blockers[id]=true;order[#order+1]=id end
                return true
            end
        end
        return false
    end
    local pitch=def.aim and def.aim.pitch or {-15,90};local p0,p1=pitch[1]*DEG,pitch[2]*DEG
    local pmin,pmax={},{};local touched=false
    for i=1,N do
        local yaw=Wrap((i-1)*M.YAW_STEP);local p=p0
        while p<=p1+1e-9 and Hit(yaw,p,false) do p=p+M.PITCH_STEP end
        if p>p1+1e-9 then touched=true
        else
            if p>p0+1e-9 then touched=true end
            pmin[i]=p
            while p+M.PITCH_STEP<=p1+1e-9 and not Hit(yaw,p+M.PITCH_STEP,false) do p=p+M.PITCH_STEP end
            if p+M.PITCH_STEP<=p1+1e-9 then touched=true end
            pmax[i]=math.min(p1,p)
        end
    end
    if not touched then return nil end
    local free=true
    for i=1,N do
        if pmin[i] and pmin[i]>M.MAX_LIFT+1e-9 then pmin[i]=nil;pmax[i]=nil end
        if not pmin[i] then free=false end
        Hit(Wrap((i-1)*M.YAW_STEP),math.max(p0,0),true)
    end
    local out={free=free,lo=-math.huge,hi=math.huge,pmin=pmin,pmax=pmax,blockers=order}
    if free then return out end
    if not pmin[1] then out.lo=0;out.hi=0;out.stuck=true;return out end
    local lo,hi=0,0
    while pmin[(hi+1)%N+1] do hi=hi+1 end
    while pmin[(lo-1)%N+1] do lo=lo-1 end
    out.lo=lo*M.YAW_STEP;out.hi=hi*M.YAW_STEP;return out
end
function M.For(bp,owner)
    local parts=bp:List();local old=cached[bp];local signatures={}
    for _,p in ipairs(parts) do signatures[p.id]=p.type..':'..p.rot..':'..table.concat(p.pos,',')..':'..tostring(owner[p.id] or 0) end
    local changed={}
    if old then
        for id,s in pairs(signatures) do if old.signatures[id]~=s then changed[id]=true end end
        for id,s in pairs(old.signatures) do if signatures[id]~=s then changed[id]=true end end
    end
    local ranges=old and old.ranges or {}
    if old then for id in pairs(changed) do ranges[id]=nil end end
    if old then for _,p in ipairs(parts) do if Defs[p.type].weapon then
        for id in pairs(changed) do if owner[id]==owner[p.id] or old.owner[id]==old.owner[p.id] then ranges[p.id]=nil;break end end
    end end end
    local result={}
    for _,p in ipairs(parts) do if Defs[p.type].weapon then
        if ranges[p.id]==nil then ranges[p.id]=M.Compute(parts,p,owner) or false end
        result[p.id]=ranges[p.id] or nil
    end end
    cached[bp]={signatures=signatures,owner=owner,ranges=ranges};return result
end
function M.PitchLimits(range,yaw)
    -- Preserve JS remainder/add/modulo ordering at exact five-degree bins.
    local f=(math.fmod(Wrap(yaw)/M.YAW_STEP,N)+N)%N;local a=math.floor(f)+1;local b=a%N+1
    local lo,hi=-math.huge,math.huge;local found=false
    for _,i in ipairs({a,b}) do if range.pmin[i] then
        found=true;lo=math.max(lo,range.pmin[i]);hi=math.min(hi,range.pmax[i])
    end end
    if found then return {lo,hi} end
end
function M.Text(range)
    if range.stuck then return '炮管被挡死了，转不动' end
    if range.free then return '左右能转一整圈，有些方向炮管要抬高才能过去' end
    local a,b=Round(range.hi/DEG),-Round(range.lo/DEG)
    return '转不了一整圈：一边最多 '..math.max(a,b)..'°，另一边最多 '..math.min(a,b)..'°'
end
return M
