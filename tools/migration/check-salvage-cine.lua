local M={}
function M.Fixtures()
    local f=assert(io.open('tools/migration/source-salvage-cine.json'));local fixtures=cjson.decode(f:read('*a'));f:close()
    local Motion=require 'salvage.CineMotion';local View=require 'render.SalvageCinematics';local r=Motion.New()
    local function Eq(v,a,label) V.assert((v-Vector3(a[1],a[2],a[3])):Length()<.0002,label) end
    local function Rotation(q,a,label)
        local expected=Quaternion(a[4],a[1],-a[2],-a[3]);local p=Vector3(.31,.46,.72)
        V.assert((q*p-expected*p):Length()<.00002,label)
    end
    for i,c in ipairs(fixtures.samples) do
        local P=Vector3(12,4,-31);local player=c.name=='drop' and Vector3.ZERO or Vector3(2,3,4)
        if c.name=='approach' then
            Motion.Approach(r,c.t,P,c.wait);Eq(r.ship,c.ship.position,'source approach '..i)
            Rotation(View.Rotation(r.rx,r.ry,r.rz),c.ship.quaternion,'source hover rotation '..i)
            V.assert(r.dust==c.dust,'source hover dust trigger '..i)
            goto continue
        end
        if c.name=='drop' then Motion.Drop(r,c.t,P,c.yaw,player)
        elseif c.name=='extract' then Motion.Extract(r,c.t,P,player)
        elseif c.name=='death' then Motion.Death(r,c.t,P)
        else Motion.Elite(r,c.t,player,Vector3(50,8,70)) end
        Eq(r.pos,c.pos,'source camera position '..i);Eq(r.tgt,c.tgt,'source camera target '..i)
        V.assert(math.abs(r.fov-c.fov)<.0001 and math.abs(r.w-c.w)<.0001,'source lens/blend '..i)
        if c.ship then Eq(r.ship,c.ship.position,'source ship '..i);Rotation(View.Rotation(r.rx,r.ry,r.rz),c.ship.quaternion,'source Euler XYZ mirror '..i) end
        if c.holder then Eq(r.holder,c.holder.position,'source frame '..i);Rotation(View.Rotation(r.door,0,0),c.door.quaternion,'source door pivot '..i) end
        if c.hold and c.hold~=cjson.null then Eq(r.hold,c.hold,'source held car '..i) end
        if c.name=='drop' then V.assert(r.throttle==(c.throttle~=cjson.null and c.throttle or nil),'source scripted throttle '..i) end
        ::continue::
    end
    local scene=Scene();local space=require('physics.Space').New(scene)
    local function Wall(z,layer)
        local node=scene:CreateChild('CineCameraTest');node.position=Vector3(0,2,z)
        local body=node:CreateComponent('RigidBody');body.collisionLayer=layer
        node:CreateComponent('CollisionShape'):SetBox(Vector3(6,6,1));return body
    end
    local wall=Wall(5,1);Wall(2,2);space:Step(1/60)
    local camera={run={world={space=space,GroundAt=function() return 0 end}}}
    local Resolve=require('salvage.Cinematics').CameraPosition
    local shot={pos=Vector3(0,2,10),tgt=Vector3(0,2,0)}
    local safe=Resolve(camera,shot)
    V.assert(math.abs(safe.z-3.65)<.01,'cinematic camera stops before actual scenery and ignores vehicle layer')
    wall.collisionLayer=2;space:Step(1/60);safe=Resolve(camera,shot)
    V.assert((safe-shot.pos):Length()<.001,'unobstructed cinematic preserves authored position')
    camera.run.world.GroundAt=function() return 8 end;safe=Resolve(camera,shot)
    V.assert(math.abs(safe.y-9.2)<.001,'cinematic camera starts above terrain')
    scene:Dispose()
end
function M.Drop(s)
    local run=s.salvage;local cine=run.cine;local before=run.rules.time
    V.assert(cine.playing and cine.current.name=='drop','loading unveiling starts original drop')
    for _=1,20 do cine:Update(1/60);s:Tick(1/60,{throttle=1,steer=1,firing=true}) end
    V.assert(run.rules.time==before and cine.heldNative==s.vehicle.native and s.vehicle.native.kinematic,'drop freezes run clock and holds physical car')
    V.assert(s.vehicle.native.position.y>run.spawn.pos[2]+50 and run.rules.heat==0,'manual throttle/fire cannot interrupt airborne drop')
    for i=1,4 do V.assert(not cine.view.nodes['frameFlame'..i]:GetChild('Batch').enabled,'inactive frame flame mesh hidden '..i) end
    local ordinary=48;s.camera:GetCamera().fov=ordinary;cine:Camera()
    V.assert(math.abs(s.camera:GetCamera().fov-50)<.001,'authored shot overrides third person lens')
    V.assert(cine:Skip() and cine.current.t==7.2,'Space skip advances to opening doors')
    V.assert(cine.playing and cine.heldNative~=nil,'skip retains grounded frame until release')
    for _=1,35 do cine:Update(.1);s:Tick(1/60,{throttle=0,steer=0}) end
    V.assert(not cine.playing and run.landed and not s.vehicle.native.kinematic,'drop finishes and restores dynamic body')
    V.assert(run.rules.time<1 and run.rules.time>0,'clock and eight second protection begin after drop')
    V.assert(cine.view.nodes.holder.enabled,'original landed frame remains in world')
    for _,mesh in ipairs(cine.view.nodes.ship:GetComponents('StaticModel',true)) do V.assert(not mesh.node.enabled,'departed transport child mesh hidden') end
end
function M.Extraction(s)
    local run=s.salvage;local cine=run.cine;local exit=run.rules.extracts[1]
    run.rules.ex={e=exit};cine:Approach(exit)
    for _=1,65 do cine:Update(.1) end
    V.assert(cine.approach and cine.approach.dust and cine.dust.uploads==2,'hover uses bounded GPU dust uploaded once')
    run.rules.ex=nil;cine:Update(.1)
    V.assert(cine.approach and cine.approach.leaving,'leaving exit starts departure')
    for _=1,42 do cine:Update(.1) end
    V.assert(not cine.approach and not cine.view.nodes.ship.enabled,'cancelled approach removes transport')
    run.rules:Emit('extracted',{exit=exit});run.rules.finished=true;run:Events()
    V.assert(cine.current.name=='extract' and not run.result and not run.committed,'extraction event defers result and persistence')
    V.assert(not run:Key(KEY_T) and not run:Key(KEY_ESCAPE) and not run.result,'source extraction leaves exit keys available to session without settling during key observation')
    for _=1,35 do cine:Update(.1);s:PostUpdate(.1) end
    V.assert(not run.result and cine.heldNative~=nil and s.vehicle.native.kinematic,'actual player is suspended during extraction')
    for _=1,29 do cine:Update(.1);s:PostUpdate(.1) end
    V.assert(run.result and run.result.ok and not cine.playing and not s.vehicle.native.kinematic,'extract finishes into source result and restores body mode')
    cine:Update(.1);V.assert(not cine.approach,'result cannot restart transport from completed countdown')
end
return M
