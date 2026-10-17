-- Port of the frozen H5 projectDecal: UV/depth clipping and convex-edge folding.
local JoinedSurface=require("render.JoinedSurface")
local PartAssets=require("parts.PartAssets")

local Rot=require 'core.Rotations'
local Models=require 'render.LiveryModel'
local M={}
-- Grid cells between the decal and the painted surface (H5 LIFT).
local LIFT=.012
local function Dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function Cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function Normalize(a) local len=math.sqrt(Dot(a,a));if len<1e-12 then return {0,0,0} end;return {a[1]/len,a[2]/len,a[3]/len} end
M.Dot=Dot;M.Sub=Sub;M.Cross=Cross;M.Normalize=Normalize
function M.Frame(d)
    local n=Normalize(d.n);local ref=math.abs(n[2])>.85 and {0,0,n[2]>0 and 1 or -1} or {0,1,0}
    local x=Normalize(Cross(ref,n));local y=Cross(n,x);local cs,sn=math.cos(d.r or 0),math.sin(d.r or 0)
    local rx,ry={},{};for k=1,3 do rx[k]=x[k]*cs+y[k]*sn;ry[k]=y[k]*cs-x[k]*sn end
    return {x=rx,y=ry,n=n,p=d.p}
end
function M.Size(d,s) local w=d.w;local h=w/(s.aspect or 1);return w,h,math.min(5,math.max(1.6,math.max(w,h)*.35)) end
function M.ToWorld(f,v) local q={};for k=1,3 do q[k]=f.p[k]+f.x[k]*v[1]+f.y[k]*v[2]+f.n[k]*v[3] end;return q end
function M.Near(d,s,parts)
    local w,h,depth=M.Size(d,s);local reach=math.max(w,h)+depth/2+1.5;local out={}
    for _,p in ipairs(parts) do if Models.Fixed(p) then
        for _,c in ipairs(p._cells or {p.pos}) do
            if math.abs(c[1]-d.p[1])<reach and math.abs(c[2]+.5-d.p[2])<reach and math.abs(c[3]-d.p[3])<reach then out[#out+1]=p;break end
        end
    end end;return out
end
-- Integer key of a frame-space point quantised to 1e-4 cell (21 bits per axis).
local function WeldKey(v)
    return ((math.floor(v[1]*1e4+.5)+1048576)<<42)|((math.floor(v[2]*1e4+.5)+1048576)<<21)|(math.floor(v[3]*1e4+.5)+1048576)
end
local function Clip(pts,axis,sign,lim)
    local out={};for i,p in ipairs(pts) do
        local q=pts[i%#pts+1];local dp,dq=lim-sign*p[axis],lim-sign*q[axis]
        if dp>=0 then out[#out+1]=p end
        if (dp>=0)~=(dq>=0) then local k=dp/(dp-dq);local v={};for j=1,8 do v[j]=p[j]+(q[j]-p[j])*k end;out[#out+1]=v end
    end;return out
end
-- Group a mesh's triangles by geometric facing. Each cluster keeps a bounding
-- sphere and a normal cone, so whole faces of a part can be rejected at once.
local function Clusters(tris)
    local byKey,list={},{}
    for _,tri in ipairs(tris) do
        local a,b,c=tri[1],tri[2],tri[3]
        local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
        local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx;local len=math.sqrt(nx*nx+ny*ny+nz*nz)
        local key
        if len<1e-9 then key='degenerate';nx,ny,nz=0,0,0
        else nx,ny,nz=nx/len,ny/len,nz/len;key=math.floor(nx*2+.5)..','..math.floor(ny*2+.5)..','..math.floor(nz*2+.5) end
        local cl=byKey[key]
        if not cl then
            cl={id=#list+1,sx=0,sy=0,sz=0,normals={},lo={math.huge,math.huge,math.huge},hi={-math.huge,-math.huge,-math.huge},degenerate=key=='degenerate'}
            byKey[key]=cl;list[#list+1]=cl
        end
        tri.k=cl.id;cl.sx,cl.sy,cl.sz=cl.sx+nx,cl.sy+ny,cl.sz+nz;cl.normals[#cl.normals+1]={nx,ny,nz}
        for _,v in ipairs(tri) do for k=1,3 do cl.lo[k]=math.min(cl.lo[k],v[k]);cl.hi[k]=math.max(cl.hi[k],v[k]) end end
    end
    for _,cl in ipairs(list) do
        local c={(cl.lo[1]+cl.hi[1])/2,(cl.lo[2]+cl.hi[2])/2,(cl.lo[3]+cl.hi[3])/2}
        cl.c=c;cl.r=math.sqrt((cl.hi[1]-c[1])^2+(cl.hi[2]-c[2])^2+(cl.hi[3]-c[3])^2)
        local len=math.sqrt(cl.sx^2+cl.sy^2+cl.sz^2);local minCos=-1
        if not cl.degenerate and len>1e-9 then
            cl.axis={cl.sx/len,cl.sy/len,cl.sz/len};minCos=1
            for _,n in ipairs(cl.normals) do minCos=math.min(minCos,n[1]*cl.axis[1]+n[2]*cl.axis[2]+n[3]*cl.axis[3]) end
        end
        cl.cone=math.acos(math.max(-1,math.min(1,minCos)));cl.normals=nil;cl.lo=nil;cl.hi=nil
    end
    return list
end
-- True only when every triangle of the cluster faces the decal at nz < -.3
-- (the per-triangle facing rejection), with a margin for rounding.
local function FacesAway(cl,fn)
    if not cl.axis or cl.cone>=math.pi then return false end
    local a=cl.axis;local d=a[1]*fn[1]+a[2]*fn[2]+a[3]*fn[3]
    local phi=math.acos(math.max(-1,math.min(1,d)))
    return math.cos(math.max(0,phi-cl.cone-1e-3))< -.3-1e-3
end
-- Part meshes rotated once per (model data, rotation). Weak keys follow the
-- bounded LiveryModel cache. Each layer records a local bounding sphere.
local rotatedCache=setmetatable({},{__mode='k'})
local function Rotated(data,rot)
    local byRot=rotatedCache[data];if not byRot then byRot={};rotatedCache[data]=byRot end
    local out=byRot[rot];if out then return out end
    out={};local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for i,mesh in ipairs(data) do
        local tris={}
        for t,tri in ipairs(mesh.triangles) do
            local rotated={}
            for j,v in ipairs(tri) do
                local point=Rot.ApplyRot(rot,{v[1],v[2],v[3]});local normal=Rot.ApplyRot(rot,{v[4],v[5],v[6]})
                rotated[j]={point[1],point[2],point[3],normal[1],normal[2],normal[3]}
                for k=1,3 do lo[k]=math.min(lo[k],point[k]);hi[k]=math.max(hi[k],point[k]) end
            end
            tris[t]=rotated
        end
        out[i]={slot=mesh.slot,triangles=tris,worldAxes=true,clusters=Clusters(tris)}
    end
    if lo[1]<=hi[1] then
        local c={(lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2}
        local r=math.sqrt((hi[1]-c[1])^2+(hi[2]-c[2])^2+(hi[3]-c[3])^2)
        out.bound={c=c,r=r}
    end
    byRot[rot]=out;return out
end
-- Scalar replica of the per-triangle tests below (same operations and order, so
-- bit-identical). Returns false only when the triangle is certainly dropped:
-- depth/facing rejection, or all three folded corners outside one clip edge.
local function Survives(tri,pos,dp,fx,fy,fn,w,h,depth)
    local a,b,c=tri[1],tri[2],tri[3]
    local qx,qy,qz=a[1]+pos[1]-dp[1],a[2]+pos[2]+.5-dp[2],a[3]+pos[3]-dp[3]
    local ax,ay,az=qx*fx[1]+qy*fx[2]+qz*fx[3],qx*fy[1]+qy*fy[2]+qz*fy[3],qx*fn[1]+qy*fn[2]+qz*fn[3]
    qx,qy,qz=b[1]+pos[1]-dp[1],b[2]+pos[2]+.5-dp[2],b[3]+pos[3]-dp[3]
    local bx,by,bz=qx*fx[1]+qy*fx[2]+qz*fx[3],qx*fy[1]+qy*fy[2]+qz*fy[3],qx*fn[1]+qy*fn[2]+qz*fn[3]
    qx,qy,qz=c[1]+pos[1]-dp[1],c[2]+pos[2]+.5-dp[2],c[3]+pos[3]-dp[3]
    local cx,cy,cz=qx*fx[1]+qy*fx[2]+qz*fx[3],qx*fy[1]+qy*fy[2]+qz*fy[3],qx*fn[1]+qy*fn[2]+qz*fn[3]
    local hi=math.max(az,bz,cz);local lo=math.min(az,bz,cz)
    if not (hi>=-math.max(w,h) and lo<=depth/2) then return false end
    local ux,uy,uz=bx-ax,by-ay,bz-az;local vx,vy,vz=cx-ax,cy-ay,cz-az
    local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
    local nlen=math.sqrt(nx*nx+ny*ny+nz*nz)
    if nlen<1e-12 then nx,ny,nz=0,0,0 else nx,ny,nz=nx/nlen,ny/nlen,nz/nlen end
    local fold=nz<.22;local len=math.sqrt(nx^2+ny^2)
    if not (nz>=-.3 and (not fold and hi>=-depth/2 or fold and len>=.5 and hi<=.05)) then return false end
    local tx,ty=fold and nx/len or 0,fold and ny/len or 0
    local a7,b7,c7=ax-az*tx,bx-bz*tx,cx-cz*tx
    local hw,hh=w/2,h/2
    if a7>hw and b7>hw and c7>hw or a7< -hw and b7< -hw and c7< -hw then return false end
    local a8,b8,c8=ay-az*ty,by-bz*ty,cy-cz*ty
    if a8>hh and b8>hh and c8>hh or a8< -hh and b8< -hh and c8< -hh then return false end
    return true
end
-- Joined block geometry stays inside its unit cell.
local JOINED_BOUND={c={0,0,0},r=math.sqrt(.75)}
-- True only when no point of the sphere can produce a kept, unclipped triangle.
local function PartOutside(bound,pos,dp,fx,fy,fn,w,h,nearDepth,farDepth)
    if not bound then return false end
    local c=bound.c;local r=bound.r*1.001+1e-4
    local qx,qy,qz=c[1]+pos[1]-dp[1],c[2]+pos[2]+.5-dp[2],c[3]+pos[3]-dp[3]
    local x=qx*fx[1]+qy*fx[2]+qz*fx[3];local y=qx*fy[1]+qy*fy[2]+qz*fy[3];local z=qx*fn[1]+qy*fn[2]+qz*fn[3]
    if z+r<nearDepth or z-r>farDepth then return true end
    -- Folding shifts x/y by at most |depth| (unit tx/ty); bound that by the sphere.
    local reachZ=math.max(math.abs(z-r),math.abs(z+r))
    return math.abs(x)-r-reachZ>w/2 or math.abs(y)-r-reachZ>h/2
end
-- pause, when given, is called between parts so callers can time-slice.
function M.Project(d,s,parts,pause)
    local f=M.Frame(d);local w,h,depth=M.Size(d,s);local out={}
    local Surface=JoinedSurface
    local _,_,joined=Surface.Build(parts,true)
    -- Lift along the vertex normal welded across all parts: faces sharing a point get one
    -- lifted position, so bevels, hard edges and part joins stay closed (a per-face lift
    -- opened cracks there that showed the base paint). Opposed normals (touching hidden
    -- faces of adjacent parts) are not averaged together.
    local lift={};local pending={}
    -- Exact early-outs: a triangle is kept only when its frame depth range meets
    -- [-max(w,h),depth/2] and its folded x/y can reach the clip box. Whole parts
    -- whose bounding sphere cannot satisfy that are skipped, and per-triangle
    -- depth is tested with scalars before any vertex table is built.
    local nearDepth,farDepth=-math.max(w,h),depth/2
    local fx,fy,fn=f.x,f.y,f.n;local dp=d.p
    for _,p in ipairs(parts) do
        if pause then pause() end
        local layers={}
        if joined[p.id] then
            local surface=joined[p.id];local triangles={}
            for i=1,#surface.position,9 do local tri={}
                for j=0,2 do local k=i+j*3;tri[#tri+1]={surface.position[k]-p.pos[1],surface.position[k+1]-p.pos[2]-.5,surface.position[k+2]-p.pos[3],surface.normal[k],surface.normal[k+1],surface.normal[k+2]} end
                triangles[#triangles+1]=tri
            end
            layers[1]={{slot=Surface.Slot(p),triangles=triangles,worldAxes=true}}
        else
            for _,layer in ipairs(PartAssets.Get(p.type,p.rot).whole.layers) do layers[#layers+1]=Rotated(Models.Read(layer),p.rot) end
        end
        for _,layer in ipairs(layers) do
        local bound=layer.bound or JOINED_BOUND
        if not PartOutside(bound,p.pos,dp,fx,fy,fn,w,h,nearDepth,farDepth) then
        for _,mesh in ipairs(layer) do if not Models.Skip(mesh.slot) then
            local culled=nil
            if mesh.clusters then
                culled={}
                for i,cl in ipairs(mesh.clusters) do
                    culled[i]=FacesAway(cl,fn) or PartOutside(cl,p.pos,dp,fx,fy,fn,w,h,nearDepth,farDepth)
                end
            end
            for _,tri in ipairs(mesh.triangles) do
                if not (culled and culled[tri.k]) and Survives(tri,p.pos,dp,fx,fy,fn,w,h,depth) then
                local verts={};for _,v in ipairs(tri) do
                    local point,normal={v[1],v[2],v[3]},{v[4],v[5],v[6]}
                    local q={point[1]+p.pos[1]-d.p[1],point[2]+p.pos[2]+.5-d.p[2],point[3]+p.pos[3]-d.p[3]}
                    verts[#verts+1]={Dot(q,f.x),Dot(q,f.y),Dot(q,f.n),Dot(normal,f.x),Dot(normal,f.y),Dot(normal,f.n)}
                end
                local a,b,c=verts[1],verts[2],verts[3];local hi=math.max(a[3],b[3],c[3]);local lo=math.min(a[3],b[3],c[3])
                if hi>=-math.max(w,h) and lo<=depth/2 then
                    local fn=Normalize(Cross(Sub(b,a),Sub(c,a)));local fold=fn[3]<.22
                    local len=math.sqrt(fn[1]^2+fn[2]^2)
                    if fn[3]>=-.3 and (not fold and hi>=-depth/2 or fold and len>=.5 and hi<=.05) then
                        local tx,ty=fold and fn[1]/len or 0,fold and fn[2]/len or 0
                        for _,v in ipairs(verts) do v[7]=v[1]-v[3]*tx;v[8]=v[2]-v[3]*ty end
                        local poly=Clip(Clip(Clip(Clip(verts,7,1,w/2),7,-1,w/2),8,1,h/2),8,-1,h/2)
                        poly=Clip(poly,3,1,depth/2);if not fold then poly=Clip(poly,3,-1,depth/2) end
                        local entries={}
                        for j,v in ipairs(poly) do
                            local key=WeldKey(v)
                            local nx,ny,nz=v[4],v[5],v[6];local len2=nx*nx+ny*ny+nz*nz
                            if len2<1e-12 then nx,ny,nz=fn[1],fn[2],fn[3] else len2=1/math.sqrt(len2);nx,ny,nz=nx*len2,ny*len2,nz*len2 end
                            local list=lift[key];if not list then list={};lift[key]=list end
                            list[#list+1]=nx;list[#list+1]=ny;list[#list+1]=nz
                            local n={};for k=1,3 do n[k]=f.x[k]*v[4]+f.y[k]*v[5]+f.n[k]*v[6] end
                            entries[j]={v=v,key=key,nx=nx,ny=ny,nz=nz,n=n,u=.5+(d.f and d.f~=0 and -1 or 1)*v[7]/w,uv=1-(.5+v[8]/h)}
                        end
                        for i=2,#poly-1 do
                            pending[#pending+1]=entries[1];pending[#pending+1]=entries[i];pending[#pending+1]=entries[i+1]
                        end
                    end
                end
                end
            end
        end end
        end
        end
    end
    for _,e in ipairs(pending) do
        if not e.p then
            local list=lift[e.key];local sx,sy,sz=0,0,0
            for i=1,#list,3 do
                local x,y,z=list[i],list[i+1],list[i+2]
                if x*e.nx+y*e.ny+z*e.nz>-.1 then sx,sy,sz=sx+x,sy+y,sz+z end
            end
            local len=math.sqrt(sx*sx+sy*sy+sz*sz);if len<1e-6 then sx,sy,sz,len=e.nx,e.ny,e.nz,1 end
            local v=e.v;local k=LIFT/len;e.p=M.ToWorld(f,{v[1]+sx*k,v[2]+sy*k,v[3]+sz*k})
        end
        out[#out+1]={p=e.p,n=e.n,u=e.u,v=e.uv}
    end;return out
end
return M
