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
local function InHashDomain(x,y,z)
    return x>=-1024 and x<=1023 and y>=-1024 and y<=1023 and z>=-1024 and z<=1023
end
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
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for _,s in ipairs(out) do for k=1,3 do lo[k]=math.min(lo[k],s[k]);hi[k]=math.max(hi[k],s[k]) end end
    out.bounds={center={(lo[1]+hi[1])*.5,(lo[2]+hi[2])*.5,(lo[3]+hi[3])*.5},
        half={(hi[1]-lo[1])*.5,(hi[2]-lo[2])*.5,(hi[3]-lo[3])*.5}}
    samplesByType[type]=out;return out
end
local function Prepare(parts,part,owner,checkpoint)
    local def=Defs[part.type]
    if not def or not def.weapon or def.drill then return nil end
    local t=Assets.Get(part.type,part.rot).weapon;local samples=Samples(part.type)
    if not t or not samples then return nil end
    local own={};for _,c in ipairs(part.cells or part._cells or {}) do own[Hash(table.unpack(c))]=true end
    local pv=V.Add(Rot.ApplyRot(part.rot,t.pivot),{part.pos[1],part.pos[2]+.5,part.pos[3]})
    local reach=0;for _,s in ipairs(samples) do reach=math.max(reach,V.Length(s)) end;reach=reach+1.5
    local occ={};local mine=owner and owner[part.id]
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge};local bounded=true
    for _,p in ipairs(parts) do
        if p.id~=part.id and not Defs[p.type].weapon and (not owner or owner[p.id]==mine) then
            for _,c in ipairs(p._cells) do
                if V.Length(V.Sub({c[1],c[2]+.5,c[3]},pv))<reach then
                    local h=Hash(table.unpack(c));if not own[h] then
                        occ[h]=p.id
                        bounded=bounded and InHashDomain(c[1],c[2],c[3]) and c[1]%1==0 and c[2]%1==0 and c[3]%1==0
                        for k=1,3 do lo[k]=math.min(lo[k],c[k]);hi[k]=math.max(hi[k],c[k]) end
                    end
                end
            end
        end
        if checkpoint then checkpoint() end
    end
    return {def=def,samples=samples,pv=pv,reach=reach,owner=mine,occ=occ,rot=part.rot,bounds=bounded and {lo=lo,hi=hi} or nil,
        key=part.type..':'..part.rot..':'..table.concat(part.pos,',')}
end
local function MissesBounds(context,m,cp,sp,cy,sy)
    local bounds=context.bounds;if not bounds then return false end
    local sample=context.samples.bounds;local pv=context.pv
    local center,half=sample.center,sample.half
    local y1,z1=center[2]*cp+center[3]*sp,-center[2]*sp+center[3]*cp
    local x,y,z=center[1]*cy+z1*sy,y1,-center[1]*sy+z1*cy
    local ry,rz=math.abs(cp)*half[2]+math.abs(sp)*half[3],math.abs(sp)*half[2]+math.abs(cp)*half[3]
    local rx,rz0=math.abs(cy)*half[1]+math.abs(sy)*rz,math.abs(sy)*half[1]+math.abs(cy)*rz
    local wx,wy,wz=m[1]*x+m[2]*y+m[3]*z+pv[1],m[4]*x+m[5]*y+m[6]*z+pv[2],m[7]*x+m[8]*y+m[9]*z+pv[3]
    -- Cube rotations are signed permutations. Absolute coefficients transform
    -- the sample box extents; one cell covers rounding and floating-point edges.
    local ex=math.abs(m[1])*rx+math.abs(m[2])*ry+math.abs(m[3])*rz0
    local ey=math.abs(m[4])*rx+math.abs(m[5])*ry+math.abs(m[6])*rz0
    local ez=math.abs(m[7])*rx+math.abs(m[8])*ry+math.abs(m[9])*rz0
    local lx,ly,lz,hx,hy,hz=wx-ex,wy-ey,wz-ez,wx+ex,wy+ey,wz+ez
    if not InHashDomain(lx-1,ly-1,lz-1) or not InHashDomain(hx+1,hy+1,hz+1) then return false end
    return hx+1<bounds.lo[1] or lx-1>bounds.hi[1] or hy+1<bounds.lo[2] or ly-1>bounds.hi[2] or hz+1<bounds.lo[3] or lz-1>bounds.hi[3]
