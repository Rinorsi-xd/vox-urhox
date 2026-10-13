local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local stage='boot';local retired=nil ---@type table|nil
engine.maxInactiveFps=120
local function Logic()
    local Rules=require 'story.MissionRules';local level=require('story.MissionData').level
    local r=Rules.New(level);r:Begin();r:Step(1.39,{alive=true});V.assert(r.index==0,'source mission waits for 1.4-second boot after rendered transition')
    r:Step(.011,{alive=true});V.assert(r:StepSpec().id=='box','frozen first task starts after reveal')
    V.assert(not r:Near({0,0,0},{0,40,0},6,6,{w=2,below=1.5,above=1.5}),'wrong deck cannot pick up objective through ceiling')
    V.assert(r:Near({0,13,0},{0,0,0},6,6,{w=15,below=13,above=7}),'measured MEGA lower extent reaches ground objective')
    V.assert(not r:Near({0,0,0},{6,0,0},6,6),'source pickup boundary remains strict')
    r:Go(4);local at={alive=true,pos={0,28,-22},size={w=2,below=1.5,above=1.5},speed=3,interact=true}
    r:Step(3,at);V.assert(r.install==0 and r.blocked,'moving faster than 2.5 m/s never installs')
    at.speed=0;r:Step(1,at);at.interact=false;r:Step(.5,at);V.assert(math.abs(r.install-.6)<.00001,'release decays install by source 0.8 per second')
    at.interact=true;r:Step(1.79,at);V.assert(r.index==4,'installation cannot complete before full 2.4 seconds');r:Step(.011,at)
    V.assert(r.index==5 and r.stats.collectors==1,'installation advances exactly once and records checkpoint')
    local timeout=Rules.New(level);timeout:Begin();timeout:Go(6)
    local p={alive=true,pos={-190,-12,0},enemies=3};timeout:Step(.01,p);V.assert(timeout.phase=='fight','source scout trigger starts live encounter')
    timeout:Step(90,p);V.assert(timeout.index==6,'scouts do not retreat at exactly 90 seconds');timeout:Step(.01,p)
    V.assert(timeout.index==7 and timeout.dropPos~=nil,'source timeout retreats scouts and still drops log')
    local events=timeout:Drain();local retreat=false;for _,e in ipairs(events) do if e.type=='clear' then retreat=e.timeout end end
    V.assert(retreat and level.steps[6].done[1][2]~=level.steps[6].retreat[1][2],'timeout does not mutate original success dialogue for replay')
