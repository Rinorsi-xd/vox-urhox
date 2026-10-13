local Unit=require "combat.CarUnit"
local BP=require "construction.Blueprint"
local Spec=require "drive.VehicleSpec"
local V3=require "core.Math3"
local Ray=require "combat.VehicleRay"
local Coord=require "core.Coord"
local f=assert(io.open('tools/migration/source-damage-fixtures.json','r'));local fixtures=cjson.decode(f:read('*a'));f:close()
---@type table|nil
local app=nil
---@type table|nil
local trial=nil
engine.maxInactiveFps=120
local function Compare(a,b,path)
    if type(b)=='number' then return type(a)=='number' and math.abs(a-b)<1e-6*math.max(1,math.abs(b)),path end
    if type(b)~='table' then return a==b,path..': '..tostring(a)..' / '..tostring(b) end
    if type(a)~='table' then return false,path..': not table' end
    for k,v in pairs(b) do local ok,why=Compare(a[k],v,path..'.'..tostring(k));if not ok then return false,why end end
    for k in pairs(a) do if b[k]==nil then return false,path..': extra '..tostring(k) end end
    return true,path
end
local function Snapshot(u,env)
    local ids,hp,events={},{},{}
    for _,p in ipairs(u.bp:List()) do ids[#ids+1]=p.id end
    for id,value in pairs(u.hp) do hp[tostring(id)]=value end
    -- Damage observations replace the source's separate sim.events channel.
    for _,e in ipairs(env.viewEvents) do if e.type~='unitDamaged' then events[#events+1]={type=e.type,id=e.id or false} end end
    return {ids=ids,hp=hp,budget=u:Budget(),integrity=u:Integrity(),alive=u.alive,kill=u.kill or false,
        damage=env.damage,kills=env.kills,rebuilds=env.rebuilds,pieces=env.pieces,events=events,fx=env.fx}
end
local function SourceReplays()
    for _,case in ipairs(fixtures.cases) do
        local env={time=0,damage=0,kills=0,rebuilds=0,pieces={},fx={},viewEvents={},random=function() return .5 end}
        function env:RecordDamage(_,amount) self.damage=self.damage+amount end
        function env:RecordKill() self.kills=self.kills+1 end
        env.debris={Spawn=function(_,parts,pose,vel,kick)
            local ids={};for _,p in ipairs(parts) do ids[#ids+1]=p.id end;table.sort(ids)
            env.pieces[#env.pieces+1]={ids=ids,kick=kick}
        end}
        function env:NewVehicle(spec)
            self.rebuilds=self.rebuilds+1
            local state={p={x=10,y=2,z=-4},q={x=0,y=0,z=0,w=1},lv={x=1,y=2,z=3},av={x=0,y=0,z=0},steer=0}
            return {body={translation=function() return state.p end,rotation=function() return state.q end,
                center=function() return state.p end,velocityAtPoint=function() return state.lv end},
                Dispose=function() end,Step=function() end,Place=function() end,
                GetState=function() return state end,SetState=function(_,s) state=s end}
        end
        local u=Unit.New(env,case.source,{name=case.name,spawn={pos={10,2,-4},yaw=0},combat=true})
        local ok,why=Compare(Snapshot(u,env),case.samples[1],case.name..' spawn');V.assert(ok,why)
        for i,a in ipairs(case.actions) do
            if a.kind=='hit' then u:HitRay({point=a.point,owner={partId=a.id}},a.damage,a.dir,a.pierce)
            elseif a.kind=='damage' then u:Damage(a.id,a.amount,a.point or {10,2,-4})
            elseif a.kind=='explode' then u:Explode(a.point,a.radius,a.damage)
            elseif a.kind=='flush' then u:Flush()
            elseif a.kind=='step' then env.time=env.time+a.dt;u:Step(a.dt) end
            ok,why=Compare(Snapshot(u,env),case.samples[i+1],case.name..' action '..i);V.assert(ok,why)
        end
    end
    for i,case in ipairs(fixtures.maskSamples) do
        local u=setmetatable({bp=BP.New():Load(case.source)},Unit)
        for j,s in ipairs(case.samples) do V.assert((u:PartAt(s.pos) or false)==s.id,'source solid-mask hit '..i..'/'..j) end
    end
    for i,case in ipairs(fixtures.rayCases) do
        local spec=Spec.Build(BP.New():Load(case.source));local wheels=require("drive.VehicleSetup").Wheels(spec)
        local vehicle={spec=spec,wheels=wheels,body={translation=function() return {x=case.pos[1],y=case.pos[2],z=case.pos[3]} end,rotation=function() return case.q end}}
        for j,s in ipairs(case.samples) do
            local hit=Ray.Cast(vehicle,s.origin,s.dir,s.length)
            if s.hit==false then V.assert(hit==nil,'Rapier empty ray '..i..'/'..j)
            else
                V.assert(hit and math.abs(hit.dist-s.hit.dist)<.0002,'Rapier nearest surface '..i..'/'..j)
                local allowed=false
                for _,id in ipairs(s.hit.allowed) do if hit and (hit.partId or false)==id then allowed=true end end
                V.assert(allowed,'Rapier shape owner '..i..'/'..j)
            end
        end
    end
end
local function Step(n,command)
    for _=1,n do trial:Tick(1/60,command or {throttle=0,steer=0}) end
end
V.atFrame(45,function()
    SourceReplays();app=assert(VOX_HANGAR).app;V.assert(app:EnterTrial(),'destruction trial requested')
end)
V.atFrame(90,function()
    trial=assert(app.trial);local world=trial.world
    Step(180)
    V.assert(#world.units==3,'three original target cars spawned')
    local u=world.units[1];local original=cjson.encode(u.source);local oldCount=u.bp:Size()
    local wheel=u.vehicle.wheels[1];local body=u.vehicle.body;local p=body.translation();local q=body.rotation()
    local center=V3.Add({p.x,p.y,p.z},V3.Rotate(q,{wheel.center[1],wheel.center[2]-wheel.drop,wheel.center[3]}))
    local axis=V3.Rotate(q,wheel.axle)
    local hit=Ray.Cast(u.vehicle,V3.Add(center,V3.Scale(axis,2)),V3.Scale(axis,-1),4)
    V.assert(hit and hit.partId==wheel.partId,'wheel sensor resolves actual wheel id')
    hit.owner={type='car',ref=u,partId=hit.partId}
    local mass=u.vehicle.mass;local load=u.spec.motion.load;local oldVehicle=u.vehicle;local before=u.vehicle:GetState()
    world:Hit(hit,10000,V3.Scale(axis,-1),0,0);u:Flush()
    V.assert(u.alive and not u.bp.parts[wheel.partId] and #u.vehicle.wheels==3,'lethal wheel hit removes wheel and suspension')
    V.assert(u.vehicle.mass<mass and oldVehicle.disposed,'rebuild reduces mass and releases old rigid body')
    V.assert(u.spec.motion.load<load,'lost wheel reduces load capacity from current blueprint')
    local ok=Compare(u.vehicle:GetState().p,before.p,'pose');V.assert(ok,'rebuild preserves body transform')
    V.assert(Compare(u.vehicle:GetState().lv,before.lv,'velocity'),'rebuild preserves linear velocity')
    trial.combatView:Consume(world)
    V.assert(not trial.combatView.units[u].view.visuals[wheel.partId],'removed wheel disappears from same vehicle view')
    V.assert(cjson.encode(u.source)==original and u.bp:Size()<oldCount,'combat never mutates saved blueprint')
    -- A deliberately single-bridge source blueprint proves grouped detachment.
    local config=fixtures.cases[1]
    local countBefore=#world.debris.pieces
    local bridge=Unit.New(world,config.source,{name='BridgeFixture',spawn={pos={130,3,-130},yaw=0}})
    world.units[#world.units+1]=bridge;trial.combatView:Consume(world)
    bridge:Damage(3,10000,{131,3,-130});bridge:Flush();trial.combatView:Consume(world)
    V.assert(bridge.bp:Size()==2 and #world.debris.pieces==countBefore+2 and not bridge.alive,'bridge detaches group then wrecks remaining sub-threshold chassis')
    local piece=world.debris.pieces[countBefore+1]
    V.assert(#piece.parts==4 and piece.mass>0 and trial.combatView.pieces[piece]~=nil,'debris has grouped source parts native mass and visible model')
    local start=piece.body.translation();Step(30);local moved=piece.body.translation()
    V.assert(V3.Length(V3.Sub({moved.x,moved.y,moved.z},{start.x,start.y,start.z}))>.2,'detached group physically moves')
    local oldVelocity=piece.body.linvel()
    world:Hit({point={moved.x,moved.y,moved.z},owner={type='debris',ref=piece}},10,{1,0,0},20,0)
    V.assert(piece.body.linvel().x>oldVelocity.x,'shots push detached physical debris')
    local kills=world.stats.kills;local core=u.bp:CoreParts()[1]
    u:Damage(core.id,10000,u:Position());u:Flush();trial.combatView:Consume(world)
    V.assert(not u.alive and u.vehicle==nil and world.stats.kills==kills+1,'core destruction kills once and removes native car')
    V.assert(trial.combatView.units[u]==nil,'destroyed car has no intact duplicate view')
    V.assert(#world.debris.pieces>1,'remaining connected car becomes physical wreck')
    Step(298)
    -- Place the last wreck across the spawn point immediately before expiry.
    -- Respawn must not depend on random debris kicks moving it out of the way.
    for _,p in ipairs(world.debris.pieces) do
        p.body.setTranslation(before.p);p.body.setRotation(before.q)
        p.body.setLinvel({x=0,y=0,z=0});p.body.setAngvel({x=0,y=0,z=0})
    end
    local firstRespawn=nil
    for _=299,305 do
        Step(1)
        if u.alive and not firstRespawn then
            firstRespawn=u.vehicle:GetState()
            V.assert(#world.debris.pieces==0,'expired wreck removed before replacement participates in physics')
        end
    end
    V.assert(firstRespawn and V3.Length({firstRespawn.av.x,firstRespawn.av.y,firstRespawn.av.z})<.01,'respawn receives no wreck collision angular impulse')
    V.assert(u.alive and u.bp:Size()==oldCount and u.vehicle.mass==mass,'five second respawn restores source blueprint and mass')
    V.assert(#world.debris.pieces==0 and next(trial.combatView.pieces)==nil,'expired debris releases physics and visuals')
    -- Oldest-first bound, including immediate spawn/remove events in one frame.
    local single={u.bp:List()[1]};local pose={p={x=130,y=8,z=-130},q={x=0,y=0,z=0,w=1}}
    for _=1,65 do world.debris:Spawn(single,pose,function() return {0,0,0} end,{0,0,0}) end
    trial.combatView:Consume(world)
    V.assert(#world.debris.pieces==60,'debris cap preserves newest sixty pieces')
    world.debris:Clear();trial.combatView:Consume(world)
    V.assert(next(trial.combatView.pieces)==nil,'clear drains batched spawn/remove events')
    -- In-app screenshot: player's real rifle damages the side target car.
    trial.vehicle:Place({78,0,-58},math.pi/2);trial.view:ResetPose();trial.yaw=-75;trial.pitch=12
    Step(120)
    local settled=u.vehicle:GetState();local up=V3.Rotate(settled.q,{0,1,0})
    V.assert(up[2]>.99 and math.abs(settled.p.x-u.spawnAt.pos[1])<.1 and math.abs(settled.p.z-u.spawnAt.pos[3])<.1,
        'respawn settles upright at original spawn without catapult or drift')
    V.assert(V3.Length({settled.lv.x,settled.lv.y,settled.lv.z})<.1,'respawn settles stationary without input')
    trial:PostUpdate(1);trial.weapons:Select(2);trial.weapons.energy=100;trial.weapons.offline=false
    local target=u.vehicle.body.translation();local aim={target.x,target.y+2.2,target.z}
    local damage=world.stats.damage
    for _=1,180 do Step(1,{throttle=0,steer=0,firing=true,aim=aim});if world.stats.damage>damage then break end end
    V.assert(world.stats.damage>damage,'actual mounted rifle damages target car through TrackWorld')
    V.assert(#trial.effects.chips.slots>0 and #trial.effects.chips.slots<=trial.effects.chips.limit,'break events produce bounded paint-colored chip pool')
    for _,arg in ipairs(GetArguments()) do
        if arg=='-destruction-phase=damaged' then Step(45)
        elseif arg=='-destruction-phase=wreck' then
            local corePart=u.bp:CoreParts()[1]
            local localCore={corePart.pos[1]*.5,(corePart.pos[2]+.5)*.5,corePart.pos[3]*.5}
            for _=1,1500 do
                if not u.alive then break end
                local p=u.vehicle.body.translation();local point=V3.Add({p.x,p.y,p.z},V3.Rotate(u.vehicle.body.rotation(),localCore))
                Step(1,{throttle=0,steer=0,firing=true,aim=point})
            end
            V.assert(not u.alive,'continued real weapon fire can destroy target core through armor')
            Step(24)
        end
    end
    trial:Aim();trial.hud.Update(trial)
    trial.Update=function() end;trial.PostUpdate=function() end
end)
V.atFrame(132,function() app:Reload() end)
V.atFrame(175,function()
    V.assert(app.mode=='hangar' and trial.disposed and #trial.world.units==0 and #trial.world.debris.pieces==0,'return releases units debris and views')
    V.finish()
end)
