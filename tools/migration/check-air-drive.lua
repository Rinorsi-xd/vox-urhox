local Space=require "physics.Space"
local Vehicle=require "drive.Vehicle"
local Spec=require "drive.VehicleSpec"
local BP=require "construction.Blueprint"
local Data=require "core.ResourceData"
local Math=require "core.Math3"
local Hover=require "drive.HoverControl"
local Thrusters=require "drive.ThrusterControl"
local f=assert(io.open('tools/migration/source-air-drive-fixtures.json','r'));local fixture=cjson.decode(f:read('*a'));f:close()
local measurements={}
local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(b)=='number' then return type(a)=='number' and math.abs(a-b)<1e-6*math.max(1,math.abs(b)) end
    if type(b)~='table' then return a==b end
    if type(a)~='table' then return false end
    for k,v in pairs(b) do if not Near(a[k],v) then return false end end
    for k in pairs(a) do if b[k]==nil then return false end end
    return true
end
local function Source()
    for i,c in ipairs(fixture.forces) do V.assert(Near(Hover.Force(c.h,c.d,c.speed,c.share,c.scale),c.result),'source hover force '..i) end
    for i,c in ipairs(fixture.hoverMotion) do
        local v=c.initial;local applied={};v.hoverStates={[10]={G=v.ground}}
        v.body={angvel=function() return v.av end,addForce=function(force) applied[#applied+1]={force=force} end,
            addTorque=function(torque) applied[#applied+1]={torque=torque} end}
        local actual={telemetry=Hover.Motion(v,c.command,v.frame),applied=applied}
        V.assert(Near(actual,c.result),'frozen hover ellipse, coasting and yaw '..i)
    end
    for i,c in ipairs(fixture.cases) do
        local applied={};local state=c.state
        local v={spec=fixture.spec,mass=500,com=c.com,inertiaY=c.inertiaY,liftTilt=0,landingTime=0,
            space={Raycast=function() end},body={translation=function() return state.p end,rotation=function() return state.q end,
            linvel=function() return state.lv end,angvel=function() return state.av end,
            addForce=function(force) applied[#applied+1]={force=force} end,
            addForceAtPoint=function(force,point) applied[#applied+1]={force=force,point=point} end}}
        for j,s in ipairs(c.samples) do
            applied={};local telemetry=Thrusters.Step(v,s.command,1/60,0,c.support)
            local outputs,directions={},{}
            for id,value in pairs(v.thrusterOutputs) do outputs[tostring(id)]=value end
            for id,value in pairs(v.thrusterDirections) do directions[tostring(id)]=value end
            V.assert(Near(telemetry,s.telemetry) and Near(outputs,s.outputs) and Near(directions,s.directions)
                and Near(applied,s.applied) and Near(v.flightTarget,s.flightTarget) and Near(v.liftTilt,s.liftTilt),
                'source bounded actuators and point forces '..i..'/'..j)
        end
    end
end
local function Native(name,spec,run)
    local scene=Scene();local space=Space.New(scene)
    -- Plane y=0 supports suspension/hover rays; no finite edge in hold tests.
    -- Separate ledge test below uses a finite platform to prove support is lost.
    local node=scene:CreateChild('Floor');node:CreateComponent('CollisionShape'):SetStaticPlane()
    local floor=node:CreateComponent('RigidBody');space:Register(floor,{type='ground'})
    local v=Vehicle.New(space,spec);v:Place({0,0,0},0)
    local function Step(seconds,command)
        for _=1,math.floor(seconds*60+.5) do v:Step(command or {},1/60);space:Step(1/60) end
    end
    run(v,Step,space)
    measurements[name]={state=v:GetState(),telemetry=v.telemetry}
    print('[AirDrive] '..name..' '..cjson.encode(measurements[name]))
    v:Dispose();V.assert(scene:GetChild('VehicleBody')==nil,name..' disposes native body');scene:Dispose()
end
V.atFrame(55,function()
    Source()
    for _,name in ipairs({'HoverBottom','HoverSide'}) do
        local spec=Spec.Build(BP.New():Load(Data.Read('Blueprints/'..name..'.json')))
        Native(name,spec,function(v,Step)
            Step(8);local rest=v.body.translation();local up=Math.Rotate(v.body.rotation(),{0,1,0})
            V.assert(v.telemetry.hovers==4 and math.abs(v.telemetry.hoverHeight-.75)<.04,name..' four emitters hold source height')
            V.assert(up[2]>.995 and math.abs(v.body.linvel().y)<.05,name..' settles upright')
            Step(2);local p=v.body.translation()
            V.assert(Math.Length({p.x-rest.x,p.y-rest.y,p.z-rest.z})<.05,name..' neutral remains stationary')
            Step(2,{climb=1});Step(5)
            V.assert(v.hoverHeightScale==1.7 and math.abs(v.telemetry.hoverHeight-1.7*.75)<.05,name..' raises hover height to current source cap')
            Step(2,{climb=-1});Step(5)
            V.assert(v.hoverHeightScale==.6 and math.abs(v.telemetry.hoverHeight-.6*.75)<.05,name..' lowers hover height')
            local start=v.body.translation();Step(3,{throttle=1});p=v.body.translation()
            V.assert(p.z-start.z>8 and math.abs(p.x-start.x)<.3,name..' held throttle drives straight')
            local coastSpeed=math.abs(v.speed);Step(6)
            V.assert(math.abs(v.speed)<coastSpeed*.05+.05,name..' source hover damping coasts then slows')
            start=v.body.translation();Step(2,{strafe=1});p=v.body.translation()
            V.assert(p.x-start.x>2,name..' source positive strafe moves along x')
            Step(1,{steer=1});V.assert(v.body.angvel().y>.3,name..' steering rotates under hover authority')
            V.assert(Math.Rotate(v.body.rotation(),{0,1,0})[2]>.9,name..' maneuver remains upright')
        end)
        local damaged=BP.New():Load(Data.Read('Blueprints/'..name..'.json'))
        for _,p in ipairs(damaged:List()) do if p.type=='hover3' and p.pos[1]<0 then damaged:Remove(p.id) end end
        Native(name..'LostLeft',Spec.Build(damaged),function(v,Step)
            v.body.setTranslation({x=0,y=1-v.spec.hovers[1].pos[2],z=0});Step(.5)
            V.assert(v.body.rotation().z>.035,name..' missing left hover support physically tips left')
        end)
    end
    local hoverSpec=Spec.Build(BP.New():Load(Data.Read('Blueprints/HoverBottom.json')))
    Native('hoverLedge',hoverSpec,function(v,Step,space)
        space.scene:GetChild('Floor'):GetComponent('CollisionShape'):SetBox(Vector3(8,.2,8),Vector3(0,-.1,0))
        Step(3);Step(3,{throttle=1});local p=v.body.translation()
        V.assert(p.z>6 and p.y<-.5 and v.telemetry.hovers==0,'hover falls after driving beyond finite support')
    end)
    Native('hoverTilt',hoverSpec,function(v,Step)
        for _,degrees in ipairs({34,36,90}) do
            v:Place({0,0,0},0);v.body.setTranslation({x=0,y=1,z=0})
            v.body.setRotation({x=0,y=0,z=math.sin(degrees*math.pi/360),w=math.cos(degrees*math.pi/360)})
            v:Step({},1/60)
            V.assert((v.telemetry.hovers>0)==(degrees<35),'hover source 35 degree support cutoff '..degrees)
        end
    end)
    local spec=fixture.spec
    Native('balancedLift',spec,function(v,Step)
        Step(1);local start=v.body.translation().y
        V.assert(next(v.thrusterOutputs)==nil,'lift stays off until commanded')
        Step(2,{climb=1});Step(6);local hold=v.body.translation().y
        V.assert(hold>start+4,'lift climbs under actual thrust')
        V.assert(math.abs(hold-v.flightTarget)<.1 and math.abs(v.body.linvel().y)<.05,'lift holds target altitude')
        Step(3,{throttle=1});local p=v.body.translation()
        V.assert(p.z>3 and math.abs(p.y-hold)<.35,'vectored lift advances while holding height')
        Step(1,{steer=1});V.assert(v.body.angvel().y>.2,'side jets provide yaw')
        Step(.5,{cutLift=true});V.assert(v.flightTarget==nil and v.body.linvel().y<0 and next(v.thrusterOutputs)==nil,'cutoff falls under gravity')
        v:Place({0,0,0},0);Step(2,{climb=1});Step(3);local before=v.body.translation().y
        Step(1,{climb=-1});V.assert(v.body.translation().y<before-.6,'descent lowers vehicle')
        Step(10,{climb=-1});V.assert(v.flightTarget==nil and next(v.thrusterOutputs)==nil,'landing disarms lift')
    end)
    local overloaded=cjson.decode(cjson.encode(spec));overloaded.motion.mass=1200;overloaded.boxes[1].mass=1200
    Native('insufficientLift',overloaded,function(v,Step)
        Step(5,{climb=1})
        V.assert(v.body.translation().y<.5 and v.telemetry.liftRatio<1,'insufficient thrust cannot lift overloaded mass')
    end)
    local heavy=Spec.Build(BP.New():Load(Data.Read('Blueprints/HeavyLift.json')))
    Native('heavySixT5',heavy,function(v,Step)
        Step(1);local start=v.body.translation().y;Step(2,{climb=1});Step(6);local hold=v.body.translation().y
        V.assert(hold>start+4 and math.abs(v.body.linvel().y)<.08,'actual six T5 car lifts and holds')
        Step(3,{throttle=1});local p=v.body.translation();local up=Math.Rotate(v.body.rotation(),{0,1,0})
        V.assert(p.z>3 and math.abs(p.y-hold)<.3 and up[2]>.998,'actual off-center mass balances forward vectoring')
        local lo,hi=1,0;for _,out in pairs(v.thrusterOutputs) do lo=math.min(lo,out);hi=math.max(hi,out) end
        V.assert(lo>=0 and hi<=1 and hi-lo>.001,'off-center lift distributes bounded unequal thrust')
        Step(110,{throttle=1});local first=v.body.linvel();Step(10,{throttle=1});local last=v.body.linvel()
        local speed=math.sqrt(last.x^2+last.z^2)*3.6;local firstSpeed=math.sqrt(first.x^2+first.z^2)*3.6
        measurements.heavyCruise={seconds=120,speed=speed,driftLast10s=math.abs(speed-firstSpeed),heightError=math.abs(v.body.translation().y-hold)}
        V.assert(speed<120.1 and math.abs(speed-firstSpeed)<.1,'heavy T5 long cruise respects speed governor')
        V.assert(math.abs(v.body.translation().y-hold)<.2 and Math.Rotate(v.body.rotation(),{0,1,0})[2]>.998,'heavy T5 long cruise maintains height and level')
        local state=v:GetState();v:SetState(state);V.assert(v.flightTarget==state.flightTarget,'rebuild preserves flight target')
        v:Place({0,0,0},0);V.assert(v.flightTarget==nil,'reset disarms altitude hold')
    end)
    local file=assert(io.open('docs/migration/evidence/air-drive-measurements.json','w'));file:write(cjson.encode(measurements));file:close();V.finish()
end)
