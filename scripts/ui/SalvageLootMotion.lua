-- Frozen srh-fly, srh-jack and srh-jban timelines, inside the existing UI frame.
local D=require 'ui.SourceDraw'
local Items=require('core.ResourceData').Read('UI/Outgame.json').items
local M={}
function M.Event(run,event)
    local now=run.rules.time
    if event.type=='suspense' then run.lootPulse={at=now,rarity=event.rarity,suspense=true}
    elseif event.type=='cargoPickup' and (event.swap or event.worldBatch) then
        run.lootFlights=run.lootFlights or {}
        for i=1,math.min(6,#event.items) do
            run.lootFlights[#run.lootFlights+1]={id=event.items[i][1],at=now+(event.worldBatch and .26+(i-1)*.11 or 0)}
        end
    elseif event.type=='reveal' and not event.worldBatch then
        local item=event.item
        if item.r>=4 then run.lootPulse={at=now,rarity=item.r,id=item.id} end
        if (event.taken or item.n)>0 then
            run.lootFlights=run.lootFlights or {}
            run.lootFlights[#run.lootFlights+1]={id=item.id,at=now+.12,row=run.rules.search and run.rules.search.i-1}
        end
    end
end
function M.Draw(run,vg,w,h,icon,slots)
    local now=run.rules.time
    for i=#(run.lootFlights or {}),1,-1 do local flight=run.lootFlights[i];local age=now-flight.at
        if age>.42 then table.remove(run.lootFlights,i)
        elseif age>=0 then
            local t=require('ui.SourceButtonMotion').Ease(age/.42,'fly')
            local fromX,fromY=w/2,h*.62
            if flight.row then fromX=w-303;fromY=h*.22+65+(flight.row-1)*49 end
            local target=slots[flight.id] or {x=w-422,y=h-126}
            local dx,dy=target.x+18-fromX,target.y+18-fromY
            local x,y=fromX+dx*t,fromY+dy*t-70*math.sin(math.pi*t)
            local size=40*(1.15-.45*t);local it=Items[flight.id]
            icon(vg,it,x-size/2,y-size/2,size,D.white)
        end
    end
    local pulse=run.lootPulse;if not pulse then return end
    local age=now-pulse.at;local red=pulse.rarity>=5;local c=red and {255,59,59,255} or {255,178,30,255}
    if age<1.6 then
        local t=age/1.6;local alpha=t<.12 and t/.12 or t<.4 and 1-(t-.12)/.28 or t<.52 and (t-.4)/.12 or 1-(t-.52)/.48
        nvgSave(vg);nvgTranslate(vg,w/2,h/2);nvgScale(vg,w*1.2,h*.9)
        nvgBeginPath(vg);nvgRect(vg,-1,-1,2,2)
        nvgFillPaint(vg,nvgRadialGradient(vg,0,0,.55,1.3,nvgRGBA(c[1],c[2],c[3],0),nvgRGBA(c[1],c[2],c[3],math.floor(alpha*(pulse.suspense and 85 or 255)))))
        nvgFill(vg);nvgRestore(vg)
    end
    if not pulse.id or age>=3.2 then return end
    local opacity=math.min(1,age/.32,(3.2-age)/.64)
    local scale=1+.4*(1-require('ui.SourceButtonMotion').Ease(math.min(1,age/.32),false))
    nvgSave(vg);nvgGlobalAlpha(vg,opacity);nvgTranslate(vg,w/2,h*.17+35);nvgScale(vg,scale,scale)
    D.Rect(vg,-250,-12,500,112,{0,0,0,160})
    D.Text(vg,red and '绝 品 · LEGENDARY' or '传 说',0,-8,14,c,'vox-story',NVG_ALIGN_CENTER)
    D.Text(vg,Items[pulse.id].name,0,17,46,D.white,'vox-story',NVG_ALIGN_CENTER)
    D.Text(vg,'价值 '..D.Number(Items[pulse.id].price)..' 信用点',0,74,16,{255,224,160,255},'vox-story',NVG_ALIGN_CENTER)
    nvgRestore(vg)
end
return M
