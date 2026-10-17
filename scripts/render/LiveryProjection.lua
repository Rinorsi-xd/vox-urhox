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
function M.Project(d,s,parts)
    local f=M.Frame(d);local w,h,depth=M.Size(d,s);local out={}
    local Surface=JoinedSurface
    local _,_,joined=Surface.Build(parts,true)
    -- Lift along the vertex normal welded across all parts: faces sharing a point get one
    -- lifted position, so bevels, hard edges and part joins stay closed (a per-face lift
    -- opened cracks there that showed the base paint). Opposed normals (touching hidden
    -- faces of adjacent parts) are not averaged together.
    local lift={};local pending={}
    for _,p in ipairs(parts) do
        local layers={}
        if joined[p.id] then
            local surface=joined[p.id];local triangles={}
            for i=1,#surface.position,9 do local tri={}
                for j=0,2 do local k=i+j*3;tri[#tri+1]={surface.position[k]-p.pos[1],surface.position[k+1]-p.pos[2]-.5,surface.position[k+2]-p.pos[3],surface.normal[k],surface.normal[k+1],surface.normal[k+2]} end
                triangles[#triangles+1]=tri
            end
            layers[1]={{slot=Surface.Slot(p),triangles=triangles,worldAxes=true}}
        else
            for _,layer in ipairs(PartAssets.Get(p.type,p.rot).whole.layers) do layers[#layers+1]=Models.Read(layer) end
        end
        for _,layer in ipairs(layers) do for _,mesh in ipairs(layer) do if not Models.Skip(mesh.slot) then
            for _,tri in ipairs(mesh.triangles) do
                local verts={};for _,v in ipairs(tri) do
                    local point,normal={v[1],v[2],v[3]},{v[4],v[5],v[6]}
                    if not mesh.worldAxes then point=Rot.ApplyRot(p.rot,point);normal=Rot.ApplyRot(p.rot,normal) end
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
        end end end
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
