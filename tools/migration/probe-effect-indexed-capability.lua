-- Isolated capability check, not a production renderer or performance benchmark.
-- Based on examples/24-model-painter.lua's VectorBuffer/Geometry/Model route.
local Batch=require 'render.EffectBatch'
local output=''
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local order={1,2,3,3,2,4}
local rows,screens,cleanupRows={},{},{}
local pairsOwned={}
---@type Scene|nil
local scene=nil
---@type thread|nil
local worker=nil
local checks=0
local function Check(ok,message) checks=checks+1;assert(ok,message) end
local function Vec(v) return {v.x,v.y,v.z} end
local function Box(b) return {min=Vec(b.min),max=Vec(b.max)} end
local function Equal(a,b,label)
    if type(a)=='table' then
        for key,value in pairs(a) do Equal(value,b[key],label..'.'..tostring(key)) end
        for key in pairs(b) do Check(a[key]~=nil,label..' extra field') end
    else Check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
end
local function ClosePair(pair)
    if pair.closed then return end
    pair.closed=true
    -- Candidate borrows baseline's material, so detach its node first.
    for _,key in ipairs({'node','model','geometry','vb','ib'}) do
        local object=pair[key]
        if object then
            local ok,err=pcall(object.Dispose,object)
            cleanupRows[#cleanupRows+1]={kind=pair.kind,object=key,ok=ok,error=not ok and tostring(err) or nil}
            if not ok then pair.cleanupFailed=true end
            pair[key]=nil
        end
    end
    if pair.baseline then
        local ok,err=pcall(pair.baseline.Dispose,pair.baseline)
        cleanupRows[#cleanupRows+1]={kind=pair.kind,object='baseline',ok=ok,error=not ok and tostring(err) or nil}
        if not ok then pair.cleanupFailed=true end
        pair.baseline=nil
    end
end
local function Fixture(index)
    local shift=index==2 and 2.5 or -2.5
    return {
        points={{shift-1,1,2},{shift+1,1,2},{shift-1,-1,2},{shift+1,-1,2}},
        uvs={{0,-1},{0,1},{4,-1},{4,1}},color={2.2,.6,.15},
        alpha=index==2 and 2 or .7,params={.3,4,2,.85},
    }
end
local function NewPair(kind)
    local pair={kind=kind,closed=false};pairsOwned[#pairsOwned+1]=pair
    pair.baseline=Batch.New(scene,kind,2)
    pair.vb=VertexBuffer:new();pair.vb:SetShadowed(true)
    pair.ib=IndexBuffer:new();pair.ib:SetShadowed(true)
    pair.geometry=Geometry:new();pair.model=Model:new()
    local elements={VertexElement(TYPE_VECTOR3,SEM_POSITION),VertexElement(TYPE_VECTOR3,SEM_NORMAL),
        VertexElement(TYPE_UBYTE4_NORM,SEM_COLOR),VertexElement(TYPE_VECTOR2,SEM_TEXCOORD,0)}
    if kind=='Streak' then elements[#elements+1]=VertexElement(TYPE_VECTOR4,SEM_TANGENT) end
    Check(pair.vb:SetSize(8,elements,true),'dynamic VB SetSize')
    Check(pair.vb:IsDynamic() and pair.vb:IsShadowed(),'dynamic shadowed VB')
    Check(pair.vb:GetVertexSize()==(kind=='Streak' and 52 or 36),'packed vertex stride')
    for _,element in ipairs({{TYPE_VECTOR3,SEM_POSITION,0},{TYPE_VECTOR3,SEM_NORMAL,12},
        {TYPE_UBYTE4_NORM,SEM_COLOR,24},{TYPE_VECTOR2,SEM_TEXCOORD,28}}) do
        Check(pair.vb:GetElementOffset(element[1],element[2],0)==element[3],'vertex element offset')
    end
    if kind=='Streak' then Check(pair.vb:GetElementOffset(TYPE_VECTOR4,SEM_TANGENT,0)==36,'tangent offset') end
    Check(pair.ib:SetSize(12,false,false),'fixed ushort indices')
    local indices=VectorBuffer()
    for quad=0,1 do for _,corner in ipairs(order) do Check(indices:WriteUShort(quad*4+corner-1),'index write') end end
    Check(pair.ib:SetData(indices),'fixed index upload');indices:Clear()
    Check(pair.geometry:SetVertexBuffer(0,pair.vb),'bind VB');pair.geometry:SetIndexBuffer(pair.ib)
    Check(pair.geometry:SetDrawRange(TRIANGLE_LIST,0,0,0,0,true),'initial empty draw range')
    pair.model:SetNumGeometries(1);Check(pair.model:SetGeometry(0,0,pair.geometry),'bind geometry')
    -- Non-degenerate, binary-exact Z extent avoids Model's observed flat-box
    -- expansion. Vertex positions and every attribute equality stay unchanged.
    -- Fixed capacity bounds conservatively cover every input in this small probe.
    -- This does not claim same-Model dynamic bounds changes notify StaticModel.
    pair.bounds=BoundingBox(Vector3(-3.5,-1,1.875),Vector3(3.5,1,2.125))
    pair.model:SetBoundingBox(pair.bounds)
    pair.node=scene:CreateChild('Indexed'..kind);pair.mesh=pair.node:CreateComponent('StaticModel')
    pair.mesh:SetModel(pair.model);pair.mesh:SetMaterial(pair.baseline.material)
    pair.mesh.castShadows=false;pair.mesh.enabled=false
    return pair
end
local function Decode(data,index,stride,kind)
    data:Seek(index*stride)
    local p,n,c,uv=data:ReadVector3(),data:ReadVector3(),data:ReadUInt(),data:ReadVector2()
    local value={position=Vec(p),normal=Vec(n),color=c,uv={uv.x,uv.y}}
    if kind=='Streak' then local t=data:ReadVector4();value.tangent={t.x,t.y,t.z,t.w} end
    return value
end
local function Actual(vertex,kind)
    local value={position=Vec(vertex.position),normal=Vec(vertex.normal),color=vertex.color,
        uv={vertex.texCoord.x,vertex.texCoord.y}}
    if kind=='Streak' then local t=vertex.tangent;value.tangent={t.x,t.y,t.z,t.w} end
    return value
end
local function Submit(pair,requested,revision)
    local baseline=pair.baseline;baseline:Begin({0,0,-12},1.25)
    local data=VectorBuffer();local count=math.min(2,requested);local writes=0
    for quad=1,requested do
        local source=Fixture(quad)
        if revision==2 then source.alpha=-.2;source.params=nil
        elseif revision==4 then source.alpha=0 end
        baseline:Quad(source.points,source.uvs,source.color,source.alpha,source.params)
        if quad<=count then
            local alpha,params=source.alpha,source.params
            local intensity=math.max(1,alpha)
            local tint=Color(source.color[1]*intensity/16,source.color[2]*intensity/16,
                source.color[3]*intensity/16,math.min(1,alpha))
            local normal=Vector3(params and params[1] or 0,params and params[2] or 0,params and params[3] or 0)
            local packed=tint:ToUInt()
            for corner=1,4 do
                local p,uv=source.points[corner],source.uvs[corner]
                Check(data:WriteVector3(Vector3(-p[1],p[2],p[3])),'position write')
                Check(data:WriteVector3(normal),'normal write');Check(data:WriteUInt(packed),'packed color write')
                Check(data:WriteVector2(Vector2(uv[1],uv[2])),'UV write');writes=writes+4
                if pair.kind=='Streak' then
                    Check(data:WriteVector4(Vector4(params and params[4] or .85,0,0,1)),'tangent write');writes=writes+1
                end
            end
        end
    end
    baseline:Finish()
    local stride=pair.vb:GetVertexSize()
    Check(data:GetSize()==count*4*stride,'active data byte size')
    if count>0 then Check(pair.vb:SetDataRange(data,0,count*4,true),'dynamic active upload') end
    data:Clear()
    Check(pair.geometry:SetDrawRange(TRIANGLE_LIST,0,count*6,0,count*4,true),'active draw range')
    pair.mesh.enabled=count>0;pair.mesh:MarkForUpdate()
    Check(pair.geometry:GetIndexStart()==0 and pair.geometry:GetIndexCount()==count*6,'index draw range')
    Check(pair.geometry:GetVertexStart()==0 and pair.geometry:GetVertexCount()==count*4,'vertex draw range')
    Check(pair.geometry:GetPrimitiveType()==TRIANGLE_LIST,'triangle type')
    Check(pair.geometry:IsEmpty()==(count==0),'empty geometry state')
    Check(baseline.count==count and baseline.mesh.enabled==pair.mesh.enabled,'count/visibility parity')
    Equal(Box(pair.model:GetBoundingBox()),Box(pair.bounds),'capacity model bounds')
    Equal(Box(pair.mesh:GetBoundingBox()),Box(pair.bounds),'capacity drawable local bounds')
    Equal(Box(pair.mesh:GetWorldBoundingBox()),Box(pair.bounds),'identity world bounds')
    local vertices,indices=pair.vb:GetData(),pair.ib:GetData();local submitted={}
    Check(vertices:GetSize()==8*stride,'shadow buffer capacity');Check(indices:GetSize()==24,'index buffer capacity')
    indices:Seek(0)
    for vertex=0,count*6-1 do
        local index=indices:ReadUShort();local expected=math.floor(vertex/6)*4+order[vertex%6+1]-1
        Check(index==expected,'fixed index topology')
        local value=Decode(vertices,index,stride,pair.kind)
        Equal(value,Actual(baseline.mesh:GetVertex(0,vertex),pair.kind),'deindexed native vertex '..vertex)
        submitted[#submitted+1]=value
    end
    vertices:Clear();indices:Clear()
    rows[#rows+1]={kind=pair.kind,revision=revision,requested=requested,quads=count,attributeWrites=writes,
        baselineAttributeSubmissions=count*6*(pair.kind=='Streak' and 5 or 4),
        activeIndices=count*6,activeVertices=count*4,capacityBounds=Box(pair.bounds),vertices=submitted,
        baselineActiveBounds=count>0 and Box(baseline.mesh:GetBoundingBox()) or nil,
        boundary='Counts are structural API submissions, not measured CPU costs. Capacity bounds may be looser than active bounds.'}
end
local function Present()
    for _=1,4 do coroutine.yield() end
end
local function Screenshot(pair,variant)
    pair.baseline.mesh.enabled=variant=='baseline';pair.mesh.enabled=variant=='indexed'
    Present()
    local image=Image:new();local filename=output:gsub('%.json$','')..'-'..pair.kind..'-'..variant..'.png'
    local ok,err=pcall(function()
        local prior=io.open(filename,'rb');if prior then prior:close();error('Preserve prior PNG; choose unique output') end
        Check((variant=='baseline' and pair.baseline.mesh.inView) or (variant=='indexed' and pair.mesh.inView),
            'active drawable reached viewport')
        Check(graphics:TakeScreenShot(image),'screenshot readback')
        Check(image:SavePNG(filename),'screenshot PNG save')
    end)
    image:Dispose();assert(ok,err)
    screens[#screens+1]={kind=pair.kind,variant=variant,path=filename,width=graphics:GetWidth(),height=graphics:GetHeight(),
        baselineInView=variant=='baseline' and pair.baseline.mesh.inView or false,
        indexedInView=variant=='indexed' and pair.mesh.inView or false}
end
local function Run()
    Check(output~='','Pass a unique -probe-output=absolute.json path')
    local prior=io.open(output,'rb');if prior then prior:close();error('Preserve prior result; choose unique output') end
    local ok,err=xpcall(function()
        scene=Scene();scene:CreateComponent('Octree')
        local cameraNode=scene:CreateChild('Camera');cameraNode.position=Vector3(0,0,-12)
        local camera=cameraNode:CreateComponent('Camera');camera.fov=45;camera.nearClip=.1;camera.farClip=50
        renderer:SetViewport(0,Viewport:new(scene,camera))
        for _,kind in ipairs({'Glow','Streak'}) do
            local pair=NewPair(kind)
            for revision,requested in ipairs({0,1,3,1,0}) do
                Submit(pair,requested,revision)
                if revision==3 then Screenshot(pair,'baseline');Screenshot(pair,'indexed') else Present() end
            end
            ClosePair(pair);Check(not pair.cleanupFailed,'pair Dispose calls')
            Check(scene:GetChild('Indexed'..kind)==nil and scene:GetChild(kind)==nil,'disposed nodes detached')
        end
    end,debug.traceback)
    renderer:SetNumViewports(0)
    for _,pair in ipairs(pairsOwned) do ClosePair(pair) end
    if scene then scene:Dispose();scene=nil end
    local cleanupOk=true;for _,row in ipairs(cleanupRows) do if not row.ok then cleanupOk=false end end
    local result={status=ok and cleanupOk and 'CAPABILITY_PASS' or 'FAIL',error=not ok and tostring(err) or nil,
        checks=checks,rows=rows,screens=screens,cleanup=cleanupRows,
        boundary='One Glow and Streak, native shadow-buffer deindex equality and exact packed attributes. '
            ..'Fixed conservative capacity bounds; no dynamic-tight-bounds notification claim. '
            ..'Saved screenshots still require nonblank/pixel/visual review and clean native logs. '
            ..'Not a production candidate, CPU benchmark, render parity acceptance or target-device FPS result.'}
    local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
function Start()
    engine.maxFps=60;engine.maxInactiveFps=60
    worker=coroutine.create(Run);SubscribeToEvent('Update','IndexedCapabilityUpdate')
end
function IndexedCapabilityUpdate()
    if not worker or coroutine.status(worker)=='dead' then return end
    local ok,err=coroutine.resume(worker)
    if not ok then print('[IndexedCapability] FAIL '..tostring(err));engine:Exit() end
end
