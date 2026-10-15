local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local stage='boot';local mode='conquest'
local Data=require 'combat.ArenaData'
local Reader=require 'core.ResourceData';local read=Reader.Read;local repeatedArenaReads=0
Reader.Read=function(path)
    if path=='Combat/Arena.json' then repeatedArenaReads=repeatedArenaReads+1 end
    return read(path)
end
engine.maxInactiveFps=120
local function Logic()
    local f=File('tools/migration/battle-rule-reference.json',FILE_READ);local ref=cjson.decode(f:ReadString());f:Dispose()
    local function Equal(actual,expected)
        if expected==cjson.null then return actual==nil end
        if type(expected)=='number' then return type(actual)=='number' and math.abs(actual-expected)<.00001 end
        if type(expected)~='table' then return actual==expected end
        if type(actual)~='table' then return false end
        for key,value in pairs(expected) do if not Equal(actual[key],value) then return false end end;return true
    end
    for _,case in ipairs(ref.cases) do
        local r=case.mode=='conquest' and require('combat.ConquestRules').New(Data.modes.conquest,Data.conquest) or require('combat.EscortRules').New(Data.modes.escort,Data.escort,420)
        for i,step in ipairs(case.steps) do
            r:Step(step.dt,step.world);if step.kill then r:Kill(step.kill) end;if step.steal then r:Steal(step.steal,300) end
            if step.snapshot then V.assert(Equal(r,step.snapshot),'H5 '..case.mode..' replay frame '..i) end
        end
    end
    local store={};function store:Read() return nil end;function store:Write() return true end
    V.assert(Equal(require('combat.Matchmaker').Find(store,4,3,nil,90862445),ref.roster),'source seeded 4v4 roster and RNG match')
