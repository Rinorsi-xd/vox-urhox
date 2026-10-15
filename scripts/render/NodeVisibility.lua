-- UrhoX components only inspect their immediate node, so hide the whole subtree.
-- Keep the mask here: repeated engine recursive writes replace its saved mask.
local M={}
local states=setmetatable({},{__mode='k'})
function M.Set(node,on,enforceHidden)
    on=on==true
    local state=states[node]
    if state and state.on==on then
        -- Animated parts may write their own visibility after the initial mask.
        if not on and enforceHidden then
            for _,child in ipairs(node:GetChildren(true)) do
                if state.mask[child]==nil then state.mask[child]=child.enabled end
            end
            node:SetEnabledRecursive(false)
        end
        return
    end
    if on then
        -- Rebuilds can dispose old children; restore only nodes still present.
        if state and state.mask then for _,child in ipairs(node:GetChildren(true)) do
            local enabled=state.mask[child];if enabled~=nil then child.enabled=enabled end
        end end
        node.enabled=true;states[node]={on=true}
    else
        local mask={};for _,child in ipairs(node:GetChildren(true)) do mask[child]=child.enabled end
        states[node]={on=false,mask=mask};node:SetEnabledRecursive(false)
    end
end
return M