end
local function Evaluate(context,checkpoint)
    if not context or not next(context.occ) then return nil end
    local def,samples,pv,occ=context.def,context.samples,context.pv,context.occ
    local m=Rot.ROTATIONS[context.rot].m;local blockers,order={},{}
    local rays=context.rays or {};context.rays=rays
    local function Hit(yaw,pitch,record)
        if checkpoint then checkpoint() end
        local row=rays[yaw];if not row then row={};rays[yaw]=row end
        local ray=row[pitch]
        local cp,sp,cy,sy
        if not ray then
            cp,sp,cy,sy=math.cos(pitch),math.sin(pitch),math.cos(yaw),math.sin(yaw)
            -- Do not cache this miss: a later edit may add an occupant here.
            if MissesBounds(context,m,cp,sp,cy,sy) then return false end
            ray={cells={},seen={},nextSample=1};row[pitch]=ray
        end
        local hit
        if type(ray)=='string' then
            for offset=1,#ray,8 do local hash=string.unpack('<i8',ray,offset);local id=occ[hash];if id then hit=id;break end end
        else
            for _,hash in ipairs(ray.cells) do local id=occ[hash];if id then hit=id;break end end
        end
        if not hit and type(ray)~='string' and ray.nextSample then
            if not cp then cp,sp,cy,sy=math.cos(pitch),math.sin(pitch),math.cos(yaw),math.sin(yaw) end
            for i=ray.nextSample,#samples do
                local s=samples[i]
                local y1,z1=s[2]*cp+s[3]*sp,-s[2]*sp+s[3]*cp
                local x,y,z=s[1]*cy+z1*sy,y1,-s[1]*sy+z1*cy
                local hash=Hash(Round(m[1]*x+m[2]*y+m[3]*z+pv[1]),
                    math.floor(m[4]*x+m[5]*y+m[6]*z+pv[2]),Round(m[7]*x+m[8]*y+m[9]*z+pv[3]))
                if not ray.seen[hash] then ray.seen[hash]=true;ray.cells[#ray.cells+1]=hash end
                ray.nextSample=i+1
                local id=occ[hash];if id then hit=id;break end
            end
            if ray.nextSample>#samples then
                row[pitch]=string.pack('<'..string.rep('i8',#ray.cells),table.unpack(ray.cells))
            end
        end
        if hit then
            if record and not blockers[hit] then blockers[hit]=true;order[#order+1]=hit end
            return true
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
function M.Compute(parts,part,owner,checkpoint)
    return Evaluate(Prepare(parts,part,owner,checkpoint),checkpoint)
end
local function SameContext(a,b)
    if not a or not b or a.key~=b.key then return false end
    for key,id in pairs(a.occ) do if b.occ[key]~=id then return false end end
    for key,id in pairs(b.occ) do if a.occ[key]~=id then return false end end
    return true
end
function M.For(bp,owner,checkpoint)
    local parts=bp:List();local old=cached[bp];local signatures={};local changed=not old
    local changedParts,invalidated={},{}
    for _,p in ipairs(parts) do
        local key=p.type..':'..p.rot..':'..table.concat(p.pos,',')..':'..tostring(owner and owner[p.id])
        signatures[p.id]=key
        if not old or old.signatures[p.id]~=key then changed=true;changedParts[#changedParts+1]=p;invalidated[p.id]=true end
    end
    if old then for id in pairs(old.signatures) do if not signatures[id] then changed=true;invalidated[id]=true end end end
    local entries,result={},{}
    for _,p in ipairs(parts) do if Defs[p.type].weapon then
        local previous=old and old.entries[p.id]
        -- Damage and repair outside the barrel's local occupancy cannot alter
        -- clearance. Check both old occupants and newly added/moved cells;
        -- owner changes and overlapping occupants still rebuild the context.
        local context=previous and previous.context
        local unaffected=old and context and old.signatures[p.id]==signatures[p.id]
        if unaffected then for _,id in pairs(context.occ) do if invalidated[id] then unaffected=false;break end end end
        if unaffected then
            for _,part in ipairs(changedParts) do
                if part.id~=p.id and not Defs[part.type].weapon and (not owner or owner[part.id]==context.owner) then
                    for _,cell in ipairs(part._cells) do
                        local x,y,z=cell[1]-context.pv[1],cell[2]+.5-context.pv[2],cell[3]-context.pv[3]
                        if math.sqrt(x*x+y*y+z*z)<context.reach then unaffected=false;break end
                    end
                end
                if not unaffected then break end
            end
        end
        if not changed or unaffected then
            entries[p.id]=previous;result[p.id]=previous.range or nil
            if checkpoint then checkpoint() end
        else
            local context=Prepare(parts,p,owner,checkpoint)
            if previous and previous.context and context and previous.context.key==context.key then context.rays=previous.context.rays end
            local range=nil ---@type table|boolean|nil
            if previous and SameContext(previous.context,context) then range=previous.range end
            if range==nil then range=Evaluate(context,checkpoint) or false end
            entries[p.id]={context=context,range=range};result[p.id]=range or nil
        end
    end end
    cached[bp]={signatures=signatures,entries=entries};return result
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
