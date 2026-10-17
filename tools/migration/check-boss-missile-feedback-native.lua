-- Controlled actual-scene consumer check; root owns running the Runtime.
local app=nil ---@type HangarApp|nil
local stage='boot'
local function Exercise(session)
    local mission=session.story
    local update=session.Update
    session.Update=function() end
    mission.voice:Hide()
    mission.rules:Go(2);mission:Events()
    local boss=mission.boss
    V.assert(boss~=nil,'production fifth objective creates Boss')
    boss.pending={};boss.missiles={};boss.raid=nil
    boss.rules:Go('fight');boss.flow.stage='fight'
    local function Impact(offset,trauma)
        local pos=mission.player:Position()
        local at={pos[1]+offset,pos[2]+1.2,pos[3]}
        local before=mission.rules.stats.missileHits or 0
        session.trauma=trauma
        boss:AddMissile(at,at,at,1,7.5,5,false)
        boss:Projectiles(1)
        return (mission.rules.stats.missileHits or 0)-before,session.trauma
    end
    local hits,trauma=Impact(0,0)
    V.assert(hits==1,'real player inside real Boss explosion passes physical line of sight')
    V.assert(math.abs(trauma-.35)<1e-9,'real Boss projectile consumer adds authored .35 impact')
    hits,trauma=Impact(0,.8)
    V.assert(hits==1 and math.abs(trauma-.8)<1e-9,'real Boss projectile preserves stronger existing impact')
    hits,trauma=Impact(50,0)
    V.assert(hits==0 and trauma==0,'far actual Boss projectile does not shake player camera')
    V.assert(#boss.missiles==0,'all actual test missiles retire through production consumer')
    V.assert(boss.step.lines.outside==nil,'frozen authored script has no outside cue; no invented voice')
    session.Update=update
    app:Reload();stage='return'
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app
        V.assert(app:EnterTrial('story5'),'actual fifth mission enters production loading flow')
        stage='loading'
    elseif stage=='loading' and app.trial and not app.loadingFlow.active then
        local ok,err=pcall(Exercise,app.trial)
        if not ok then V.assert(false,tostring(err));stage='failed';V.finish() end
    elseif stage=='return' and not app.trial and not app.loadingFlow.active and not app.pendingAssetRelease then
        stage='done';V.assert(true,'actual scene returns through normal release flow');V.finish()
    end
end
for frame=40,1400 do V.atFrame(frame,Poll) end
V.atFrame(1405,function() V.assert(stage=='done','Boss missile feedback controlled lifecycle');V.finish() end)
