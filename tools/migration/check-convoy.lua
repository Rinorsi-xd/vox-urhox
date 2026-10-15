local app=nil ---@type table?
local work=nil ---@type thread?
local stage='boot';local retired=nil ---@type table?
engine.maxInactiveFps=120
local function Logic()
    local file=File('tools/migration/source-convoy.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    local convoy=require('story.ConvoyRules').New(data.step,data.nav,function(_,_,hint) return hint end)
    local rules=require('story.MissionRules').New(require('story.MissionData').levels[2],convoy)
    rules:Begin();rules:Go(2)
    local function Compare(expected)
        for key,value in pairs(expected) do
            if type(value)=='number' then V.assert(math.abs((key=='progress' and rules.progress or convoy[key])-value)<.00001,'source convoy '..key)
            elseif type(value)=='table' then for i,v in ipairs(value) do V.assert(math.abs(convoy[key][i]-v)<.00001,'source convoy position') end
            elseif type(value)=='boolean' then V.assert(convoy[key]==value,'source convoy '..key) end
        end
    end
    for _,case in ipairs(data.trace) do
        if case.op=='retry' then convoy:Retry(rules)
        else rules.time=case.time;convoy:Update(rules,case.dt,{pos=case.pos,alive=case.alive,enemyPositions=case.enemyPositions,talking=false}) end
        Compare(case.expected)
    end
    V.assert(rules.stats.fails==1,'transport destruction records exactly one failure');V.assert(convoy.hp>=.5,'checkpoint retry guarantees half transport health')
    rules:Ask(data.step.ask);V.assert(rules:Choose(2) and rules.flags.rate==1 and not rules.choice,'three-way reply records source zero-based flag')
    V.assert(not rules:Choose(1),'completed choices cannot fire twice')
end
local function Exercise(s)
    local m=s.story;retired=m;s.Update=function() end
    V.assert(m.level.id=='s2' and m.convoy.total>300 and #m.view.collectors==1 and m.view.truck~=nil,'actual imported truck and preceding collector exist on source route')
    V.assert(#require('story.MissionData').view.truck.wheels==6,'all six original truck wheels are imported')
    local function Step(n)
        for i=1,n do m.voice:Update(1/60,true);s:Tick(1/60,{throttle=0,steer=0,handbrake=true});if i%30==0 then coroutine.yield() end end
    end
    local function Jump(pos) m:Place({pos=pos,yaw=m.convoy.yaw});s.view:ResetPose();s.view:Update(1);s:PostUpdate(.1) end
    Step(90);V.assert(m.rules:StepSpec().id=='meet','second mission starts original meeting objective')
    Jump(m.rules:Target());Step(2);V.assert(m.rules:StepSpec().id=='convoy','actual player contact starts escort')
    m.voice.queue={};m.voice.card=nil;Step(40);V.assert(m.rules.choice and m.rules.choice.id=='rate','original service-rating dialogue appears')
    s:HandleKey(KEY_2);V.assert(m.rules.flags.rate==1 and not m.rules.choice,'real PC numeric key selects dialogue')
    m.voice:Say({{'yun','您好！我是星际前途物流 AI「小运」，工号 0000001。本次运输全程录音，用于提升服务质量。'}},true)
    m.voice:Update(1,true);V.assert(m.voice.card and m.voice.card.id and m.voice.source.playing,'original logistics AI voice plays')
    local before=m.convoy.d;Jump({300,30,200});Step(120);V.assert(m.convoy.far and m.convoy.d-before<4,'transport slows to wait when player leaves leash')
    for wave,p in ipairs({.15,.5,.76}) do
        m:ClearEnemies();m.convoy.d=m.convoy.total*p;m.convoy.pos=m.convoy:Along(m.convoy.d);m.rules.progress=p;Jump(m.convoy.pos);Step(2)
        V.assert(#m.entries==1+(wave==2 and 4 or 3),'source interception wave '..wave..' spawns native pirates')
    end
    local c=m.convoy;local hp=c.hp
    for i=2,#m.entries do local u=m.entries[i].unit;u.vehicle:Place({c.pos[1]+i*3,c.pos[2]+2,c.pos[3]},0);u:SavePose() end
    Step(2);V.assert(c.blocked and c.hp<hp,'real pirate proximity blocks and damages transport')
    m:ClearEnemies();c.hp=.001;m:Spawn({enemies={{at={c.pos[1],c.pos[2],c.pos[3]},role='assault',target='truck'}}});Step(30)
    V.assert(m.rules.failAt and m.rules.stats.fails==1,'transport loss invokes actual retry lifecycle')
    Step(185);V.assert(not m.rules.failAt and #m.entries==1 and c.hp>=.5 and c.d>=c.cpD,'three-second retry clears attackers and restores checkpoint transport')
    m.rules:Ask(m.level.steps[2].beats[6].ask);s.hud.Update(s,.1);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/convoy-choice-native.png');image:Dispose()
    m.rules:Choose(1);m:Events();m:ClearEnemies();c.d=c.total-.01;c.pos=c:Along(c.d);c.v=5.2;Jump(c.pos);Step(2)
    V.assert(m.rules.phase=='complete' and m.rules.stats.checkpoints==3,'delivered cargo completes actual escort')
    m.voice.queue={};m.voice.card=nil;Step(250);V.assert(m.rules.finished and m.saved and m.rules.grade=='A','source failed-once grade is saved for mission two')
    s.hud.Update(s,.6);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
    image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/convoy-result-native.png');image:Dispose()
    app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('story2'),'second mission uses production loading gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(#retired.view.objects==0 and cache:GetMemoryUse(StringHash('Texture2DArray'))==0,'convoy return releases meshes and terrain arrays');stage='done';V.finish()
    end
end
for frame=40,1000 do V.atFrame(frame,Poll) end
V.atFrame(1005,function() V.assert(stage=='done','convoy lifecycle complete');V.finish() end)
