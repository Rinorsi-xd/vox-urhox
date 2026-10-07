-- Source style.css desktop breakpoint. This remains a single landscape dock.
local M={}
function M.ForWidth(width)
    local compact=width<=1440
    local tool=compact and 54 or 62
    local slot=compact and 56 or 64
    local toggles=compact and 108 or 128
    local tools=tool*4+15
    local hotbar=slot*10+54
    local paint=40+52+24+tool*2
    -- In paint mode the shorter dock leaves room for the camera toggle's
    -- intrinsic text width; the build dock shrinks it to the CSS minimum.
    local paintToggles=compact and 122.09375 or toggles
    return {tool=tool,slot=slot,thumbnail=compact and 42 or 46,toggles=toggles,paintToggles=paintToggles,tools=tools,
        hotbar=hotbar,paint=paint,dock=tools+hotbar+toggles+32,paintDock=tools+paint+paintToggles+32,
        nameWidth=compact and 280 or 360,nameSize=compact and 28 or 34}
end
return M
