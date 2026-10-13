-- Source matchHud's projected objective diamonds and mode progress.
local D=require 'ui.SourceDraw'
local Coord=require 'core.Coord'
local M={}
local blue={46,168,255,255};local red={255,74,61,255};local orange={255,106,19,255}
function M.Draw(vg,session,w,h)
    local b=session.battle;if b.mode=='elimination' then return end
    local r=b.rules;local camera=session.camera:GetCamera();local player=b.player:Position()
    local points=b.objectives.points or {{id='运输车',pos=b.objectives:At(r.s).pos}}
    for i,p in ipairs(points) do
        local point=Coord.Vec(p.pos[1],p.pos[2]+4,p.pos[3]);local uv=camera:WorldToScreenPoint(point)
        local localPoint=camera.node:WorldToLocal(point)
        local x,y=uv.x*w,uv.y*h;if localPoint.z<0 then x=w-x;y=h-y end
        x=math.max(40,math.min(w-40,x));y=math.max(130,math.min(h-190,y))
        local st=r.points and r.points[i];local c=st and (st.contested and orange or st.owner=='blue' and blue or st.owner=='red' and red) or D.white
        D.Path(vg,{x,y-18,x+18,y,x,y+18,x-18,y});nvgFillColor(vg,D.Color(c));nvgFill(vg)
        D.Text(vg,p.id,x,y-10,st and 19 or 12,{11,13,17,255},'vox-title',NVG_ALIGN_CENTER)
        local distance=math.sqrt((player[1]-p.pos[1])^2+(player[3]-p.pos[3])^2)
        D.Text(vg,math.floor(distance+.5)..' m',x,y+26,12,D.white,'vox-tabular',NVG_ALIGN_CENTER)
        if st then
            for j=1,3 do D.Rect(vg,x-20+(j-1)*15,y+47,11,4,math.abs(st.v)*3>=j and (st.v>=0 and blue or red) or {255,255,255,55}) end
            if b.player.alive and distance<16 and math.abs(player[2]-p.pos[2])<8 then
                D.Panel(vg,w/2-170,h*.7,340,72,12,{11,13,17,225})
                D.Text(vg,st.contested and '争夺中' or '占领 '..p.id,w/2,h*.7+12,22,D.white,'vox-title',NVG_ALIGN_CENTER)
                D.Rect(vg,w/2-148,h*.7+51,296,5,{255,255,255,30});D.Rect(vg,w/2-148,h*.7+51,296*math.abs(st.v),5,st.v>=0 and blue or red)
            end
        end
    end
    if b.mode=='escort' then
        local y=84;local width=330;local x=(w-width)/2
        D.Rect(vg,x,y,width,6,{255,255,255,30});D.Rect(vg,x,y,width*r.s/r.length,6,r.attack=='blue' and blue or red)
        for _,k in ipairs(b.objectives.tuning.checkpoints) do D.Rect(vg,x+width*k-1,y-3,2,12,D.white) end
        D.Text(vg,r.contested and '争夺中' or r.pushing>0 and '推进中' or r.idle>=8 and '回退中' or '等待推进',w/2,y+13,12,D.white,'vox-title',NVG_ALIGN_CENTER)
    end
end
return M
