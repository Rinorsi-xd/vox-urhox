-- Injected only into the explicit trial-sections QA variant. No engine objects.
local trialSession=false
local trialHud=false
local instanceOwners={}
local instanceLabels={}
local instanceMethods={}
local function InstallTrialMethods()
    for _,entry in ipairs(TRIAL_METHODS) do
        local module=require(entry[1])
        for _,key in ipairs(entry[2]) do Wrap(module,key,entry[3]..'.'..key) end
    end
    assert(M.bindings==57+TRIAL_MODULE_BINDINGS,'Unique base and trial module bindings')
end
local function BindTrialInstances(app)
    local trial=assert(app and app.trial,'Trial profile needs an active session')
    local hud=assert(trial.hud,'Trial profile needs the activated HUD')
    local mode=assert(trial.battle and hud.match or trial.story and hud.story,'Trial profile supports match or story HUD')
    local owners={hud,assert(hud.readouts),hud.readouts,mode,assert(hud.sniper)}
    local keys={'Update','Tick','Refresh','Update','Update'}
    if trialSession then
        assert(trialSession==trial and trialHud==hud,'Trial profile session/HUD changed during sampling')
        for i,owner in ipairs(owners) do
            assert(instanceOwners[i]==owner,'Trial profile HUD child changed during sampling')
            assert(instanceMethods[i]==owner[keys[i]],'Trial profile HUD method changed during sampling')
        end
        return
    end
    trialSession=trial;trialHud=hud
    for i,owner in ipairs(owners) do
        Wrap(owner,keys[i],TRIAL_INSTANCE_LABELS[i])
        instanceOwners[i]=owner;instanceLabels[i]=TRIAL_INSTANCE_LABELS[i]
        instanceMethods[i]=owner[keys[i]]
    end
    assert(M.bindings==TRIAL_EXPECTED_BINDINGS,'Exact unique trial module and HUD bindings')
end