end
local function Exercise(s)
    local m=s.story;local update=s.Update;s.Update=function() end;retired=m
    local progress=app.store:Read('story-progress',function(d) return type(d)=='table' end) or {}
    local clears=progress.s1 and progress.s1.clears or 0
    V.assert(m~=nil and s.battle==nil and s.combat==m and s.hud.story~=nil,'real mission uses shared vehicle combat and source story HUD')
    V.assert(#s.world.units==1 and m.player.externalView and not m.player.autoRespawn,'mission player is damageable, without idle trial clones')
    local function Step(n)
        for i=1,n do m.voice:Update(1/60,true);s:Tick(1/60,{throttle=0,steer=0,handbrake=true});if i%30==0 then coroutine.yield() end end
    end
    local function Jump(target)
        m:Place({pos=target,yaw=0});s.view:ResetPose();s.view:Update(1);s:PostUpdate(.1)
    end
    Step(90);V.assert(m.rules:StepSpec().id=='box','production transition begins source black-box objective')
    Jump(m.rules:Target());Step(2);V.assert(m.rules.stats.intel==1 and m.rules:StepSpec().id=='exit','actual player contact picks frozen black box')
    Jump(m.rules:Target());Step(2);V.assert(m.rules:StepSpec().id=='poster','real reach event advances to original highland intel')
    Jump(m.rules:Target());Step(2);V.assert(m.rules.stats.intel==2 and m.rules:StepSpec().id=='deck','actual highland intel advances to deck install')
    local core=m.player.bp:CoreParts()[1];m.player.struct=0;m.player:Damage(core.id,1e9,m.player:Position());m.player:Flush();m:SyncPlayer();s.combatView:Consume(s.world)
    Step(120);V.assert(not m.player.alive and m.rules.stats.deaths==1,'real destruction waits three seconds, counted once')
    Step(65);V.assert(m.player.alive and s.vehicle==m.player.vehicle and s.view.view.root.enabled,'checkpoint airdrop restores real body and displayed parts')
    V.assert(m.rules:StepSpec().id=='deck' and m.rules.stats.intel==2,'respawn preserves collected intel and current task')
    m.player.bodyHp=m.player.bodyHpMax*.5;m.player.hitAt=s.world.time;Step(120);V.assert(m.player:Health()<.6,'breathing recovery waits five seconds after real hit')
    Step(240);V.assert(m.player:Health()>.6,'frozen source baseline heals fifteen percent per second after delay')
    s.pointer.captured=true;Jump(m.rules:Target());Step(15);V.assert(m.rules.install==0,'standing in installation ring without G cannot complete')
    s.controls.held.interact=true;Step(150);V.assert(m.rules.stats.collectors==1 and #m.view.collectors==1,'held interaction spawns imported animated collector')
    Jump(m.rules:Target());s.controls.held.interact=true;Step(150);V.assert(m.rules.stats.collectors==2 and m.rules:StepSpec().id=='scouts','second original collector completes source route')
    Jump(m.rules:Target());Step(2);V.assert(#m.entries==4 and #s.world.units==4 and m.rules.phase=='fight','source trigger spawns three real pirate hover vehicles')
    local enemy=m.entries[2];local hp,structure=m.player:Health(),m.player.struct
    enemy.env.hit({point=m.player:Position(),owner={type='car',ref=m.player,partId=m.player.bp:CoreParts()[1].id}},400,{0,0,1},0,0)
    V.assert(m.player:Health()<hp or m.player.struct<structure,'enemy combat environment damages actual player')
    local fellow=m.entries[3].unit;local friendHp=fellow:Health();enemy.env.hit({point=fellow:Position(),owner={type='car',ref=fellow,partId=fellow.bp:CoreParts()[1].id}},400,{0,0,1},0,0)
    V.assert(fellow:Health()==friendHp,'pirates do not damage allies')
    local before=m.entries[2].unit:Position();Step(120);local after=m.entries[2].unit:Position()
    V.assert(math.sqrt((after[1]-before[1])^2+(after[3]-before[3])^2)>1,'pirate AI drives native crater physics')
    for i=2,#m.entries do local u=m.entries[i].unit;u.kill='QA combat destruction';u.dirty=true;u:Flush() end
    Step(2);V.assert(m.rules.stats.kills==3 and m.rules:StepSpec().id=='log' and m.view.intel.log~=nil,'destroyed pirates leave source last-kill log position')
    Jump(m.rules:Target());Step(2);V.assert(m.rules.stats.intel==3 and m.rules:StepSpec().id=='east','dropped intel is picked by actual player')
    Jump(m.rules:Target());s.pointer.captured=true;s.controls.held.interact=true;Step(150);V.assert(m.rules.stats.collectors==3 and m.rules:StepSpec().id=='home','third original installation opens return objective')
    Jump(m.rules:Target());Step(2);m.voice:Update(120,true);m.voice.queue={};m.voice.card=nil;Step(250)
    V.assert(m.rules.finished and m.rules.grade=='A' and not s.pointer.captured,'mission settles original one-loss grade and releases pointer')
    V.assert(m.saved and app.store:Read('story-progress',function(d) return type(d)=='table' end).s1.clears==clears+1,'mission records grade and clear once')
    local time=s.world.time;Step(30);V.assert(s.world.time==time,'result pauses physics while HUD remains active')
    s.hud.Update(s,.6);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/story-result-native.png');image:Dispose()
    s.Update=update;app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('story1'),'production story scene loading gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(#retired.view.objects==0 and #retired.voice.queue==0 and not retired.voice.card,'return frees mission meshes, materials and voice queue')
        V.assert(cache:GetMemoryUse(StringHash('Texture2DArray'))==0,'story return frees native crater texture arrays');stage='done';V.finish()
    end
end
for frame=40,1000 do V.atFrame(frame,Poll) end
V.atFrame(1005,function() V.assert(stage=='done','story first mission completes lifecycle');V.finish() end)
