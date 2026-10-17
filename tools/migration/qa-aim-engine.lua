-- Optional QA-only tail. F16 runs a private, unrendered real-engine fixture.
-- This checks real Bullet + shipping combat paths; it is not natural play/FPS QA.
do
    local running,finished=false,false
    local task=nil
    local report=nil
    local owned={}
    local function Check(ok,name,detail)
        report.checks[#report.checks+1]={name=name,ok=ok==true,detail=detail}
        assert(ok,name)
    end
    local function Emit()
        -- Engine console messages can be cut mid-JSON. Keep each record small;
        -- the runner requires every numbered chunk before accepting the report.
        local text=cjson.encode(report);local size=1800
        local total=math.ceil(#text/size)
        for index=1,total do
            print('QA_AIM_ENGINE_CHUNK '..cjson.encode({runId=report.runId,index=index,total=total,
                text=text:sub((index-1)*size+1,index*size)}))
        end
    end
    local function Cleanup()
        if owned.gate then owned.gate:Cancel() end
        if owned.session then require('controls.DriveAim').Clear(owned.session) end
        for _,unit in ipairs(owned.units or {}) do unit:Dispose() end
        if owned.world then owned.world.debris:Clear();owned.world.space:Dispose() end
        if owned.scene then owned.scene:Dispose() end
        owned={}
    end
    local function Run()
        local Gate=require 'app.ResourceGate'
        local function Ready(paths,label)
            local gate=Gate.New();owned.gate=gate
            local done,success,message=false,false,''
            gate:Start(paths,function(ok,why) done=true;success=ok;message=why end)
            while not done do coroutine.yield() end
            Check(success,label,message)
            for _,path in ipairs(paths) do assert(cache:Exists(path),'QA resource unavailable: '..path) end
            gate:Cancel();owned.gate=nil
        end
        -- Hall readiness does not imply readiness of this fixture's laser rig.
        Ready({'Parts/Dependencies.json'},'fixture dependency index downloaded')
        local Dependencies=require 'parts.Dependencies'
        local resources=Dependencies.For({{type='core',rot=10},{type='cube',rot=10},{type='laser3',rot=10}})
        Ready(resources,'fixture native vehicle resources downloaded')
        report.resources={count=#resources,ready=true}
        local V=require 'core.Math3'
        local Coord=require 'core.Coord'
        local Blueprint=require 'construction.Blueprint'
        local Space=require 'physics.Space'
        local TrackWorld=require 'drive.TrackWorld'
        local CarUnit=require 'combat.CarUnit'
        local Debris=require 'combat.Debris'
        local Metrics=require 'drive.TrialMetrics'
        local Assist=require 'combat.AimAssist'
        local Reach=require 'combat.AimReach'
        local WeaponDefs=require 'combat.WeaponDefs'
        local DriveAim=require 'controls.DriveAim'
        local scene=Scene();owned.scene=scene;scene:CreateComponent('Octree')
        local world={scene=scene,space=Space.New(scene),units={},time=0,targets={},cones={},fx={},viewEvents={},
            stats={shots=0,hits=0,damage=0,kills=0},metrics=Metrics.New({})}
        owned.world=world;world.debris=Debris.New(world.space)
        for _,method in ipairs({'NewVehicle','CastRay','Hit','RecordDamage','RecordKill'}) do world[method]=TrackWorld[method] end
        local function Tower(gun)
            local bp=Blueprint.New();bp:Add{type='core',pos={0,0,0},rot=10}
            for y=1,gun and 2 or 5 do bp:Add{type='cube',pos={0,y,0},rot=10} end
            if gun then bp:Add{type='laser3',pos={0,3,0},rot=10} end
            return bp:ToTable()
        end
        owned.units={}
        local function Unit(gun,team,z)
            local u=CarUnit.New(world,Tower(gun),{name='qa-'..team,team=team,combat=true,autoRespawn=false,spawn={pos={0,0,z},yaw=0}})
            owned.units[#owned.units+1]=u;world.units[#world.units+1]=u
            Check(u.alive and u.vehicle~=nil,'real connected vehicle spawned '..team)
            u.vehicle.body.setTranslation({x=0,y=0,z=z});u:SavePose()
            return u
        end
        local player=Unit(true,'blue',0);local enemy=Unit(false,'red',5)
        coroutine.yield()
        local session={weapons=player.weapons,vehicle=player.vehicle,combat={player=player},world=world,app={touchPrefs={assist=true}},scope=false,touch=false}
        owned.session=session
        local weapon=assert(player.weapons:Group().weapons[1])
        Check(weapon.type=='laser3' and weapon.pivot~=nil,'actual loaded laser mount')
        local stats=weapon.stats
        local origin={0,3,-5};local direction=V.Normalize({.31,-2.75,10})
        local function Cast(...) return world:CastRay(...) end
        local raw=Cast(origin,direction,100,player.vehicle.body)
        Check(not raw or not raw.owner or raw.owner.ref~=enemy,'centre camera ray misses enemy for soft-lock fixture')
        local old=Assist.Apply(origin,direction,raw,player,world.units,Cast,stats,1)
        local reach=Reach.New(player.weapons,player.vehicle)
        Check(old and old.ref==enemy and old.point~=nil,'actual camera collision selects enemy low surface',old and old.point)
        Check(not reach(old.point),'baseline selected surface exceeds actual turret limits',old.point)
        local point=DriveAim.Resolve(session,origin,direction,raw)
        Check(point~=nil and session.aimRef==enemy and reach(point),'actual Resolve selects reachable same enemy surface',point)
        report.geometry={origin=origin,direction=direction,baseline=old.point,fallback=point,pivot=weapon.pivot,
            pitchLimits=weapon.stats.pitch,freeYaw=weapon.range and weapon.range.free}
        coroutine.yield()
        local exactDirection=V.Normalize(V.Sub(point,origin))
        local exactHit=world:CastRay(origin,exactDirection,100,player.vehicle.body)
        Check(exactHit and exactHit.owner and exactHit.owner.ref==enemy,'actual direct camera reticle hits enemy')
        local probe=session.aimReach;local reachCalls=0
        session.aimReach=function(...) reachCalls=reachCalls+1;return probe(...) end
        local exactPoint=DriveAim.Resolve(session,origin,exactDirection,exactHit)
        session.aimReach=probe
        Check(exactPoint==nil and session.aimRef==enemy and reachCalls==0,
            'actual direct reticle hit keeps exact surface and skips recovery',{point=exactHit.point,reachCalls=reachCalls})
        coroutine.yield()
        local function State()
            local p=player.vehicle.body.translation()
            return {pos={p.x,p.y,p.z},quat=player.vehicle.body.rotation(),body=player.vehicle.body,aim=point,firing=true}
        end
        local state=State();player.weapons:Aim(weapon,1000000,state)
        Check(player.weapons:Aligned(weapon),'real live turret can align')
        local muzzle=player.weapons:Muzzle(weapon,state)
        local shotDirection=V.Normalize(V.Sub(point,muzzle.pos))
        local first=world:CastRay(muzzle.pos,shotDirection,stats.range,player.vehicle.body)
        Check(first and first.owner and first.owner.ref==enemy,'real muzzle collision hits same enemy',first and first.point)
        local env={stats=world.stats,castRay=Cast,hit=function(...) world:Hit(...) end}
        local damage=world.stats.damage;local shots=world.stats.shots
        player.weapons:Fire(weapon,state,env)
        Check(world.stats.shots==shots+1 and world.stats.damage>damage,'actual laser Fire damages real enemy',{damage=world.stats.damage-damage,hits=world.stats.hits})
        coroutine.yield()
        -- Small native wall intersects the muzzle line while remaining clear of the camera line.
        local wallAt=V.Add(muzzle.pos,V.Scale(V.Sub(point,muzzle.pos),.25))
        local cameraT=(wallAt[3]-origin[3])/(point[3]-origin[3])
        local cameraAt=V.Add(origin,V.Scale(V.Sub(point,origin),cameraT))
        local separation=V.Length(V.Sub(cameraAt,wallAt));local width=math.min(.12,separation*.5)
        Check(width>.01,'camera and muzzle paths have separable geometry',separation)
        local wall=scene:CreateChild('QAMuzzleWall');wall.position=Coord.Vec(table.unpack(wallAt))
        wall:CreateComponent('CollisionShape'):SetBox(Vector3(width,width,width))
        local wallBody=wall:CreateComponent('RigidBody');wallBody.collisionLayer=1
        world.space:Register(wallBody,{type='qa-wall'})
        local cameraHit=world:CastRay(origin,V.Normalize(V.Sub(point,origin)),V.Length(V.Sub(point,origin))+1,player.vehicle.body)
        local muzzleHit=world:CastRay(muzzle.pos,shotDirection,stats.range,player.vehicle.body)
        Check(cameraHit and cameraHit.owner and cameraHit.owner.ref==enemy,'native muzzle wall does not occlude camera')
        Check(muzzleHit and muzzleHit.owner and muzzleHit.owner.type=='qa-wall','native muzzle wall blocks weapon ray',muzzleHit and muzzleHit.point)
        damage=world.stats.damage;shots=world.stats.shots
        player.weapons.energy=WeaponDefs.ENERGY.max
        player.weapons:Fire(weapon,state,env)
        Check(world.stats.shots==shots+1 and world.stats.damage==damage,'actual Fire cannot damage through native wall')
        report.wall={centre=wallAt,size=width,cameraHit=cameraHit.point,muzzleHit=muzzleHit.point}
        world.space:Unregister(wallBody);wall:Dispose()
        coroutine.yield()
        -- Camera obstacle begins above the original low ray, hiding every
        -- lifted surface while preserving the low point used for blocked feedback.
        local wallZ=(origin[3]+old.point[3])*0.5
        local lowT=(wallZ-origin[3])/(old.point[3]-origin[3])
        local lowAt=V.Add(origin,V.Scale(V.Sub(old.point,origin),lowT))
        local rawAt=V.Add(origin,V.Scale(direction,(wallZ-origin[3])/direction[3]))
        local highAt=V.Add(origin,V.Scale(exactDirection,(wallZ-origin[3])/exactDirection[3]))
        local bottom=(math.max(lowAt[2],rawAt[2])+highAt[2])*.5
        Check(bottom>math.max(lowAt[2],rawAt[2])+.02 and bottom<highAt[2]-.02,
            'camera low and recovered paths have separated native wall geometry')
        local cameraWall=scene:CreateChild('QACameraWall')
        cameraWall.position=Coord.Vec(lowAt[1],bottom+4,wallZ)
        cameraWall:CreateComponent('CollisionShape'):SetBox(Vector3(4,8,.02))
        local cameraWallBody=cameraWall:CreateComponent('RigidBody');cameraWallBody.collisionLayer=1
        world.space:Register(cameraWallBody,{type='qa-camera-wall'})
        local lowRay=world:CastRay(origin,V.Normalize(V.Sub(old.point,origin)),100,player.vehicle.body)
        local liftedRay=world:CastRay(origin,exactDirection,100,player.vehicle.body)
        Check(lowRay and lowRay.owner and lowRay.owner.ref==enemy,'native camera wall leaves original low surface visible')
        Check(liftedRay and liftedRay.owner and liftedRay.owner.type=='qa-camera-wall','native camera wall hides lifted surface')
        raw=world:CastRay(origin,direction,100,player.vehicle.body)
        local blocked=DriveAim.Resolve(session,origin,direction,raw)
        Check(blocked~=nil and session.aimRef==enemy and not reach(blocked),
            'actual recovery refuses camera-occluded reachable surface',blocked)
        state.aim=blocked;player.weapons:Aim(weapon,1000000,state)
        Check(not player.weapons:Aligned(weapon),'actual occluded fallback retains mechanical limit')
        shots=world.stats.shots;damage=world.stats.damage
        player.weapons.energy=WeaponDefs.ENERGY.max
        player.weapons:Fire(weapon,state,env)
        Check(world.stats.shots==shots and world.stats.damage==damage,'actual limited aim cannot fire through camera wall')
        report.cameraWall={centre={lowAt[1],bottom+4,wallZ},size={4,8,.02},
            lowHit=lowRay.point,liftedHit=liftedRay.point,blocked=blocked}
        world.space:Unregister(cameraWallBody);cameraWall:Dispose()
        coroutine.yield()
        local previousVehicle=player.vehicle;local previousWeapons=player.weapons;local previousCallback=session.aimReach
        player.dirty=true;player:Flush()
        Check(player.alive and player.vehicle~=previousVehicle,'actual CarUnit Flush replaces native vehicle')
        session.vehicle=player.vehicle;session.weapons=player.weapons
        raw=world:CastRay(origin,direction,100,player.vehicle.body)
        DriveAim.Resolve(session,origin,direction,raw)
        Check(session.aimReach~=previousCallback and session.aimReachVehicle==player.vehicle,'Resolve uses replacement native vehicle after Flush')
        previousCallback=session.aimReach
        player:Spawn();player.vehicle.body.setTranslation({x=0,y=0,z=0});player:SavePose()
        session.vehicle=player.vehicle;session.weapons=player.weapons
        Check(player.weapons~=previousWeapons,'actual Spawn replaces weapon system')
        raw=world:CastRay(origin,direction,100,player.vehicle.body)
        DriveAim.Resolve(session,origin,direction,raw)
        Check(session.aimReach~=previousCallback and session.aimReachSystem==player.weapons,'Resolve uses replacement weapon system after Spawn')
        DriveAim.Clear(session)
        Check(session.aimReach==nil and session.aimReachVehicle==nil and session.aimReachSystem==nil,'Clear releases callback retained owners')
    end
    local previous=HandleUpdate
    function HandleUpdate(eventType,eventData)
        if previous then previous(eventType,eventData) end
        if not running and not finished and input:GetKeyPress(KEY_F16) then
            report={schema=1,runId=tostring(os.time())..'-aim',checks={},boundary='QA private unrendered native Bullet scene; real CarUnit, WeaponLoadout, CastRay, Hit and Fire. No natural game input or performance claim.'}
            task=coroutine.create(Run);running=true
        end
        if not running then return end
        local ok,err=coroutine.resume(task)
        if not ok or coroutine.status(task)=='dead' then
            running=false;finished=true;report.result=ok and 'PASS' or 'FAIL';if not ok then report.failure=tostring(err) end
            local clean,why=pcall(Cleanup);report.cleanup=clean
            if not clean then report.result='FAIL';report.cleanupFailure=tostring(why) end
            Emit()
        end
    end
end
