local app=nil ---@type HangarApp|nil
local stage='boot';local work=nil ---@type thread|nil
engine.maxInactiveFps=120
local function Exercise(session)
    local b=session.battle;local w=session.world;local L=w.layout
    local originalUpdate=session.Update;session.Update=function() end
    V.assert(L.pads.player.width==56 and L.pads.enemy.depth==48,'frozen launch pads are 56 by 48 metres')
    V.assert(#L.nav.edges==147 and #L.blocks==1910,'frozen road graph and collision layouts are current')
    V.assert(#session.environment.dynamics==52,'all 52 frozen machinery nodes are bound')
    dofile('tools/migration/check-crater-authoring.lua').Check({environment=session.environment,camera={node=session.camera:GetNode()},scene=session.scene})
    local function Step(n,command)
        for i=1,n do session:Tick(1/60,command or {throttle=0,steer=0});if i%30==0 then coroutine.yield() end end
    end
    Step(180)
    for _,entry in ipairs(b.entries) do
        local u=entry.unit;local p=u:Position();local pad=L.pads[u.team=='blue' and 'player' or 'enemy']
        local v=u.vehicle;local supported=v.telemetry.contact>0 or (v.telemetry.hoverAuthority or 0)>0 or (v.telemetry.legContacts or 0)>0
        print('[BattleQA] launch '..u.team..entry.slot..' pos='..table.concat(p,',')..' wheels='..v.telemetry.contact..' hover='..tostring(v.telemetry.hoverAuthority)..' legs='..tostring(v.telemetry.legContacts))
        V.assert(supported and p[2]>pad.pos[2]-1,'supported launch slot '..u.team..entry.slot)
    end
    local blueStart=b.player:Position();blueStart={table.unpack(blueStart)}
    b.rules:Step(5,b:WorldState());b.rules:Drain();Step(1500)
    local farthest=0
    for _,entry in ipairs(b.entries) do if entry.driver and entry.unit.alive then
        local p=entry.unit:Position();local pad=L.pads[entry.unit.team=='blue' and 'player' or 'enemy']
        farthest=math.max(farthest,math.sqrt((p[1]-pad.pos[1])^2+(p[3]-pad.pos[3])^2))
    end end
    V.assert(farthest>45,'real AI exits launch pad through source road graph')
    b:Restart();session:StartIntro();session:PostUpdate(0)
    local time=w.time;local ruleTime=b.rules.t;local position=session.camera:GetNode().position
    for i=1,90 do originalUpdate(session,1/60);session:PostUpdate(1/60);if i%15==0 then coroutine.yield() end end
    V.assert(w.time==time and b.rules.t==ruleTime,'cinematic pauses physics and preparation countdown')
    V.assert((session.camera:GetNode().position-position):Length()>1,'source cinematic camera actually moves')
    V.assert(require('urhox-libs/UI').GetTopOverlay()==session.intro.page,'intro blocks controls behind it')
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/crater-baseline-intro-native.png');image:Dispose()
    session.intro:Finish();V.assert(session.hud.root:IsVisible() and require('urhox-libs/UI').GetTopOverlay()==nil,'skipping restores HUD and input ownership')
    V.assert(require('combat.Matchmaker').IntroSeen(app.store,'elimination'),'completed mode introduction is remembered')
    session.Update=originalUpdate;app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then app=VOX_HANGAR.app;V.assert(app:EnterTrial('crater','elimination'),'load real authored battlefield');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        V.assert(app.hangar and cache:GetExistingResource('Model','Crater/mesh-0.bin')==nil,'return releases unused map models');stage='done';V.finish()
    end
end
for frame=35,1140 do V.atFrame(frame,Poll) end
V.atFrame(1145,function() V.assert(stage=='done','current battlefield lifecycle finished');V.finish() end)
