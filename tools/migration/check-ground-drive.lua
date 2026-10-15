local Contact=require 'drive.ContactControl'
local Stability=require 'drive.ChassisStability'
local f=assert(io.open('.tmp/source-ground-drive-fixtures.json','r'))
local fixture=cjson.decode(f:read('*a'));f:close()
local function Near(a,b,path)
    if b==cjson.null then return a==nil or a==cjson.null or a==math.huge,path end
    if type(b)=='number' then return type(a)=='number' and math.abs(a-b)<=1e-6*math.max(1,math.abs(b)),path end
    if type(b)~='table' then return a==b,path end
    if type(a)~='table' then return false,path end
    for k,value in pairs(b) do local ok,where=Near(a[k],value,path..'/'..tostring(k));if not ok then return false,where end end
    for k in pairs(a) do if b[k]==nil then return false,path..'/extra/'..tostring(k) end end
    return true,path
end
V.atFrame(55,function()
    for i,c in ipairs(fixture.cases) do
        local v=c.initial;local applied,actuators={},{}
        v.steerWheels={};v.trackWheels={}
        for j,w in ipairs(v.wheels) do
            w.index=j;actuators[j]={engine=0,brake=0,steering=0,side=1}
            if w.steer then v.steerWheels[#v.steerWheels+1]=w end
            if w.track then v.trackWheels[#v.trackWheels+1]=w end
        end
        v.body={angvel=function() return {x=.2,y=.3,z=-.1} end,
            addForce=function(force) applied[#applied+1]={force=force} end,
            addTorque=function(torque) applied[#applied+1]={torque=torque} end,
            addForceAtPoint=function(force,point) applied[#applied+1]={force=force,point=point} end}
        v.vc={wheelIsInContact=function(j) return v.contacts[j] end,
            wheelSuspensionForce=function(j) return v.loads[j] end,
            wheelSuspensionLength=function(j) return v.lengths[j] end,
            wheelHardPoint=function(j) return {x=v.wheels[j].center[1],y=.2,z=v.wheels[j].center[3]} end,
            wheelContactNormal=function() return {x=0,y=1,z=0} end,
            setWheelEngineForce=function(j,value) actuators[j].engine=value end,
            setWheelBrake=function(j,value) actuators[j].brake=value end,
            setWheelSteering=function(j,value) actuators[j].steering=value end,
            setWheelSideFrictionStiffness=function(j,value) actuators[j].side=value end,
            wheelEngineForce=function(j) return actuators[j].engine end,
            wheelBrake=function(j) return actuators[j].brake end}
        for j,s in ipairs(c.samples) do
            applied={};local telemetry=Contact.Step(v,c.command,s.dt,v.frame)
            local actual={telemetry=telemetry,actuators=actuators,applied=applied,steer=v.steer,aLong=v.aLong,aLat=v.aLat,contacts=v.contactStates}
            local expected={telemetry=s.telemetry,actuators=s.actuators,applied=s.applied,steer=s.steer,aLong=s.aLong,aLat=s.aLat,contacts=s.contacts}
            local ok,where=Near(actual,expected,'case '..i..' sample '..j)
            V.assert(ok,'frozen H5 ground outputs '..where)
            if not ok then print('[GroundDrive] expected '..cjson.encode(expected));print('[GroundDrive] actual '..cjson.encode(actual)) end
        end
    end
    for i,c in ipairs(fixture.stability) do
        local v=c.initial;local applied={};local angular,ray
        v.body={translation=function() return v.p end,angvel=function() return v.av end,
            addForce=function(force) applied[#applied+1]=force end,setAngvel=function(value) angular=value end}
        v.space={Raycast=function(_,origin,direction,span,excluded,skip,fixed,mask)
            ray={origin={x=origin[1],y=origin[2],z=origin[3]},direction={x=direction[1],y=direction[2],z=direction[3]}}
            V.assert(mask==0x6fff and excluded==v.body and math.abs(span-(v.cgH+3.4))<1e-8,'stability support query contract '..i)
            if type(c.gap)=='number' then return {dist=c.gap+v.cgH,normal={c.normal.x,c.normal.y,c.normal.z}} end
        end}
        V.assert(Stability.Wants(v)==c.wanted,'source chassis capability gate '..i)
        Stability.Step(v,1/60,v.frame,c.contact)
        if type(c.gap)~='number' then v.stability.gap=c.result.state.gap end
        local ok,where=Near({applied=applied,angular=angular or c.result.angular,state=v.stability,ray=ray},c.result,'stability '..i)
        V.assert(ok,'frozen H5 chassis outputs '..where)
    end
    V.finish()
end)
