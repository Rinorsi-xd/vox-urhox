-- QA only. Route allocation samples without changing ray arithmetic or results.
local M={}
function M.Install(probe,ray,math3)
    local originalCast=assert(ray.Cast);local depth=0;local restored=false
    local routes={cold=originalCast,warm=originalCast};local replacements={}
    local tokenMeta={__close=function()depth=depth-1 end};local tokens={}
    for i=1,128 do tokens[i]=setmetatable({},tokenMeta) end
    probe:Wrap(routes,'cold','gcRay.coldBounds')
    probe:Wrap(routes,'warm','gcRay.cachedBounds')
    local names={'Add','Sub','Scale','Normalize','Cross','Array','Vec','Inverse','RotateUnit',
        'QMul','Rotate','Unrotate','Turret','Mix','Reject','Jitter'}
    for _,name in ipairs(names)do
        local original=assert(math3[name],name)
        local route={call=original};probe:Wrap(route,'call','gcRay.math.'..name)
        local replacement=function(...)
            if depth>0 then return route.call(...) end
            return original(...)
        end
        math3[name]=replacement
        replacements[#replacements+1]={name=name,original=original,replacement=replacement}
    end
    local routed=function(vehicle,...)
        assert(depth<128,'Ray observer nesting limit');depth=depth+1
        local guard <close> = tokens[depth]
        if vehicle.rayBounds then return routes.warm(vehicle,...) end
        return routes.cold(vehicle,...)
    end
    ray.Cast=routed;probe:Wrap(ray,'Cast','gcRay.Cast')
    local originalRestore=probe.Restore
    function probe:Restore()
        originalRestore(self)
        if restored then return end
        assert(depth==0,'Ray observer did not unwind')
        assert(ray.Cast==routed,'Ray observer restoration ownership changed')
        ray.Cast=originalCast
        for _,item in ipairs(replacements)do
            assert(math3[item.name]==item.replacement,'Math observer restoration ownership changed')
            math3[item.name]=item.original
        end
        restored=true
    end
    return {Restored=function()return restored end,Depth=function()return depth end}
end
return M
