local app,retired ---@type table?,table?
local work ---@type thread?
local stage='boot'
engine.maxInactiveFps=120
local function Logic()
    local file=File('tools/migration/source-siege.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    local level=require('story.MissionData').levels[3];local r=require('story.MissionRules').New(level)
    r:Begin();r:Go(3);local healed,restored,failed=0,0,0
    for _,c in ipairs(data.trace) do
        r.stepT=c.stepT;local done=r.hold:Update(r,c.dt,{alive=c.alive,pos=c.pos,enemyPositions=c.enemies})
        for _,e in ipairs(r:Drain()) do
            if e.type=='heal' then healed=healed+e.fraction elseif e.type=='restore' then restored=restored+e.count end
        end
        -- fail() is idempotent in the real mission; reference counts its invocation.
        if r.hold.energy<=0 then failed=failed+1 end
        local s=c.expected
        for _,pair in ipairs({{r.hold.left,s.left},{r.hold.energy,s.energy},{r.hold.healT,s.healT},{r.progress,s.progress},{healed,s.healed},{restored,s.restored},{failed,s.failed}}) do
            V.assert(math.abs(pair[1]-pair[2])<.00001,'frozen hold state/repair parity')
        end
        V.assert(done==s.done,'frozen hold completion parity')
    end
    r=require('story.MissionRules').New(level);r:Begin();r:Go(2)
    local world={alive=true,pos=level.spawn.pos,talking=false,enemies=0,enemyPositions={}}
    r:Step(.6,world);V.assert(r.choice and r.choice.id=='surrender','parley opens original surrender choices')
    r:Choose(3);world.talking=true;r:Step(2,world);V.assert(r.index==2,'talk objective waits for reply playback')
    world.talking=false;r:Step(.1,world);V.assert(r.index==3 and r.hold.left==120,'reply completion enters full siege timer')
    r.hold.energy=.001;world.pos={0,6,-234};world.enemyPositions={{0,6,-234}};r:Step(4,world)
    V.assert(r.failAt and r.stats.fails==1,'shield loss records failure once')
    world.enemyPositions={};r:Step(3.1,world)
    V.assert(not r.failAt and r.hold.energy==1 and r.stepT<4,'retry resets shield, warmup and beats')
end
local function Exercise(s)
    local m=s.story;retired=m;s.Update=function() end
    local function Step(n)
        for i=1,n do m.voice:Update(1/60,true);s:Tick(1/60,{throttle=0,steer=0,handbrake=true});if i%30==0 then coroutine.yield() end end
    end
    local function Jump(p) m:Place({pos=p,yaw=0});s.view:ResetPose();s.view:Update(1);s:PostUpdate(.1) end
    local function Silence() m.voice.queue={};m.voice.card=nil;m.voice.fade=nil end
    Step(90);Jump(m.rules:Target());Step(2)
    V.assert(m.rules:StepSpec().kind=='talk','real scene reaches surrender conversation')
    Silence();Step(40);s:HandleKey(KEY_3);Silence();Step(30)
    V.assert(m.rules:StepSpec().kind=='hold' and m.view.zone.enabled,'real conversation enables source repair circle')
    Jump({0,6,-234});m.player.bodyHp=m.player.bodyHpMax*.5;m.player.hitAt=s.world.time
    m.rules.stepT=4;Step(60);V.assert(m.player:Health()>.54 and m.player:Health()<.6,'live base repairs without waiting for breathing regen')
    for i,t in ipairs({8,36,66,84,104}) do
        m:ClearEnemies();m.rules.stepT=t-.01;Step(2)
        V.assert(#m.entries==1+(i==2 and 4 or i==5 and 5 or 3),'source siege enemy wave '..i)
    end
    m:ClearEnemies();m.rules.hold.energy=.00001
    m:Spawn({enemies={{at={0,8,-234},role='assault'}}});Step(2)
    V.assert(m.rules.failAt and m.rules.stats.fails==1,'native pirate inside drain circle breaks shield')
    Step(185);V.assert(not m.rules.failAt and m.rules.hold.energy==1 and #m.entries==1,'actual retry clears attackers and resets hold')
    Silence();m.rules.stepT=56;m.rules.hold.left=70;Step(20)
    V.assert(m.rules.choice and m.rules.choice.id=='lunch','original lunch interruption creates native choices')
    s.hud.Update(s,.1);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/siege-choice-native.png');image:Dispose()
    s:HandleKey(KEY_2);Silence();m:ClearEnemies();m.rules.beatsFired={true,true,true,true,true,true,true,true};m.rules.hold.left=.01
    Step(2);V.assert(m.rules:StepSpec().id=='coupon' and m.view.intel.coupon,'hold completion drops real source coupon')
    Jump(m.rules:Target());Step(2);Silence();Step(250)
    V.assert(m.rules.finished and m.rules.grade=='A' and m.saved,'failed-once siege completes and saves original evaluation')
    s.hud.Update(s,.6);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/siege-result-native.png');image:Dispose()
    app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('story3'),'siege enters production resource/transition gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(#retired.view.objects==0 and cache:GetMemoryUse(StringHash('Texture2DArray'))==0,'siege exit releases mission and terrain resources');stage='done';V.finish()
    end
end
for frame=40,1200 do V.atFrame(frame,Poll) end
V.atFrame(1205,function() V.assert(stage=='done','siege lifecycle complete');V.finish() end)
