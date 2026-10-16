-- Port of the frozen H5 projectDecal: UV/depth clipping and convex-edge folding.
local JoinedSurface=require("render.JoinedSurface")
local PartAssets=require("parts.PartAssets")

local Rot=require 'core.Rotations'
local Models=require 'render.LiveryModel'
local M={}
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
                        for i=2,#poly-1 do for _,v in ipairs({poly[1],poly[i],poly[i+1]}) do
                            local q=M.ToWorld(f,{v[1]+fn[1]*.012,v[2]+fn[2]*.012,v[3]+fn[3]*.012})
                            local n={};for k=1,3 do n[k]=f.x[k]*v[4]+f.y[k]*v[5]+f.n[k]*v[6] end
                            out[#out+1]={p=q,n=n,u=.5+(d.f and d.f~=0 and -1 or 1)*v[7]/w,v=1-(.5+v[8]/h)}
                        end end
                    end
                end
            end
        end end end
    end;return out
end
return M
