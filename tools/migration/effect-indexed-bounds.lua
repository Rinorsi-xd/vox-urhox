-- Isolated dynamic-bounds gate. No production replacement or CPU claim.
local Batch=require 'render.EffectBatch'
local output=''
for _,arg in ipairs(GetArguments()) do output=arg:match('^%-probe%-output=(.+)$') or output end
local rows,cleanup={},{}
local owned={}
local checks=0
---@type Scene|nil
local scene=nil
---@type thread|nil
local worker=nil
local function Check(ok,message) checks=checks+1;assert(ok,message) end
local function Vec(v) return {v.x,v.y,v.z} end
local function Box(b) return {min=Vec(b.min),max=Vec(b.max)} end
local function EqualBox(a,b,label)
    for _,key in ipairs({'min','max'}) do
        for _,axis in ipairs({'x','y','z'}) do
            Check(a[key][axis]==b[key][axis],label..'.'..key..'.'..axis..' '..tostring(a[key][axis])..' ~= '..tostring(b[key][axis]))
        end
    end
end
local function Present() for _=1,4 do coroutine.yield() end end
local function Close()
    renderer:SetNumViewports(0)
    for _,entry in ipairs(owned) do
        local ok,err=pcall(entry.object.Dispose,entry.object)
        cleanup[#cleanup+1]={object=entry.name,ok=ok,error=not ok and tostring(err) or nil}
    end
    owned={}
    if scene then scene:Dispose();scene=nil end
end
local function Own(name,object) owned[#owned+1]={name=name,object=object};return object end
local function Run()
    Check(output~='','Pass unique absolute -probe-output=path.json')
    local prior=io.open(output,'rb');if prior then prior:close();error('Preserve prior result; choose unique output') end
    local ok,err=xpcall(function()
        scene=Scene();local octree=scene:CreateComponent('Octree')
        local cameraNode=scene:CreateChild('Camera');cameraNode.position=Vector3(0,0,-12)
        local camera=cameraNode:CreateComponent('Camera');camera.fov=45;camera.nearClip=.1;camera.farClip=100
        renderer:SetViewport(0,Viewport:new(scene,camera))
        local baseline=Batch.New(scene,'Glow',2)
        Own('baseline',baseline)
        local node=Own('node',scene:CreateChild('DynamicIndexedBounds'))
        local mesh=node:CreateComponent('StaticModel');mesh.castShadows=false;mesh.enabled=false
        local vb=Own('vb',VertexBuffer:new());vb:SetShadowed(true)
        local ib=Own('ib',IndexBuffer:new());ib:SetShadowed(true)
        local geometry=Own('geometry',Geometry:new());local model=Own('model',Model:new())
        local elements={VertexElement(TYPE_VECTOR3,SEM_POSITION),VertexElement(TYPE_VECTOR3,SEM_NORMAL),
            VertexElement(TYPE_UBYTE4_NORM,SEM_COLOR),VertexElement(TYPE_VECTOR2,SEM_TEXCOORD,0)}
        Check(vb:SetSize(8,elements,true),'dynamic VB capacity')
        Check(ib:SetSize(12,false,false),'ushort IB capacity')
        local indexData=VectorBuffer()
        for quad=0,1 do for _,i in ipairs({0,1,2,2,1,3}) do Check(indexData:WriteUShort(quad*4+i),'index write') end end
        Check(ib:SetData(indexData),'index upload');indexData:Clear()
        Check(geometry:SetVertexBuffer(0,vb),'bind vertex buffer');geometry:SetIndexBuffer(ib)
        Check(geometry:SetDrawRange(TRIANGLE_LIST,0,0,0,0,true),'empty draw range')
        model:SetNumGeometries(1);Check(model:SetGeometry(0,0,geometry),'bind geometry')
        model:SetBoundingBox(BoundingBox(Vector3(-.5,-.5,1.875),Vector3(.5,.5,2.125)))
        mesh:SetModel(model);mesh:SetMaterial(baseline.material)
        local function Submit(label,count,shift,size,expectedVisible,transform)
            node.position=transform and transform.position or Vector3.ZERO
            node.scale=transform and transform.scale or Vector3.ONE
            node.rotation=transform and transform.rotation or Quaternion.IDENTITY
            baseline.node.position=node.position;baseline.node.scale=node.scale;baseline.node.rotation=node.rotation
            baseline:Begin({0,0,-12},1.25)
            local data=VectorBuffer();local tight=BoundingBox()
            local normal=Vector3(.3,0,0);local tint=Color(.1,.04,.01,.8)
            for quad=1,count do
                local x=shift+(quad-1)*size*3;local half=size*.5
                -- Nonflat, binary-exact depths exercise real tight bounds without
                -- Model's separately observed sanitation of zero-width axes.
                local points={{x-half,half,1.875},{x+half,half,2.125},{x-half,-half,2.125},{x+half,-half,1.875}}
                local uvs={{-1,-1},{1,-1},{-1,1},{1,1}}
                baseline:Quad(points,uvs,{1.6,.64,.16},.8,{.3,0,0})
                for corner=1,4 do
                    local p=points[corner];local native=Vector3(-p[1],p[2],p[3]);tight:Merge(native)
                    Check(data:WriteVector3(native),'position write');Check(data:WriteVector3(normal),'normal write')
                    Check(data:WriteUInt(tint:ToUInt()),'color write')
                    Check(data:WriteVector2(Vector2(uvs[corner][1],uvs[corner][2])),'UV write')
                end
            end
            baseline:Finish()
            if count>0 then Check(vb:SetDataRange(data,0,count*4,true),'active upload') end
            data:Clear();Check(geometry:SetDrawRange(TRIANGLE_LIST,0,count*6,0,count*4,true),'active draw range')
            mesh.enabled=count>0
            local before=Box(mesh:GetBoundingBox())
            if count>0 then
                EqualBox(tight,baseline.mesh:GetBoundingBox(),label..' active baseline bounds')
                model:SetBoundingBox(tight)
                -- This notification route is a hypothesis until this gate passes.
                model:SendEvent('ReloadFinished')
                mesh:MarkForUpdate()
                EqualBox(model:GetBoundingBox(),tight,label..' model bounds')
                EqualBox(mesh:GetBoundingBox(),tight,label..' notified local bounds')
                EqualBox(mesh:GetWorldBoundingBox(),baseline.mesh:GetWorldBoundingBox(),label..' transformed world bounds')
            end
            Present()
            local found,baselineFound=false,false;local queryRows={}
            for _,result in ipairs(octree:GetDrawables(camera.frustum)) do
                local drawable=result.drawable
                local id=drawable:GetID()
                if id==mesh:GetID() then found=true end
                if id==baseline.mesh:GetID() then baselineFound=true end
                queryRows[#queryRows+1]={nodeName=result.node.name,nodeId=result.node:GetID(),drawableId=id,
                    inView=drawable.inView,worldBounds=Box(drawable:GetWorldBoundingBox())}
            end
            rows[#rows+1]={label=label,count=count,beforeLocalBounds=before,modelBounds=Box(model:GetBoundingBox()),
                localBounds=Box(mesh:GetBoundingBox()),worldBounds=Box(mesh:GetWorldBoundingBox()),
                expectedVisible=expectedVisible,frustumFound=found,inView=mesh.inView,empty=geometry:IsEmpty(),
                queryRows=queryRows,meshId=mesh:GetID(),baselineId=baseline.mesh:GetID(),
                baselineFound=baselineFound,baselineInView=baseline.mesh.inView,
                baselineWorldBounds=Box(baseline.mesh:GetWorldBoundingBox()),
                frustumModelIntersection=camera.frustum:IsInside(mesh:GetWorldBoundingBox()),
                frustumBaselineIntersection=camera.frustum:IsInside(baseline.mesh:GetWorldBoundingBox()),
                camera={position=Vec(cameraNode.position),fov=camera.fov,aspectRatio=camera.aspectRatio,nearClip=camera.nearClip,farClip=camera.farClip}}
            Check(found==expectedVisible,label..' octree frustum membership')
            Check(baselineFound==expectedVisible,label..' baseline octree frustum membership')
            Check(mesh.inView==expectedVisible,label..' rendered inView')
            Check(baseline.mesh.inView==expectedVisible,label..' baseline rendered inView')
            Check(geometry:IsEmpty()==(count==0),label..' geometry empty state')
        end
        Submit('initial-empty',0,0,1,false)
        Submit('one-small',1,0,1,true)
        Submit('growth',2,-2,2,true)
        Submit('shrink',1,0,.5,true)
        Submit('vertex-move-out',1,80,.5,false)
        Submit('vertex-reenter',1,0,.5,true)
        Submit('node-move-out',1,0,1,false,{position=Vector3(80,0,0),scale=Vector3.ONE,rotation=Quaternion.IDENTITY})
        Submit('node-transform-reenter',1,0,1,true,{position=Vector3(1,0,0),scale=Vector3(2,1,2),rotation=Quaternion(30,Vector3.UP)})
        Submit('empty-after-visible',0,0,1,false)
        Submit('repopulate-after-empty',1,0,1,true)
    end,debug.traceback)
    Close()
    local clean=true;for _,entry in ipairs(cleanup) do if not entry.ok then clean=false end end
    local result={status=ok and clean and 'BOUNDS_PASS' or 'FAIL',checks=checks,error=not ok and tostring(err) or nil,
        rows=rows,cleanup=cleanup,boundary='Dynamic tight active Model and StaticModel bounds, actual frustum membership/inView and lifecycle gate only. No CPU benefit, shader/pixel parity, production readiness or device FPS claim.'}
    local file=assert(io.open(output,'wb'));file:write(cjson.encode(result));file:close();engine:Exit()
end
function Start()
    engine.maxFps=60;engine.maxInactiveFps=60
    worker=coroutine.create(Run);SubscribeToEvent('Update','IndexedBoundsUpdate')
end
function IndexedBoundsUpdate()
    if not worker or coroutine.status(worker)=='dead' then return end
    local ok,err=coroutine.resume(worker)
    if not ok then print('[IndexedBounds] FAIL '..tostring(err));Close();engine:Exit() end
end
