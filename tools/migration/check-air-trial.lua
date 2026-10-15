local Math=require "core.Math3"
local Coord=require "core.Coord"
---@type HangarApp|nil
local app=nil
---@type table|nil
local trial=nil
local phase='active'
for _,arg in ipairs(GetArguments()) do phase=arg:match('^%-air%-phase=(.+)$') or phase end
engine.maxInactiveFps=120
local function Step(seconds,command)
    for _=1,math.floor(seconds*60+.5) do trial:Tick(1/60,command or {}) end
end
V.atFrame(45,function()
    app=assert(VOX_HANGAR).app
    V.assert(app:EnterTrial(),'source aircraft enters existing trial session')
end)
V.atFrame(90,function()
    trial=assert(app.trial);local t=trial;local v=t.vehicle
    local lift=#v.spec.thrusters>0
    local lifts=0;for _,jet in ipairs(v.spec.thrusters) do if jet.dir[2]>.7 then lifts=lifts+1 end end
    V.assert((lift and lifts==6) or (#v.spec.hovers==4 and v.hoverMode),'source blueprint has actual actuators')
    v:Place({0,0,-40},0);t.view:ResetPose();t.yaw=145;t.pitch=16
    Step(8)
    V.assert(not t.hud.holds,'PC aircraft HUD has no abandoned touch controls')
    t.controls.held.climb=true;t.controls.held.cutLift=true;t.controls.held.fire=true;t:Pause()
    V.assert(not next(t.controls.held) and not t.pointer.captured,'PC pause releases aircraft lift, cutoff and weapons')
    local initial=v.body.translation().y
    Step(lift and 2 or 1,{climb=1});Step(5)
    V.assert(v.body.translation().y>initial+(lift and 4 or .15),'same session supports commanded ascent')
    if lift then
        Step(1.5,{throttle=1})
        for _,item in ipairs(t.view.actuators.items) do
            local direction=v.thrusterDirections[item.id]
            local actual=item.vis.rig.gimbal.worldRotation*Coord.Vec(table.unpack(item.vis.data.segments.info.exhaustDir))
            local expected=Math.Rotate(v.body.rotation(),Math.Scale(direction,-1));local target=Coord.Vec(table.unpack(expected))
            V.assert(actual:DotProduct(target)>.999,'visible gimbal follows physical thrust direction '..item.id)
            if #item.vis.rig.rotors>0 then
                V.assert(item.motor>0 and math.abs(item.angles[1] or 0)>.01,'native rotor spins under output '..item.id)
            end
        end
        local motor=t.view.actuators.items[1].motor
        Step(.1,{cutLift=true})
        V.assert(t.view.actuators.items[1].motor<motor and t.view.actuators.items[1].motor>0,'rotor coasts after cutoff')
        Step(2,{climb=1});Step(4)
    else
        for _,item in ipairs(t.view.actuators.items) do
            V.assert(math.abs(item.angles[1] or 0)>.01,'native hover ring follows supported force '..item.id)
        end
        Step(1,{strafe=1});V.assert(v.body.linvel().x>1,'hover strafe drives real vehicle')
        Step(5)
    end
    local retained=t.view.actuators.items[#t.view.actuators.items];local angle=retained.angles[1];local motor=retained.motor
    t.view:Bind(app.blueprint,v)
    local rebound=t.view.actuators.items[#t.view.actuators.items]
    V.assert(rebound.angles[1]==angle and rebound.motor==motor,'rebinding surviving actuators preserves angle and spool')
    local measured={state=v:GetState(),telemetry=v.telemetry,actuators=#t.view.actuators.items}
    local f=assert(io.open('docs/migration/evidence/air-trial-'..(lift and 'lift' or 'hover')..'-measurements.json','w'));f:write(cjson.encode(measured));f:close()
    if phase=='idle' then t:Reset();v:Place({0,0,-40},0);t.view:ResetPose();Step(6)
    elseif phase=='cut' and lift then Step(.45,{cutLift=true})
    elseif lift then Step(.5,{throttle=1}) end
    t.yaw=145;t.pitch=16;t:PostUpdate(1);t.hud.Update(t)
    t.Update=function() end;t.PostUpdate=function() end
end)
V.atFrame(132,function() app:Reload() end)
V.atFrame(175,function()
    V.assert(app.mode=='hangar' and trial.disposed,'return disposes air trial and restores same blueprint in hangar')
    V.assert(#trial.world.units==0 and #trial.world.debris.pieces==0,'air target cars release on exit')
    V.finish()
end)
