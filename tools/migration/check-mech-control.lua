local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-7 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v) then return false end end;return true
end
V.atFrame(40,function()
    local f=File('tools/migration/source-mech-control.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Dispose()
    local IK=require('parts.MechIK');local C=require('drive.MechControl')
    for _,row in ipairs(data.poses) do
        local pose=IK.Solve(row.type,row.target,row.pitch,row.toe,row.yaw)
        V.assert(Near(pose,row.pose),'source exact mech IK '..row.type..':'..row.pitch..':'..row.yaw)
        V.assert(math.abs(IK.SinkCapacity(row.type)-row.sink)<1e-8 and math.abs(IK.ExtendCapacity(row.type)-row.extend)<1e-8,'source mech joint capacity '..row.type)
    end
    for _,row in ipairs(data.timings) do
        local c=setmetatable({standAvg=8.5,sinkCap=IK.SinkCapacity(row.type),extCap=IK.ExtendCapacity(row.type),boosting=false,slopeF=row.slope,list={{},{}}},C)
        V.assert(Near(c:Timing(row.speed,row.spin,row.ratio,row.lat),row.out),'source slope stride timing '..row.type..':'..row.speed..':'..row.slope..':'..row.lat)
    end
    for _,scenario in ipairs(data.dynamics) do
        local position,velocity,spin={x=0,y=0,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0};local forces={};local body={}
        body.rotation=function() return {x=0,y=0,z=0,w=1} end;body.translation=function() return position end;body.linvel=function() return velocity end;body.angvel=function() return spin end;body.velocityAtPoint=function() return velocity end
        for _,method in ipairs({'addForce','addTorque','addForceAtPoint','applyTorqueImpulse'}) do body[method]=function(...) local args={};for _,a in ipairs({...}) do if type(a)=='table' then args[#args+1]=a end end;forces[#forces+1]={method=method,args=args} end end
        body.applyImpulse=function(j) forces[#forces+1]={method='applyImpulse',args={j}};velocity={x=velocity.x+j.x/scenario.mass,y=velocity.y+j.y/scenario.mass,z=velocity.z+j.z/scenario.mass} end
        body.setAngvel=function(a) spin=a;forces[#forces+1]={method='setAngvel',args={a}} end
        local space={};space.Raycast=function(_,p,d,distance) local denominator=d[2]-scenario.slope*d[3];if math.abs(denominator)<1e-9 then return nil end;local t=(scenario.slope*p[3]-p[2])/denominator;if t<0 or t>distance then return nil end;local k=math.sqrt(1+scenario.slope^2);return {point={p[1]+d[1]*t,p[2]+d[2]*t,p[3]+d[3]*t},normal={0,1/k,-scenario.slope/k},dist=t} end
        local controller=C.New({spec=scenario.spec,mass=scenario.mass,com={0,0,0},inertiaY=scenario.mass*4,body=body,space=space,capabilities={totalLoad=scenario.spec.mechLegs[1].load*2,mechShare=1},legMode=true})
        for frame,row in ipairs(scenario.frames) do
            position=row.position;velocity=row.velocity;spin=row.spin;forces={};local out=controller:Step(row.cmd,1/60,0)
            V.assert(Near(out,row.out) and Near(forces,row.forces),'source mech force and telemetry '..scenario.type..':'..scenario.slope..':'..frame)
            local states={};for _,s in ipairs(controller.list) do states[#states+1]={target=s.target,lift=s.lift,foot=s.foot,pitch=s.pitch,toe=s.toe,yaw=s.yaw,grounded=s.grounded} end
            V.assert(Near(states,row.states) and math.abs(controller.phase-row.phase)<1e-7 and math.abs(controller.jetFuel-row.jetFuel)<1e-7 and math.abs(controller.boostFuel-row.boostFuel)<1e-7,'source mech gait and fuel '..scenario.type..':'..scenario.slope..':'..frame)
        end
    end
    local state={yaw=0};setmetatable(state,C);state:SharedYaw({strafe=1,throttle=0},1);V.assert(math.abs(state.yaw)<=math.pi/6,'source shared leg yaw stays within thirty degrees')
    state:SharedYaw({},1);V.assert(state.yaw==0,'no strafe points knees forward')
    for i,row in ipairs(data.hitboxes) do
        local vehicle={spec={mechLegs={row.leg}},mechStates={[101]={}},mechControl={Pose=function() return row.pose end}}
        local boxes=require('drive.MechHitboxes').New(vehicle);local items={}
        for _,box in ipairs(boxes.items) do items[#items+1]={center=box.center,half=box.half,quat=box.quat,partId=box.partId} end
        V.assert(Near(items,row.items),'source animated mech hit sensors '..i)
    end
    V.finish()
end)
