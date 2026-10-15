local Math=require "core.Math3"
local Legs=require "drive.LegControl"
local Space=require "physics.Space"
local Vehicle=require "drive.Vehicle"
local Spec=require "drive.VehicleSpec"
local BP=require "construction.Blueprint"
local Data=require "core.ResourceData"
local Track=require "drive.TrackWorld"
local Hitboxes=require "drive.LegHitboxes"
local function Near(a,b,path)
    if b==cjson.null then return a==nil or a==cjson.null,path end
    if type(b)=='number' then return type(a)=='number' and math.abs(a-b)<2e-5*math.max(1,math.abs(b)),path end
    if type(b)~='table' then return a==b,path end
    if type(a)~='table' then return false,path end
    if #a~=#b then return false,path..'.length' end
    for k,value in pairs(b) do local ok,where=Near(a[k],value,path..'.'..tostring(k));if not ok then return false,where end end
    return true,path
end
local function Check(a,b,label)
    local ok,where=Near(a,b,label);assert(ok,'source mismatch '..where..' actual='..cjson.encode(a)..' expected='..cjson.encode(b))
end
local function Source()
    local f=assert(io.open('tools/migration/source-leg-drive-fixtures.json','r'));local fixture=cjson.decode(f:read('*a'));f:close()
    for _,case in ipairs(fixture.cases) do
        local state,forces,velocities,vi,afterImpulse={},{},{},0,nil;local v={spec=case.spec,com=case.com,mass=case.mass,inertiaY=case.inertiaY,capabilities=case.capabilities,legMode=case.legMode}
        v.body={rotation=function() return state.q end,translation=function() return state.p end,linvel=function() return state.lv end,
            angvel=function() return state.av end,center=function() return state.com end,
            velocityAtPoint=function(p) vi=vi+1;local sample=assert(velocities[vi]);Check(p,sample.p,'velocity point');return sample.result end}
        for _,method in ipairs({'addForce','addForceAtPoint','addTorque','applyImpulse'}) do
            v.body[method]=function(a,b)
                forces[#forces+1]={method=method,args=method=='addForceAtPoint' and {a,b} or {a}}
                if method=='applyImpulse' then state.lv=afterImpulse.lv;state.av=afterImpulse.av end
            end
        end
        local c=Legs.New(v);local rays,index={},0
        c.Cast=function(_,p,d,length)
            index=index+1;local ray=assert(rays[index],'extra ray '..index)
            Check({p=p,d=d,length=length},{p=ray.p,d=ray.d,length=ray.length},case.name..'/'..case.scenario..'/ray'..index)
            return ray.hit~=cjson.null and ray.hit or nil
        end
        for i,sample in ipairs(case.samples) do
            state=sample.state;forces={};rays=sample.rays;index=0;velocities=sample.velocities;vi=0;afterImpulse=sample.afterImpulse
            local result=c:Step(sample.command,1/60,sample.support)
            assert(index==#rays,'missing source rays at '..i)
            Check(result,sample.telemetry,'telemetry'..i);Check(forces,sample.forces,'forces'..i)
            Check({phase=c.phase,cadence=c.cadence},{phase=sample.phase,cadence=sample.cadence},'gait'..i)
            for j,s in ipairs(c.list) do
                Check({id=s.leg.partId,foot=s.foot,previous=s.previous,target=s.target,bladeAngle=s.bladeAngle,grounded=s.grounded,mode=s.mode,force=s.force},sample.states[j],'state'..i..'/'..j)
            end
        end
        V.assert(true,case.name..'/'..case.scenario..' source rays, forces, IK targets and gait '..#case.samples..' steps')
    end
    for i,sample in ipairs(fixture.hitboxes) do
        local v={spec=sample.spec,legStates={}}
        for _,s in ipairs(sample.states) do v.legStates[s.id]={target=s.target~=cjson.null and s.target or nil,bladeAngle=s.bladeAngle} end
        local hitboxes=Hitboxes.New(v)
        for j,box in ipairs(hitboxes.items) do Check({center=Math.Vec(box.center),half=box.half,quat=box.quat,partId=box.partId},sample.items[j],'hitbox'..i..'/'..j) end
        V.assert(true,'source articulated hit sensors '..i)
    end
end
local measurements={}
local function Native(name,run,track,specOverride)
    local scene=Scene();local world=track and Track.New(scene) or nil
    local space=world and world.space or Space.New(scene)
    if not world then
        local n=scene:CreateChild('Floor');n:CreateComponent('CollisionShape'):SetStaticPlane();space:Register(n:CreateComponent('RigidBody'),{type='ground'})
    end
    local v=Vehicle.New(space,specOverride or Spec.Build(BP.New():Load(Data.Read('Blueprints/'..name..'.json'))));v:Place({0,0,-100},0)
    local function Step(seconds,command,each)
        for i=1,math.floor(seconds*60+.5) do v:Step(command or {},1/60);space:Step(1/60);if each then each(i) end end
    end
    run(v,Step,space)
    v:Dispose();if world then world:Dispose() end;scene:Dispose()
end
V.atFrame(55,function()
    Source()
    for _,name in ipairs({'LegT3','LegT5','LegWaveT5'}) do
        Native(name,function(v,Step)
            Step(4);local start=v.body.translation()
            V.assert(v.telemetry.legAvailable==#v.spec.legs and v.telemetry.legContacts==#v.spec.legs,name..' all feet planted at idle')
            Step(2);local p=v.body.translation()
            V.assert(Math.Length(Math.Sub(Math.Array(start),Math.Array(p)))<.05,name..' neutral remains still')
            local prev={};local slides,maxSlide,swings=0,0,0
            Step(3,{throttle=1},function()
                for _,s in ipairs(v.legControl.list) do
                    if s.mode=='swing' then swings=swings+1 end
                    if s.grounded and prev[s.leg.partId] then local d=Math.Length(Math.Sub(s.foot,prev[s.leg.partId]));slides=slides+d;maxSlide=math.max(maxSlide,d) end
                    prev[s.leg.partId]=s.grounded and s.foot or nil
                end
            end)
            V.assert(v.body.translation().z-p.z>10 and swings>60,name..' actual forward locomotion and cyclic stepping')
            V.assert(maxSlide<.001,name..' stance foot stays locked')
            Step(3);V.assert(math.abs(v.speed)<.1,name..' release stops movement')
            p=v.body.translation();Step(1,{strafe=1});V.assert(v.body.translation().x-p.x>1,name..' lateral movement')
            Step(1,{steer=1});V.assert(v.body.angvel().y>.3,name..' commanded yaw')
            Step(3);local before=v.body.translation().y;local jumped=false;local maxY=before
            Step(1,{jump=true},function() jumped=jumped or v.telemetry.legJumped;maxY=math.max(maxY,v.body.translation().y) end)
            V.assert(jumped and maxY-before>1,name..' jump impulse lifts actual chassis')
            Step(4);V.assert(v.telemetry.legContacts==#v.spec.legs,name..' lands and replants')
            V.assert(#v.legHitboxes.items==#v.spec.legs*4,name..' four articulated hit sensors per leg')
            measurements[name]={telemetry=v.telemetry,position=v.body.translation(),slides=slides,maxSlide=maxSlide,swings=swings,jumpRise=maxY-before}
        end)
    end
    for _,scenario in ipairs({{name='wall',p={-66,0,-32},time=7},{name='hill',p={-100,0,-41},time=8},{name='jumpWall',p={-66,0,-32},time=7}}) do
        Native('LegT3',function(v,Step)
            v:Place(scenario.p,0);Step(1);local maxY=-100;local climbing=false
            local jumped=false
            for i=1,scenario.time*60 do
                Step(1/60,{throttle=1,jump=scenario.name=='jumpWall' and i>54 and i<60},function()
                    maxY=math.max(maxY,v.body.center().y);climbing=climbing or v.telemetry.legClimbing;jumped=jumped or v.telemetry.legJumped
                end)
            end
            measurements[scenario.name]={maxY=maxY,climbing=climbing,telemetry=v.telemetry,position=v.body.translation()}
            V.assert(maxY>(scenario.name=='hill' and 10 or 7),'native source '..scenario.name..' climbs above obstacle')
            if scenario.name=='jumpWall' then V.assert(jumped and climbing,'jumping toward wall reattaches and climbs') end
        end,true)
    end
    Native('LegT3',function(v,Step,space)
        local floor=space.scene:GetChild('Floor'):GetComponent('CollisionShape')
        floor:SetBox(Vector3(16,.2,16),Vector3(0,-.1,-100))
        Step(3);Step(3,{throttle=1});local before=v.body.translation().y
        Step(.5,{throttle=1})
        V.assert(v.telemetry.legAvailable==0 and v.body.translation().y<before-1,'legs lose support beyond finite terrain and fall')
    end)
    local short=BP.New():Load(Data.Read('Blueprints/LegT3.json'));local removed=0
    for _,part in ipairs(short:List()) do if part.type=='leg3' and removed<3 then short:Remove(part.id);removed=removed+1 end end
    Native('LegT3',function(v,Step)
        Step(1,{jump=true});V.assert(not v.telemetry.legGrip and not v.telemetry.legJumped and not v.telemetry.legJumpReady,'three surviving legs cannot wall-grip or jump')
    end,false,Spec.Build(short))
    local overloaded=Spec.Build(BP.New():Load(Data.Read('Blueprints/LegT3.json')));overloaded.motion.mass=overloaded.motion.load*1.2
    Native('LegT3',function(v,Step,space)
        Step(1);V.assert(not v.telemetry.legGrip,'overloaded legs lose wall grip')
        local n=space.scene:CreateChild('DynamicProbeObstacle');n.position=Vector3(0,1,-100)
        n:CreateComponent('CollisionShape'):SetBox(Vector3(1,1,1));local body=n:CreateComponent('RigidBody');body.mass=2;space:Register(body,{type='debris'})
        local h=v.legControl:Cast({0,3,-100},{0,-1,0},4)
        V.assert(h and math.abs(h.point[2])<.01,'support ignores dynamic debris and own chassis')
        body.kinematic=true;h=v.legControl:Cast({0,3,-100},{0,-1,0},4)
        V.assert(h and math.abs(h.point[2])<.01,'support also ignores kinematic bodies')
    end,false,overloaded)
    local f=assert(io.open('docs/migration/evidence/leg-drive-measurements.json','w'));f:write(cjson.encode(measurements));f:close()
    print('[LegDrive] '..cjson.encode(measurements));V.finish()
end)
