local M={}
function M.Compute(spec)
    local wheel,hover,leg=0,0,0
    for _,w in ipairs(spec.wheels) do wheel=wheel+w.load end
    for _,h in ipairs(spec.hovers) do if h.works then hover=hover+h.load end end
    for _,l in ipairs(spec.legs) do if l.works then leg=leg+l.load end end
    local total=wheel+hover+leg
    return {wheelLoad=wheel,hoverLoad=hover,legLoad=leg,totalLoad=total,
        wheelShare=total>0 and wheel/total or 0,hoverShare=total>0 and hover/total or 0,legShare=total>0 and leg/total or 0,
        hoverMode=hover>0 and hover>=wheel and hover>leg,legMode=leg>0 and leg>=wheel and leg>=hover}
end
function M.Falloff(speed,limit) return limit<=.01 and 0 or math.max(0,1-(math.max(0,speed)/limit)^3) end
return M
