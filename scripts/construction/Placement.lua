-- Source editor mounting, sampled rotation and x=0 mirror rules. Grid units.
local Rot=require 'core.Rotations'
local Defs=require('parts.Defs').PARTS
local Blueprint=require 'construction.Blueprint'
local Mounts=require 'parts.Mounts'
local M={}
function M.Rotation(type,normal,forward,spin,sampled)
    if sampled~=nil then return Rot.RotateAroundAxis(sampled,normal,spin) end
    local face=Defs[type].faceCamera;local fwd
    if normal[2]~=0 then
        fwd=Rot.SnapDir(forward[1],0,forward[3]);if face then fwd={-fwd[1],0,-fwd[3]} end
    elseif face or normal[3]~=0 then fwd={0,1,0} else fwd={0,0,1} end
    return Rot.SpinAroundUp(Rot.RotIndex(normal,fwd),spin)
end
function M.For(type,hit,place,forward,spin,sampled)
    local def=Defs[type];local n=hit.normal
    if def.leg then
        return {pos=place,rot=n[2]~=0 and Rot.IDENTITY or Rot.RotIndex({0,1,0},{-n[3],0,n[1]}),reason=n[2]~=0 and '节足要装在车身侧面' or nil}
    end
    if def.hover then
        if n[2]>0 then return {pos=place,rot=Rot.RotIndex({0,-1,0},{0,0,1}),reason='悬浮器要装在车底或侧面'} end
        if n[2]<0 then
            local dirs={{0,0,1},{1,0,0},{0,0,-1},{-1,0,0}};local f=Rot.SnapDir(forward[1],0,forward[3]);local index=1
            for i,d in ipairs(dirs) do if Rot.Eq(d,f) then index=i;break end end
            return {pos=place,rot=Rot.RotIndex({0,-1,0},dirs[(index-1+spin)%4+1])}
        end
        return {pos=place,rot=Rot.RotIndex({0,1,0},{-n[3],0,n[1]})}
    end
    if not def.track then return {pos=place,rot=M.Rotation(type,n,forward,spin,sampled)} end
    local out=n[1]~=0 and n or {place[1]<0 and -1 or 1,0,0}
    local rot=Rot.RotIndex(out,{0,1,0});local dn=math.huge
    for _,c in ipairs(Blueprint.PartCells(type,place,rot)) do dn=math.min(dn,Rot.Dot(c,n)) end
    dn=dn-Rot.Dot(place,n)
    return {pos={place[1]-n[1]*dn,place[2]-n[2]*dn,place[3]-n[3]*dn},rot=rot}
end
function M.Mirror(type,pos,rot)
    local def=Defs[type];local mount=Mounts.HoverInfo(type,rot)
    local fix=(def.leg or mount and mount.mount=='side') and Rot.RotIndex({0,1,0},{0,0,-1}) or def.mirrorFix or Rot.IDENTITY
    local mr=Rot.MirrorRot(rot,fix);local mp={-pos[1],pos[2],pos[3]}
    local cells=Blueprint.PartCells(type,pos,rot);local want={}
    for i,c in ipairs(cells) do want[i]={-c[1],c[2],c[3]} end
    local got=Blueprint.PartCells(type,mp,mr)
    for a=1,3 do
        local lo,other=math.huge,math.huge
        for _,c in ipairs(want) do lo=math.min(lo,c[a]) end
        for _,c in ipairs(got) do other=math.min(other,c[a]) end
        mp[a]=mp[a]+lo-other
    end
    if mp[1]==pos[1] and mr==rot then return nil end
    local set={};for _,c in ipairs(cells) do set[Blueprint.Key(table.unpack(c))]=true end
    local same=true;for _,c in ipairs(want) do same=same and set[Blueprint.Key(table.unpack(c))]==true end
    if same then return nil end
    return {pos=mp,rot=mr}
end
function M.MirrorPart(bp,part)
    local m=M.Mirror(part.type,part.pos,part.rot);if not m then return nil end
    for _,id in ipairs(bp.cellIds[Blueprint.Key(table.unpack(m.pos))] or {}) do
        local q=bp.parts[id]
        if q.id~=part.id and q.type==part.type and Rot.Eq(q.pos,m.pos) and q.rot==m.rot then return q end
    end
end
return M
