local Motion=require 'ui.SourceButtonMotion'
local M={ids={'scorpion','hawk','raceCar','megaMech','vanguard','tianyuan'}}
local function Tween(value)
    return {value=value,start=value,target=value,elapsed=0,duration=0}
end
function M.Ensure(ws)
    if ws.slides then return end
    ws.slides={}
    for _,id in ipairs(M.ids) do
        ws.slides[id]={alpha=Tween(id==ws.selected and 1 or 0),imageElapsed=0}
    end
end
function M.Select(s,id)
    local ws=s.workshop;M.Ensure(ws)
    if id~=ws.selected then
        for _,slide in pairs(ws.slides) do slide.imageElapsed=0 end
        ws.selected=id
    end
    ws.elapsed=0;s.revision=-1
end
function M.Step(s,dt)
    local ws=s.workshop;M.Ensure(ws)
    for id,slide in pairs(ws.slides) do
        local previous=slide.alpha.value
        Motion.Step(slide.alpha,id==ws.selected and 1 or 0,.9,dt,'ease')
        if id==ws.selected then slide.imageElapsed=slide.imageElapsed+dt end
        if previous>0 and slide.alpha.value==0 then
            require('urhox-libs/UI/Core/ImageCache').Release('UI/Prefabs/'..id..'.jpg')
        end
    end
end
function M.Keep(ws,keep)
    M.Ensure(ws)
    for id,slide in pairs(ws.slides) do
        if id==ws.selected or slide.alpha.value>0 then keep['UI/Prefabs/'..id..'.jpg']=true end
    end
end
function M.Render(vg,ws,x,y,w,h)
    local Paint=require 'ui.WorkshopPaint'
    -- CSS paints slides in markup order; deselected images return to scale(1.12).
    for _,id in ipairs(M.ids) do
        local slide=ws.slides[id];local alpha=slide.alpha.value
        if alpha>0 then
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
