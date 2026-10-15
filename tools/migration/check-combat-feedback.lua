local Mix=require 'audio.RecoveryMix'
local Audio=require 'audio.CombatFeedbackAudio'
local app=nil ---@type HangarApp|nil
local trial=nil ---@type table|nil
local stage='boot'
local function Near(a,b) return math.abs(a-b)<.00001 end
local function Logic(scene)
    local f=File('tools/migration/source-combat-feedback.json',FILE_READ);local cases=cjson.decode(f:ReadString()).cases;f:Dispose()
    for n,trace in ipairs(cases) do
        local mix=Mix.New();local saved={};local unit={alive=true,env={time=0},hp=1}
        unit.Health=function(self) return self.hp end;unit.Position=function() return {0,0,0} end
        for i,item in ipairs(trace) do
            local s=item.step
            if s.replace then unit={alive=true,env={time=0},hp=1,Health=unit.Health,Position=unit.Position} end
            unit.hp=s.h;unit.env.time=s.t;unit.alive=s.alive~=false
            local events={};if s.event then local e=s.id and saved[s.id] or {type=s.event,unit=unit};events[1]=e;if s.id then saved[s.id]=e end end
            local plays={};mix:Consume(events,unit,function(id,_,rate) plays[#plays+1]={id=id,rate=rate} end)
            V.assert(#plays==#item.plays,'source recovery event count '..n..'/'..i)
            for j,p in ipairs(item.plays) do V.assert(plays[j] and plays[j].id==p.id and Near(plays[j].rate,p.rate),'source recovery cue '..n..'/'..i..'/'..j) end
            V.assert(Near(mix.amount,item.loop.amount) and Near(mix.rate,item.loop.rate),'source repair envelope '..n..'/'..i)
        end
    end
    local motion=require('ui.CombatFeedbackMotion').New();local l=require('ui.ReticleState').Layout(1920,1080)
    for i=1,12 do motion:Hit(i*.6,.2) end;V.assert(#motion.hits==5,'directional hits bounded at five')
    motion:Update(1.01,.2);V.assert(#motion.hits==0 and motion.low>0,'source hit timeout and low health pulse')
    motion:Kill('QA target',false,nil,nil,l,function() return .5 end);V.assert(#motion.cubes==22 and motion.score.target==300,'source kill emits 22 blocks and 300 display points')
    for _=1,90 do motion:Update(1/60,1) end
    V.assert(#motion.cubes==0 and motion.score.shown==300,'blocks arrive and displayed score finishes')
    motion:Kill('QA second',true,nil,nil,l,function() return .5 end);V.assert(motion.score.target==600 and motion.streak==2,'source chain kill carries display points')
    motion:Clear();V.assert(#motion.cubes==0 and #motion.hits==0 and not motion.score,'clear retires transient UI')
    local audio=Audio.New(scene);audio.focus=function() return true end;audio:SetActive(true)
    for _,id in ipairs({'hit_tick','break_tick','kill_confirm','part_restore','repair_done','respawn','shield_hit','shield_down'}) do
        audio.time=audio.time+2;V.assert(audio:Play(id,1,0),'decoded source WAV '..id)
    end
    for _=1,40 do audio.time=audio.time+.25;audio:Play('hit_tick') end;V.assert(#audio.voices<=10,'source transient audio voices bounded')
    local unit={alive=true,env={time=0},hp=.5,Position=function() return {0,0,0} end,Health=function(self) return self.hp end}
    audio:Consume({{type='unitHealed',unit=unit}},unit)
    V.assert(audio.loop and audio.loop.playing and Near(audio.loop.frequency,audio.sounds.repair_loop:GetFrequency()*Mix.Rate(.5)),'real repair event starts pitched loop')
    local gain=audio.loop.gain;unit.hp=.9;unit.env.time=.1;audio:Consume({{type='unitHealed',unit=unit}},unit)
    V.assert(audio.loop.gain>gain and audio.loop.frequency>audio.sounds.repair_loop:GetFrequency(),'more health raises repair gain and pitch')
    unit.env.time=.56;audio:Consume({},unit);V.assert(not audio.loop.playing,'repair stops after source 450ms bridge')
    local event={type='unitKilled',unit=unit};audio:Consume({event},unit);audio:Consume({event},unit)
    V.assert(#audio.pending==1,'damage events consumed once')
    audio:SetActive(false);V.assert(#audio.pending==0 and not audio.loop.playing,'pause discards delayed explosions and repair')
    audio:SetActive(true);audio.focus=function() return false end
    V.assert(not audio:Hit('hit'),'background cannot play confirmation');audio:Dispose()
    V.assert(audio.disposed and #audio.voices==0,'feedback sound ownership released')
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;Logic(app.scene);V.assert(app:EnterTrial('trial'),'production loader includes feedback dependencies');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then
        trial=app.trial;trial.pointer.captured=true;trial.feedbackAudio.focus=function() return true end;trial:Tick(1/60,{})
        local fresh={bp={Size=function() return 17 end}}
        trial.hud.overlay:Consume({{type='unitSpawn',unit=fresh}})
        V.assert(trial.hud.overlay.partCounts[fresh]==17,'later spawned targets retain first-hit part baseline')
        fresh.bp.Size=function() return 23 end
        trial.hud.overlay:Consume({{type='unitSpawn',unit=fresh}})
        V.assert(trial.hud.overlay.partCounts[fresh]==23,'respawn refreshes the part baseline')
        local unit=trial.world.units[1];local core=unit.bp:CoreParts()[1]
        unit:Damage(core.id,1,unit:Position());unit:Heal(.01)
        local damaged,healed=false,false
        for _,e in ipairs(trial.world.viewEvents) do if e.unit==unit then damaged=damaged or e.type=='unitDamaged';healed=healed or e.type=='unitHealed' end end
        V.assert(damaged and healed,'real CarUnit emits damage and actual healing events')
        trial:Tick(1/60,{});V.assert((trial.feedbackAudio.counts.hit_tick or 0)>0,'production damage metrics play local hit confirmation')
        local world=trial.world;local damage=world.stats.damage;world.feedbackPlayer=unit
        unit:Damage(core.id,1,unit:Position());V.assert(world.stats.damage==damage,'received damage cannot become player damage credit')
        local other=world.units[2];world.attacker=unit;other:Damage(other.bp:CoreParts()[1].id,1,other:Position());world.attacker=nil
        V.assert(world.stats.damage>damage,'player source receives real damage credit');world.feedbackPlayer=nil
        trial:Pause();V.assert(not trial.feedbackAudio:Audible() and #trial.feedbackAudio.pending==0,'actual session pause stops feedback')
        app:Reload();stage='return'
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then
        V.assert(trial.feedbackAudio.disposed,'actual return disposes feedback audio');stage='done';V.finish()
    end
end
for i=40,650 do V.atFrame(i,Poll) end
V.atFrame(655,function() V.assert(stage=='done','combat feedback lifecycle completed: '..stage);V.finish() end)
