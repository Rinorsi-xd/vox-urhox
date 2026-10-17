-- Dedicated actual Web geometry fixture. No App, gameplay or mocked bindings.
local Config=assert(G1_OBJECTIVE_CONFIG)
local Identity=assert(G1_OBJECTIVE_IDENTITY)
local Before=assert(load(G1_OBJECTIVE_BEFORE,'@ObjectiveBefore.lua'))()
local Candidate=assert(load(G1_OBJECTIVE_CANDIDATE,'@ObjectiveCandidate.lua'))()
local clock=function()return Time:GetSystemTime()end
local scene=nil ---@type Scene?
local worker=nil ---@type thread?
local finished=false
local function Emit(result)
    if finished then return end;finished=true
    local text=cjson.encode(result);local count=math.ceil(#text/3500)
    for index=1,count do print('OBJECTIVE_WEB_CPU_CHUNK '..cjson.encode({index=index,count=count,data=text:sub((index-1)*3500+1,index*3500)})) end
end
local function Fixture(module,kind)
    scene=Scene();scene:CreateComponent('Octree')
    local cameraNode=scene:CreateChild('Camera');local camera=cameraNode:CreateComponent('Camera')
    camera.farClip=600;camera.nearClip=.1
    local viewport=Viewport:new(scene,camera);renderer:SetViewport(0,viewport)
    local mode
    if kind=='conquest' then
        mode={id=kind,points={{pos={0,0,0},radius=22},{pos={-60,0,20},radius=24},{pos={60,0,20},radius=18}},bases={blue={aim={-45,0,-50}},red={aim={45,0,50}}}}
    else
        mode={id=kind,path={{-50,0,-50},{0,0,0},{50,0,50}},cum={0,70.71067811865476,141.4213562373095},length=141.4213562373095,tuning={checkpoints={.5}}}
        function mode:At(s)return {pos={s*100-50,0,s*100-50}}end
    end
    local view=module.New({scene=scene},mode)
    local function Step(index)
        local outside=index%120>=85 and index%120<100
        cameraNode.position=outside and Vector3(0,35,180) or Vector3(0,65,-145)
        cameraNode:LookAt(outside and Vector3(0,35,400) or Vector3(0,0,0))
        local rule
        if kind=='conquest' then
            local points={};for j=1,3 do points[j]={v=((index*j)%61-30)/30,owner=({'none','blue','red'})[(index+j)%3+1],contested=(index+j)%7==0}end
            rule={points=points,score={blue=index%21*5,red=(600-index)%21*5},shield={blue=index%2==0,red=index%3==0}}
        else rule={s=(index%120)/120,idle=index%12,pushing=index%2,contested=index%5==0} end
        return rule
    end
    return {view=view,cameraNode=cameraNode,step=Step,dispose=function()
        view:Dispose();renderer:SetViewport(0,nil);scene:Dispose();scene=nil
    end}
end
local function Run()
    local rounds={}
    for _,label in ipairs({'A1','B1','B2','A2'}) do
        local round={label=label,variant=label:sub(1,1)=='A' and 'before' or 'candidate',cases={}}
        local module=round.variant=='before' and Before or Candidate
        for _,kind in ipairs({'conquest','escort'}) do
            math.randomseed(Config.seed)
            local fixture=Fixture(module,kind)
            for i=1,Config.warmup do
                local rule=fixture.step(i);fixture.view:Update(Config.dt,rule,fixture.cameraNode);coroutine.yield()
            end
            collectgarbage('collect')
            local samples,total,dueSteps,culledSteps={},0,0,0
            for index=1,Config.steps do
                local step=index+Config.warmup;local rule=fixture.step(step)
                if fixture.view.age+Config.dt>=fixture.view.nextUpdate then dueSteps=dueSteps+1 end
                local started=clock();fixture.view:Update(Config.dt,rule,fixture.cameraNode);local elapsed=(clock()-started)&0xffffffff
                samples[index]=elapsed;total=total+elapsed
                local outside=false;for _ in pairs(fixture.view.culled)do outside=true;break end
                if outside then culledSteps=culledSteps+1 end
                coroutine.yield()
            end
            local randomTail={};for i=1,16 do randomTail[i]=math.random()end
            round.cases[#round.cases+1]={name=kind,samplesMs=samples,totalMs=total,msPerStep=total/Config.steps,dueSteps=dueSteps,nonDueSteps=Config.steps-dueSteps,culledSteps=culledSteps,age=fixture.view.age,nextUpdate=fixture.view.nextUpdate,randomTail=randomTail}
            fixture.dispose();coroutine.yield()
        end
        rounds[#rounds+1]=round
    end
    Emit({status='PASS',configuration=Config,identity=Identity,rounds=rounds,boundary='Actual Web Runtime Scene/Camera.frustum/CustomGeometry/Color/Commit. One Update per real engine callback, identical fixed dt/rule/camera sequences. Timer includes only ObjectiveView.Update wall time; initialization, rule/camera generation, serialization, GC collect and reporting excluded. Renderer still submits the real scene outside timer. Integer wall includes bindings/GC/preemption; not whole-frame FPS, high-pressure combat or mobile acceptance. Offline full ordered output equivalence is separate.'})
end
function Start()
    assert(Config.steps>=100 and Config.steps<=600 and Config.dt==1/60)
    worker=coroutine.create(Run);SubscribeToEvent('Update','ObjectiveWebCpuUpdate')
    print('OBJECTIVE_WEB_CPU_READY '..cjson.encode({configuration=Config,identity=Identity}))
end
function ObjectiveWebCpuUpdate()
    if not worker or coroutine.status(worker)=='dead' then return end
    local ok,message=coroutine.resume(worker)
    if not ok then Emit({status='FAIL',configuration=Config,identity=Identity,error=tostring(message)})end
end
function Stop()
    UnsubscribeFromEvent('Update')
    if scene then scene:Dispose();scene=nil end
end
