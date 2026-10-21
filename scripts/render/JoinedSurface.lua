-- Source JoinedMesh.rebuild in blueprint coordinates. Exact source shape data
-- is exported offline; 16-bit face coverage handles complementary slopes.
local Defs=require('parts.Defs').PARTS
local Rot=require 'core.Rotations'
local Data=require('core.ResourceData').Read('Parts/JoinedShapes.json')
local M={slots={light='paint',heavy='heavyPaint',glass='glassPaint',neon='neonPaint'}}
function M.IsJoined(p) local d=Defs[p.type];return p.g and p.g>0 and d.shape and not d.panel and M.slots[d.mat]~=nil end
function M.Shape(p) return Data.shapes[Defs[p.type].shape] end
function M.Slot(p) return M.slots[Defs[p.type].mat] end
local function Key(v) return table.concat(v,',') end
local function Face(p,d)
    for i,n in ipairs(Data.dirs) do if n[1]==d[1] and n[2]==d[2] and n[3]==d[3] then return M.Shape(p).faces[p.rot+1][i] end end
    error('Joined face must be an axis direction')
end
-- Keep the uncached builder as the exact surface definition. A cached build
-- asks it to emit just one changed part while retaining all neighbour coverage.
-- pause, when given, is called between parts so callers can time-slice.
function M.Build(parts,collectParts,pause,onlyPart)
    local at,out,groups,byPart={},{},{},{}
    for _,p in ipairs(parts) do if M.IsJoined(p) then local k=Key(p.pos);at[k]=at[k] or {};at[k][#at[k]+1]=p end end
    for _,p in ipairs(parts) do if M.IsJoined(p) and (not onlyPart or p==onlyPart) then
        if pause then pause() end
        local slot=M.Slot(p);out[slot]=out[slot] or {position={},normal={},colors={}};local o=out[slot]
        groups[p.g]=groups[p.g] or {};local group=groups[p.g]
        local partSurface=collectParts and {position={},normal={}} or nil
        if partSurface then byPart[p.id]=partSurface end
        local geo=M.Shape(p);local hiddenFaces={}
        for t=1,#geo.position,9 do
            local v,n={},{}
            for j=0,2 do local i=t+j*3
                v[j+1]=Rot.ApplyRot(p.rot,{geo.position[i],geo.position[i+1],geo.position[i+2]})
                n[j+1]=Rot.ApplyRot(p.rot,{geo.normal[i],geo.normal[i+1],geo.normal[i+2]})
            end
            local hidden=false
            for a=1,3 do if not hidden then for _,s in ipairs({-.5,.5}) do
                if math.abs(v[1][a]-s)<1e-4 and math.abs(v[2][a]-s)<1e-4 and math.abs(v[3][a]-s)<1e-4 then
                    local d={0,0,0};d[a]=s>0 and 1 or -1;local dk=Key(d)
                    if hiddenFaces[dk]==nil then
                        local cover=0;local neighbours=at[Key({p.pos[1]+d[1],p.pos[2]+d[2],p.pos[3]+d[3]})] or {}
                        for _,q in ipairs(neighbours) do if M.Slot(q)==slot then cover=cover|Face(q,{-d[1],-d[2],-d[3]}) end end
                        hiddenFaces[dk]=(Face(p,d)&~cover)==0
                    end
                    hidden=hiddenFaces[dk];break
                end
            end end end
            if not hidden then for j=1,3 do
                for a=1,3 do local value=v[j][a]+p.pos[a]+(a==2 and .5 or 0)
                    o.position[#o.position+1]=value;o.normal[#o.normal+1]=n[j][a];group[#group+1]=value
                    if partSurface then partSurface.position[#partSurface.position+1]=value;partSurface.normal[#partSurface.normal+1]=n[j][a] end
                end
                o.colors[#o.colors+1]=p.color
            end end
        end
    end end
    return out,groups,byPart
end
-- Cache exact per-part surfaces, including the six adjacent face-cover masks.
-- Unchanged material streams retain their identity so JoinedMesh skips uploads.
-- This cache belongs to one joined mesh and is discarded with that mesh.
function M.BuildCached(parts,cache)
    local at={}
    for _,p in ipairs(parts) do if M.IsJoined(p) then
        local key=Key(p.pos);at[key]=at[key] or {};at[key][#at[key]+1]=p
    end end
    local entries,slots,groupParts={},{},{};cache.rebuiltParts=0
    for _,p in ipairs(parts) do if M.IsJoined(p) then
        local slot=M.Slot(p);local signature={p.type,p.rot,p.color,p.g,table.unpack(p.pos)}
        local neighbours={p}
        for _,d in ipairs(Data.dirs) do
            local cover=0
            for _,q in ipairs(at[Key({p.pos[1]+d[1],p.pos[2]+d[2],p.pos[3]+d[3]})] or {}) do
                neighbours[#neighbours+1]=q
                if M.Slot(q)==slot then cover=cover|Face(q,{-d[1],-d[2],-d[3]}) end
            end
            signature[#signature+1]=(Face(p,d)&~cover)==0
        end
        local old=cache.parts and cache.parts[p.id];local same=old~=nil
        if same then for i,v in ipairs(signature) do if old.signature[i]~=v then same=false;break end end end
        local entry=old
        if not same then
            local surface=M.Build(neighbours,false,nil,p)
            entry={signature=signature,surface=surface[slot]};cache.rebuiltParts=cache.rebuiltParts+1
        end
        entries[p.id]=entry
        slots[slot]=slots[slot] or {};slots[slot][#slots[slot]+1]=entry
        groupParts[p.g]=groupParts[p.g] or {};groupParts[p.g][#groupParts[p.g]+1]=entry
    end end
    local function Streams(lists,previous,build)
        local result={}
        for key,list in pairs(lists) do
            local old=previous and previous[key];local same=old and #old.parts==#list
            if same then for i,entry in ipairs(list) do if old.parts[i]~=entry then same=false;break end end end
            result[key]=same and old or {parts=list,value=build(list)}
        end
        return result
    end
    local function Append(to,from) for i=1,#from do to[#to+1]=from[i] end end
    cache.slots=Streams(slots,cache.slots,function(list)
        local out={position={},normal={},colors={}}
        for _,entry in ipairs(list) do for _,field in ipairs({'position','normal','colors'}) do Append(out[field],entry.surface[field]) end end
        return out
    end)
    cache.groups=Streams(groupParts,cache.groups,function(list)
        local out={};for _,entry in ipairs(list) do Append(out,entry.surface.position) end;return out
    end)
    cache.parts=entries
    local out,groups={},{}
    for slot,stream in pairs(cache.slots) do out[slot]=stream.value end
    for group,stream in pairs(cache.groups) do groups[group]=stream.value end
    return out,groups
end
-- Equivalent to source THREE.EdgesGeometry(positions, 20): omit coplanar
-- triangle diagonals and internal cell divisions, retain boundaries/creases.
function M.Edges(pos)
    local pending,out={},{};local threshold=math.cos(20*math.pi/180)
    local function Hash(v)
        return table.concat({math.floor(v[1]*10000+.5),math.floor(v[2]*10000+.5),math.floor(v[3]*10000+.5)},',')
    end
    local function Emit(a,b) out[#out+1]=a;out[#out+1]=b end
    for i=1,#pos,9 do
        local v={{pos[i],pos[i+1],pos[i+2]},{pos[i+3],pos[i+4],pos[i+5]},{pos[i+6],pos[i+7],pos[i+8]}}
        local u={v[3][1]-v[2][1],v[3][2]-v[2][2],v[3][3]-v[2][3]};local w={v[1][1]-v[2][1],v[1][2]-v[2][2],v[1][3]-v[2][3]}
        local n=Rot.Cross(u,w);local len=math.sqrt(Rot.Dot(n,n));if len>1e-12 then
            for a=1,3 do n[a]=n[a]/len end
            for j=1,3 do local a,b=v[j],v[j%3+1];local h,k=Hash(a),Hash(b);local key=h..'|'..k;local reverse=k..'|'..h
                if h~=k then
                    local edge=pending[reverse]
                    if edge then if Rot.Dot(n,edge.n)<=threshold then Emit(a,b) end;pending[reverse]=false
                    elseif pending[key]==nil then pending[key]={a=a,b=b,n=n} end
                end
            end
        end
    end
    for _,edge in pairs(pending) do if edge then Emit(edge.a,edge.b) end end
    return out
end
return M
