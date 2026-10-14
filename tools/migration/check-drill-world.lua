local SceneWorld=Scene();SceneWorld:CreateComponent('Octree')
local Space=require 'physics.Space'
local M=require 'core.Math3'
local Coord=require 'core.Coord'
local Weapons=require 'combat.WeaponSystem'
local space=Space.New(SceneWorld);space.world.gravity=Vector3.ZERO
local world={scene=SceneWorld,space=space,units={}}
local Sweep=require('physics.DrillSweep').New(world)
local function Box(name,p,size,owner,mass)
    local n=SceneWorld:CreateChild(name);n.position=Coord.Vec(table.unpack(p))
    n:CreateComponent('CollisionShape'):SetBox(Vector3(table.unpack(size)))
    local b=n:CreateComponent('RigidBody');b.mass=mass or 0;b.collisionLayer=2
    return space:Register(b,owner),n
end
local function Slice(x,y,z) return {{pos={x,y,z},half={1,1,1},quat={x=0,y=0,z=0,w=1}}} end
local app=nil ---@type HangarApp|nil
V.atFrame(55,function()
    local body=Box('Own',{0,20,0},{3,3,3},{type='car'},100)
    local wall,node=Box('ShoulderWall',{.9,20,5},{.3,3,.5},{type='obstacle'})
    space:Step(1/60)
    local hit=Sweep:Cast({0,20,0},{0,0,1},10,body,Slice(0,20,0))
    V.assert(hit and hit.body==wall and math.abs(hit.dist-3.75)<.1,'blade shoulder hits wall missed by centre ray')
    V.assert(body.native.collisionLayer==2,'own collision layer restored after every sweep')
    local trigger=Box('UnrelatedTrigger',{0,20,2},{4,4,.5},{type='sensor'});trigger.native.trigger=true
    local floor=Box('SupportingRoad',{0,18.6,2},{20,1,20},{type='ground'})
    space:Step(1/60)
    local after=Sweep:Cast({0,20,0},{0,0,1},10,body,Slice(0,20,0))
    V.assert(after and after.body==wall,'supporting road and unrelated trigger cannot hide a forward wall')
    V.assert(trigger.native.collisionLayer==2 and floor.native.collisionLayer==2,'ignored bodies restore query filters')
    local enemy=Box('SensorOwner',{20,20,0},{1,1,1},{type='car'},200)
    local sensor={center={-20,0,3},half={.5,.5,.25},partId=73}
    local unit={alive=true,vehicle={body=enemy,spec={sensors={sensor}},legHitboxes={items={}}}}
    world.units={unit};space:Step(1/60)
    local sensed=Sweep:Cast({0,20,0},{0,0,1},10,body,Slice(0,20,0))
    V.assert(sensed and sensed.owner.ref==unit and sensed.owner.partId==73,'swept blade includes non-colliding track/leg sensors with part id')
    V.assert(#Sweep.sensors==1 and Sweep.sensors[1].body.collisionLayer==0 and Sweep.sensors[1].body.collisionMask==0x4000,'pooled hit sensors never support physics or ordinary rays')
    sensor.center[3]=8
    local moved=Sweep:Cast({0,20,0},{0,0,1},10,body,Slice(0,20,0))
    V.assert(moved and moved.body==wall and #Sweep.sensors==1,'sensor follows new pose without allocating another native shape')
    local casts=Sweep.casts;local t=os.clock()
    for _=1,120 do Sweep:Cast({0,20,0},{0,0,1},10,body,Slice(0,20,0)) end
    print('DRILL_SWEEP_BUDGET '..cjson.encode({casts=Sweep.casts-casts,milliseconds=(os.clock()-t)*1000,sensorPool=#Sweep.sensors,probePool=#Sweep.probes}))
    local initialCcd={radius=.31,threshold=.27};body.enableCcd(initialCcd)
    for _,type in ipairs({'tianyuanDrill','fuyuanDrill'}) do
        body.setTranslation({x=0,y=30,z=0});body.setLinvel({x=0,y=0,z=0});body.setAngvel({x=0,y=0,z=0})
        local ws=Weapons.New({weapons={{type=type,partId=1,muzzle={0,0,1},dir={0,0,1},quat={x=0,y=0,z=0,w=1}}}})
        local dealt=0;local env={stats={shots=0}}
        env.sweepDrill=function() return {dist=.1,point={0,30,2},normal={0,0,-1},owner={type='car',ref=unit}} end
        env.hit=function(_,damage) dealt=dealt+damage end
        local function Step(firing)
            local state={firing=firing,pos=M.Array(body.translation()),quat=body.rotation(),aim={0,30,50},body=body}
            ws:Step(1/60,state,env);space:Step(1/60)
        end
        for _=1,90 do Step(true) end;Step(false)
        V.assert(ws.drill.active and dealt>0,type..' real native body enters attack and damages victim')
        V.assert(type~='fuyuanDrill' or body.native.kinematic,type..' latch uses native kinematic mode')
        local rs=require('ui.ReticleState').Fire(ws,false,'',0,false)
        V.assert(rs.word==(type=='fuyuanDrill' and '咬住' or '突进'),type..' original reticle reports actual attack')
        for _=1,110 do Step(false) end
        V.assert(not ws.drill.active and not body.native.kinematic,type..' naturally finishes and restores dynamic body')
        V.assert(math.abs(body.native.ccdRadius-.31)<1e-5 and math.abs(body.native.ccdMotionThreshold-.27)<1e-5,type..' restores exact native CCD settings')
        V.assert(type~='fuyuanDrill' or body.linvel().y>9,type..' final fling leaves upward velocity')
        ws.drill:Cancel()
        local speed=require('render.DrillSpeed').New();local camera=SceneWorld:CreateChild('TestCamera'):CreateComponent('Camera')
        camera.node.position=Vector3(0,30,-5)
        ws.drill.active={phase='dash',dir={0,0,1},grinding=false,w={stats={easter=type=='fuyuanDrill'}}}
        local views=renderer.numViewports;speed:Update(.2,camera,ws,true)
        V.assert(speed.visible and speed.scene and renderer.numViewports==views+1,'speed shader appends one overlay without render target allocation')
        speed:Clear();V.assert(not speed.mesh.enabled,'pause hides speed streaks immediately')
        speed:Dispose();V.assert(renderer.numViewports==views,'overlay disposal restores viewport count')
        ws.drill.active=nil
    end
    space:Unregister(body.native);V.assert(not body.isValid(),'disposed body adapter cannot be reused by attack motor')
    Sweep:Dispose();SceneWorld:Dispose()
    app=assert(VOX_HANGAR).app
    local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'tianyuan')
    local ok,why=app:LoadBlueprint(bp:ToTable());V.assert(ok,why or 'original Tianyuan tank loaded');V.assert(app:EnterTrial(),'actual trial requested with original drill prefab')
end)
V.atFrame(95,function()
    local t=assert(app.trial);V.assert(t.weapons:Group().weapons[1].stats.drill,'original prefab creates real drill weapon group')
    local ws=t.weapons;local b=t.vehicle.body
    for _=1,90 do t:Tick(1/60,{throttle=0,steer=0,firing=true,aim={0,2,100}}) end
    V.assert(ws.drill.held and ws.drill.held.windup==1,'TrialSession holds native charge from normal firing input')
    t:Tick(1/60,{throttle=0,steer=0,firing=false,aim={0,2,100}})
    V.assert(ws.drill:ControlsBody(),'TrialSession release starts body motor')
    local before=b.translation();t:Tick(1/60,{throttle=-1,steer=1,aim={0,2,100}});local after=b.translation()
    V.assert(after.z>before.z+.3,'drill drives actual vehicle despite reverse steering command')
    t.pointer.captured=true;t:PostUpdate(.1);V.assert(t.drillSpeed.visible,'actual trial uses source speed shader')
    local g=ws:Group();local vis=t.view.view.visuals[g.weapons[1].id]
    V.assert(vis and vis.rig.spin and math.abs(vis.rig.spin.rotation.z)>.001,'actual segmented drill blade spins')
    t:Pause();V.assert(not ws.drill.active and not t.vehicle.native.kinematic and not t.drillSpeed.visible,'pause cancels motor and overlay')
    -- Real native target car, source drill mount, actual part damage and rebuild.
    local target=t.world.units[1];target.vehicle:Place({0,0,30},math.pi);target:SavePose()
    t.vehicle:Place({0,0,0},0);t.view:ResetPose()
    ws.energy=100;ws.offline=false;for _,w in ipairs(ws:Group().weapons) do w.cool=0 end
    local hits=t.world.stats.hits;local health=target:Health()
    for _=1,90 do t:Tick(1/60,{throttle=0,steer=0,firing=true,aim={0,2,30}}) end
    for _=1,100 do t:Tick(1/60,{throttle=0,steer=0,aim={0,2,30}}) end
    V.assert(t.world.stats.hits>hits and target:Health()<health,'real drill damages original target car through native swept contacts')
    V.assert(t.world.drillSweep and #t.world.drillSweep.probes==5,'production world reuses original five blade slices')
    local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'fuyuan')
    local unit=require('combat.CarUnit').New(t.world,bp:ToTable(),{name='DrillRebuildQA',spawn={pos={70,30,0},yaw=0},combat=true})
    local wpn=unit.weapons;local body=unit.vehicle.body
    local env={stats={shots=0},sweepDrill=function() return {dist=.1,point={70,30,2},normal={0,0,-1},owner={type='car',ref=target}} end,hit=function() end}
    local function Fire(press)
        wpn:Step(1/60,{firing=press,pos=M.Array(body.translation()),quat=body.rotation(),aim={70,30,50},body=body},env)
    end
    for _=1,90 do Fire(true) end;Fire(false)
    V.assert(body.native.kinematic and wpn.drill:Latched(),'real unit latched before damaged refit')
    local part=nil ---@type BlueprintPart|nil
    for _,p in ipairs(unit.bp:List()) do if p.type=='cube' then part=p;break end end
    unit:Destroy(assert(part).id);unit:Flush()
    V.assert(unit.alive and not body.isValid() and not unit.vehicle.native.kinematic and not wpn.drill.active,'damage refit cancels before native body snapshot/disposal')
    unit:Dispose();V.assert(not unit.vehicle and not wpn.drill.active,'unit disposal leaves no live drill body')
    V.finish()
end)
