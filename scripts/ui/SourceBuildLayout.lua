-- Source style.css desktop breakpoint. This remains a single landscape dock.
local M={}
function M.ForWidth(width)
    local compact=width<=1440
    local tool=compact and 42 or 46
    local slot=compact and 48 or 54
    local toggles=compact and 128 or 140
    local tools=tool*5+16
    local hotbar=slot*10+36
    local paint=compact and 268 or 311
    local paintToggles=toggles
    -- Frozen DOM: 1353px dock; its color label overflows the nominal row by 3px.
    local dock=tools+hotbar+paint+toggles+80
    return {tool=tool,slot=slot,thumbnail=compact and 38 or 42,toggles=toggles,paintToggles=paintToggles,tools=tools,
        hotbar=hotbar,paint=paint,dock=dock,paintDock=dock+58,
        nameWidth=compact and 280 or 360,nameSize=compact and 28 or 34}
end
return M
