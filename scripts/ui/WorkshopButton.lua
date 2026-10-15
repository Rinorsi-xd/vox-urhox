local Base=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Button=Base:Extend('VoxWorkshopSourceButton')
local Motion=require 'ui.SourceButtonMotion'
function Button:Update(dt)
    if self.props.sourceKind~='tab' then return end
    if not self.tabMotion then
        local initial=self.props.selected and 1 or 0
        self.tabMotion={line={value=initial,start=initial,target=initial,elapsed=0,duration=0},color={value=initial,start=initial,target=initial,elapsed=0,duration=0}}
    end
    Motion.Step(self.tabMotion.line,self.props.selected and 1 or 0,.25,dt,false)
    Motion.Step(self.tabMotion.color,(self.props.selected or self.state.hovered) and 1 or 0,.15,dt,'ease')
end
function Button:GetShelfContent(vg)
    local kind=self.props.sourceKind
    if kind~='ghost' and kind~='all' then return nil end
    local r=self:GetAbsoluteLayout()
    -- Final .wsh-sh span overrides the button's font and color.
    return {size=11,spacing=4,color=D.orange,x=kind=='all' and 20 or 37,y=(r.h-14)/2,
        width=vg and D.Width(vg,self.props.text,11,nil,4) or nil,
        count=kind=='all' and {x=90,y=(r.h-18)/2,w=29.140625,h=18,size=13,spacing=3} or nil,
        arrow=kind=='all' and {x=r.w-32,y=(r.h-18)/2,w=18,h=18} or nil}
