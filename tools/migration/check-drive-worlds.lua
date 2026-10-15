local Space=require 'physics.Space'
local Vehicle=require 'drive.Vehicle'
local Spec=require 'drive.VehicleSpec'
local BP=require 'construction.Blueprint'
local sourceFile=assert(io.open('.tmp/source-drive-worlds.json','r'))
local source=cjson.decode(sourceFile:read('*a'));sourceFile:close()
local output={sourceCommit=source.sourceCommit,engine='Bullet',dt=source.dt,ground=source.ground,phases=source.phases,cases={}}
---@type Scene?
local scene=nil
local caseIndex,repeatIndex,phaseIndex,frame=1,1,1,0
local current={}
local function StartRun()
    scene=Scene();current.space=Space.New(scene)
    -- Ground top y=0, matching Rapier. Vehicle is the only dynamic collider.
    -- +---------------- vehicle ----------------+  y>0
    -- ==========================================  y=0, recorded source dimensions
    local floor=scene:CreateChild('WorldComparisonGround');floor.position=Vector3(0,-1,0)
    local body=floor:CreateComponent('RigidBody');body.friction=.9;body.restitution=0
    body.collisionLayer=1;body.collisionMask=0x7fff
    floor:CreateComponent('CollisionShape'):SetBox(Vector3(source.ground.half[1]*2,2,source.ground.half[3]*2))
    current.space:Register(body,{type='ground'})
    local sourceCase=source.cases[caseIndex]
    local bp=BP.New();bp:Load(sourceCase.blueprint)
    V.assert(bp.dropped==nil or bp.dropped==0,sourceCase.name..' exact frozen blueprint loads without dropped parts')
    current.v=Vehicle.New(current.space,Spec.Build(bp));current.v:Place({0,0,0},0)
    local com=current.v.body.localCom()
    current.run={mass=current.v.body.mass(),com={com.x,com.y,com.z},samples={}}
    phaseIndex=1;frame=0
end
local function FinishRun()
    local case=output.cases[caseIndex]
    if not case then case={name=source.cases[caseIndex].name,runs={}};output.cases[caseIndex]=case end
    case.runs[#case.runs+1]=current.run
    current.v:Dispose();scene:Dispose();scene=nil
    repeatIndex=repeatIndex+1
    if repeatIndex>3 then repeatIndex=1;caseIndex=caseIndex+1 end
    if caseIndex>#source.cases then
        local file=assert(io.open('.tmp/native-drive-worlds.json','w'));file:write(cjson.encode(output));file:close()
        V.finish();return false
    end
    StartRun();return true
end
V.atFrame(45,StartRun)
local function StepFrame(n)
    if n<46 or not scene then return end
    -- Keep live frame work bounded while advancing exactly the original 60Hz.
    for _=1,48 do
        local phase=source.phases[phaseIndex]
        if frame==0 and phase.reset then current.v:Place({0,0,0},0) end
        current.v:Step(phase.cmd,source.dt);current.space:Step(source.dt);frame=frame+1
        if frame%6==0 then
            local p,lv=current.v.body.translation(),current.v.body.linvel()
            local suspension={}
            for _,s in ipairs(current.v.suspension.states) do suspension[#suspension+1]={length=s.length,force=s.force,contact=s.grounded} end
            current.run.samples[#current.run.samples+1]={phase=phase.name,frame=frame,p={p.x,p.y,p.z},lv={lv.x,lv.y,lv.z},yaw=current.v:Yaw(),speed=current.v.speed,contact=current.v.telemetry.contact,suspension=suspension}
            V.assert(p.x==p.x and p.y==p.y and p.z==p.z,'finite actual world trajectory')
        end
        if frame>=phase.frames then
            frame=0;phaseIndex=phaseIndex+1
            if phaseIndex>#source.phases and not FinishRun() then return end
        end
    end
end
for n=46,400 do V.atFrame(n,function()StepFrame(n)end) end
