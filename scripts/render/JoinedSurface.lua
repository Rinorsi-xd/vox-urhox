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
function M.Build(parts,collectParts)
    local at,out,groups,byPart={},{},{},{}
    for _,p in ipairs(parts) do if M.IsJoined(p) then local k=Key(p.pos);at[k]=at[k] or {};at[k][#at[k]+1]=p end end
    for _,p in ipairs(parts) do if M.IsJoined(p) then
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
