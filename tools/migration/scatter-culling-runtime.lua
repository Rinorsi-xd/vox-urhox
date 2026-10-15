-- Separate validator entry; production and baked-map inputs remain untouched.
cache:AddResourceDir('tools/migration',false)
local Core=require 'scatter-culling-core'
local scene,environment,camera,sceneFile,request,records,variants,phase
local cases,current,remaining,lastMs,samples,report
local savedFps,savedInactive
local function Read(path)
    local file=File(path,FILE_READ);local value=cjson.decode(file:ReadString());file:Dispose();return value
end
local function Write(path,value)
    local file=File(path,FILE_WRITE);file:WriteString(cjson.encode(value));file:Dispose()
end
local function Vec(v)return Vector3(v[1],v[2],v[3])end
local function Percentile(values,p)
    local ordered={};for i,v in ipairs(values)do ordered[i]=v end;table.sort(ordered)
    return ordered[math.max(1,math.ceil(#ordered*p))]
end
local function Stats(values)
    local total=0;local spikes=0
    for _,v in ipairs(values)do total=total+v;if v>100 then spikes=spikes+1 end end
    return{median=Percentile(values,.5),p95=Percentile(values,.95),max=Percentile(values,1),mean=total/#values,above100=spikes}
end
local function GroupState()
    local selected={};local all={}
    if current.mode=='original'then for _,record in ipairs(records)do all[#all+1]=record.group end
    else for _,item in ipairs(variants[current.mode].groups)do all[#all+1]=item.group end end
    local visible=0;local count=0
    for _,group in ipairs(all)do
        local inView=group:IsInView(camera);local bound=group.worldBoundingBox
        if inView then visible=visible+1;count=count+group.numInstanceNodes end
        local minDistance,maxDistance=math.huge,0
        for i=1,group.numInstanceNodes do
            local p=group:GetInstanceNode(i-1).worldPosition
            local d=(p-camera.node.worldPosition).length
            minDistance=math.min(minDistance,d);maxDistance=math.max(maxDistance,d)
        end
        selected[#selected+1]={id=group.ID,instances=group.numInstanceNodes,inView=inView,drawDistance=group.drawDistance,
            center={bound.center.x,bound.center.y,bound.center.z},centerDistance=(bound.center-camera.node.worldPosition).length,
            minInstanceDistance=minDistance,maxInstanceDistance=maxDistance}
    end
    return{groups=#all,visibleGroups=visible,instancesInVisibleGroups=count,items=selected}
end
local function Cleanup()
    if variants then Core.Restore(records,variants);variants=nil end
    renderer:SetViewport(0,nil)
    if environment then environment:Dispose();environment=nil end
    if sceneFile then sceneFile:Dispose();sceneFile=nil end
    if scene then scene:Dispose();scene=nil end
    if savedFps then engine.maxFps=savedFps;engine.maxInactiveFps=savedInactive end
end
local function Finish()
    Core.Select(records,variants,'original',false)
    for _,variant in pairs(variants)do V.assert(Core.Validate(records,variant)==4160,'all 4160 source instances preserved after run '..variant.size)end
    report.result='MEASURED';report.completed=true;Write(request.out..'/native.json',report)
    Cleanup();phase='done'
    -- V.finish does not end the validator frame budget. Keep the isolated blank
    -- tail uncapped by the hidden-window 10 FPS limit until its report is saved.
    engine.maxFps=200;engine.maxInactiveFps=200
    print('SCATTER_CULLING MEASURED '..request.out);V.finish()
end
local function NextCase()
    local nextCase=cases[#report.cases+1]
    if not nextCase then Finish();return end
    current=nextCase;Core.Select(records,variants,current.mode,current.unlimited)
    camera.node.position=Vec(current.position);camera.node:LookAt(Vec(current.target));camera.fov=55
    samples={wall={},step={},batches={},triangles={},graphicsBatches={},graphicsTriangles={}}
    remaining=request.settleFrames;phase='settle';lastMs=nil
    print('SCATTER_CULLING setup '..current.name..' '..current.mode..' '..current.range)
end
local function SaveCase()
    -- Screenshots and group enumeration happen after samples, never in steady data.
    local result={name=current.name,mode=current.mode,range=current.range,repeatBaseline=current.repeatBaseline,
        position=current.position,target=current.target,fov=camera.fov,frames=#samples.wall,raw=samples,
        wallMs=Stats(samples.wall),engineStepMs=Stats(samples.step),batches=Stats(samples.batches),triangles=Stats(samples.triangles),
        graphicsBatches=Stats(samples.graphicsBatches),graphicsTriangles=Stats(samples.graphicsTriangles),groups=GroupState()}
    local image=Image:new();assert(graphics:TakeScreenShot(image),'Cannot read native framebuffer')
    result.image=current.name..'-'..current.range..'-'..current.mode..(current.repeatBaseline and '-repeat'or'')..'.png'
    assert(image:SavePNG(request.out..'/'..result.image),'Cannot save experiment screenshot');image:Dispose()
    report.cases[#report.cases+1]=result;Write(request.out..'/partial.json',report);NextCase()
end
local function PrepareCases()
    cases={};local poses={
        {name='south-yard',position={0,8,-170},target={0,4,-80}},
        {name='crater-road',position={140,12,-40},target={35,1,0}},
        {name='wreck-edge',position={0,25,70},target={0,0,0}}}
    local widest=records[1];local radius=-1
    for _,record in ipairs(records)do
        local box=record.group.worldBoundingBox
        if box.size.length>radius then radius=box.size.length;widest=record end
    end
    local center=widest.group.worldBoundingBox.center;local instance=widest.instances[1].node.worldPosition
    local direction=Vector3(instance.x-center.x,0,instance.z-center.z)
    if direction.length<.1 then direction=Vector3(1,0,0)else direction=direction:Normalized()end
    local limit=widest.fields.drawDistance
    for _,offset in ipairs({-2,2})do
        local p=center+direction*(limit+offset)+Vector3(0,6,0)
        poses[#poses+1]={name=offset<0 and'distance-inside'or'distance-outside',position={p.x,p.y,p.z},
            target={instance.x,instance.y,instance.z},distanceDiagnostic=true}
    end
    report.distanceFixture={sourceGroup=widest.id,drawDistance=limit,sourceBoundsSize=radius,
        center={center.x,center.y,center.z},targetInstance=widest.instances[1].id,
        note='Authored target-group views around source bounding-center distance. Pixel pairs and unlimited controls detect changed range behavior; inView counts are per group, not proof each instance was drawn.'}
    for _,pose in ipairs(poses)do
        local ranges=pose.distanceDiagnostic and{'limited','unlimited-diagnostic'}or{'limited'}
        for _,range in ipairs(ranges)do for _,mode in ipairs({'original','32','64','original-repeat'})do
            cases[#cases+1]={name=pose.name,range=range,unlimited=range~='limited',position=pose.position,target=pose.target,
                mode=mode=='original-repeat'and'original'or mode,repeatBaseline=mode=='original-repeat'}
        end end
    end
end
local function Bind()
    local node=scene:CreateChild('QA_ScatterCamera');camera=node:CreateComponent('Camera')
    camera.nearClip=.1;camera.farClip=1500
    environment:Update(1,node)
    records,report.instances=Core.Snapshot(scene:GetComponents('StaticModelGroup',true),'Crater/mesh-293.bin')
    V.assert(#records==36 and report.instances==4160,'actual hotspot 36 original groups and 4160 instances')
    variants={['32']=Core.Build(records,32),['64']=Core.Build(records,64)}
    report.partitions={original=#records,cell32=#variants['32'].groups,cell64=#variants['64'].groups}
    for _,variant in pairs(variants)do V.assert(Core.Validate(records,variant)==4160,'partition preserves source resources and affine transforms '..variant.size)end
    -- Native counters compare one frozen authored scene with the default render path.
    -- This intentionally does not construct another game or alter production post effects.
    renderer:SetViewport(0,Viewport:new(scene,camera));PrepareCases();NextCase()
end
local function Tick()
    if not scene then return end
    if phase=='scene'then
        if scene.asyncLoading then return end
        sceneFile:Dispose();sceneFile=nil;math.randomseed(1337)
        environment=require('scene.Crater').New(scene,require('drive.CraterLayout').Read());phase='environment';return
    end
    if phase=='environment'then
        if require('app.SceneLoader').EnvironmentReady({},scene)then Bind()end;return
    end
    if phase=='settle'then
        remaining=remaining-1
        if remaining<=0 then phase='sample';lastMs=Time:GetSystemTime()end
        return
    end
    if phase~='sample'then return end
    local now=Time:GetSystemTime();samples.wall[#samples.wall+1]=now-lastMs;lastMs=now
    samples.step[#samples.step+1]=GetTime():GetTimeStep()*1000
    samples.batches[#samples.batches+1]=renderer:GetNumBatches();samples.triangles[#samples.triangles+1]=renderer:GetNumPrimitives()
    samples.graphicsBatches[#samples.graphicsBatches+1]=graphics:GetNumBatches();samples.graphicsTriangles[#samples.graphicsTriangles+1]=graphics:GetNumPrimitives()
    if #samples.wall>=request.sampleFrames then SaveCase()end
end
local function Update()
    local ok,message=xpcall(Tick,debug.traceback)
    if not ok then
        if report then report.result='FAILED';report.failure=tostring(message);Write(request.out..'/native.json',report)end
        Cleanup();phase='failed';engine.maxFps=200;engine.maxInactiveFps=200;V.assert(false,tostring(message));V.finish()
    end
end
V.atFrame(2,function()
    request=Read('.tmp/scatter-culling-request.json')
    savedFps=engine.maxFps;savedInactive=engine.maxInactiveFps;engine.maxFps=200;engine.maxInactiveFps=200
    report={result='RUNNING',cases={},scope='Native frozen authored Crater scene/default render path; static culling attribution, not six-car battle/Web/phone acceptance.',
        configuration={width=graphics:GetWidth(),height=graphics:GetHeight(),api=graphics.apiName,multiSample=graphics.multiSample,
            vSync=graphics.vSync,drawShadows=renderer.drawShadows,dynamicInstancing=renderer.dynamicInstancing,
            maxFps=engine.maxFps,maxInactiveFps=engine.maxInactiveFps,settleFrames=request.settleFrames,sampleFrames=request.sampleFrames},
        provenance=request.provenance}
    scene=Scene();scene.asyncLoadingMs=3;sceneFile=assert(cache:GetFile('Scenes/Crater.xml'))
    assert(scene:LoadAsyncXML(sceneFile,LOAD_SCENE_AND_RESOURCES));phase='scene';SubscribeToEvent('Update',Update)
end)
