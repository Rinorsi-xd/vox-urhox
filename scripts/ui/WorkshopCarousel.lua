local ImageCache=require("urhox-libs/UI/Core/ImageCache")
local WorkshopPaint=require("ui.WorkshopPaint")

local Motion=require 'ui.SourceButtonMotion'
local ResourceGate=require 'app.ResourceGate'
local M={ids=require('core.ResourceData').Read('UI/Workshop.json').featured}
local function Tween(value)
    return {value=value,start=value,target=value,elapsed=0,duration=0}
end
function M.Ensure(ws)
    ws.shelf=ws.shelf or {elapsed=0}
    if ws.slides then return end
    ws.slides={}
    ws.imagesReady={}
    ws.caption={elapsed=0,distance=30}
    ws.imageGate=ResourceGate.New()
    for _,id in ipairs(M.ids) do
        ws.slides[id]={alpha=Tween(id==ws.selected and 1 or 0),imageElapsed=0}
    end
end
function M.Select(s,id)
    local ws=s.workshop;M.Ensure(ws)
    if ws.pending==id then return end
    ws.pending=id
    -- Commit text and image together only when the actual artwork is local.
    ws.imageGate:Start({'UI/Prefabs/'..id..'.jpg'},function(ok,err)
        if ws.pending~=id then return end
        ws.pending=nil
        if not ok then
            if s.message then s.message:SetText(err) end
            return
        end
        local repeatSelection=ws.imagesReady[id] and id==ws.selected
        ws.imagesReady[id]=true
        if id~=ws.selected then
            for _,slide in pairs(ws.slides) do slide.imageElapsed=0 end
            ws.selected=id
            ws.caption={elapsed=0,distance=24}
        elseif repeatSelection then
            ws.caption={elapsed=0,distance=24}
        end
        ws.elapsed=0;s.revision=-1
    end)
end
function M.Mount(s)
    local ws=s.workshop;M.Ensure(ws)
    if not ws.imagesReady[ws.selected] and not ws.pending then M.Select(s,ws.selected) end
end
function M.Leave(ws)
    if not ws then return end
    if ws.imageGate then ws.imageGate:Cancel() end
    ws.imageGate=nil;ws.pending=nil;ws.imagesReady=nil;ws.slides=nil;ws.caption=nil;ws.shelf=nil
end
function M.Target(ws)
    return ws.pending or ws.selected
end
function M.Ready(ws,id)
    return ws.imagesReady and ws.imagesReady[id]==true
end
function M.Step(s,dt)
    local ws=s.workshop;M.Ensure(ws)
    ws.caption.elapsed=math.min(.46,ws.caption.elapsed+math.max(0,dt))
    ws.shelf.elapsed=math.min(.62,ws.shelf.elapsed+math.max(0,dt))
    for id,slide in pairs(ws.slides) do
        local previous=slide.alpha.value
        Motion.Step(slide.alpha,id==ws.selected and 1 or 0,.9,dt,'ease')
        if id==ws.selected and M.Ready(ws,id) then slide.imageElapsed=slide.imageElapsed+dt end
        if previous>0 and slide.alpha.value==0 then
            ImageCache.Release('UI/Prefabs/'..id..'.jpg')
        end
    end
end
-- Frozen motion.js: six siblings, 40ms stagger, 260ms (.16,1,.3,1).
function M.Caption(ws,index)
    if not ws.caption then return 1,0 end
    local delay=math.min(index-1,16)*.04
    if ws.caption.elapsed>=delay+.26 then return 1,0 end
    local progress=math.max(0,math.min(1,(ws.caption.elapsed-delay)/.26))
    local alpha=Motion.Ease(progress,false)
    return alpha,-ws.caption.distance*(1-alpha)
end
-- Frozen feature view: header actions precede row cards in DOM order.
function M.Shelf(ws,index)
    if not ws.shelf then return 1,0 end
    local delay=.12+math.min(index-1,16)*.03
    if ws.shelf.elapsed>=delay+.26 then return 1,0 end
    local progress=math.max(0,math.min(1,(ws.shelf.elapsed-delay)/.26))
    local alpha=Motion.Ease(progress,false)
    return alpha,20*(1-alpha)
end
function M.Keep(ws,keep)
    M.Ensure(ws)
    for id,slide in pairs(ws.slides) do
        if id==ws.selected or id==ws.pending or slide.alpha.value>0 then keep['UI/Prefabs/'..id..'.jpg']=true end
    end
end
function M.Render(vg,ws,x,y,w,h)
    local Paint=WorkshopPaint
    -- CSS paints slides in markup order; deselected images return to scale(1.12).
    for _,id in ipairs(M.ids) do
        local slide=ws.slides[id];local alpha=slide.alpha.value
        if alpha>0 and M.Ready(ws,id) then
            local ken=id==ws.selected and Motion.Ease(math.min(1,slide.imageElapsed/9),'css-ease-out') or 1
            local zoom=1.22-.1*ken;local translate=.02*(1-ken)
            local imageX=x+w*.24+w*.76*.5*(1-zoom)+w*.76*translate*zoom
            local imageY=y+h*.5*(1-zoom)
            local bounds={imageX,imageY,imageX+w*.76*zoom,imageY,imageX+w*.76*zoom,imageY+h*zoom,imageX,imageY+h*zoom}
            nvgSave(vg);nvgGlobalAlpha(vg,alpha)
            Paint.Image(vg,'UI/Prefabs/'..id..'.jpg',{x=x+w*.24,y=y,w=w*.76,h=h},zoom,.58,bounds,nil,.5,translate)
            nvgRestore(vg)
        end
    end
end
return M
