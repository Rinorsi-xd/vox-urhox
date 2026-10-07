local Math=require "core.Math3"
local LegView=require "render.LegView"
local Coord=require "core.Coord"
local Ray=require "combat.VehicleRay"
local CELL=require("Config").CELL
local phase='walk1';local app,trial
for _,arg in ipairs(GetArguments()) do phase=arg:match('^%-leg%-phase=(.+)$') or phase end
engine.maxInactiveFps=120
local function Step(seconds,command,each)
    for i=1,math.floor(seconds*60+.5) do trial:Tick(1/60,command or {});if each then each(i) end end
end
V.atFrame(45,function()
    app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),'leg blueprint enters shared trial')
end)
V.atFrame(90,function()
    trial=assert(app.trial);local t=trial;local v=t.vehicle
    v:Place({0,0,-70},0);t.view:ResetPose();Step(4)
    V.assert(#t.view.legs.items==#v.spec.legs,'actual rig bound to every leg')
    V.assert(not t.hud.holds,'PC leg HUD has no abandoned touch controls')
    t.controls.held.jump=true;t.controls.held.strafeLeft=true;t.controls.held.fire=true;t:Pause()
    V.assert(not next(t.controls.held) and not t.pointer.captured,'PC pause releases jump, strafe and weapons')
    local maxError,samples,maxSensor=0,0,0
    Step(2,{throttle=.5},function(i)
        if i%3~=0 then return end
        for _,alpha in ipairs({0,.5,1}) do
            t.view:Update(alpha,1/60)
            for _,item in ipairs(t.view.legs.items) do
                local s=v.legStates[item.id]
                if s.grounded then maxError=math.max(maxError,Math.Length(Math.Sub(LegView.ToeWorld(item),s.foot)));samples=samples+1 end
            end
        end
        -- At alpha=0 the visual body equals the controller's pre-physics pose.
        t.view:Update(0,1/60)
        for _,sensor in ipairs(v.legHitboxes.items) do
            local s=v.legStates[sensor.partId]
            if s.grounded then
                local vis=t.view.view.visuals[sensor.partId]
                local a=vis.rig.joints[sensor.name]:LocalToWorld(Coord.Vec(table.unpack(sensor.segmentCenter)))
                local b=t.view.view.root:LocalToWorld(Coord.Vec(table.unpack(Math.Scale(sensor.center,1/CELL))))
                maxSensor=math.max(maxSensor,(a-b).length)
            end
        end
    end)
    V.assert(samples>200 and maxError<.025,'rendered stance toes remain locked through body interpolation')
    V.assert(maxSensor<.001,'animated sensor centers match actual native joint hierarchy')
    local hits=0
    for _,sensor in ipairs(v.legHitboxes.items) do if sensor.name=='blade' then
        local p=v.body.translation();local origin=Math.Add(Math.Array(p),Math.Rotate(v.body.rotation(),sensor.center))
        local hit=Ray.Cast(v,origin,{0,1,0},.1)
        if hit and hit.partId==sensor.partId then hits=hits+1 end
    end end
    V.assert(hits==#v.spec.legs,'current moving blade sensors return source part IDs')
    local target=t.world.units[1];local original=target.vehicle;local removed=original.spec.legs[1].partId
    local survivor=original.spec.legs[2].partId;local foot=original.legStates[survivor].foot
    target:Damage(removed,10000,target:Position());target:Flush();t.combatView:Consume(t.world)
    V.assert(target.alive and #target.vehicle.spec.legs==#v.spec.legs-1,'destroying a leg rebuilds surviving mobile chassis')
    V.assert(original.disposed and target.vehicle.legStates[removed]==nil,'old body and removed leg state released')
    V.assert(Math.Length(Math.Sub(target.vehicle.legStates[survivor].foot,foot))<1e-6,'rebuild retains surviving planted foot')
    V.assert(#t.combatView.units[target].legs.items==#v.spec.legs-1,'rebuild removes corresponding visual rig')
    Step(.1);V.assert(target.vehicle.telemetry.legAvailable==#v.spec.legs-1,'surviving legs resume support')
    v:Place({0,0,-70},0);t.view:ResetPose();Step(4)
    V.assert(v.legControl.cooldown==0 and v.legControl.phase==0,'reset clears jump and gait clock')
    if phase=='wall' then
        v:Place({-66,0,-32},0);t.view:ResetPose();Step(1)
        local climbed=false
        for i=1,480 do
            Step(1/60,{throttle=1})
            if v.telemetry.legClimbing and v.body.center().y>3 and Math.Rotate(v.body.rotation(),{0,1,0})[2]<.7 then climbed=true;break end
        end
        V.assert(climbed,'wall screenshot captures actual tilted chassis climbing above 3 metres')
    elseif phase=='jump' then Step(.35,{jump=true,throttle=.3})
    elseif phase=='walk1' then Step(.5,{throttle=.5})
    elseif phase=='walk2' then Step(.65,{throttle=.5})
    elseif phase=='walk3' then Step(.8,{throttle=.5}) end
    t.view:Update(.5,1/60);t.yaw=phase=='wall' and 0 or 140;t.pitch=phase=='wall' and 15 or 22;t:PostUpdate(1);t.hud.Update(t)
    local root=t.view.view.root
    V.assert((t.target.position-(root.position+root.rotation*Coord.Vec(table.unpack(v.com)))).length<.001,'leg follow target tracks interpolated chassis center on floor and wall')
    local f=assert(io.open('docs/migration/evidence/leg-trial-measurements.json','w'))
    f:write(cjson.encode({samples=samples,maxToeError=maxError,maxSensorError=maxSensor,hits=hits,phase=phase,telemetry=v.telemetry}));f:close()
    t.Update=function() end;t.PostUpdate=function() end
end)
V.atFrame(132,function() app:Reload() end)
V.atFrame(175,function()
    V.assert(app.mode=='hangar' and trial.disposed,'return releases leg trial and restores shared hangar')
    V.assert(#trial.world.units==0 and #trial.world.debris.pieces==0,'target leg rigs and debris released')
    V.finish()
end)
