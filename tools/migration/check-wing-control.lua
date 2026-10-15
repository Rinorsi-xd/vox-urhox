local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-6*math.max(1,math.abs(b)) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v) then print('[WingGolden] mismatch '..tostring(k)..' actual='..tostring(a[k])..' expected='..tostring(v));return false end end;return true
end
V.atFrame(40,function()
    local f=File('tools/migration/source-wing-fixtures.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Dispose();local C=require 'drive.WingControl'
    for _,row in ipairs(data.coefficients) do V.assert(Near(C.NormalCoefficient(row.alpha),row.value),'source wing stall coefficient '..row.alpha) end
    for _,scenario in ipairs(data.dynamics) do
        local position,velocity,spin,quat={},{},{},{};local forces={};local body={rotation=function() return quat end,translation=function() return position end,linvel=function() return velocity end,angvel=function() return spin end}
        for _,method in ipairs({'addForce','addTorque','addForceAtPoint'}) do body[method]=function(...) local args={};for _,a in ipairs({...}) do if type(a)=='table' then args[#args+1]=a end end;forces[#forces+1]={method=method,args=args} end end
        local space={Raycast=function(_,p,dir,distance) return p[2]<=distance and {dist=p[2]} or nil end}
        local vehicle={body=body,spec=scenario.spec,mass=scenario.mass,com=scenario.com,space=space}
        for i,frame in ipairs(scenario.frames) do
            position,velocity,spin,quat=frame.position,frame.velocity,frame.spin,frame.quat;forces={};vehicle.flightTarget=frame.flightTarget~=cjson.null and frame.flightTarget or nil
            local out=C.Step(vehicle,frame.cmd,1/60,frame.contact,frame.support);local key=scenario.layout..'/'..scenario.mode..'/'..i
            V.assert(Near(out,frame.out),'source wing telemetry '..key)
            V.assert(Near(vehicle.wingState,frame.st),'source wing pilot and surface state '..key)
            V.assert(Near(forces,frame.forces),'source wing world force and torque '..key)
        end
    end
    for i,row in ipairs(data.jets) do
        local forces={};local body={rotation=function() return {x=0,y=0,z=0,w=1} end,translation=function() return {x=0,y=15,z=0} end,linvel=function() return {x=0,y=0,z=row.speed} end,angvel=function() return {x=0,y=0,z=0} end}
        for _,method in ipairs({'addForce','addTorque','addForceAtPoint'}) do body[method]=function(...) local args={};for _,a in ipairs({...}) do if type(a)=='table' then args[#args+1]=a end end;forces[#forces+1]={method=method,args=args} end end
        local vehicle={body=body,mass=620,inertiaY=2000,com={0,0,0},spec={thrusters={row.thruster},wings={{}},bounds={min={-1,-1,-2}}},boostFuel=1}
        local out=require('drive.ThrusterControl').Step(vehicle,{throttle=row.throttle},1/60,0,0)
        V.assert(Near(forces,row.forces),'source wing jet actual thrust and reverse force '..i)
        V.assert(Near(vehicle.thrusterOutputs[4],row.outputs['4']) and Near(vehicle.thrusterDirections[4],row.directions['4']),'source wing jet visual fire and direction '..i)
        V.assert(Near(out,row.out),'source wing jet telemetry '..i)
    end
    V.finish()
end)