end
function Button:GetTabContent(vg)
    if self.props.sourceKind~='tab' then return nil end
    local size=self.props.sourceFontSize or 19
    local width=D.Width(vg,self.props.text,size,nil,2)
    return {size=size,spacing=2,x=16,y=10,width=width,
        count={x=16+width+4,y=10,size=11,width=D.Width(vg,self.props.count,11,'vox-display')}}
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local x,y,w,h=r.x,r.y,r.w,r.h
    local kind=p.sourceKind;local c=D.white
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.45) end
    if kind=='tab' or kind=='sort' then
        c=(p.selected or self.state.hovered) and D.white or {219,238,255,kind=='sort' and 115 or 128}
        if kind=='tab' and self.tabMotion then
            local t=self.tabMotion.color.value;c={219+36*t,238+17*t,255,128+127*t}
        end
        if kind=='sort' and p.separator then D.Text(vg,'/',x,y+8,13,{255,255,255,77},nil,nil,1) end
        local tab=self:GetTabContent(vg)
        if tab then
            D.Text(vg,p.text,x+tab.x,y+tab.y,tab.size,c,nil,nil,tab.spacing,false,math.floor(tab.size+.5)+math.floor(tab.size*.2+.5))
            local countColor={c[1],c[2],c[3],math.floor(c[4]*.7+.5)}
            D.Text(vg,p.count,x+tab.count.x,y+tab.count.y,11,countColor,'vox-display',nil,0,false,13)
        else D.Text(vg,p.text,x+12,y+8,13,c,nil,nil,nil,nil,nil,p.selected and require('ui.WorkshopPaint').textShadows.sort or nil) end
        if kind=='tab' then
            local scale=self.tabMotion and self.tabMotion.line.value or 0
            if scale>0 then
                local length=(w-28)*scale;local left=x+(w-length)/2;local top=y+h-5
                local skew=math.tan(math.pi/6)*1.5
                local points={left+skew,top,left+length+skew,top,left+length-skew,top+3,left-skew,top+3}
                nvgBeginPath(vg);nvgRect(vg,left-18,top-18,length+36,39)
                nvgFillPaint(vg,nvgBoxGradient(vg,left,top,length,3,0,12,nvgRGBA(122,216,255,204),nvgRGBA(122,216,255,0)));nvgFill(vg)
                D.Path(vg,points);nvgFillColor(vg,D.Color(D.orange));nvgFill(vg)
            end
        end
    else
        if kind=='view' or kind=='all' or kind=='go' then Relief.Draw(vg,x,y,w,h,true,false,{x,y,x+w-14,y,x+w,y+14,x+w,y+h,x,y+h})
        elseif kind=='back' then Relief.Draw(vg,x,y,w,h,false,false,{x,y,x+w,y,x+w,y+h-14,x+w-14,y+h,x,y+h})
        elseif kind=='control' then
            c=p.selected and D.ink or {219,238,255,153}
            if p.selected then D.Rect(vg,x,y,w,h,D.orange) end
        elseif kind=='add' or kind=='ghost' or kind=='pager' then
            local cut=kind=='ghost' and 10 or kind=='pager' and 0 or 14
            D.Path(vg,{x,y,x+w,y,x+w,y+h-cut,x+w-cut,y+h,x,y+h});nvgFillColor(vg,nvgRGBA(8,15,28,kind=='ghost' and 140 or 153));nvgFill(vg)
            local edge=kind=='add' and {219,238,255,89} or {122,216,255,77}
            D.Rect(vg,x,y,w,1,edge);D.Rect(vg,x,y,1,h,edge)
            D.Rect(vg,x+w-1,y,1,h-cut,edge);D.Rect(vg,x,y+h-1,w-cut,1,edge)
        end
        if self.state.hovered and not p.disabled then D.Rect(vg,x,y,w,h,{255,255,255,24}) end
        if kind=='view' then
            D.Icon(vg,'eye',x+20,y+18,28);D.Text(vg,p.text,x+62,y+10,22,{255,255,255,255},nil,nil,3);D.Text(vg,'实景 3D 预览',x+62,y+39,12,{237,246,255,191},'vox-body')
        elseif kind=='go' then
            D.Rect(vg,x,y,70,h,{8,15,28,64});D.Icon(vg,'plus',x+20,y+20,30)
            D.Text(vg,p.text,x+88,y+11,26,nil,nil,nil,4);D.Text(vg,'现有的车不受影响',x+88,y+44,12,{237,246,255,179},'vox-body')
            local kw=D.Width(vg,'Enter',11)+18;local kx=x+w-20-kw;local ky=y+(h-22)/2
            D.Rect(vg,kx,ky,kw,22,{8,15,28,89})
            D.Line(vg,kx,ky,kx+kw,ky,{255,255,255,89});D.Line(vg,kx,ky+22,kx+kw,ky+22,{255,255,255,89})
            D.Line(vg,kx,ky,kx,ky+22,{255,255,255,89});D.Line(vg,kx+kw,ky,kx+kw,ky+22,{255,255,255,89})
            D.Text(vg,'Enter',kx+9,ky+4,11,{255,255,255,255})
        else
            local size=kind=='add' and 16 or kind=='all' and 16 or kind=='control' and 13 or 14
            local icon=(kind=='add' or kind=='back') and 18 or 17;local ix=x+(kind=='all' and 20 or kind=='add' and 22 or kind=='back' and 14 or 12)
            if kind=='pager' then
                nvgSave(vg);nvgTranslate(vg,x+w/2,y+h/2);nvgRotate(vg,math.rad(p.iconRotation));D.Icon(vg,'chev',-12,-12,24);nvgRestore(vg)
                nvgRestore(vg);return
            end
            if p.icon then D.Icon(vg,p.icon,ix,y+(h-icon)/2,icon,kind=='ghost' and D.orange or c) end
            local tx=ix+(p.icon and icon+8 or 0)
            local shelf=self:GetShelfContent(vg)
            if shelf then
                D.Text(vg,p.text or '',x+shelf.x,y+shelf.y,shelf.size,shelf.color,nil,nil,shelf.spacing,false,14)
            else
                D.Text(vg,p.text or '',tx,y+(h-size*1.2)/2,size,kind=='add' and {255,255,255,255} or c,nil,nil,kind=='add' and 2 or 1)
            end
            if shelf and shelf.count then
                local box=shelf.count
                D.Rect(vg,x+box.x,y+box.y,box.w,box.h,{255,255,255,255})
                D.Text(vg,p.count,x+box.x+7,y+box.y+1,box.size,D.ink,'vox-tabular',nil,box.spacing,false,16)
            end
            if shelf and shelf.arrow then
                local box=shelf.arrow
                nvgSave(vg);nvgTranslate(vg,x+box.x+box.w/2,y+box.y+box.h/2);nvgRotate(vg,-math.pi/2);D.Icon(vg,'chev',-9,-9,18);nvgRestore(vg)
            end
        end
    end
    nvgRestore(vg)
end
return Button
