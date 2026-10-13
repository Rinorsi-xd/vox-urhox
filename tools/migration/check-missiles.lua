local app=nil ---@type HangarApp|nil
local stage='boot';local work=nil ---@type thread|nil
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Coord=require 'core.Coord'
local Weapons=require 'combat.WeaponSystem'
engine.maxInactiveFps=120
local function Exercise(s)
    local world=s.world;local target=world.targets[1];local update=s.Update;s.Update=function() end
    local audio=s.weaponAudio;audio.focus=function() return true end
    local function Step(n,cmd)
        for i=1,n do s:Tick(1/60,cmd or {throttle=0,steer=0,aim=target.pos});if i%30==0 then coroutine.yield() end end
    end
    target.node.position=Coord.Vec(155,10.4,20);target.native.position=target.node.position;target.pos={155,12,20};target.hp=10000
    s.vehicle:Place({155,0,-140},0);s.view:ResetPose();s.yaw=0;s.pitch=12
    local groupIndex
    for i,g in ipairs(s.weapons.groups) do if g.kind=='missile' then groupIndex=i end end
    V.assert(groupIndex~=nil,'frozen Mini Heavy prefab equips actual missile group');s.weapons:Select(groupIndex)
    s.pointer.captured=true
    Step(145);local lock=s.weapons:LockInfo()
    V.assert(lock and lock.locked and lock.ref==target,'production camera locks native board after two seconds')
    local shots=world.stats.shots;Step(60,{throttle=0,steer=0,aim=target.pos,firing=true})
    V.assert(world.stats.shots>shots and #s.weapons.projectiles>0,'mounted multibarrel launch creates actual projectiles')
    V.assert(s.effects.missiles.view and s.effects.missiles.view.count>0,'production projectile pool displays frozen missile meshes')
    local w=s.weapons:Group().weapons[1];local vis=s.view.view.visuals[w.id]
    V.assert(vis.weaponMotion and vis.weaponMotion.kind=='missile' and #vis.weaponMotion.petals>0,'actual imported missile rig opens authored petals')
    local hp=target.hp;Step(540)
    V.assert(target.hp<hp and world.stats.hits>0,'curved swept missiles damage physical native target')
    V.assert(#s.weapons.projectiles==0 and s.effects.missiles.view.count==0,'arrived missile meshes return to pool')
    Step(210)
    V.assert(w.mphase=='ready' and w.open==0,'full volley reloads and closes gates before next shot')
    for _,id in ipairs({'missile_scan','missile_lock','missile_open','missile_launch','missile_eject','missile_blast','missile_reload','missile_close'}) do
        V.assert((audio.counts[id] or 0)>0,'actual weapon lifecycle plays original '..id..' WAV')
    end
    local flight=audio.loops.missile_flight
    V.assert(flight and flight.source.frequency==audio.sounds.missile_flight:GetFrequency(),'flight loop uses absolute source sample frequency')
    V.assert(#audio.slots<=10,'weapon sample voices remain bounded')
    audio:SetActive(false)
    local stopped=true;for _,source in ipairs(audio.slots) do stopped=stopped and not source.playing end
    for _,loop in pairs(audio.loops) do stopped=stopped and not loop.source.playing end
    V.assert(stopped,'pause stops weapon samples and all looping beds')
    audio:SetActive(true)
    for _=1,40 do audio.time=audio.time+.04;audio:Play('mg_fire') end
    local overlapping=0;for i,source in ipairs(audio.slots) do if source.playing and audio.voiceIds[i]=='mg_fire' then overlapping=overlapping+1 end end
    V.assert(overlapping<=3 and #audio.slots<=10,'burst fire limits same-cue voices to three and all voices to ten')
    audio:Loop('mg_motor',.8,1.05,.4,.1)
    V.assert(math.abs(audio.loops.mg_motor.source.frequency-audio.sounds.mg_motor:GetFrequency()*1.05)<.1,'motor pitch is multiplied by actual sample frequency')
    for _,tube in ipairs(w.tubes) do V.assert(tube,'all physical tube rounds replenish') end
    -- Native collision at an unrelated ray angle must block shots before target.
    local wall=world.root:CreateChild('MissileTestWall');wall.position=Coord.Vec(155,12,10)
    wall:CreateComponent('CollisionShape'):SetBox(Vector3(40,40,1));local body=wall:CreateComponent('RigidBody');world.space:Register(body,{type='obstacle'})
    world.space:Step(1/60);local before=target.hp
    local mount={partId=1,type='missile5',pivot={0,0,0},muzzle={0,0,1},off={0,0,1},offs={{0,0,1}},quat={x=0,y=0,z=0,w=1},dir={0,0,1}}
    local ws=Weapons.New({weapons={mount}},function() return .5 end)
    local state={firing=true,pos={155,12,-140},eye={155,12,-140},quat={x=0,y=0,z=0,w=1},aim=target.pos,body=s.vehicle.body}
    for _=1,700 do ws:Step(1/60,state,world.env) end
    V.assert(target.hp==before,'actual native wall blocks curved projectile and splash line of sight')
    world.space:Unregister(body);wall:Dispose()
    -- Test splash redistribution on native destructible car, not a fake hit sink.
    local unit=world.units[1];local p=unit:Position();local core=unit.bp:CoreParts()[1];local health=unit.hp[core.id]
    world:Explode(p,30,200,unit.vehicle.body)
    V.assert(unit.hp[core.id]==health,'splash excludes launch vehicle')
    world:Explode(p,30,200,s.vehicle.body)
    V.assert(unit.hp[core.id]<health or unit.dirty,'splash reaches exposed physical vehicle parts')
    -- Stress fixed projectile/particle limits with many simultaneous source shots.
    for _=1,180 do s.effects:Consume({{type='blast',kind='missile',pos=target.pos,dir={0,0,1},radius=3.6,tier=5}}) end
    s.effects:Update(.05,{},s.camera:GetNode())
    V.assert(#s.effects.missiles.booms<=64 and #s.effects.missiles.log<=128 and #s.effects.zaps<=64,'missile volley explosion lists remain bounded')
    for _,b in pairs(s.effects.batches) do V.assert(b.count<=b.limit,'missile effect GPU upload budget is bounded') end
    for _=1,50 do s.effects:Update(.1,{},s.camera:GetNode()) end
    V.assert(#s.effects.missiles.booms==0,'all missile fireballs expire')
    s.yaw=-30;s.pitch=18;s:PostUpdate(1);target.hp=10000;s.weapons.energy=100
    Step(150);Step(65,{throttle=0,steer=0,aim=target.pos,firing=true});s:PostUpdate(.1)
    coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/missile-native-'..require('render.Quality').current.name..'.png');image:Dispose()
    s.Update=update;_G.VOX_QA_MISSILE_EFFECTS=s.effects;_G.VOX_QA_MISSILE_AUDIO=audio;app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app
        V.assert(app:LoadBlueprint(Prefab.Create(BP.New(),'miniHeavy'):ToTable()),'loads frozen equipped source vehicle')
        V.assert(app:EnterTrial('trial'),'production trial loader');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then
        work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work)
        if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then
        local fx=VOX_QA_MISSILE_EFFECTS
        V.assert(fx.disposed and fx.missiles.view==nil and #fx.missiles.booms==0,'return disposes missile pool and transients')
        local audio=VOX_QA_MISSILE_AUDIO
        V.assert(audio.disposed and #audio.slots==0 and next(audio.loops)==nil,'return disposes all weapon sample players')
        stage='done';V.finish()
    end
end
for i=45,650 do V.atFrame(i,Poll) end
V.atFrame(655,function() V.assert(stage=='done','equipped missile lifecycle completed');V.finish() end)
