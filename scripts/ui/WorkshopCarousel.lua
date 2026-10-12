local Motion=require 'ui.SourceButtonMotion'
local ResourceGate=require 'app.ResourceGate'
local M={ids=require('core.ResourceData').Read('UI/Workshop.json').featured}
local function Tween(value)
    return {value=value,start=value,target=value,elapsed=0,duration=0}
end
function M.Ensure(ws)
    if ws.slides then return end
    ws.slides={}
    ws.imagesReady={}
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
        ws.imagesReady[id]=true
        if id~=ws.selected then
            for _,slide in pairs(ws.slides) do slide.imageElapsed=0 end
            ws.selected=id
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
    ws.imageGate=nil;ws.pending=nil;ws.imagesReady=nil;ws.slides=nil
end
function M.Target(ws)
    return ws.pending or ws.selected
end
function M.Ready(ws,id)
    return ws.imagesReady and ws.imagesReady[id]==true
end
function M.Step(s,dt)
    local ws=s.workshop;M.Ensure(ws)
    for id,slide in pairs(ws.slides) do
        local previous=slide.alpha.value
        Motion.Step(slide.alpha,id==ws.selected and 1 or 0,.9,dt,'ease')
        if id==ws.selected and M.Ready(ws,id) then slide.imageElapsed=slide.imageElapsed+dt end
        if previous>0 and slide.alpha.value==0 then
            require('urhox-libs/UI/Core/ImageCache').Release('UI/Prefabs/'..id..'.jpg')
        end
    end
end
function M.Keep(ws,keep)
    M.Ensure(ws)
    for id,slide in pairs(ws.slides) do
        if id==ws.selected or id==ws.pending or slide.alpha.value>0 then keep['UI/Prefabs/'..id..'.jpg']=true end
    end
end
function M.Render(vg,ws,x,y,w,h)
    local Paint=require 'ui.WorkshopPaint'
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
