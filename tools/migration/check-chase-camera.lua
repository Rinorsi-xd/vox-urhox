local State=require 'controls.ChaseState'
local Adapter=require 'controls.ChaseCamera'
local Fov=require 'controls.SpeedFov'
local f=assert(io.open('.tmp/source-chase-camera.json','r'));local fixture=cjson.decode(f:read('*a'));f:close()
local function Near(a,b,tolerance) return math.abs(a-b)<(tolerance or 1e-6) end
local function VectorNear(a,b,tolerance) for i=1,3 do if not Near(a[i],b[i],tolerance) then return false end end;return true end
V.atFrame(55,function()
    local scene=Scene();scene:CreateComponent('PhysicsWorld');local target=scene:CreateChild('CameraTarget')
    local camera=Adapter.Create(scene)
    for i,c in ipairs(fixture.cases) do
        local state=State.New();state.minY=c.ground<0 and -math.huge or .35
        local pitch=state:Reset(c.pos,c.radius);local yaw=-.7*180/math.pi
        V.assert(Near(pitch,-c.resetPitch*180/math.pi),'source reset pitch '..i)
        for j,s in ipairs(c.samples) do
            state:Zoom(s.delta);yaw,pitch=State.Look(yaw,pitch,s.mouse[1],s.mouse[2],s.sens,c.flight)
            local pose=state:Pose(s.dt,s.car.pos,yaw,pitch,function(origin,dir,span)
                local e=s.expected.ray
                V.assert(VectorNear(origin,e.origin) and VectorNear(dir,e.dir) and Near(span,e.span),'source obstruction ray '..i..'/'..j)
                return type(c.obstacle)=='number' and c.obstacle or nil
            end,type(s.eye)=='table' and s.eye or nil)
            Adapter.Apply(camera,target,s.dt,pose,yaw,pitch)
            local position=camera:GetNode().position;local forward=camera:GetNode().rotation*Vector3.FORWARD
            local e=s.expected
            V.assert(Near(yaw,-e.yaw*180/math.pi) and Near(pitch,-e.pitch*180/math.pi) and Near(state.zoom,e.zoom)
                and VectorNear(state.target,e.target) and Near(state.curDist,e.curDist),'source camera state '..i..'/'..j)
            V.assert(VectorNear({-position.x,position.y,position.z},e.position,5e-4)
                and VectorNear({-forward.x,forward.y,forward.z},e.forward,2e-5),'actual ThirdPersonCamera pose '..i..'/'..j)
        end
    end
    camera:GetNode():Dispose();scene:Dispose()
    for i,c in ipairs(fixture.fov) do
        local state=Fov.New();local spec=c.scenario
        local vehicle={spec={motion=spec},legMode=spec.legMode,mechMode=spec.mechMode,telemetry={legSpeedLimit=spec.legSpeedLimit}}
        for j,s in ipairs(c.samples) do
            vehicle.body={linvel=function() return s.lv end};local o=s.options
            local value=state:Step(vehicle,s.dt,48,s.previous,{scope=type(o.scope)=='number' and o.scope or nil,rush=o.rush,charge=o.charge,punch=o.punch})
            local e=s.expected
            V.assert(Near(value,e.current) and Near(state.speed,e.speed) and Near(state.peak,e.peak) and Near(state.scopeT,e.scopeT),
                'source horizontal speed/peak/scope FOV '..i..'/'..j)
        end
    end
    V.finish()
end)
