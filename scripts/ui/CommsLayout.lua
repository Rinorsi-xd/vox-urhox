-- Source homeViewport + storyHud compact factor, in the caller's UI units.
-- The UI frame already owns DPR; never multiply it into the canvas again.
local M={}
function M.Scale(width,height,compact)
    local reference=compact and 600 or 1080
    return math.min(width/(reference*16/9),height/reference)*(compact and .62 or 1)
end
function M.Compact(touch,width,height,dpr)
    return touch and math.min(width,height)/math.max(1,dpr)<=600
end
return M
