local app=nil ---@type HangarApp|nil
local stage='boot';local work=nil ---@type thread|nil
local Mix=require 'audio.DrivingMix'
local Audio=require 'audio.DrivingAudio'
local function Near(a,b) return math.abs(a-b)<1e-5*math.max(1,math.abs(b)) end
local function Stopped(audio)
    for _,loop in pairs(audio.loops) do if loop.source.playing or loop.gain~=0 or loop.source.gain~=0 then return false end end
    for _,voice in ipairs(audio.voices) do if voice.source.playing then return false end end;return true
end
local function Logic(scene)
    local f=assert(io.open('tools/migration/source-driving-audio.json'));local fixtures=cjson.decode(f:read('*a'));f:close()
    local out=Mix.New()
    for i,case in ipairs(fixtures.cases) do
        local vehicle={speed=case.speed,wheels={},spec={hovers={}},thrusterOutputs={[1]=case.thrust},telemetry={hoverForce=case.command.cutLift and 0 or 100}}
        if case.kind=='wheel' or case.kind=='mixed' then vehicle.wheels[#vehicle.wheels+1]={track=false} end
        if case.kind=='track' or case.kind=='mixed' then vehicle.wheels[#vehicle.wheels+1]={track=true} end
        if case.kind=='hover' or case.kind=='mixed' then vehicle.spec.hovers[1]={works=true} end
        Mix.Fill(out,vehicle,case.command)
        for _,mix in ipairs(out) do local wanted=case.loops[mix.id]
            V.assert(Near(mix.amount,wanted.amount) and Near(mix.pitch,wanted.pitch),'source mix '..i..' '..case.kind..' '..mix.id)
        end
    end
    local audio=Audio.New(scene);audio.focus=function() return true end;audio:SetActive(true)
    local camera=scene:CreateChild('DrivingAudioCamera')
    local wheels={{track=false},{track=true}};local hovers={{works=true}}
    local vehicle={speed=6,wheels=wheels,spec={hovers=hovers},thrusterOutputs={[1]=.64},telemetry={hoverForce=10},body={translation=function() return {x=0,y=0,z=0} end}}
    for _=1,60 do audio:Update(1/60,vehicle,{throttle=1},camera) end
    local loops=0;for key,loop in pairs(audio.loops) do
        loops=loops+1;V.assert(loop.source.playing and loop.source.frequency>30000,'decoded live sample '..key)
    end
    V.assert(loops==5,'mixed chassis owns exactly five local loops')
    V.assert(Near(audio.loops.drive_idle.source.frequency,audio.sounds.drive_idle:GetFrequency()*.975),'loop pitch uses source Hz')
    local gain=audio.loops.drive_idle.source.gain
    for _=1,120 do audio:Update(1/60,vehicle,{throttle=1},camera,nil,true) end
    V.assert(Near(audio.loops.drive_idle.source.gain,gain*.3),'voice ducks original driving bed to 30 percent')
    local enemy={alive=true,vehicle={speed=6,wheels={{track=false}},spec={hovers={}},thrusterOutputs={},telemetry={},body={translation=function() return {x=10,y=0,z=0} end}}}
    for _=1,60 do audio:Update(1/60,vehicle,{},camera,{{unit=enemy}}) end
    V.assert(audio.loops['remote:drive_idle'].source.playing and audio.loops['remote:drive_idle'].source.panning<0,'remote vehicle gets distance attenuation and mirrored listener stereo')
    enemy.alive=false
    for _=1,60 do audio:Update(1/60,vehicle,{},camera,{{unit=enemy}}) end
    V.assert(not audio.loops['remote:drive_idle'].source.playing,'destroyed remote engine fades out')
    vehicle.wheels={};vehicle.spec.hovers={};vehicle.thrusterOutputs={};vehicle.telemetry.hoverForce=0
    for _=1,60 do audio:Update(1/60,vehicle,{},camera) end
    V.assert(Stopped(audio),'losing all movement parts silences engine loops')
    for _,id in ipairs({'mech_step','mech_push','mech_land'}) do audio.time=audio.time+1;V.assert(audio:Play(id,1,0),'approved mech sample '..id) end
    for _=1,40 do audio.time=audio.time+.25;audio:Play('mech_step',1,0) end
    V.assert(#audio.voices<=3,'mechanical transient sources remain bounded')
    audio:SetActive(false);V.assert(Stopped(audio),'pause immediately retires every loop and transient')
    audio:SetActive(true);vehicle.wheels={{track=false}};audio:Update(.1,vehicle,{},camera)
    audio.focus=function() return false end;audio:Update(.1,vehicle,{},camera);V.assert(Stopped(audio),'focus loss stops the driving bed')
    audio.focus=function() return true end;audio.volume=0;audio:Update(.1,vehicle,{},camera);V.assert(not audio:Play('mech_land',1,0) and Stopped(audio),'mute cannot restart samples')
    audio:Dispose();V.assert(audio.disposed and next(audio.loops)==nil and next(audio.sounds)==nil,'sample ownership disposed')
    camera:Dispose()
    local events=require('audio.DrivingEvents').New();local list={{leg={partId=1},grounded=true}}
    local v={legControl={list=list},telemetry={legContacts=1},speed=3,body={linvel=function() return {y=-6} end}}
    local played={};local function Emit(id) played[#played+1]=id end
    events:Observe(v,.1,Emit);V.assert(#played==0,'initial stance does not fake a footstep')
    list[1].grounded=false;events:Observe(v,.01,Emit);list[1].grounded=true;events:Observe(v,.01,Emit)
    V.assert(played[1]=='mech_step','real swing-to-contact produces step')
    v.telemetry.legJumped=true;v.telemetry.legContacts=0;list[1].grounded=false;events:Observe(v,.2,Emit)
    V.assert(played[2]=='mech_push','actual controller jump produces launch')
    v.telemetry.legJumped=false;v.telemetry.legContacts=1;list[1].grounded=true;events:Observe(v,.01,Emit)
    V.assert(played[3]=='mech_land','falling and regain of support produces landing once')
    events:Observe(v,.1,Emit);V.assert(#played==3,'stable stance does not repeat landing')
    events:Clear();events:Observe(v,.1,Emit);V.assert(#played==3,'teleport or rebuild resets contact history')
end
local function Exercise(s)
    local update=s.Update;s.Update=function() end;local audio=s.drivingAudio;audio.focus=function() return true end
    s.pointer.captured=true
    for i=1,180 do s:Tick(1/60,{throttle=1,steer=0});if i%30==0 then coroutine.yield() end end
    V.assert(math.abs(s.vehicle.speed)>1 and (audio.counts.drive_load or 0)>0 and audio.loops.drive_load.source.playing,'actual production wheel car drives with approved load loop')
    s:Pause();V.assert(Stopped(audio),'real session pause stops driving')
    s.pointer.captured=true;s:Tick(.1,{throttle=0,steer=0});s:Reset();V.assert(Stopped(audio),'real teleport stops samples and event history')
    s.Update=update;_G.VOX_QA_DRIVING_AUDIO=audio;app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        stage='logic';app=VOX_HANGAR.app;Logic(app.scene)
        V.assert(app:EnterTrial('trial'),'production loader includes all driving dependencies');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then
        V.assert(VOX_QA_DRIVING_AUDIO.disposed and next(VOX_QA_DRIVING_AUDIO.loops)==nil,'return releases production driving audio');stage='done';V.finish()
    end
end
for i=45,650 do V.atFrame(i,Poll) end
V.atFrame(655,function() V.assert(stage=='done','driving audio lifecycle completed: '..stage);V.finish() end)
