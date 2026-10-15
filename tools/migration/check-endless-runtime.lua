local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local phase='boot';local retired=nil ---@type table|nil
local disposalTrial=nil ---@type TrialSession|nil
local disposalEdit=nil ---@type table|nil
local disposalWorld=nil ---@type table|nil
local damageBefore=nil ---@type function|nil
local function Finish()
    V.finish();engine.maxInactiveFps=1000;engine.maxFps=1000
end
local function Capture(s,name)
    s.hud.Update(s,0);coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/endless-'..name..'-native.png');image:Dispose()
end
local function Exercise(s)
    local e=s.endless;retired=e;local update=s.Update;s.Update=function() end
    V.assert(e~=nil and s.combat==e and e.player.externalView and not e.player.autoRespawn,'production endless owns damageable player and retained shared combat')
    local function Step(n,command)
        for i=1,n do s:Tick(1/60,command or {throttle=0,steer=0,handbrake=true});if i%20==0 then coroutine.yield() end end
    end
    Step(605);V.assert(e.run.state=='combat' and #e.entries>=2 and #s.world.units>=2,'natural ten-second countdown spawns actual enemy vehicles')
    local shield=e.shield;local origin={shield.pos[1]+shield.rx*2,shield.pos[2]+8,shield.pos[3]}
    local aim=e.shieldTarget.aimPoint(origin);local direction=require('core.Math3').Sub(aim,origin);local length=require('core.Math3').Length(direction)
    V.assert(e.shieldTarget.pos==shield.pos and e.shieldTarget.zone==shield and length>0 and require('combat.ShieldQuery').Ray(shield,origin,require('core.Math3').Scale(direction,1/length),length+.1)~=nil,'actual endless shield target exposes original surface aim contract')
    local enemy=e.entries[2];local airborne=enemy.unit.airdropActive;enemy.unit.airdropActive=false;enemy.unit.vehicle.airdropActive=false;enemy.driver.time=2
    local ok,command,target=pcall(enemy.driver.Step,enemy.driver,1/60,e.player,false,e.shieldTarget)
    V.assert(ok and type(command)=='table' and target and target[1]~=nil,'actual full EnemyDriver can think while player stands inside base shield')
    enemy.unit.airdropActive=airborne;enemy.unit.vehicle.airdropActive=airborne
    local enemy=e.entries[2];local old=e.run.shield.hp;local core=e.player.bp:CoreParts()[1]
    enemy.env.hit({point=e.player:Position(),owner={type='car',ref=e.player,partId=core.id}},200,{0,0,1},0,0)
    V.assert(e.run.shield.hp==old-200 and e.player:Health()==1,'enemy ray damages base shield instead of protected actual car')
    e.run:ShieldHit(1e9);e.invulnerableUntil=0;local hp=e.player:Health();enemy.env.hit({point=e.player:Position(),owner={type='car',ref=e.player,partId=core.id}},20,{0,0,1},0,0)
    V.assert(e.player:Health()<hp or e.player.struct<e.player.structMax,'base break exposes real player to enemy fire')
    local time=s.world.time;e.run.queue={};for i=2,#e.entries do local u=e.entries[i].unit;u.kill='Native endless test destruction';u.dirty=true;u:Flush() end
    Step(1);V.assert(e.run.state=='rest' and #e.run.supplies==3 and e.run.credits>0,'actual enemy destruction yields collected credits and original three supplies')
    Capture(s,'supply')
    local units=s.world.units;local player=e.player;local wave=e.run.wave;local runTime=e.run.time
    local base=e.world.layout.base.pos
    e.player.vehicle:Place({base[1],base[2]+1,base[3]},0);e.player:SavePose()
    e:ChooseSupply(1);V.assert(e:EnterEdit(),'rest base opens real shared BuildSession')
    for i=1,8 do coroutine.yield() end
    local st=e.edit.host.blueprint:Stats();local b=st.bb
    local center=e.edit.root:LocalToWorld(require('core.Coord').Vec((b.minX+b.maxX)*.5*require('Config').CELL,((b.minY+b.maxY)*.5+.5)*require('Config').CELL,(b.minZ+b.maxZ)*.5*require('Config').CELL))
    local cam=e.edit.host.camera.camera;local screen=cam:WorldToScreenPoint(center);local forward=cam.node.worldDirection
    print('[EndlessEditCamera] '..tostring(cam.node.worldPosition)..' center='..tostring(center)..' projected='..tostring(screen))
    V.assert(math.abs(screen.x-.5)<.01 and math.abs(screen.y-.5)<.01 and (center-cam.node.worldPosition):DotProduct(forward)>0,'actual retained editor camera centers its world-space vehicle')
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/endless-edit-native.png');image:Dispose()
    local hidden=true;local playerModels=s.view.view.root:GetComponents('StaticModel',true)
    for _,model in ipairs(playerModels) do hidden=hidden and not model.enabledEffective end
    V.assert(#playerModels>0 and hidden,'actual battle player child models are hidden during retained-world editor')
    require('ui.EndlessEditBar').Shop(e.edit);for i=1,20 do coroutine.yield() end
    V.assert(e.edit.shop:IsOpen() and e.edit.shop.parent~=nil,'actual shop opens mounted UI overlay')
    V.assert(e.edit.shop:IsVisible(),'actual source rectangular shop is visible')
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/endless-shop-native.png');image:Dispose()
    e.edit.shop:Close();e.edit.shop=nil
    V.assert(e.edit.build and e.edit.build.editor.bp~=app.blueprint and s.world.units==units,'run editor keeps same battlefield and isolates garage blueprint')
    local clock=s.world.time;Step(5);V.assert(s.world.time==clock and e.run.time==runTime,'editing freezes both Bullet world and endless clock')
    local bp=e.edit.host.blueprint;local parts=bp:Size();local history=e.edit.host.editor.history;local data={type='laser5',pos={0,30,0},rot=1}
    V.assert(not history:Commit({{op='add',data=data}}) and bp:Size()==parts,'run inventory rejects unavailable actual editor placement')
    local resumed=e.edit:Depart();V.assert(resumed.ok and e.edit==nil and s.world.units==units and e.player==player and e.run.wave==wave,'depart returns to same world, enemy list and wave')
    local shown=false;for _,model in ipairs(s.view.view.root:GetComponents('StaticModel',true)) do shown=shown or model.enabledEffective end
    V.assert(shown,'actual living battle player child models return after retained-world editor')
    V.assert(e:NextWave(),'actual supply selected permits next wave');Step(302);V.assert(e.run.state=='combat' and e.run.wave==2,'native countdown resumes next wave')
    local function KillPlayer() e.player.kill='Native endless test death';e.player.dirty=true;e.player:Flush();Step(1) end
    KillPlayer();V.assert(e.run.lives==2 and not e.player.alive,'native death consumes one life');Step(302);V.assert(e.player.alive and s.vehicle==e.player.vehicle,'five-second native respawn binds display/body without resetting wave')
    KillPlayer();Step(302);KillPlayer();V.assert(e.run.state=='over' and e.run.lives==0 and e.result~=nil,'three actual deaths settle the original run')
    local clock=s.world.time;Step(20);V.assert(s.world.time==clock,'settlement pauses real world')
    s.hud.Update(s,0);coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/endless-result-native.png');image:Dispose()
    s.Update=update;app:Reload();phase='return'
end
local function Poll()
    if phase=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;dofile('tools/migration/check-mode-disposal.lua').Run();app.blueprint:Load(require('endless.Data').starters[1].source);V.assert(app:EnterTrial('endless'),'production endless map entry through loading flow');phase='loading'
    elseif phase=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);phase='exercise'
    elseif phase=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,debug.traceback(work,tostring(err)));phase='failed';app:Stop();Finish() end
    elseif phase=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(retired.disposed and retired.edit==nil and #retired.entries==0 and not retired.world and not retired.session,'return disposes endless editor and runtime without retaining the battlefield')
        V.assert(app:EnterTrial('endless'),'second production entry covers disposal during retained-world editing');phase='dispose-loading'
    elseif phase=='dispose-loading' and app.trial and not app.loadingFlow.active then
        local s=app.trial;local e=s.endless;disposalTrial=s;disposalWorld=s.world;damageBefore=e.baseDamage;retired=e
        V.assert(e:EnterEdit(),'actual initial countdown opens shared editor for cancellation coverage')
        disposalEdit=e.edit;disposalEdit.qaLeaveCalls=0;local leave=e.edit.Leave
        e.edit.Leave=function(edit)
            edit.qaLeaveCalls=edit.qaLeaveCalls+1
            if not edit.left then V.assert(s.view and s.view.view and s.view.view.root and not s.view.disposed,'TrialSession leaves actual editor while battle view still exists') end
            return leave(edit)
        end
        app:Reload();phase='dispose-return'
    elseif phase=='dispose-return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        disposalTrial:Dispose();retired:Dispose();disposalEdit:Leave()
        V.assert(disposalEdit.left and disposalEdit.qaLeaveCalls==2 and not disposalEdit.controller and not disposalEdit.host and not disposalEdit.build and not disposalEdit.originalViewport,'actual retained editor first and repeated Leave release UI host camera and viewport references')
        V.assert(disposalTrial.disposed and not disposalTrial.world and not disposalTrial.view and not disposalTrial.scene and retired.disposed and not retired.session and not retired.world,'actual repeated TrialSession disposal detaches endless and scene')
        V.assert(disposalWorld.RecordDamage==damageBefore,'actual endless disposal restores damage handler before releasing world')
        V.assert(app:EnterTrial('endless'),'third production entry covers application stop during editing');phase='stop-loading'
    elseif phase=='stop-loading' and app.trial and not app.loadingFlow.active then
        local s=app.trial;local e=s.endless
        V.assert(e:EnterEdit(),'actual retained editor opens before application stop')
        local edit=e.edit;edit.qaLeaveCalls=0;local leave=edit.Leave
        edit.Leave=function(active)
            active.qaLeaveCalls=active.qaLeaveCalls+1
            if not active.left then V.assert(s.view and s.view.view.root and app.graphicsSettings.post and active.originalRoot.node,'application stop leaves editor before graphics and HUD owners are disposed') end
            return leave(active)
        end
        app:Stop();s:Dispose();e:Dispose();edit:Leave()
        V.assert(app.stopped and not app.trial and s.disposed and not s.scene and not e.world and not edit.controller and not edit.host and edit.qaLeaveCalls==2,'actual Stop and repeated Leave release application trial world and editor hosts')
        phase='done';Finish()
    end
end
for frame=40,2100 do V.atFrame(frame,Poll) end
V.atFrame(2105,function() V.assert(phase=='done','native endless lifecycle and active-editor Reload/Stop disposal complete');V.finish() end)
