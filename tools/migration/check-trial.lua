local original=nil ---@type Blueprint|nil
local previous=nil ---@type table|nil
local app=nil ---@type HangarApp|nil
local measured={}
local exercise=nil ---@type thread|nil
engine.maxInactiveFps=120
local function Exercise(t,name)
    -- Spread the deterministic simulation workload across rendered frames;
    -- batching 20 simulated seconds in one callback creates a false frame spike.
    local function Step(n,cmd)
        for i=1,n do t:Tick(1/60,cmd or {throttle=0,steer=0});if i%60==0 then coroutine.yield() end end
    end
    Step(180);local p=t.vehicle.body.translation()
    V.assert(t.vehicle.telemetry.contact>0,name.." grounded on imported course")
    Step(90);local after=t.vehicle.body.translation()
    V.assert(math.abs(after.z-p.z)<.1 and math.abs(after.x-p.x)<.1,name.." neutral holds position")
    Step(240,{throttle=1,steer=0});local forward=t.vehicle.body.translation()
    V.assert(forward.z-p.z>15,name.." throttle moves through source course")
    t:PostUpdate(1/60)
    local root=t.view.view.root.position
    V.assert(math.abs(root.z-forward.z)<1,name.." visible vehicle follows native physics")
    V.assert(math.abs(t.camera:GetNode().position.z-root.z)>3,name.." third person camera follows vehicle")
    local changed=0
    for _,w in ipairs(t.view.wheels) do if math.abs(w.vis.rig.spin.rotation.w)<.9999 then changed=changed+1 end end
    for _,w in ipairs(t.view.tracks) do if math.abs(t.vehicle:WheelTravel(w.i))>1 then changed=changed+1 end end
    V.assert(changed>0,name.." wheel or track rig consumes travelled distance")
    local speed=t.vehicle.speed;Step(60,{throttle=-1,steer=0})
    V.assert(math.abs(t.vehicle.speed)<speed*.8,name.." reverse input brakes")
    t:Reset();Step(180);Step(120,{throttle=1,steer=0});Step(30,{throttle=1,steer=1})
    V.assert(t.vehicle:Yaw()>.1,name.." left steering uses source handedness")
    local steps=t.fixedSteps;local dropped=t.droppedTime;t:Tick(1,{throttle=0,steer=0})
    V.assert(t.fixedSteps-steps<=6 and t.droppedTime>dropped+.8,name.." long frame catch-up is bounded")
    t.teleport=6;t:Reset();Step(180)
    local r=t.vehicle.body.translation()
    V.assert(math.abs(r.x+75)<1 and math.abs(r.z-10)<1,name.." teleport resets pose at source ramp zone")
    measured[name]={forward=forward,speed=speed,steps=t.fixedSteps,nodes=t.scene:GetNumChildren(true),memory=cache.totalMemoryUse}
end
local function ResumeExercise()
    if exercise and coroutine.status(exercise)~='dead' then
        local ok,err=coroutine.resume(exercise);assert(ok,err)
    end
end
for frame=91,134 do V.atFrame(frame,ResumeExercise) end
for frame=181,224 do V.atFrame(frame,ResumeExercise) end
V.atFrame(45,function()
    app=assert(VOX_HANGAR).app;original=app.blueprint
    V.assert(app.trial==nil and package.loaded['app.TrialSession']==nil,"trial simulation not loaded at boot")
    V.assert(app:EnterTrial(),"trial requested from same app")
end)
V.atFrame(90,function()
    local t=assert(app.trial,"trial did not load");previous=t
    V.assert(app.mode=="trial" and app.hangar==nil and app.car==nil,"hangar runtime released after scene swap")
    V.assert(VOX_HANGAR==nil and VOX_TRIAL.session==t,"active scene globals match trial")
    local plane=t.world.space:Raycast({10,2,-18},{0,-1,0},4)
    V.assert(plane and math.abs(plane.point[2])<.001 and plane.normal[2]>.999,"finite ground has stable planar ray normals")
    V.assert(t.world.space:Raycast({205,2,0},{0,-1,0},4)==nil,"ground ends at source 400 metre footprint")
    for _,block in ipairs(t.world.layout.blocks) do if block.kind=="ramp" then
        local hit=t.world.space:Raycast({block.pos[1],block.pos[2]+3,block.pos[3]},{0,-1,0},6)
        local top=block.pos[2]+block.size[2]/2/math.cos(block.rot[1])
        V.assert(hit and math.abs(hit.point[2]-top)<.02,"source ramp top matches visible rotated box")
        break
    end end
    t.Update=function() end
    exercise=coroutine.create(function() Exercise(t,"car");app:Reload() end);ResumeExercise()
end)
V.atFrame(135,function()
    V.assert(app.mode=="hangar" and app.trial==nil and previous.disposed,"return disposes trial session")
    V.assert(app.blueprint==original and app.car~=nil,"return preserves blueprint and rebuilds visible car")
    V.assert(cache:GetExistingResource("Model","Track/model-0.mdl")==nil,"unused trial ground model released")
    previous=nil
    app.blueprint=require("build.Prefab").BuildTank(require("build.Blueprint").New())
    V.assert(app:EnterTrial(),"second entry loads selected tank")
end)
V.atFrame(180,function()
    local t=assert(app.trial);previous=t
    V.assert(t.vehicle.tracked and #t.view.tracks==2,"tank binds two moving tracks")
    t.Update=function() end
    exercise=coroutine.create(function() Exercise(t,"tank");app.blueprint=original;app:Reload() end);ResumeExercise()
end)
V.atFrame(225,function()
    V.assert(app.mode=="hangar" and previous.disposed and app.blueprint==original,"second return restores original car")
    V.assert(cache:GetExistingResource("Model","Track/model-0.mdl")==nil,"second return releases trial resources")
    local f=assert(io.open('docs/migration/evidence/trial-measurements.json','w'));f:write(cjson.encode(measured));f:close()
    V.finish()
end)
