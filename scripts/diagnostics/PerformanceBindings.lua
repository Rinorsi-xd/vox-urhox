-- Wall-duration attribution only: nested labels overlap and are not additive.
-- Attach after BeginFrame; constructors and per-ray calls stay uninstrumented.
local CollectionCycle=require 'core.CollectionCycle'
local M={}
local groups={}
local function Group(prefix,names)
    local out={}
    for name in names:gmatch('%S+') do out[#out+1]={name,prefix..'.'..name} end
    groups[prefix]=out
end
Group('app','Update PostUpdate AdvanceOpeningRetirements ReleaseSettledAssets')
Group('gc','Step Collect Restore')
Group('loader','Update ReadScene Commit EnvironmentReady')
Group('loading','Advance Observe Rendered FramePresented PrepareScene Close')
Group('sceneWarmup','Rendered')
Group('combatWarmup','Presented')
Group('graphics','Update PostUpdate')
Group('preview','Update')
Group('opening','Update Camera')
Group('trial','Update Tick PostUpdate ConsumeWorldEvents Aim')
Group('world','Step Explode Hit')
Group('physics','Step')
Group('debris','Advance CapturePoses')
Group('combat','Update BeforeStep AfterStep SyncPlayer Events')
Group('objectives','PlaceCart UnitTick Update')
Group('rules','Step')
Group('unit','Step Flush Build RegenerateStructure RestoreMissing Destroy Die Explode')
Group('vehicle','Step StepRotors ApplyRotors PostStep SyncDrillPose')
Group('weapons','Step')
Group('drill','Step')
Group('ai','Step')
Group('suspension','Sample Apply')
Group('legs','Step')
Group('legHitboxes','Update')
Group('mech','Step')
Group('mechHitboxes','Update')
Group('playerView','Update SavePose')
Group('combatView','Consume SavePose Update')
Group('vehicleView','UpdateIdle UpdateWeaponEffects SyncBlueprint AddPart RemovePart')
Group('effects','Consume Update')
Group('chips','Update Break')
Group('missiles','Update')
Group('environment','Update')
Group('camera','Pose')
Group('aimLines','Update')
Group('boundary','Update')
Group('weaponAudio','Update Consume')
Group('drivingAudio','Update Observe')
Group('feedbackAudio','Update Consume')
Group('collisionAudio','BeforeStep AfterStep')
Group('voice','Update')
Group('battleSounds','Update')
Group('hud','Update')
Group('hudOverlay','Update Consume')
Group('storyView','Update')
Group('storyExplosion','Update')

-- These are already Vehicle/LegControl/TrialSession dependencies. Resolve them
-- only after a vehicle exists, once per Lua state, without loading new systems.
local vehicleModules={
    {'drive.ContactControl','Step','contact.Step'},
    {'drive.ChassisStability','Step','stability.Step'},
    {'drive.HoverControl','Step','hover.Step'},
    {'drive.HoverControl','Motion','hover.Motion'},
    {'drive.ThrusterControl','Step','thrusters.Step'},
    {'drive.WingControl','Step','wings.Step'},
    {'drive.LegGait','Step','legGait.Step'},
    {'render.WeaponView','Update','weaponView.Update'},
}
local loadedModules=false
local function Bind(monitor,object,prefix)
    if type(object)~='table' then return end
    for _,item in ipairs(groups[prefix]) do monitor:Wrap(object,item[1],item[2]) end
end
local function Class(monitor,object,prefix)
    if type(object)~='table' then return end
    local mt=getmetatable(object)
    local methods=type(mt)=='table' and mt.__index
    Bind(monitor,type(methods)=='table' and methods or object,prefix)
end
local function Vehicle(monitor,vehicle)
    if not vehicle then return end
    Class(monitor,vehicle,'vehicle')
    Class(monitor,vehicle.suspension,'suspension')
    Class(monitor,vehicle.legControl,'legs')
    Class(monitor,vehicle.legHitboxes,'legHitboxes')
    Class(monitor,vehicle.mechControl,'mech')
    Class(monitor,vehicle.mechHitboxes,'mechHitboxes')
    if not loadedModules then
        for _,entry in ipairs(vehicleModules) do entry.module=require(entry[1]) end
        loadedModules=true
    end
    for _,entry in ipairs(vehicleModules) do monitor:Wrap(entry.module,entry[2],entry[3]) end
end
local function View(monitor,view)
    if not view then return end
    Class(monitor,view,'playerView')
    Class(monitor,view.view,'vehicleView')
end

function M.Attach(monitor,app)
    if not monitor or not app then return end
    Bind(monitor,CollectionCycle,'gc')
    Class(monitor,app,'app')
    Class(monitor,app.loader,'loader')
    Class(monitor,app.loadingFlow,'loading')
    local flow=app.loadingFlow
    if flow then
        Class(monitor,flow.renderWarmup,'sceneWarmup')
        Class(monitor,flow.combatWarmup,'combatWarmup')
    end
    Class(monitor,app.graphicsSettings,'graphics')
    Class(monitor,app.previews,'preview')
    Class(monitor,app.opening,'opening')
    local trial=app.trial
    if not trial or trial.disposed then return end
    Class(monitor,trial,'trial')
    local world=trial.world
    if world then
        Class(monitor,world,'world')
        Class(monitor,world.space,'physics')
        Class(monitor,world.debris,'debris')
        for _,unit in ipairs(world.units or {}) do
            Class(monitor,unit,'unit')
            Vehicle(monitor,unit.vehicle)
            Class(monitor,unit.weapons,'weapons')
            if unit.weapons then Class(monitor,unit.weapons.drill,'drill') end
        end
    end
    Vehicle(monitor,trial.vehicle)
    Class(monitor,trial.combat,'combat')
    if trial.combat then
        Class(monitor,trial.combat.objectives,'objectives')
        Class(monitor,trial.combat.rules,'rules')
        Class(monitor,trial.combat.voice,'voice')
        Class(monitor,trial.combat.sounds,'battleSounds')
        for _,entry in ipairs(trial.combat.entries or {}) do Class(monitor,entry.driver,'ai') end
    end
    if trial.story then
        Class(monitor,trial.story.view,'storyView')
        Class(monitor,trial.story.explosion,'storyExplosion')
    end
    View(monitor,trial.view)
    Class(monitor,trial.combatView,'combatView')
    if trial.combatView then
        for _,view in pairs(trial.combatView.units or {}) do View(monitor,view) end
    end
    Class(monitor,trial.effects,'effects')
    if trial.effects then
        Class(monitor,trial.effects.chips,'chips')
        Class(monitor,trial.effects.missiles,'missiles')
    end
    Class(monitor,trial.environment,'environment')
    Class(monitor,trial.chase,'camera')
    Class(monitor,trial.aimLines,'aimLines')
    Class(monitor,trial.boundary,'boundary')
    Class(monitor,trial.weaponAudio,'weaponAudio')
    Class(monitor,trial.drivingAudio,'drivingAudio')
    Class(monitor,trial.feedbackAudio,'feedbackAudio')
    Class(monitor,trial.collisionAudio,'collisionAudio')
    Bind(monitor,trial.hud,'hud')
    if trial.hud then Class(monitor,trial.hud.overlay,'hudOverlay') end
end

local bodySamples=setmetatable({},{__mode='k'})
local function BodyCount(space,now)
    if not space or not space.bodies then return nil end
    local sample=bodySamples[space]
    if not sample or ((now-sample.at)&0xffffffff)>=1000 then
        local count=0;for _ in pairs(space.bodies) do count=count+1 end
        sample={count=count,at=now};bodySamples[space]=sample
    end
    return sample.count,((now-sample.at)&0xffffffff)
end
local function Length(value) return type(value)=='table' and #value or 0 end
function M.Context(app)
    local trial=app and app.trial
    local flow=app and app.loadingFlow
    local loader=app and app.loader
    local world=trial and trial.world
    local fx=trial and trial.effects
    local story=trial and trial.story
    local rules=story and story.rules
    local units=world and world.units
    local vehicles,alive,parts,projectiles=0,0,0,0
    for _,unit in ipairs(units or {}) do
        if unit.alive then alive=alive+1 end
        if unit.vehicle and not unit.vehicle.disposed then vehicles=vehicles+1 end
        -- Count current simulation parts without blueprint List/Stats/Graph work.
        if unit.vehicle and unit.vehicle.spec then parts=parts+Length(unit.vehicle.spec.partIds) end
        projectiles=projectiles+Length(unit.weapons and unit.weapons.projectiles)
    end
    local bodyCount,bodyAge=BodyCount(world and world.space,Time:GetSystemTime())
    local loadingStep=flow and flow.steps and flow.steps[flow.current or 0]
    local warmup=flow and flow.combatWarmup
    local sceneWarmup=flow and flow.renderWarmup
    local gc=CollectionCycle.State()
    return {
        trialId=trial and tostring(trial),mode=app and app.mode,map=trial and trial.map and trial.map.id,
        story=story and story.level and story.level.id,storyStep=rules and rules.index,storyPhase=rules and rules.phase,
        matchState=trial and trial.battle and trial.battle.rules.state,
        loading=flow and flow.active or false,loadingPhase=flow and flow.phase,
        loaderPhase=loader and loader.phase,prepareStage=loader and loader.prepareStage,
        loadingStep=loadingStep and loadingStep.id,loadingStepState=loadingStep and loadingStep.state,
        warmupPhase=warmup and warmup.phase,warmupFrames=warmup and warmup.frames,
        warmupGroup=warmup and warmup.index,warmupGroups=warmup and Length(warmup.groups),
        sceneWarmupNext=sceneWarmup and sceneWarmup.next,
        sceneWarmupItems=sceneWarmup and Length(sceneWarmup.items),
        hangarRetained=app and app.hangar~=nil or false,
        openingActive=app and app.opening and app.opening.active or false,
        mapPreviewRetained=app and app.mapPreview~=nil or false,
        buildRetained=app and app.build~=nil or false,
        sceneIsTrial=app and trial and app.scene==trial.scene or false,
        gcEpoch=gc.epoch,gcActive=gc.active,gcStepping=gc.stepping,
        stepsTotal=trial and trial.fixedSteps or 0,accumulator=trial and trial.accumulator or 0,
        droppedTime=trial and trial.droppedTime or 0,
        units=Length(units),vehicles=vehicles,alive=alive,parts=parts,projectiles=projectiles,
        effects=Length(fx and fx.particles)+Length(fx and fx.smoke)+Length(fx and fx.beams)
            +Length(fx and fx.flares)+Length(fx and fx.rings)+Length(fx and fx.flashes)+Length(fx and fx.zaps),
        particles=Length(fx and fx.particles),smoke=Length(fx and fx.smoke),
        beams=Length(fx and fx.beams),flares=Length(fx and fx.flares),rings=Length(fx and fx.rings),
        debris=Length(world and world.debris and world.debris.pieces),
        physicsBodies=bodyCount,physicsBodiesAgeMs=bodyAge,
        batches=renderer:GetNumBatches(),primitives=renderer:GetNumPrimitives(),
        cacheBytes=cache:GetTotalMemoryUse(),backgroundResources=cache:GetNumBackgroundLoadResources(),
        luaKiB=collectgarbage('count'),
    }
end
return M
