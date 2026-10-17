-- Six direct BeforeStep children only; outside calls retain the original path.
function M.PrepareBeforeStep()
    assert(M.prepared and not M.enabled and identity.beforeStepPipeline==true and identity.presentationPipeline==true)
    local wanted={
        {'drive.Vehicle','Step','before.Vehicle'},
        {'combat.EnemyDriver','Step','before.Driver'},
        {'combat.WeaponSystem','Step','before.Weapons'},
        {'combat.BattleController','Pick','before.Pick'},
        {'combat.CarUnit','Flush','before.Flush'},
        {'combat.CarUnit','RegenerateStructure','before.Regenerate'},
    }
    for _,item in ipairs(wanted) do
        local owner=require(item[1]);local key,name=item[2],item[3]
        assert(type(owner[key])=='function','Missing BeforeStep boundary '..name)
        local original=owner[key]
        Wrap(owner,key,name)
        local measured=owner[key]
        owner[key]=function(...)
            if M.enabled and #stack>0 and stack[#stack].name=='fixed.BeforeStep' then return measured(...) end
            return original(...)
        end
    end
end
