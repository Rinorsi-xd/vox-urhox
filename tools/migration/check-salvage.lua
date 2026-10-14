local stage='boot';local app=nil ---@type HangarApp|nil
local work=nil ---@type thread|nil
local Loot=require 'salvage.Loot'
local Rules=require 'salvage.RunRules'
local GP=require('core.ResourceData').Read('Salvage/Gameplay.json')
local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local function AudioLogic(scene)
    local sound=require('audio.SalvageAudio').New(scene);sound.focus=function() return true end
    V.assert(not sound:Event({type='reveal',item={r=4}}),'inactive salvage does not play or queue reveal')
    sound:SetActive(true)
    for r=0,5 do
        local id='reveal'..r;local sample=sound.sounds[id]
        V.assert(sample:GetFrequency()==48000 and sample.sixteenBit and not sample.stereo,'source mono PCM decode '..id)
        V.assert(sound:Event({type='reveal',item={r=r}}) and sound.counts[id]==1,'source rarity event routes '..id)
    end
    V.assert(sound:Event({type='suspense'}) and sound.counts.suspense==1,'production suspense routes original heartbeat')
    V.assert(#sound.voices==4,'bursts retain four reusable voices')
    V.assert(not sound:Event({type='noise'}),'world noise does not create a loot sound')
    local function Stopped() for _,source in ipairs(sound.voices) do if source.playing then return false end end;return true end
    sound:SetActive(false);V.assert(Stopped(),'pause immediately stops all reveal tails')
    sound:SetActive(true);sound:Event({type='reveal',item={r=5}})
    V.assert(sound.voices[1].frequency==48000 and math.abs(sound.voices[1].gain-.6)<.001,'native voice uses original pitch and default effects volume')
    sound.focus=function() return false end;sound:SetActive(true)
    V.assert(Stopped() and not sound:Event({type='suspense'}),'focus loss stops playback and rejects stale sound')
    sound.focus=function() return true end;sound.volume=0
    V.assert(not sound:Event({type='suspense'}),'zero effects volume suppresses reveals')
    sound:Dispose();sound:Dispose();V.assert(sound.disposed and next(sound.voices)==nil and next(sound.sounds)==nil,'disposal releases voices and is idempotent')
    V.assert(not sound:Event({type='suspense'}),'disposed audio cannot replay')
end
local function Logic()
    dofile('tools/migration/check-salvage-cine.lua').Fixtures()
    local f=assert(io.open('tools/migration/source-salvage-fixtures.json'));local fixtures=cjson.decode(f:read('*a'));f:close()
    for i,c in ipairs(fixtures.cases) do local at=0;local state={red=0}
        local result=Loot.Roll(c.kind,function() at=at+1;return assert(c.values[at],'unexpected RNG use '..i) end,state,c.op,nil)
        V.assert(#result==#c.result and state.red==c.red and at==#c.values,'source roll size/RNG/red '..i)
        for j,item in ipairs(result) do local want=c.result[j]
            V.assert(item.id==want.id and item.n==want.n and item.r==want.r and item.t==want.t,'source roll item '..i..':'..j)
        end
    end
    for i,c in ipairs(fixtures.slots) do
        V.assert(Loot.Used(c.cargo)==c.used and Loot.Mass(c.cargo)==c.mass and Loot.Room(c.cargo,c.id,c.n)==c.room,'source cargo '..i)
    end
    local function State(o) return {alive=true,pos=o.g,speed=0,width=5,hold=false} end
    local r=Rules.New(GP,Data.ops[1],function() return .4 end)
    local o;for _,it in ipairs(r.objects) do if it.ctype=='supply' then o=it;break end end
    local s=State(o);s.tap=true;r:Step(.1,s);V.assert(r.search and r.search.i==1,'E opens actual source crate')
    s.tap=false;r:Step(.2,s);local progress=r.search.p
    s.pos={o.g[1]+100,o.g[2],o.g[3]};r:Step(.1,s);V.assert(not r.search,'leaving closes search')
    s.pos=o.g;s.tap=true;r:Step(.1,s);V.assert(r.search.p==progress,'reopen retains partial search')
    s.tap=false;for _=1,100 do r:Step(.1,s) end;V.assert(r.opened[o.id] and Loot.Used(r.cargo)>0,'real crate reveals and fills cargo')
    local v;for _,it in ipairs(r.objects) do if it.ctype=='vault' then v=it;break end end
    s=State(v);s.tap=true;r:Step(.1,s);s.tap=false;s.hold=true
    for _=1,81 do r:Step(.1,s) end;V.assert(r.search.crack>=8 and r.heat>0,'stationary hold cracks vault and raises heat')
    for i,e in ipairs(r.extracts) do
        local run=Rules.New(GP,Data.ops[1],function() return .4 end);local exit=run.extracts[i];run.time=(exit.openAt or 0)+1
        if exit.needs then run.cargo[exit.needs]=1 end
        local s=State(exit);s.width=3
        for _=1,math.ceil(exit.wait*10)+2 do run:Step(.1,s) end
        local found=false;for _,event in ipairs(run:Drain()) do if event.type=='extracted' then found=true end end
        V.assert(run.finished and found,'actual extraction rule '..e.id)
    end
    local dead=Rules.New(GP,Data.ops[1]);dead:Step(.1,{alive=false});V.assert(dead.finished and dead:Drain()[1].type=='failed','death ends run')
    local expired=Rules.New(GP,Data.ops[1]);expired.time=899.99;expired:Step(.02,State(o));V.assert(expired.finished,'time limit ends run')
    local Motion=require 'ui.SourceButtonMotion';local button={props={},state={hovered=true}}
    Motion.UpdateCTA(button,.18);V.assert(button.sourceMotion.x.value==-2 and button.sourceMotion.y.value==-3,'source CTA hover position')
    button.state.pressed=true;Motion.UpdateCTA(button,.06);V.assert(button.sourceMotion.x.value==3 and button.sourceMotion.y.value==4,'source CTA press position')
end
local function Exercise(s)
    local update=s.Update;s.Update=function() end
    V.assert(s.salvage.begun and s.combat==s.salvage and s.hud.salvage~=nil,'production loading begins salvage and attaches HUD')
    local run=s.salvage;local before=run.rules.time
    dofile('tools/migration/check-salvage-cine.lua').Drop(s);before=run.rules.time
    run.audio.focus=function() return true end
    s.pointer.captured=true
    for i=1,120 do s:Tick(1/60,{throttle=0,steer=0});if i%20==0 then coroutine.yield() end end
    V.assert(run.rules.time>before+1.9 and s.vehicle.body.translation().y> -100,'production physics and clock run')
    local o;for _,it in ipairs(run.rules.objects) do if it.ctype=='supply' then o=it;break end end
    s.vehicle:Place({o.g[1],o.g[2]+2,o.g[3]},0);s.view:ResetPose();s:HandleKey(KEY_E)
    s:Tick(1/60,{throttle=0,steer=0});V.assert(run.rules.search~=nil,'session E routes to search')
    for i=1,480 do s:Tick(1/60,{throttle=0,steer=0});if i%30==0 then coroutine.yield() end end
    V.assert(Loot.Used(run.rules.cargo)>0,'production search adds loot')
    local reveals=0;for id,n in pairs(run.audio.counts) do if id:match('^reveal') then reveals=reveals+n end end
    V.assert(reveals>0 and #run.audio.voices<=4,'real search events play decoded reveal audio')
    s:Pause();local stopped=true;for _,source in ipairs(run.audio.voices) do if source.playing then stopped=false end end
    V.assert(stopped and not run.audio.active,'real session pause stops loot voices')
    _G.VOX_QA_SALVAGE_AUDIO=run.audio
    local stash=app.salvageLobby;local data=stash.data;local save=stash.Save;stash.Save=function() return false,'injected write failure' end
    dofile('tools/migration/check-salvage-cine.lua').Extraction(s)
    V.assert(not run.committed and stash.data==data and run.saveError~=nil,'failed persistence rolls back and retains result')
    stash.Save=save;V.assert(run:Commit(),'retry commits extraction')
    local raids=stash.data.stats.raids;V.assert(run:Commit() and stash.data.stats.raids==raids,'retry never commits twice')
    V.assert(run:Return(),'committed result permits return')
    s.hud.Update(s,0);V.assert(s.dialog~=nil,'completed run opens result overlay')
    local keyPressed,hasFocus=s.KeyPressed,s.HasFocus
    s.KeyPressed=function(_,key) return key==KEY_RETURN end;s.HasFocus=function() return true end
    s:PollKeys(false);s.KeyPressed=keyPressed;s.HasFocus=hasFocus
    V.assert(s.wantsReturn,'Enter reaches return gate while result overlay is open')
    s.Update=update;stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app;Logic();AudioLogic(app.scene);V.assert(app.bays:Save(1),'validation draft saved before lobby switch');require('ui.GarageHud').GetState().SetLobby('salvage');stage='warehouse'
    elseif stage=='warehouse' and app.warehouse and app.warehouse.ready then
        V.assert(app.warehouse.effects.uploads==1 and #app.warehouse.effectData.dust.positions==900,'warehouse dust uploads once')
        V.assert(app:EnterTrial('salvage'),'production salvage entry');stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then
        work=coroutine.create(function() Exercise(app.trial) end);stage='exercise'
    elseif stage=='exercise' then
        local ok,err=coroutine.resume(work);if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active then
        V.assert(VOX_QA_SALVAGE_AUDIO.disposed and not next(VOX_QA_SALVAGE_AUDIO.voices),'return disposes production salvage sound sources')
        V.assert(app.lobby=='salvage','return preserves salvage lobby');stage='done';V.finish()
    end
end
for i=45,1950 do V.atFrame(i,Poll) end
V.atFrame(1955,function() V.assert(stage=='done','salvage lifecycle completed '..stage);V.finish() end)
