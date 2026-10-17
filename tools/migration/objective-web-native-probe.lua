-- Separate untimed native ownership/readback proof. Real Commit is counted.
local Config=assert(G1_OBJECTIVE_CONFIG)
local function Module(source,name)
    local instrumented,count=source:gsub('self%.mesh:Commit%(%)','self.mesh:Commit();self.nativeCommits=(self.nativeCommits or 0)+1')
    assert(count>0,'Real Commit observation required')
    return assert(load(instrumented,name))()
end
local modules={Module(G1_OBJECTIVE_BEFORE,'@NativeBefore.lua'),Module(G1_OBJECTIVE_CANDIDATE,'@NativeCandidate.lua')}
local scene=nil ---@type Scene?
local worker=nil ---@type thread?
local function Vector(v)return {v.x,v.y,v.z}end
local function Capture(view)
    local out={commits=view.nativeCommits,batches={}};local names={}
    for name in pairs(view.batches)do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names)do
        local batch=view.batches[name];local mesh=batch.mesh;local q=batch.node.rotation
        local row={name=name,enabled=mesh.enabled,position=Vector(batch.node.position),scale=Vector(batch.node.scale),rotation={q.w,q.x,q.y,q.z},vertices={}}
        assert(mesh:GetNumGeometries()==1)
        for i=0,mesh:GetNumVertices(0)-1 do local v=mesh:GetVertex(0,i);row.vertices[#row.vertices+1]={position=Vector(v.position),normal=Vector(v.normal),color=v.color}end
        row.vertexCount=#row.vertices;out.batches[#out.batches+1]=row
    end
    return out
end
local comparisons={fields=0,vertices=0,batches=0}
local function Equal(a,b)
    assert(type(a)==type(b),'Native readback type differs')
    if type(a)=='table'then for k,v in pairs(a)do Equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'Extra native field')end
    else assert(a==b,'Native readback field differs');comparisons.fields=comparisons.fields+1 end
end
local function Run()
    local baseline,observations={},{}
    for variant,module in ipairs(modules)do
        for _,kind in ipairs({'conquest','escort'})do
            scene=Scene();scene:CreateComponent('Octree')
            local cameraNode=scene:CreateChild('Camera');local camera=cameraNode:CreateComponent('Camera');camera.farClip=600
            renderer:SetViewport(0,Viewport:new(scene,camera))
            local mode={id=kind,points={{pos={0,0,0},radius=22},{pos={-60,0,20},radius=24},{pos={60,0,20},radius=18}},bases={blue={aim={-45,0,-50}},red={aim={45,0,50}}},path={{-50,0,-50},{0,0,0},{50,0,50}},cum={0,70.71,141.42},length=141.42,tuning={checkpoints={.5}}}
            function mode:At(s)return {pos={s*100-50,0,s*100-50}}end
            local view=module.New({scene=scene},mode)
            for i=1,120 do
                local outside=i>=85 and i<100
                cameraNode.position=outside and Vector3(0,35,180) or Vector3(0,65,-145)
                cameraNode:LookAt(outside and Vector3(0,35,400) or Vector3(0,0,0))
                view:Update(1/60,{points={{v=.3,owner='blue'},{v=-.7,owner='red',contested=true},{v=.9,owner='none'}},score={blue=75,red=95},shield={blue=true,red=false},s=i/120,idle=i%12,pushing=i%2,contested=i%5==0},cameraNode)
                coroutine.yield()
            end
            local data=Capture(view)
            if variant==1 then baseline[kind]=data else
                Equal(baseline[kind],data)
                for _,row in ipairs(data.batches)do comparisons.batches=comparisons.batches+1;comparisons.vertices=comparisons.vertices+row.vertexCount end
            end
            observations[#observations+1]={variant=variant==1 and 'before' or 'candidate',case=kind,commits=data.commits,batches=#data.batches,vertices=(function()local n=0;for _,r in ipairs(data.batches)do n=n+r.vertexCount end;return n end)(),viewport={width=graphics:GetWidth(),height=graphics:GetHeight()},camera=Vector(cameraNode.position)}
            print('OBJECTIVE_WEB_CPU_SNAPSHOT '..cjson.encode({label=variant==1 and 'before' or 'candidate',case=kind}))
            repeat coroutine.yield()until input:GetKeyPress(KEY_F8)
            view:Dispose();renderer:SetViewport(0,nil);scene:Dispose();scene=nil;coroutine.yield()
        end
    end
    local result={status='PASS',configuration=Config,identity=G1_OBJECTIVE_IDENTITY,nativeComparison={status='PASS',comparisons=comparisons,observations=observations},boundary='Untimed real Web GetNumVertices/GetVertex readback of all batch vertex position/normal/color and enabled/node pose. Same 120-step rule/dt/camera sequence. Counts increment only after actual native Commit returns. No CPU timing or FPS claim.'}
    local text=cjson.encode(result);local count=math.ceil(#text/3500)
    for i=1,count do print('OBJECTIVE_WEB_CPU_CHUNK '..cjson.encode({index=i,count=count,data=text:sub((i-1)*3500+1,i*3500)}))end
end
function Start()worker=coroutine.create(Run);SubscribeToEvent('Update','ObjectiveNativeUpdate')end
function ObjectiveNativeUpdate()
    if coroutine.status(worker)=='dead'then return end
    local ok,message=coroutine.resume(worker)
    if not ok then print('ERROR: Objective native comparison '..tostring(message))end
end
function Stop()UnsubscribeFromEvent('Update');if scene then scene:Dispose();scene=nil end end
