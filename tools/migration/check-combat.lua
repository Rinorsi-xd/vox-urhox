---@type HangarApp|nil
local app=nil
---@type table|nil
local trial=nil
local measurements={}
local Weapons=require "combat.WeaponSystem"
local Defs=require "combat.WeaponDefs"
local Math=require "core.Math3"
local Coord=require "core.Coord"
engine.maxInactiveFps=120
local function Fresh(target,world)
    target.alive=true;target.hp=target.definition.hp;target.native.enabled=true;target.hitAt=-9
    world.space:Step(1/60)
end
local function State(t,p,aim)
    return {firing=true,pos=p,quat={x=0,y=math.sin(math.pi/4),z=0,w=math.cos(math.pi/4)},
        vel={0,0,0},aim=aim,body=t.vehicle.body}
end
local function Mount(kind)
    return {weapons={{type=kind,partId=1,pivot={0,0,0},off={0,0,0},muzzle={0,0,0},
        quat={x=0,y=0,z=0,w=1},dir={0,0,1}}}}
end
V.atFrame(45,function()
    app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),"combat scene requested")
end)
V.atFrame(90,function()
    trial=assert(app.trial);local t=trial;local world=t.world;local target=world.targets[1]
    local kinds={};for kind,stats in pairs(Defs.STATS) do if not stats.homing and not stats.drill then kinds[#kinds+1]=kind end end;table.sort(kinds)
    for _,kind in ipairs(kinds) do
        Fresh(target,world);t.effects:Clear()
        local ws=Weapons.New(Mount(kind),function() return .5 end)
        local start=world.stats.hits;local shot=world.stats.shots;local hp=target.hp
        for _=1,180 do
            ws:Step(1/60,State(t,{36,1.6,8},{48,1.6,8}),world.env)
            t.effects:Consume(ws.fx);t.effects:Update(1/60,ws.projectiles,t.camera:GetNode())
            if world.stats.hits>start then break end
        end
        V.assert(world.stats.shots>shot,kind.." fires against native world")
        V.assert(world.stats.hits>start and target.hp<hp,kind.." damages real target")
        V.assert(t.effects.events>0,kind.." consumes fixed-step effects")
        t.targetFeedback:Update(world.targets,world.time,t.camera:GetNode(),1/60)
        V.assert(t.targetFeedback.batch.count==2,kind.." damaged target has one world health bar")
        measurements[kind]={hp=target.hp,shots=world.stats.shots-shot,energy=ws.energy}
    end
    -- An actual collider between muzzle and target must block both hitscan and swept bolts.
    local wall=world.root:CreateChild("CombatTestWall");wall.position=Coord.Vec(42,1.6,8)
    wall:CreateComponent("CollisionShape"):SetBox(Vector3(1,4,4))
    local rigid=wall:CreateComponent("RigidBody");world.space:Register(rigid,{type="obstacle"});world.space:Step(1/60)
    for _,kind in ipairs({"laser5","mg5","sniper5"}) do
        Fresh(target,world);local ws=Weapons.New(Mount(kind),function() return .5 end)
        for _=1,120 do ws:Step(1/60,State(t,{36,1.6,8},{48,1.6,8}),world.env) end
        V.assert(target.hp==target.definition.hp,kind.." cannot shoot through native wall")
    end
    world.space:Unregister(rigid);wall:Dispose();world.space:Step(1/60)
    local camera=t.camera:GetNode();local savedPosition,savedRotation=camera.position,camera.rotation
    camera.position=Coord.Vec(36,1.6,8);camera:LookAt(Coord.Vec(48,1.6,8))
    local aim=t:Aim()
    V.assert(t.aimHit and t.aimHit.owner.ref==target and math.abs(aim[1]-47.85)<.02,"camera centre aim resolves native target in source coordinates")
    camera.position=savedPosition;camera.rotation=savedRotation
    -- Target death disables collider and damage; respawn restores exactly once.
    local hit=world.space:Raycast({36,1.6,8},{1,0,0},20,t.vehicle.body)
    V.assert(hit and hit.owner.ref==target,"nearest ray selects intended board")
    local kills=world.stats.kills;world:Hit(hit,10000,{1,0,0},0)
    V.assert(not target.alive and target.hp==0 and world.stats.kills==kills+1,"lethal damage marks target dead once")
    world:Hit(hit,10000,{1,0,0},0)
    V.assert(world.stats.kills==kills+1,"dead target cannot count duplicate kills")
    world:Step(1/60)
    local after=world.space:Raycast({36,1.6,8},{1,0,0},20,t.vehicle.body)
    V.assert(not after or after.owner.ref~=target,"destroyed target no longer blocks rays")
    for _=1,245 do world:Step(1/60) end
    V.assert(target.alive and target.hp==target.definition.hp,"target respawns with full health after four seconds")
    local moving=world.targets[9];local before=moving.node.position.z
    world:Step(.1);V.assert(math.abs(moving.node.position.z-before)>.01,"moving target follows source motion")
    local pos=moving.body.translation();local movingHit=world.space:Raycast({pos.x-3,1.6,pos.z},{1,0,0},6,t.vehicle.body)
    V.assert(movingHit and movingHit.owner.ref==moving,"native ray follows moving target")
    local cone=world.cones[1];local cp=cone.body.translation();local old=cone.body.linvel()
    world:Hit({owner={type="cone",ref=cone},point={cp.x,cp.y,cp.z}},10,{1,0,0},100)
    V.assert(cone.body.linvel().x>old.x+1,"shots impulse dynamic cones")
    -- Real mounted car weapons, animation, event collection across multi-step frames.
    Fresh(target,world);t.vehicle:Place({28,0,8},math.pi/2);t.view:ResetPose()
    for _=1,180 do t:Tick(1/60,{throttle=0,steer=0,aim={48,1.6,8}}) end
    local oldHits=world.stats.hits;local effects=t.effects.events
    for _=1,60 do t:Tick(1/30,{throttle=0,steer=0,aim={48,1.6,8},firing=true}) end
    V.assert(world.stats.hits>oldHits,"TrialSession mounted guns hit native target")
    V.assert(t.effects.events>effects+2,"30 Hz presentation consumes events from every 60 Hz step")
    local g=t.weapons:Group();local w=g.weapons[1]
    V.assert(math.abs(w.spinAngle)>0 and t.view.view.visuals[w.id].rig.head~=nil,"firing drives mounted rig state")
    local p=t.vehicle.body.translation()
    local ray=world.space:Raycast({p.x,p.y+10,p.z},{0,-1,0},20,t.vehicle.body)
    V.assert(ray and ray.body.native~=t.vehicle.native,"aim ray excludes player body")
    t.weapons.energy=0;t.weapons.offline=false
    for _=1,60 do t:Tick(1/60,{throttle=0,steer=0,firing=true,aim={48,1.6,8}}) end
    V.assert(t.weapons.offline,"continuous fire exhausts energy")
    for _=1,120 do t:Tick(1/60,{throttle=0,steer=0,aim={48,1.6,8}}) end
    V.assert(not t.weapons.offline and t.weapons.energy>=25,"release allows energy recovery and restart")
    -- Replay the current PC capture adapter, without controlling desktop input.
    local pointer=t.pointer;local setMode=pointer.SetMouseMode
    pointer.SetMouseMode=function() end
    local function Event(touch)
        return {IsTouch=function() return touch end,IsPrimaryButton=function() return true end}
    end
    t.hud.playfield.props.onPointerDown(Event(true))
    V.assert(not pointer.captured,"touch does not capture the PC playfield")
    t.hud.playfield.props.onPointerDown(Event(false))
    V.assert(pointer.captured and not t.controls.held.fire,"entry click captures without firing")
    pointer:Sample({left=true},.016);pointer:Sample({left=true},.016)
    V.assert(not t.controls.held.fire,"capture click remains suppressed until release")
    pointer:Sample({},.016);pointer:Sample({left=true,dx=12,dy=-3},.016)
    V.assert(t.controls.held.fire,"captured primary button fires")
    local dx,dy=t.controls:TakeLook()
    V.assert(dx==12 and dy==-3,"captured mouse movement feeds view deltas")
    pointer:Sample({left=true,right=true},.016);pointer:Sample({left=true},.016)
    V.assert(t.controls.held.fire,"releasing scope button preserves primary fire")
    pointer:Sample({},.016);V.assert(not t.controls.held.fire,"primary release clears fire")
    pointer:Sample({left=true},.016);t:Pause()
    V.assert(not pointer.captured and not t.controls.held.fire and not t.scope,"pause releases look, fire and scope")
    pointer.SetMouseMode=setMode
    t.controls.held.fire=true;t:Reset();V.assert(not t.controls.held.fire and #t.weapons.projectiles==0,"reset cancels fire and in-flight bolts")
    for _,batch in pairs(t.effects.batches) do V.assert(batch.count<=batch.limit,"effect draw budget is bounded") end
    local stats=world.stats.shots
    local burst={type="beam",kind="sniper",tier=5,from={28,2,8},to={48,1.6,8},dir=Math.Normalize({20,-.4,0}),hit=true,normal={-1,0,0}}
    for _=1,100 do t.effects:Consume({burst}) end
    t.effects:Update(.05,{},t.camera:GetNode())
    V.assert(#t.effects.beams<=64 and #t.effects.rings<=40 and #t.effects.particles<=t.effects.maxParticles,"burst overload stays within transient capacities")
    for _,batch in pairs(t.effects.batches) do
        V.assert(batch.count<=batch.limit and batch.mesh:GetNumVertices(0)<=batch.limit*6,"burst geometry stays within upload limit")
    end
    V.assert(world.stats.shots==stats,"render-only events never mutate combat simulation")
    for _=1,40 do t.effects:Update(.1,{},t.camera:GetNode()) end
    local total=0;for _,batch in pairs(t.effects.batches) do total=total+batch.count end
    V.assert(total==0 and #t.effects.beams==0 and #t.effects.rings==0,"all transient effects expire without leaving visible geometry")
    -- Stable screenshot: actual same-app car, native target and source event path.
    t.vehicle:Place({28,0,8},math.pi/2);t.view:ResetPose();t.weapons:Select(2)
    Fresh(target,world);t.weapons.energy=100;t.weapons.offline=false
    t.yaw=-72;t.pitch=9
    for _=1,180 do t:Tick(1/60,{throttle=0,steer=0,aim={48,1.6,8}}) end
    t:PostUpdate(1)
    local shots=world.stats.shots
    for _=1,180 do
        t:Tick(1/60,{throttle=0,steer=0,firing=true,aim={48,1.6,8}})
        if world.stats.shots>shots then break end
    end
    t:Tick(.04,{throttle=0,steer=0,aim={48,1.6,8}})
    V.assert(t.effects.batches.Ribbon.count>0,"native beam batch contains actual shot")
    for _,arg in ipairs(GetArguments()) do
        if arg=="-combat-phase=late" then t.effects:Update(.22,{},t.camera:GetNode());world.time=world.time+.22
        elseif arg=="-combat-phase=clear" then
            for _=1,25 do t.effects:Update(.1,{},t.camera:GetNode()) end
            world.time=world.time+2.5
        end
    end
    t.targetFeedback:Update(world.targets,world.time,t.camera:GetNode(),0);t:Aim();t.hud.Update(t)
    t.Update=function() end;t.PostUpdate=function() end
    local file=assert(io.open("docs/migration/evidence/combat-measurements.json","w"));file:write(cjson.encode(measurements));file:close()
end)
V.atFrame(132,function() app:Reload() end)
V.atFrame(175,function()
    V.assert(app.mode=="hangar" and trial.disposed and trial.effects.disposed,"return releases combat session and batches")
    V.assert(app.scene:GetChild("CombatEffects",true)==nil,"no combat draw nodes remain in hangar")
    V.finish()
end)
