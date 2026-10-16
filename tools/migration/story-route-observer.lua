-- Explicit QA route mode: preserve decisions and memory counters, omit UI audits.
function G0_StoryRouteState(data)
    local out={observationMode='story-route'}
    for _,key in ipairs({'mode','map','width','height','touch','loadingFlow','sceneVisible',
        'pointer','camera','vehicle','widgets','aimTargets','wing','story'}) do out[key]=data[key] end
    local original=data.performance or {}
    local performance={}
    for _,key in ipairs({'luaKiB','resourceBytes','api','desktop','modelBytes','arrayBytes',
        'texture2DBytes','imageBytes','materialBytes','xmlBytes','soundBytes','jsonBytes',
        'retiredTargets','batches','primitives','fixedSteps','droppedSeconds','focus','minimized',
        'ambience','lifecycle','battleObjects','battleTiming'}) do
        performance[key]=original[key]
    end
    if original.battleTiming and original.battleTiming.enabled then
        performance.updateTiming={}
        for label,sample in pairs(original.updateTiming or {}) do
            if label:sub(1,7)=='battle.' then performance.updateTiming[label]=sample end
        end
    end
    out.performance=performance
    return out
end
