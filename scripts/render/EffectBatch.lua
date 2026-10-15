-- Bounded shared batches, never one scene node/material per particle. Source-space
-- positions cross the handedness boundary here. RGB / 16 preserves HDR in UNORM8.
local Coord=require "core.Coord"
local M={};M.__index=M
function M.New(root,kind,limit,shaderDirectory)
    local self=setmetatable({},M)
    self.node=root:CreateChild(kind);self.mesh=self.node:CreateComponent("CustomGeometry")
    self.mesh.dynamic=true;self.mesh.castShadows=false
    self.mesh.enabled=false
    self.material=Material:new();assert(self.material:SetSurfaceShader((shaderDirectory or "Shaders/BLGL/Combat/")..kind..".shader"))
    self.material.renderOrder=kind=='Smoke' and 139 or kind=='Glow' and 143 or 142
    self.mesh.material=self.material
    self.limit=limit;self.count=0;self.kind=kind
    self.points={{0,0,0},{0,0,0},{0,0,0},{0,0,0}}
    self.uvs={{0,0},{0,0},{0,0},{0,0}};self.params={0,0,0}
    return self
end
function M:Begin(camera,time)
    self.count=0;self.camera=camera;self.time=time;self.started=false
end
local order={1,2,3,3,2,4}
function M:Quad(points,uvs,color,alpha,params)
    if self.count>=self.limit then return end
    if not self.started then
        self.mesh:BeginGeometry(0,TRIANGLE_LIST)
        self.material:SetShaderParameter("clock",Variant(self.time));self.started=true
    end
    self.count=self.count+1
    local intensity=math.max(1,alpha)
    local tint=Color(color[1]*intensity/16,color[2]*intensity/16,color[3]*intensity/16,math.min(1,alpha))
    local normal=Vector3(params and params[1] or 0,params and params[2] or 0,params and params[3] or 0)
    local tangent=self.kind=='Streak' and Vector4(params and params[4] or .85,0,0,1)
    for _,i in ipairs(order) do
        self.mesh:DefineVertex(Coord.Vec(table.unpack(points[i])))
        self.mesh:DefineNormal(normal);self.mesh:DefineColor(tint);self.mesh:DefineTexCoord(Vector2(table.unpack(uvs[i])))
        if tangent then self.mesh:DefineTangent(tangent) end
    end
end
local function SetPoint(p,x,y,z) p[1]=x;p[2]=y;p[3]=z end
local function SetUV(p,u,v) p[1]=u;p[2]=v end
function M:Segment(a,b,width,color,alpha,core,u0,u1,streak,taper)
    if self.count>=self.limit then return end
    local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
    local length=math.sqrt(dx*dx+dy*dy+dz*dz);local inverse=length>0 and 1/length or 1
    dx=dx*inverse;dy=dy*inverse;dz=dz*inverse
    local cx,cy,cz=a[1]-self.camera[1],a[2]-self.camera[2],a[3]-self.camera[3]
    local cameraLength=math.sqrt(cx*cx+cy*cy+cz*cz);local cameraInverse=cameraLength>0 and 1/cameraLength or 1
    cx=cx*cameraInverse;cy=cy*cameraInverse;cz=cz*cameraInverse
    local sx,sy,sz=dy*cz-dz*cy,dz*cx-dx*cz,dx*cy-dy*cx
    local sideLength=math.sqrt(sx*sx+sy*sy+sz*sz)
    if sideLength<.00001 then sx=0;sy=1;sz=0
    else local sideInverse=1/sideLength;sx=sx*sideInverse;sy=sy*sideInverse;sz=sz*sideInverse end
    local half=width*.5;local tx,ty,tz=b[1],b[2],b[3]
    if streak then tx=tx+dx*half;ty=ty+dy*half;tz=tz+dz*half end
    local points,uvs,params=self.points,self.uvs,self.params
    SetPoint(points[1],a[1]+sx*-half,a[2]+sy*-half,a[3]+sz*-half)
    SetPoint(points[2],a[1]+sx*half,a[2]+sy*half,a[3]+sz*half)
    SetPoint(points[3],tx+sx*-half,ty+sy*-half,tz+sz*-half)
    SetPoint(points[4],tx+sx*half,ty+sy*half,tz+sz*half)
    local finish=streak and length+width*.5 or (u1 or 1)
    local start=streak and 0 or (u0 or 0)
    SetUV(uvs[1],start,-1);SetUV(uvs[2],start,1);SetUV(uvs[3],finish,-1);SetUV(uvs[4],finish,1)
    SetPoint(params,core or .3,streak and length or 0,streak and width or 0)
    params[4]=taper or .85
    self:Quad(points,uvs,color,alpha,params)
end
function M:Disc(pos,size,color,alpha,right,up,thick,profile)
    if self.count>=self.limit then return end
    local half=size*.5;local rx,ry,rz=right[1]*half,right[2]*half,right[3]*half
    local ux,uy,uz=up[1]*half,up[2]*half,up[3]*half
    local points,uvs,params=self.points,self.uvs,self.params
    SetPoint(points[1],pos[1]-rx-ux,pos[2]-ry-uy,pos[3]-rz-uz)
    SetPoint(points[2],pos[1]-ux+rx,pos[2]-uy+ry,pos[3]-uz+rz)
    SetPoint(points[3],pos[1]-rx+ux,pos[2]-ry+uy,pos[3]-rz+uz)
    SetPoint(points[4],pos[1]+rx+ux,pos[2]+ry+uy,pos[3]+rz+uz)
    SetUV(uvs[1],-1,-1);SetUV(uvs[2],1,-1);SetUV(uvs[3],-1,1);SetUV(uvs[4],1,1)
    SetPoint(params,thick or .18,profile or 0,0);self:Quad(points,uvs,color,alpha,params)
end
function M:Finish()
    self.mesh.enabled=self.count>0
    -- Empty geometry needs no GPU upload and must not retain a visible old batch.
    if self.count>0 then self.mesh:Commit() end
end
function M:Dispose() self.node:Dispose();self.material:Dispose() end
return M
