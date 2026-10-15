local app,retired ---@type table?,table?
local work ---@type thread?
local stage='boot'
engine.maxInactiveFps=120
local function Logic()
    local file=File('tools/migration/source-capture.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    local level=require('story.MissionData').levels[4];local r,index=nil,0
    for _,c in ipairs(data.trace) do
        if c.index~=index then index=c.index;r=require('story.MissionRules').New(level);r:Begin();r:Go(index);r:Drain() end
        local positions,tags={},{guard=0,counter=0}
        for _,e in ipairs(c.enemies) do positions[#positions+1]=e.pos;tags[e.tag]=tags[e.tag]+1 end
        local done=r.cap:Update(r,c.dt,{pos=c.pos,enemyPositions=positions,enemyTags=tags,nav=data.nav,interact=c.interact})
        local e=c.expected
        V.assert(r.cap.phase==e.phase,'frozen capture stage parity')
        V.assert(math.abs(r.cap.p-e.p)<.00001 and math.abs(r.cap.scrub-e.scrub)<.00001,'frozen occupation and scrub timing')
        V.assert((r.stats.sites or 0)==e.sites and (r.stats.graffiti or 0)==e.graffiti,'frozen capture statistics')
        V.assert(done==e.done,'frozen capture completion')
        if e.checkpoint then for j=1,3 do V.assert(math.abs(r.checkpoint.pos[j]-e.checkpoint.pos[j])<.00001,'original captured checkpoint') end end
        r:Drain()
    end
end
local function Exercise(s)
    local m=s.story;retired=m;s.Update=function() end
    local function Step(n)
        for i=1,n do m.voice:Update(1/60,true);s:Tick(1/60,{throttle=0,steer=0,handbrake=true});if i%30==0 then coroutine.yield() end end
    end
    local function Jump(p) m:Place({pos=p,yaw=0});s.view:ResetPose();s.view:Update(1);s:PostUpdate(.1) end
    local function Silence() m.voice.queue={};m.voice.card=nil;m.voice.fade=nil end
    local function Destroy()
        for i=2,#m.entries do local u=m.entries[i].unit;u.kill='QA native destruction';u.dirty=true;u:Flush() end
        Step(2)
    end
    local function Shot(name)
        s.hud.Update(s,.5);s:PostUpdate(.1);coroutine.yield();coroutine.yield()
        local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/capture-'..name..'-native.png');image:Dispose()
    end
    Step(90);V.assert(#m.view.collectors==3 and m.view.sites.A and m.view.sites.C,'all three original occupied sites exist')
    for site=1,3 do
        local spec=m.rules:StepSpec();V.assert(spec.kind=='capture','actual capture step '..site)
        if site==2 then Silence();Step(40);V.assert(m.rules.choice and m.rules.choice.id=='tag','original graffiti reply opens')
            Shot('choice');s:HandleKey(KEY_2);Silence();V.assert(m.rules.flags.tag==1,'original zero-based graffiti reply stored')
        end
        Jump(spec.pos);Step(2);V.assert(#m.entries==4 and m.rules.cap.phase=='cap','three real original guards spawned')
        if site==3 then
            local boss=m.entries[2].unit;local before=m.rules.stats.kills
            V.assert(m.entries[2].flee==.6 and boss.spec.weapons[1],'original little-fox escape threshold')
            -- Remove non-core parts through production damage until integrity crosses the source threshold.
            for _,p in ipairs(boss.bp:List()) do if p.type~='core' and boss:Integrity()>=.59 then boss:Destroy(p.id) end end
            m:AfterStep(0)
            V.assert(#m.entries==3 and m.rules.flags.huhuFled and m.rules.stats.kills==before,'damaged real boss retreats without awarding kill')
        end
        Destroy();Jump(spec.pos);Step(site==3 and 425 or 365)
        V.assert(m.rules.cap.phase=='counter' and m.rules.stats.sites==site and #m.entries==4,'capture summons actual counterattack')
        V.assert(m.view.sites[spec.site].captured,'source company flag replaces pirate flag')
        if site==1 then
            local checkpoint=m.rules.checkpoint;local u=m.player;u.kill='QA player destruction';u.dirty=true;u:Flush();Step(190)
            V.assert(u.alive and m.rules.stats.deaths==1 and math.abs(u:Position()[1]-checkpoint.pos[1])<5,'native destruction respawns at reclaimed site')
            Shot('counter')
        end
        Destroy();Jump(spec.pos);Step(2);V.assert(m.rules.cap.phase=='scrub','all guards and attackers cleared before cleaning')
        s.pointer.captured=true;s.controls.held.interact=true;Step(110)
        s.controls.held.interact=false
        V.assert(m.rules.stats.graffiti==site and m.view.sites[spec.site].scrubbed,'native held interact scrubs source graffiti')
        Silence()
    end
    Step(260);V.assert(m.rules.finished and m.saved and m.rules.stats.sites==3 and m.rules.stats.graffiti==3,'capture result completes and saves')
    Shot('result');app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;Logic();V.assert(app:EnterTrial('story4'),'capture enters production loading gate');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(#retired.view.objects==0 and not next(retired.view.sites) and cache:GetMemoryUse(StringHash('Texture2DArray'))==0,'capture releases scene resources');stage='done';V.finish()
    end
end
for frame=40,1500 do V.atFrame(frame,Poll) end
V.atFrame(1505,function() V.assert(stage=='done','capture lifecycle complete');V.finish() end)
