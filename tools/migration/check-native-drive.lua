local Space=require "physics.Space"
local Vehicle=require "drive.Vehicle"
local Spec=require "drive.VehicleSpec"
local BP=require "construction.Blueprint"
local Prefab=require "construction.Prefab"
local Math=require "core.Math3"
---@type Scene|nil
local scene=nil
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
V.atFrame(55,function()
    scene=Scene();local space=Space.New(scene)
    local floor=scene:CreateChild("TestGround")
    floor.position=Vector3.ZERO
    local ground=floor:CreateComponent("RigidBody");ground.friction=.9
    floor:CreateComponent("CollisionShape"):SetStaticPlane()
    space:Register(ground,{type="ground"})
    local evidence={}
    for _,name in ipairs({'raceCar','tianyuan','fuyuan'}) do
        local build=function(bp) return Prefab.Create(bp,name) end
        local v=Vehicle.New(space,Spec.Build(build(BP.New())))
        V.assert(name=='raceCar' or v.tracked,name..' actual prefab has tracked locomotion')
        local function Step(frames,cmd)
            for _=1,frames do v:Step(cmd or {throttle=0,steer=0},1/60);space:Step(1/60) end
        end
        v:Place({0,0,0},0);Step(300)
        local rest=v.body.translation();local velocity=v.body.linvel()
        local com=v.body.localCom()
        V.assert(math.abs(velocity.y)<.1,name.." settles vertically")
        V.assert(v.telemetry.contact>0,name.." suspension contacts ground")
        Step(120)
        V.assert(Distance(rest,v.body.translation())<.1,name.." neutral input stays stationary")
        Step(360,{throttle=1,steer=0})
        local forward=v.body.translation();local speed=v.speed
        V.assert(forward.z-rest.z>15,name.." held throttle moves forward")
        V.assert(speed>5 and speed<v.spec.motion.topSpeed*1.15,name.." acceleration respects top speed")
        V.assert(math.abs(forward.x-rest.x)<1,name.." straight input tracks straight")
        Step(80,{throttle=-1,steer=0})
        V.assert(math.abs(v.speed)<speed*.8,name.." opposite throttle brakes")
        v:Place({0,0,0},0);Step(240);Step(180,{throttle=1,steer=0})
        local yaw=0;local lastYaw=v:Yaw()
        for _=1,90 do
            Step(1,{throttle=1,steer=1})
            local current=v:Yaw();local delta=current-lastYaw
            yaw=yaw+math.atan(math.sin(delta),math.cos(delta));lastYaw=current
        end
        V.assert(yaw>.1,name.." left input produces source positive yaw")
        local up=Math.Rotate(v.body.rotation(),{0,1,0})
        V.assert(up[2]>.7,name.." steering preserves upright chassis")
        v:Place({0,3,0},0);Step(360)
        V.assert(math.abs(v.body.linvel().y)<.3 and v.telemetry.contact>0,name.." drop settles onto suspension")
        evidence[name]={rest=rest,com=com,forward=forward,speed=speed,yaw=yaw,up=up,telemetry=v.telemetry}
        v:Dispose()
        V.assert(scene:GetChild("VehicleBody")==nil,name.." vehicle releases body")
    end
    local file=assert(io.open("docs/migration/evidence/native-drive-measurements.json","w"));file:write(cjson.encode(evidence));file:close()
    scene:Dispose();scene=nil;V.finish()
end)
