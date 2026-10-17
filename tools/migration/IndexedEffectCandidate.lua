-- Rejected isolated Batch experiment; only fixture preparation copies it to dev.
local Base=require 'render.EffectBatch'
local Coord=require 'core.Coord'
local BaseNew=Base.New
local M={};M.__index=M;setmetatable(M,{__index=Base})
local function UpdateBounds(self,bounds)
    self.model:SetBoundingBox(bounds)
    -- Pending Native dynamic-bounds gate; keep notification in one place.
    self.model:SendEvent('ReloadFinished')
    self.mesh:MarkForUpdate()
end
function M.New(root,kind,limit,shaderDirectory)
    assert(limit>=0 and limit%1==0,'nonnegative integer batch limit')
    local self=BaseNew(root,kind,limit,shaderDirectory);setmetatable(self,M)
    self.mesh:Dispose();self.mesh=self.node:CreateComponent('StaticModel')
    self.mesh.castShadows=false;self.mesh.enabled=false
    self.vb=VertexBuffer:new();self.vb:SetShadowed(true)
    self.ib=IndexBuffer:new();self.ib:SetShadowed(true)
    self.geometry=Geometry:new();self.model=Model:new();self.data=VectorBuffer()
    local elements={VertexElement(TYPE_VECTOR3,SEM_POSITION),VertexElement(TYPE_VECTOR3,SEM_NORMAL),
        VertexElement(TYPE_UBYTE4_NORM,SEM_COLOR),VertexElement(TYPE_VECTOR2,SEM_TEXCOORD,0)}
    if kind=='Streak' then elements[#elements+1]=VertexElement(TYPE_VECTOR4,SEM_TANGENT) end
    local capacity=math.max(1,limit);self.largeIndices=capacity*4>65536
    assert(self.vb:SetSize(capacity*4,elements,true),'indexed candidate VB size')
    assert(self.ib:SetSize(capacity*6,self.largeIndices,false),'indexed candidate IB size')
    local indices=VectorBuffer()
    for quad=0,capacity-1 do for _,corner in ipairs({0,1,2,2,1,3}) do
        if self.largeIndices then indices:WriteUInt(quad*4+corner) else indices:WriteUShort(quad*4+corner) end
    end end
    assert(self.ib:SetData(indices),'indexed candidate IB upload');indices:Clear()
    assert(self.geometry:SetVertexBuffer(0,self.vb),'indexed candidate VB binding')
    self.geometry:SetIndexBuffer(self.ib)
    assert(self.geometry:SetDrawRange(TRIANGLE_LIST,0,0,0,0,true),'indexed candidate empty draw range')
    self.model:SetNumGeometries(1);assert(self.model:SetGeometry(0,0,self.geometry),'indexed candidate model binding')
    self.model:SetBoundingBox(BoundingBox(Vector3.ZERO,Vector3(.001,.001,.001)))
    self.mesh:SetModel(self.model);self.mesh:SetMaterial(self.material)
    return self
end
function M:Begin(camera,time)
    Base.Begin(self,camera,time);self.data:Clear()
    self.minX=math.huge;self.minY=math.huge;self.minZ=math.huge
    self.maxX=-math.huge;self.maxY=-math.huge;self.maxZ=-math.huge
end
function M:Quad(points,uvs,color,alpha,params)
    if self.count>=self.limit then return end
    if not self.started then self.material:SetShaderParameter('clock',Variant(self.time));self.started=true end
    self.count=self.count+1
    local intensity=math.max(1,alpha)
    local tint=Color(color[1]*intensity/16,color[2]*intensity/16,color[3]*intensity/16,math.min(1,alpha)):ToUInt()
    local normal=Vector3(params and params[1] or 0,params and params[2] or 0,params and params[3] or 0)
    local tangent=self.kind=='Streak' and Vector4(params and params[4] or .85,0,0,1)
    local data=self.data
    for corner=1,4 do
        local p,uv=points[corner],uvs[corner];local native=Coord.Vec(p[1],p[2],p[3])
        data:WriteVector3(native);data:WriteVector3(normal);data:WriteUInt(tint);data:WriteVector2(Vector2(uv[1],uv[2]))
        if tangent then data:WriteVector4(tangent) end
        self.minX=math.min(self.minX,native.x);self.minY=math.min(self.minY,native.y);self.minZ=math.min(self.minZ,native.z)
        self.maxX=math.max(self.maxX,native.x);self.maxY=math.max(self.maxY,native.y);self.maxZ=math.max(self.maxZ,native.z)
    end
end
function M:Finish()
    local count=self.count
    if count>0 then
        assert(self.vb:SetDataRange(self.data,0,count*4,true),'indexed candidate active VB upload')
        assert(self.geometry:SetDrawRange(TRIANGLE_LIST,0,count*6,0,count*4,true),'indexed candidate draw range')
        UpdateBounds(self,BoundingBox(Vector3(self.minX,self.minY,self.minZ),Vector3(self.maxX,self.maxY,self.maxZ)))
    else
        assert(self.geometry:SetDrawRange(TRIANGLE_LIST,0,0,0,0,true),'indexed candidate empty draw range')
    end
    self.mesh.enabled=count>0
end
function M:Dispose()
    if self.disposed then return end;self.disposed=true
    self.node:Dispose();self.material:Dispose();self.model:Dispose()
    self.geometry:Dispose();self.vb:Dispose();self.ib:Dispose();self.data:Clear()
end
return M
