-- Six direct Vehicle children; nested/outside calls retain the original path.
function M.PrepareVehicle()
    assert(M.prepared and not M.enabled and identity.vehiclePipeline==true and identity.beforeStepPipeline==true)
    local wanted={
        {'drive.RaySuspension','Sample','vehicle.Sample'},
        {'drive.RaySuspension','Apply','vehicle.Apply'},
        {'drive.LegControl','Step','vehicle.Legs'},
        {'drive.HoverControl','Step','vehicle.Hover'},
        {'drive.ContactControl','Step','vehicle.Contact'},
        {'drive.LegHitboxes','Update','vehicle.LegHitboxes'},
    }
    for _,item in ipairs(wanted) do
        local owner=require(item[1]);local key,name=item[2],item[3]
        assert(type(owner[key])=='function','Missing Vehicle boundary '..name)
        local original=owner[key]
        Wrap(owner,key,name)
        local measured=owner[key]
        owner[key]=function(...)
            if M.enabled and #stack>0 and stack[#stack].name=='before.Vehicle' then return measured(...) end
            return original(...)
        end
    end
end
