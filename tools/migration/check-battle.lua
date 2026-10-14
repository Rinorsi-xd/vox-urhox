local Rules=require 'combat.EliminationRules'
local Data=require('core.ResourceData').Read('Combat/Arena.json')
local app=nil ---@type HangarApp|nil
local stage='boot';local exercise=nil ---@type thread|nil
engine.maxInactiveFps=120
local function Logic()
    local r=Rules.New(Data.modes.elimination);local w={alive={blue=3,red=3},hp={blue=3,red=3}}
    r:Step(5,w);V.assert(r.state=='live' and r:TimeLeft()==150,'source preparation is five seconds and round is 150 seconds')
    r:Step(90,w);V.assert(r.sudden and r:TimeLeft()==60,'source final sixty seconds disable healing')
    w.alive.red=0;r:Step(.1,w);V.assert(r.state=='roundEnd' and r.score.blue==1,'team wipe wins first round')
    r:Step(6,w);V.assert(r.state=='prep' and r.round==2,'six second intermission prepares next round')
    w.alive.red=3;r:Step(5,w);w.alive.red=0;r:Step(.1,w);r:Step(6,w)
    V.assert(r.state=='over' and r.winner=='blue' and #r.history==2,'two wins settle match once')
    local draw=Rules.New(Data.modes.elimination);draw:Step(5,w);w.alive.blue=0;draw:Step(.1,w)
    V.assert(draw.state=='roundEnd' and draw.score.blue==0 and draw.score.red==0 and not draw.history[1].winner,'simultaneous wipe is a draw')
    local tie=Rules.New(Data.modes.elimination);w.alive={blue=2,red=2};w.hp={blue=.8,red=.8};tie:Step(5,w);tie:Step(150,w)
    V.assert(not tie.history[1].winner,'equal health at timeout is a draw')
    local health=Rules.New(Data.modes.elimination);health:Step(5,w);w.hp.blue=1.2;health:Step(150,w)
    V.assert(health.history[1].winner=='blue' and health.history[1].how=='hp','timeout uses surviving health after tied counts')
end
local function Exercise(s)
    local b=s.battle;local world=s.world;local player=b.player
    local function Step(count,command)
        for i=1,count do s:Tick(1/60,command or {throttle=0,steer=0});if i%30==0 then coroutine.yield() end end
    end
    V.assert(#world.units==6 and #b.entries==6,'production battle owns exactly three units per side')
    V.assert(player.vehicle==s.vehicle and player.weapons==s.weapons,'player shares damageable physical body and mounted weapons')
    V.assert(player.autoRespawn==false and s.hud.match~=nil,'elimination disables automatic respawn and creates source match HUD')
    b.rules:Step(5,b:WorldState());b.rules:Drain();local bot=b.entries[4].unit;local start=bot:Position();start={table.unpack(start)}
    Step(360)
    local after=bot:Position();V.assert(math.abs(after[1]-start[1])+math.abs(after[3]-start[3])>3,'actual AI advances on native terrain')
    V.assert(s.effects.events>0,'AI mounted weapons produce real shot effects')
    local core=player.bp:CoreParts()[1];local body=player.bodyHp;player.struct=0
    player:Damage(core.id,body*.1,player:Position())
    V.assert(player:Health()<1 and player.hp[core.id]>0,'player receives real hull damage while local core survives above shatter threshold')
    player.hitAt=world.time-5;local hp=player:Health();b.rules.sudden=false
    Step(1);V.assert(player:Health()>hp,'five seconds without hits enables source breathing heal')
    b.rules.sudden=true;player.hitAt=world.time-5;hp=player:Health();Step(1)
    V.assert(player:Health()<=hp,'sudden death disables breathing heal')
    local weaponId=player.spec.weapons[1].partId;player:Destroy(weaponId);player:Flush();b:SyncPlayer();s.combatView:Consume(world)
    V.assert(not player.bp.parts[weaponId],'destroyed mounted weapon actually disappears')
    player:RestoreMissing(1);player:Flush();b:SyncPlayer();s.combatView:Consume(world)
    V.assert(player.bp.parts[weaponId]~=nil and s.view.view.visuals[weaponId]~=nil,'repair restores source weapon and rendering through connectivity')
    local oldEnergy=player.weapons.energy;player.weapons:Refit(player.spec)
    V.assert(player.weapons.energy==oldEnergy,'damage rebuild never replenishes weapon energy')
    -- Team filtering is exercised through the actual mounted-weapon environment.
    local friend=b.entries[2].unit;local friendHp=friend.bodyHp;local friendCore=friend.bp:CoreParts()[1]
    b.entries[1].env.hit({owner={type='car',ref=friend,partId=friendCore.id},point=friend:Position()},9999,{0,0,1},0,0)
    V.assert(friend.bodyHp==friendHp,'friendly fire cannot damage team mate')
    player:Damage(core.id,1e9,player:Position());player:Flush();b:SyncPlayer();s.combatView:Consume(world)
    V.assert(not player.alive and not s.view.view.root.enabled,'player destruction hides only player presentation')
    Step(330);V.assert(not player.alive,'dead player cannot auto-respawn after training five-second timer')
    b:Restart();V.assert(player.alive and player.vehicle==s.vehicle and b.rules.state=='prep','restart restores physical player and resets match rules')
    b.rules:Step(5,b:WorldState());b.rules:Drain()
    for _,e in ipairs(b.entries) do if e.unit.team=='red' then local c=e.unit.bp:CoreParts()[1];e.unit.struct=0;e.unit:Damage(c.id,1e9,e.unit:Position()) end end
    Step(1);V.assert(b.rules.state=='roundEnd' and b.rules.score.blue==1,'actual enemy destruction ends round')
    Step(366);V.assert(b.rules.state=='prep' and b.rules.round==2 and b:WorldState().alive.red==3,'next round respawns all source vehicles once')
    b.rules:Step(5,b:WorldState());b.rules:Drain()
    for _,e in ipairs(b.entries) do if e.unit.team=='red' then local c=e.unit.bp:CoreParts()[1];e.unit.struct=0;e.unit:Damage(c.id,1e9,e.unit:Position()) end end
    Step(367);V.assert(b.rules.state=='over' and b.rules.winner=='blue','real match reaches final result')
    while b.mvpShow.preparing do coroutine.yield() end
    V.assert(not b.mvpShow.failed,'final result prepares the production MVP scene')
    b.mvpShow:Skip();b.mvpShow:Skip()
    local focus=s.HasFocus;s.HasFocus=function() return true end
    for _=1,24 do b.mvpShow:Update(1/60) end
    s.HasFocus=focus
    s.hud.Update(s,.1);coroutine.yield();coroutine.yield();s.hud.Update(s,.1)
    V.assert(s.hud.match.back:IsVisible() and s.hud.match.retry:IsVisible(),'result exposes actual return and replay controls')
    local UI=require 'urhox-libs/UI';local Event=require 'urhox-libs/UI/Core/PointerEvent'
    local button=s.hud.match.back;local rect=button:GetAbsoluteLayoutForHitTest();local scale=UI.GetScale()
    local hit=UI.FindWidgetAt(rect.x+rect.w/2,rect.y+rect.h/2)
    print('[BattleQA] Return '..cjson.encode({rect=rect,scale=scale,root=s.hud.root.props.pointerEvents,button=button.props.pointerEvents,hit=hit and hit.props.text or 'other',overlay=UI.GetTopOverlay()~=nil}))
    V.assert(UI.FindWidgetAt(rect.x+rect.w/2,rect.y+rect.h/2)==button,'result return button owns actual hit target')
    for _,kind in ipairs({'PointerDown','PointerUp'}) do UI.HandlePointerEvent(Event.new(kind,{x=(rect.x+rect.w/2)*scale,y=(rect.y+rect.h/2)*scale,pointerId=89,pointerType='mouse',button=MOUSEB_LEFT})) end
    V.assert(s.wantsReturn,'result return dispatch invokes production action');stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('trial','elimination'),'battle uses production asynchronous scene loader');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then exercise=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(exercise);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then V.assert(app.hangar and app.car,'result returns to authored hall with a single scene owner');stage='done';V.finish() end
end
for frame=40,800 do V.atFrame(frame,Poll) end
V.atFrame(805,function() V.assert(stage=='done','battle lifecycle completed');V.finish() end)
