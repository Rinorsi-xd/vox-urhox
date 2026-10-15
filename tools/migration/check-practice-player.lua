local UI=require 'urhox-libs/UI'
local BP=require 'construction.Blueprint'
local Prefab=require 'construction.Prefab'
local Trial=require 'app.TrialSession'
local session=nil ---@type table|nil
local scene=nil ---@type Scene|nil
local player=nil ---@type table|nil
local initialParts=0
local deadAt=0
local retired=nil ---@type table|nil
local function Check(ok,message) V.assert(ok,'Practice player: '..message) end
local function Command() return {throttle=0,steer=0,aim={0,2,70}} end
local function Dispose()
    if session then session:Dispose();session=nil end
    if scene then scene:Dispose();scene=nil end
end
V.atFrame(2,function()
    local fonts=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DEFAULT,fonts={{family='sans',weights={normal=fonts.body,bold=fonts.bold}}}})
    scene=Scene();scene:CreateComponent('Octree')
    local app={store={Read=function() return nil end},toasts={Push=function() end}}
    session=Trial.New(scene,Prefab.BuildRaceCar(BP.New()),app)
    session.hud=require('ui.DriveHud').Create(session)
    player=session.practice.player;initialParts=player.bp:Size()
    Check(session.combat==session.practice and session.vehicle==player.vehicle and session.weapons==player.weapons,'actual TrialSession uses the unified player and weapons')
    Check(player.externalControl and player.externalView and player.team=='player' and player.hull and player.structure,'player owns source hull/structure and external view')
    local count=0;for _,unit in ipairs(session.world.units) do if unit==player then count=count+1 end end
    Check(count==1 and #session.world.units==#session.world.layout.unitSpots+1,'one player in actual ray/explosion/physics unit list')
    Check(session.combatView.units[player]==nil,'player has one view, never a duplicate combat view')
    Check(#session.hud.overlay.tags==#session.world.layout.unitSpots,'world markers exclude own external player')
    local p=player:Position();local hit=session.world:CastRay({p[1]-30,p[2],p[3]},{1,0,0},60)
    Check(hit and hit.owner and hit.owner.ref==player,'actual world ray sees damageable player')
    local selfExcluded=session.world:CastRay({p[1]-30,p[2],p[3]},{1,0,0},60,player.vehicle.body)
    Check(not selfExcluded or not selfExcluded.owner or selfExcluded.owner.ref~=player,'own shots exclude their body')
end)
V.atFrame(4,function()
    local pos=player:Position();local before=player:Life();player.struct=0
    local core=player.bp:CoreParts()[1]
    session.world:Hit({owner={type='car',ref=player,partId=core.id},point=pos},player.bodyHpMax*.12,{1,0,0},0,0)
    session.hud.overlay:Consume(session.world.viewEvents)
    Check(player:Life()<before and player:Life()>0,'actual HitRay lowers player hull life')
    Check(#session.hud.overlay.feedback.hits>0,'actual damage event reaches directional feedback')
    local total=session.world.stats.damage
    Check(total==0,'self damage never inflates player outgoing damage stats')
    session:Tick(1/60,Command())
    Check(session.hud.vitals.hp==player:Life() and session.hud.vitals.hp<1,'HUD reads real life instead of constant full HP')
    local hp=player.bodyHp;session.world:Explode(pos,8,player.bodyHpMax*.04,nil,function(u) return u==player end)
    Check(player.bodyHp<hp,'actual world explosion can damage the player')
end)
V.atFrame(6,function()
    retired=player.vehicle;local oldWeapons=player.weapons;local energy=oldWeapons.energy
    local wheel=player.spec.wheels[1];Check(wheel~=nil,'original race car has a wheel fixture')
    local id=wheel.partId;player:Destroy(id)
    session:Tick(1/60,Command())
    Check(player.alive and player.bp:Size()<initialParts,'destroyed movement part is absent from live blueprint')
    Check(not retired.body.isValid() and session.vehicle==player.vehicle and session.view.vehicle==player.vehicle,'damage Flush replaces Bullet body and rebinds driven view')
    Check(session.view.view.visuals[id]==nil and session.weapons==oldWeapons,'missing part disappears while weapon state is preserved')
    Check(session.weapons.energy>=energy,'a rebuild never drains existing weapon energy')
    local restored=player:RestoreMissing(1);player:Heal(1)
    session:Tick(1/60,Command())
    Check(#restored>0 and player.bp.parts[id] and session.view.view.visuals[id],'real recovery restores part and driven model')
    Check(session.hud.overlay.feedback.full and session.hud.vitals.hp==1,'recovery events reach full repair HUD feedback')
    local core=player.bp:CoreParts()[1];retired=player.vehicle
    player:Destroy(core.id);session:Tick(1/60,Command());deadAt=player.deadAt
    Check(not player.alive and not retired.body.isValid() and session.hud.vitals.hp==0,'core destruction kills player, retires body and zeros HUD')
    Check(not session.view.view.root.enabled and not session.firing,'dead player view and firing are hidden')
end)
for frame=8,302 do V.atFrame(frame,function()
    session:Tick(1/60,Command())
end) end
V.atFrame(303,function()
    Check(not player.alive and session.world.time-deadAt<5,'no early respawn before source five seconds')
    while session.world.time-deadAt<5.05 do session:Tick(1/60,Command()) end
    Check(player.alive and player.bp:Size()==initialParts,'source five-second automatic respawn restores blueprint')
    Check(session.vehicle==player.vehicle and session.weapons==player.weapons and session.view.vehicle==player.vehicle,'respawn rebinds new weapons, Bullet body and view')
    Check(session.hud.vitals.hp==1 and session.view.view.root.enabled,'respawn clears damage HUD and reveals own view')
    local weapons=session.weapons;weapons.energy=weapons.energyMax*.5
    local shots={{id='teleport-retains-inflight'}};weapons.projectiles=shots
    local target=session.world.units[2];local oldTarget=target.vehicle
    target:Destroy(target.bp:CoreParts()[1].id);target:Flush()
    session:HandleKey(KEY_N)
    Check(session.teleport==2 and session.weapons==weapons and session.weapons.energy==weapons.energyMax*.5,'N teleport preserves damage/weapon resources and changes area')
    Check(not target.alive,'N teleport does not restore destroyed targets')
    Check(session.weapons.projectiles==shots and #shots==1,'N teleport preserves shots in flight')
    session:HandleKey(KEY_BACKSPACE)
    Check(session.teleport==1 and target.alive and target.vehicle~=oldTarget,'Backspace restores targets and returns to spawn')
    Check(session.weapons~=weapons and player:Life()==1 and session.world.stats.damage==0,'Backspace resets player weapons, health and world statistics')
    Check(#session.weapons.projectiles==0,'Backspace explicitly clears shots in flight')
    player.vehicle.body.setTranslation({x=10,y=-40,z=10});session:Update(1/60)
    Check(player.alive and player.vehicle.body.translation().y> -30,'trial falling uses source spawn recovery instead of a combat death')
    local heldWorld=session.world;local held=player.vehicle.body
    Dispose()
    Check(not held.isValid() and heldWorld.space==nil,'session teardown releases the unified player through world ownership')
    UI.Shutdown();V.finish()
end)
