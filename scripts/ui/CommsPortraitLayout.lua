-- Frozen storyHud.css image boxes and HoloPortrait bottom-aligned contain fit.
local M={}
function M.Rect(who)
    if who=='huhu' then return {x=-3,y=-16,w=156,h=195} end
    if who=='boss' then return {x=-4,y=2,w=158,h=196} end
    return {x=-70,y=-2,w=330,h=410}
end
function M.Fit(width,height,imageWidth,imageHeight)
    local box=width/height;local aspect=imageWidth/imageHeight
    local sx=aspect>box and 1 or aspect/box
    local sy=aspect>box and box/aspect or 1
    return sx,sy,(1-sx)/2,0
end
function M.Contain(rect,imageWidth,imageHeight,top)
    local scale=math.min(rect.w/imageWidth,rect.h/imageHeight)
    local width,height=imageWidth*scale,imageHeight*scale
    return {x=rect.x+(rect.w-width)/2,y=rect.y+(top and 0 or rect.h-height),w=width,h=height}
end
function M.Emblem(height)
    local width,availableHeight=106,height-84
    local scale=math.min(width,availableHeight)/64
    return 22+(width-64*scale)/2,30+(availableHeight-64*scale)/2,scale
end
return M
