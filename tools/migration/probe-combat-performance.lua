-- QA-only inclusive CPU timings; never substitutes simulation or resource results.
local totals={}
local seen=setmetatable({},{__mode='k'})
local phase='boot'
local suspended=setmetatable({},{__mode='k'})
local rawYield=coroutine.yield
function coroutine.yield(...)
    local thread=coroutine.running();local start=Time:GetSystemTime()
    local values=table.pack(rawYield(...))
    suspended[thread]=(suspended[thread] or 0)+Time:GetSystemTime()-start
    return table.unpack(values,1,values.n)
end
local function Wrap(object,key,label)
    if not object or type(object[key])~='function' then return end
    local keys=seen[object]
    if not keys then keys={};seen[object]=keys end
    if keys[key]==object[key] then return end
    local original=object[key]
    local function measured(...)
        local thread=coroutine.running();local paused=suspended[thread] or 0
        local start=Time:GetSystemTime()
        local a,b,c,d=original(...)
        local elapsed=Time:GetSystemTime()-start-((suspended[thread] or 0)-paused)
        local id=phase..':'..label
        local stat=totals[id]
        if not stat then stat={calls=0,totalMs=0,maxMs=0,over16=0,over100=0};totals[id]=stat end
        stat.calls=stat.calls+1;stat.totalMs=stat.totalMs+elapsed
        stat.maxMs=math.max(stat.maxMs,elapsed)
        if elapsed>=16 then stat.over16=stat.over16+1 end
        if elapsed>=100 then stat.over100=stat.over100+1 end
        if elapsed>=50 then print('COMBAT_SLOW '..cjson.encode({phase=phase,label=label,ms=elapsed,at=start})) end
        return a,b,c,d
    end
    object[key]=measured;keys[key]=measured
end
local targets={
 ['combat.CarUnit']={'Flush','Spawn','Build','Explode'},
 ['construction.Blueprint']={'Graph','Connectivity'},
 ['construction.Rotors']={'Spec'},
 ['construction.TurretRange']={'For'},
 ['drive.VehicleSpec']={'Build','BuildParts','MergeBoxes'},
 ['drive.Vehicle']={'New'},
 ['drive.RaySuspension']={'Sample','Apply'},
 ['drive.ContactControl']={'Step'},
 ['drive.HoverControl']={'Step','Motion'},
 ['drive.ThrusterControl']={'Step'},
 ['drive.ChassisStability']={'Step'},
 ['drive.LegControl']={'Step'},
 ['drive.LegHitboxes']={'Update'},
 ['drive.MechControl']={'Step'},
 ['drive.MechHitboxes']={'Update'},
 ['combat.EnemyDriverThink']={'Run','Sniper','Route'},
 ['combat.EnemyDriverNav']={'Graph','Nearest','Path','Direct'},
 ['physics.Space']={'Raycast','Step'},
 ['render.CombatView']={'Consume','Update'},
 ['render.CombatEffects']={'New','Consume','Update'},
 ['render.SceneWarmup']={'New','Step'},
 ['render.MissileView']={'New'},
 ['render.Chip']={'Emit'},
 ['app.TrialSession']={'New','Activate','Tick','Update','PostUpdate','Dispose'},
 ['app.SceneLoader']={'Update','Commit'},
 ['render.GraphicsSettings']={'Update','PostUpdate'},
}
local rawRequire=require
function require(name)
    local result,loader=rawRequire(name)
    local methods=targets[name]
    if methods and type(result)=='table' then
        for _,method in ipairs(methods) do Wrap(result,method,name..'.'..method) end
    end
    return result,loader
end
local function Count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local update=HandleUpdate
function HandleUpdate(et,ed)
    local app=VOX_HANGAR and VOX_HANGAR.app or VOX_TRIAL and VOX_TRIAL.app
    if app then
        phase=app.loadingFlow.active and ('loading:'..tostring(app.loadingFlow.map and app.loadingFlow.map.id))
            or app.trial and (app.trial.map.id..':'..(app.trial.battle and app.trial.battle.rules.state or app.trial.story and tostring(app.trial.story.rules.step) or 'drive'))
            or 'hangar'
        Wrap(app,'Update','app.Update');Wrap(app,'PostUpdate','app.PostUpdate')
        Wrap(app.graphicsSettings,'Update','graphics.Update');Wrap(app.graphicsSettings,'PostUpdate','graphics.PostUpdate')
        Wrap(app.loader,'Update','loader.Update');Wrap(app.previews,'Update','previews.Update')
        local s=app.trial
        if s then
            Wrap(s.combat,'BeforeStep','actors.BeforeStep');Wrap(s.combat,'AfterStep','actors.AfterStep')
            Wrap(s.world,'Step','world.Step');Wrap(s.world,'CastRay','world.CastRay')
            Wrap(s.view,'Update','playerView.Update');Wrap(s.environment,'Update','environment.Update')
            for _,entry in ipairs(s.combat and s.combat.entries or {}) do
                Wrap(entry.driver,'Step','enemyDriver.Step');Wrap(entry.unit.vehicle,'Step','vehicle.Step')
                Wrap(entry.unit.weapons,'Step','weapons.Step')
            end
        end
    end
    update(et,ed)
    if app and input:GetKeyPress(KEY_F8) then
        local s=app.trial
        local residency={phase=phase,appScene=tostring(app.scene),trialScene=s and tostring(s.scene),
            hangar=app.hangar~=nil,opening=app.opening~=nil and app.opening.active==true,
            mapPreview=app.mapPreview~=nil,build=app.build~=nil,loader=app.loader.state,
            pendingScene=app.loader.pending~=nil,pendingRelease=app.pendingAssetRelease~=nil,
            worldUnits=s and #s.world.units or 0,physicsBodies=s and Count(s.world.space.bodies) or 0,
            fixedSteps=s and s.fixedSteps,droppedTime=s and s.droppedTime,
            batches=renderer.numBatches,primitives=renderer.numPrimitives,
            cacheBytes=cache:GetTotalMemoryUse(),luaKiB=collectgarbage('count')}
        print('COMBAT_PROFILE '..cjson.encode({timings=totals,residency=residency}))
    end
end
