-- Decode downloaded sounds before constructing players; checkpoint can yield.
local M={}
local modules={'audio.WeaponAudio','audio.DrivingAudio','audio.CombatFeedbackAudio'}
function M.Prepare(checkpoint)
    local paths,seen={},{}
    for _,name in ipairs(modules) do
        for _,path in ipairs(require(name).Dependencies()) do
            if not seen[path] then seen[path]=true;paths[#paths+1]=path end
        end
    end
    for i,path in ipairs(paths) do
        assert(cache:GetResource('Sound',path),'Cannot prepare sound: '..path)
        if checkpoint then checkpoint(i/#paths,'audio-resources') end
    end
    return #paths
end
return M