end
local function Exercise(s)
    local b=s.battle;local w=s.world;local player=b.player;local rule=b.rules
    V.assert(#b.entries==8 and #w.units==8,mode..' loads source 4v4 vehicles')
    V.assert(s.hud.match~=nil and b.objectives.view~=nil,mode..' actual target rendering and HUD attached')
    local voice=b.voice
    V.assert(voice.ready,'source combat radio resources are ready')
    voice:Reset();voice:Say('kill');voice:Say('takenA');voice:Say('win')
    V.assert(#voice.queue==1 and voice.queue[1].key=='win','match result interrupts stale tactical voice queue')
    voice:Next();local first=voice.card.id
    V.assert(voice.source.sound~=nil and voice.card.text~='' and voice.source.playing,'approved voice sample and source subtitle play together')
    voice:Say('win');voice:Next();V.assert(voice.card.id~=first,'same radio category never repeats consecutive variant')
    voice:Reset();voice:Say('kill');voice:Say('kill');V.assert(#voice.queue==1,'kill feedback respects source cooldown')
    voice.time=voice.time+3;voice:Next();V.assert(not voice.card,'expired tactical events are discarded')
    for _,key in ipairs({'takenA','takenB','takenC','roundWin','shieldDownUs','go','min1'}) do voice:Say(key) end
    V.assert(#voice.queue==5,'combat announcer keeps a bounded five-event queue')
    voice:Reset();voice:Say(mode=='conquest' and 'titleConquest' or 'titleAttack');voice:Next()
    local update=s.Update;s.Update=function() end
    local function Step(n)
        for i=1,n do s:Tick(1/60,{throttle=0,steer=0});if i%30==0 then coroutine.yield() end end
    end
    if s.intro and not s.intro.done then s.intro:Finish() end
    rule:Step(5,b:WorldState());rule:Drain()
    if mode=='conquest' then
        local point=b.objectives.points[1].pos;player.vehicle:Place({point[1],point[2]+2,point[3]},0)
        V.assert(b:WorldState().inPoint.A.blue>0,'real player overlaps authored A capture circle')
        rule:Step(12,{inPoint={A={blue=1,red=0},B={blue=1,red=0},C={blue=1,red=0}}})
        V.assert(rule:Owned('blue')==3 and not rule.shield.red,'all source capture nodes drop enemy shield')
        rule.score.red=20;local base=b.objectives.bases.red;local dealt=b.objectives:Hit(player,{point=base.aim,owner={type='reactor',team='red'}},300)
        V.assert(dealt and math.abs(rule.score.red-18)<.00001,'mounted weapon reactor hit steals source charge')
        b.objectives:Explode(player,base.aim,3.6,300)
        V.assert(math.abs(rule.score.red-16.8)<.00001,'source missile reactor blast steals charge at sixty percent damage')
        rule.shield.red=true;b.objectives:Explode(player,base.aim,3.6,300)
        V.assert(math.abs(rule.score.red-16.8)<.00001,'active reactor shield excludes missile charge theft')
        local home=b.objectives.bases.blue.zone.pos;player.vehicle:Place({home[1],home[2]+2,home[3]},0)
        player.bodyHp=player.bodyHpMax*.5;local hp=player:Health();b.objectives:UnitTick(b.entries[1],.4)
        V.assert(player:Health()>hp and b.objectives:HomeProtected(player),'actual own base repairs and protects player')
        local from={base.zone.pos[1],base.zone.pos[2]+2,base.zone.pos[3]};rule.shield.red=true
        local hit=b.objectives:Cast(player,from,{-1,0,0},base.zone.rx*2+20,player.vehicle.body)
        V.assert(hit and hit.owner and hit.owner.type=='shield','live hostile shield intercepts physical weapon ray')
    else
        V.assert(b.objectives.length>300 and b.objectives.cart~=nil and b.objectives.cartBody.kinematic,'authored route and source boss payload are present')
        local initial=b.objectives:At(0).pos
        print('[BattleQA] payload initial '..cjson.encode({expected=initial,position={b.objectives.cartBody.position.x,b.objectives.cartBody.position.y,b.objectives.cartBody.position.z},s=rule.s,t=rule.t,state=rule.state}))
        V.assert(math.abs(b.objectives.cartBody.position.z-initial[3])<.01,'payload starts on source route before cinematic advances physics')
        local p=b.objectives:At(0).pos;player.vehicle:Place({p[1]+12,p[2]+2,p[3]},0)
        V.assert(b:WorldState().near.blue>0,'physical player inside source payload push range')
        rule:Step(20,{near={blue=2,red=0}});b.objectives:PlaceCart()
        V.assert(rule.s==100 and b.objectives.cartBody.position.z~=p[3],'kinematic source payload follows actual progress')
        local before=rule.s;rule:Step(1,{near={blue=1,red=1}});V.assert(rule.s==before and rule.contested,'equal attackers and defenders stop cart')
        rule:Step(12,{near={blue=0,red=0}});V.assert(rule.s<before,'unattended payload backs toward checkpoint')
    end
    local shooterEntry,ally,enemy
    for _,entry in ipairs(b.entries) do
        if entry.unit==player then shooterEntry=entry
        elseif entry.unit.team==player.team then ally=entry.unit else enemy=entry.unit end
    end
    local point={0,w:GroundAt(0,0)+30,0}
    local function Place(unit,p)
        unit.vehicle:Place(p,0);unit:SavePose();w.space:Step(1/60)
    end
    local function Splash(unit)
        local p=unit:Position();shooterEntry.env.explode({p[1],p[2]+8,p[3]},30,200,player.vehicle.body)
    end
    Place(ally,point);local friendly=ally.struct;local friendlyDamage=b.stats[player].damage;Splash(ally)
    V.assert(ally.struct==friendly and b.stats[player].damage==friendlyDamage,mode..' mounted missile splash excludes teammates')
    local enemyPoint={70,w:GroundAt(70,0)+30,0}
    Place(enemy,enemyPoint);enemy.guardUntil=w.time+10;local guarded=enemy.struct;local guardedDamage=b.stats[player].damage;Splash(enemy)
    V.assert(enemy.struct==guarded and b.stats[player].damage==guardedDamage,mode..' mounted missile splash respects respawn guard')
    enemy.guardUntil=0
    if mode=='conquest' then
        local base=b.objectives.bases[enemy.team].zone.pos
        Place(enemy,{base[1],base[2]+2,base[3]});rule.shield[enemy.team]=true;local protected=b.stats[player].damage;Splash(enemy)
        V.assert(b.stats[player].damage==protected,'missile splash respects actual active hostile home shield')
        Place(enemy,enemyPoint)
    end
    local health,structure=enemy:Health(),enemy.struct;local credited=b.stats[player].damage;Splash(enemy)
    V.assert((enemy:Health()<health or enemy.struct<structure) and b.stats[player].damage>credited,mode..' native enemy splash damage credits actual shooter')
    V.assert(w.attacker==nil,mode..' missile splash clears transient attacker attribution')
    -- Keep rule in live state while exercising production 8-second respawn.
    local core=player.bp:CoreParts()[1];player.struct=0;player:Damage(core.id,1e9,player:Position());player:Flush();b:SyncPlayer();s.combatView:Consume(w)
    Step(60);V.assert(not player.alive,mode..' cannot respawn before eight seconds');Step(450)
    V.assert(player.alive and s.vehicle==player.vehicle and s.view.view.root.enabled,mode..' real player respawns and rebinds presentation')
    b:Restart();s:StartIntro();s.intro:Update(1);s.intro:Camera();s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    if mode=='conquest' then for _,shield in ipairs(s.environment.effects.shields) do V.assert(shield.down==0 and shield.raise==1,'replay resets live base shield presentation') end end
    for unit,view in pairs(s.combatView.units) do
        local p=unit.vehicle.native.position
        V.assert((view.view.root.position-p).length<.01,mode..' cinematic vehicle pose is installed while world paused')
    end
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/'..mode..'-intro-native.png');image:Dispose();s.intro:Finish()
    s:PostUpdate(.1);b.objectives:Update(.1);coroutine.yield();coroutine.yield()
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/'..mode..'-live-native.png');image:Dispose()
    voice:Reset();voice:Say('go');voice:Next()
    -- Background validation has no input focus; freeze the radio clock for capture.
    voice.time=voice.time+.4
    V.assert(voice.card~=nil and voice.time-voice.card.at>.28,'radio card is past its transparent entrance before capture')
    coroutine.yield();coroutine.yield()
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/'..mode..'-radio-native.png');image:Dispose()
    if mode=='conquest' then rule=b.rules;rule:Step(5,b:WorldState());rule.score.blue=100;b:AfterStep(.01)
    else rule=b.rules;rule:Step(5,b:WorldState());rule.s=rule.length;rule:Step(.01,{near={blue=1,red=0}});b:AfterStep(8)
        V.assert(rule.half==2 and rule.attack=='red' and rule.state=='prep','second half changes team spawn and attack roles')
        rule:Step(5,b:WorldState());rule.s=rule.length/2;rule.t=rule.limit+Data.escort.bonus*2;rule:Step(1,{near={blue=0,red=0}});b:AfterStep(8)
    end
    V.assert(b.rules.state=='over' and b.result~=nil,mode..' settles and records match once')
    s.Update=update;app:Reload();stage='return';_G.VOX_QA_LAST_VOICE=voice
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('crater',mode),'production '..mode..' scene loader');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(repeatedArenaReads==0,'battle HUD, intro, vehicle spawn and respawn never reparse shared arena data')
        V.assert(VOX_QA_LAST_VOICE.disposed and #VOX_QA_LAST_VOICE.queue==0 and not VOX_QA_LAST_VOICE.card,'scene return cancels voice resources and card')
        if mode=='conquest' then mode='escort';V.assert(app:EnterTrial('crater',mode),'production escort scene loader');stage='loading'
        else stage='done';V.finish() end
    end
end
for frame=40,1750 do V.atFrame(frame,Poll) end
V.atFrame(1755,function() V.assert(stage=='done','both objective mode lifecycles completed');V.finish() end)
