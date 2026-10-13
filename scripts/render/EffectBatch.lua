-- Bounded shared batches, never one scene node/material per particle. Source-space
-- positions cross the handedness boundary here. RGB / 16 preserves HDR in UNORM8.
local V=require "core.Math3"
local Coord=require "core.Coord"
local M={};M.__index=M
function M.New(root,kind,limit,shaderDirectory)
    local self=setmetatable({},M)
    self.node=root:CreateChild(kind);self.mesh=self.node:CreateComponent("CustomGeometry")
    self.mesh.dynamic=true;self.mesh.castShadows=false
    self.mesh.enabled=false
    self.material=Material:new();assert(self.material:SetSurfaceShader((shaderDirectory or "Shaders/BLGL/Combat/")..kind..".shader"))
    self.material.renderOrder=142;self.mesh.material=self.material
    self.limit=limit;self.count=0;return self
end
function M:Begin(camera,time)
    self.count=0;self.camera=camera
    self.mesh:BeginGeometry(0,TRIANGLE_LIST)
    self.material:SetShaderParameter("clock",Variant(time))
end
local order={1,2,3,3,2,4}
function M:Quad(points,uvs,color,alpha,params)
    if self.count>=self.limit then return end
    self.count=self.count+1
    local tint=Color(color[1]/16,color[2]/16,color[3]/16,math.min(1,alpha))
    local normal=Vector3(table.unpack(params or {0,0,0}))
    for _,i in ipairs(order) do
        self.mesh:DefineVertex(Coord.Vec(table.unpack(points[i])))
        self.mesh:DefineNormal(normal);self.mesh:DefineColor(tint);self.mesh:DefineTexCoord(Vector2(table.unpack(uvs[i])))
    end
end
local function Offset(p,v,k) return V.Add(p,V.Scale(v,k)) end
function M:Segment(a,b,width,color,alpha,core,u0,u1,streak)
    local dir=V.Normalize(V.Sub(b,a));local side=V.Cross(dir,V.Normalize(V.Sub(a,self.camera)))
    if V.Length(side)<.00001 then side={0,1,0} else side=V.Normalize(side) end
    local length=V.Length(V.Sub(b,a));local tip=streak and Offset(b,dir,width*.5) or b
    local points={Offset(a,side,-width*.5),Offset(a,side,width*.5),Offset(tip,side,-width*.5),Offset(tip,side,width*.5)}
    local finish=streak and length+width*.5 or (u1 or 1)
    self:Quad(points,{{streak and 0 or (u0 or 0),-1},{streak and 0 or (u0 or 0),1},{finish,-1},{finish,1}},
        color,alpha,{core or .3,streak and length or 0,streak and width or 0})
end
function M:Disc(pos,size,color,alpha,right,up,thick)
    local r,u=V.Scale(right,size*.5),V.Scale(up,size*.5)
    self:Quad({V.Sub(V.Sub(pos,r),u),V.Add(V.Sub(pos,u),r),V.Add(V.Sub(pos,r),u),V.Add(V.Add(pos,r),u)},
        {{-1,-1},{1,-1},{-1,1},{1,1}},color,alpha,{thick or .18,0,0})
end
function M:Finish()
    self.mesh.enabled=self.count>0
    -- Empty geometry needs no GPU upload and must not retain a visible old batch.
    if self.count>0 then self.mesh:Commit() end
end
function M:Dispose() self.node:Dispose();self.material:Dispose() end
return M
