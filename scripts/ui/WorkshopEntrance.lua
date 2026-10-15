-- Frozen workshop.js enter() groups and workshop.css wsdFill keyframes.
local Motion=require 'ui.SourceButtonMotion'
local M={}
function M.Start(ws,kind)
    ws.entrance={kind=kind,elapsed=0}
end
function M.Step(ws,dt)
    local entry=ws.entrance
    if entry then entry.elapsed=math.min(entry.kind=='detail' and .9 or entry.kind=='grid' and .82 or .74,entry.elapsed+math.max(0,dt)) end
end
function M.Group(ws,index)
    local entry=ws.entrance
    if not entry then return 1,0,0 end
    local detail=entry.kind=='detail'
    if entry.kind=='grid' then
        if index<=4 then return 1,0,0 end
        index=index-4
    end
    local delay=math.min(index-1,16)*(detail and .04 or entry.kind=='grid' and .035 or .03)
    if entry.elapsed>=delay+.26 then return 1,0,0 end
    local alpha=Motion.Ease(math.max(0,math.min(1,(entry.elapsed-delay)/.26)),false)
    if detail then return alpha,-30*(1-alpha),0 end
    return alpha,0,(entry.kind=='grid' and 18 or 22)*(1-alpha)
end
function M.Fill(ws)
    local entry=ws.entrance
    if not entry or entry.kind~='detail' then return 1 end
    return Motion.Ease(math.min(1,entry.elapsed/.9),false)
end
return M
