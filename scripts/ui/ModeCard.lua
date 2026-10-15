local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Card=UI.Panel:Extend('VoxSourceModeCard')
function Card:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.item
    local selected=self.owner.modeChoice==p.id;local hover=self.state.hovered
    local story=p.id=='story';local accent=story and {70,200,255,255} or D.orange
    local x,y,w,h=r.x,r.y-(selected and 6 or 0),r.w,r.h
    local points={x,y,x+w-22,y,x+w,y+22,x+w,y+h,x+22,y+h,x,y+h-22}
    local state=p.id=='story' and (hover and 'story-hover' or 'story') or selected and 'selected' or hover and 'hover' or 'idle'
    local zoom=1.08*(selected and 1.08 or hover and 1.06 or 1)
    Paint.Image(vg,'UI/Modes/Filtered/'..(p.art or p.id)..'-'..state..'.jpg',{x=x,y=y,w=w,h=h},zoom,p.bias or .5,points,nil,p.focus)
    local stops={{0,.3,{8,9,12,38},{8,9,12,0}},{.3,.72,{8,9,12,0},{8,9,12,217}},{.72,1,{8,9,12,217},{8,9,12,247}}}
    if story then
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h*.75)
        for gy=0,math.floor(h*.75/22) do
            D.Rect(vg,x,y+gy*22,w,1,{70,200,255,18*(1-gy*22/(h*.75))})
        end
        for gx=0,math.floor(w/22) do
            nvgBeginPath(vg);nvgRect(vg,x+gx*22,y,1,h*.75)
            D.Gradient(vg,x,y,1,h*.75,{70,200,255,18},{70,200,255,0})
        end
        nvgRestore(vg)
    end
    for _,stop in ipairs(stops) do
        nvgSave(vg);nvgIntersectScissor(vg,x,y+h*stop[1],w,h*(stop[2]-stop[1]))
        D.Path(vg,points);D.Gradient(vg,x,y+h*stop[1],w,h*(stop[2]-stop[1]),stop[3],stop[4]);nvgRestore(vg)
    end
    local edge=story and {70,200,255,115} or selected and D.orange or {255,255,255,20};local thickness=selected and 3 or 1
    D.Rect(vg,x,y,w-22,thickness,edge);D.Rect(vg,x,y,thickness,h-22,edge)
    D.Rect(vg,x+w-thickness,y+22,thickness,h-22,edge);D.Rect(vg,x+22,y+h-thickness,w-22,thickness,edge)
    if selected then D.Rect(vg,x,y,w-22,5,D.orange) end
    if p.no then
        D.Text(vg,p.no,x+20,y+16,46,selected and {155,215,250,192} or {255,255,255,41},'vox-tabular')
        local tag=p.size..'V'..p.size;local tw=D.Width(vg,tag,18,'vox-tabular')+20
        D.Rect(vg,x+w-28-tw,y+18,tw,27,selected and D.orange or D.white)
        D.Text(vg,tag,x+w-18-tw,y+22,18,D.ink,'vox-tabular')
    end
    local footY=y+h-(self.wide and 68 or 156.92);local fx=x+22
    local is= self.wide and 34 or 40;local iy=footY+(self.wide and 18 or 0)
    D.Path(vg,{fx+is*.25,iy,fx+is*.75,iy,fx+is,iy+is*.5,fx+is*.75,iy+is,fx+is*.25,iy+is,fx,iy+is*.5})
    nvgFillColor(vg,D.Color((selected or story) and accent or {255,255,255,26}));nvgFill(vg)
    D.Icon(vg,p.icon,fx+(is-22)*.5,iy+(is-22)*.5,22,story and {4,18,31,255} or selected and D.ink or D.white)
    local ty=footY+(self.wide and 0 or 50)
    D.Text(vg,p.en,fx,ty,13,accent,story and 'vox-legacy-display' or nil,nil,5)
    local nameSize=self.wide and 30 or 46;local nameFont=story and 'vox-legacy-display' or nil
    D.Text(vg,p.name,fx+(self.wide and 46 or 0),footY+(self.wide and 21.4 or 70),nameSize,story and {244,245,247,255} or nil,nameFont,nil,1,false,nameSize*1.02)
    local text=p.sub or ''
    local sy=self.wide and y+h-32 or footY+120.92
    local sx=self.wide and fx+46+D.Width(vg,p.name,30,nameFont,1)+12 or fx
    local sw=x+w-22-sx
    if sw>12 then
        local size=13
        if D.Width(vg,text,size,'vox-body')>sw then
            local short=''
            for _,cp in utf8.codes(text) do
                local nextText=short..utf8.char(cp)
                if D.Width(vg,nextText..'…',size,'vox-body')>sw then break end;short=nextText
            end
            text=short..'…'
        end
        D.Text(vg,text,sx,sy,size,story and {154,160,170,255} or D.muted,'vox-body')
    end
    if p.id=='story' then
        local badge='第一章 · 5 关';local badgeWidth=D.Width(vg,badge,11,'vox-body',2)+16
        D.Rect(vg,x+w-14-badgeWidth,y+12,badgeWidth,20,accent);D.Text(vg,badge,x+w-6-badgeWidth,y+15,11,{4,18,31,255},'vox-body',nil,2)
    end
end
return Card
