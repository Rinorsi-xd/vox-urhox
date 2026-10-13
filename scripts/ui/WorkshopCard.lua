-- Frozen workshop.css card geometry and pointer transitions.
local Button=require 'urhox-libs/UI/Widgets/Button'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Motion=require 'ui.SourceButtonMotion'
local Card=Button:Extend('VoxWorkshopCard')
local function Tween() return {value=0,start=0,target=0,elapsed=0,duration=0} end
function Card:Init(props)
    props.padding=0;props.minWidth=0;props.minHeight=0
    Button.Init(self,props)
    self.cardMotion={lift=Tween(),image=Tween(),filter=Tween(),sweep=Tween(),reveal=Tween(),opacity=Tween(),button=Tween()}
end
function Card:Update(dt)
    local target=self.state.hovered and 1 or 0;local m=self.cardMotion
    Motion.Step(m.lift,target,.3,dt,false)
    Motion.Step(m.image,target,.6,dt,false)
    Motion.Step(m.filter,target,.3,dt,'ease')
    if target==0 then m.sweep=Tween() else Motion.Step(m.sweep,1,.8,dt,'ease') end
    Motion.Step(m.reveal,target,.3,dt,'ease')
    Motion.Step(m.opacity,target,.2,dt,'ease')
    Motion.Step(m.button,target,.25,dt,'ease')
end
local function PolygonFade(vg,points,x,y,w,h,a,b)
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h);D.Path(vg,points)
    D.Gradient(vg,x,y,w,h,a,b);nvgRestore(vg)
end
function Card:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.item
    local tier=self.tier;local c=Paint.colors[tier];local m=self.cardMotion
    local x,y,w,h=r.x,r.y-3*m.lift.value,r.w,r.h
    local points={x,y,x+w-22,y,x+w,y+22,x+w,y+h,x+22,y+h,x,y+h-22}
    local zoom=self.hero and 1.12+.08*m.image.value or 1.32+.1*m.image.value
    D.Path(vg,points);nvgFillColor(vg,nvgRGBA(8,18,31,255));nvgFill(vg)
    Paint.Image(vg,'UI/Prefabs/Filtered/card-'..p.id..'.jpg',{x=x,y=y,w=w,h=h},zoom,.62,points)
    if m.filter.value>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,m.filter.value)
        Paint.Image(vg,'UI/Prefabs/Filtered/hover-'..p.id..'.jpg',{x=x,y=y,w=w,h=h},zoom,.62,points)
        nvgRestore(vg)
    end
    Paint.Radial(vg,points,x+w*.5,y+h*1.2,w*1.2,h*.8,{c[1],c[2],c[3],89},.6)
    PolygonFade(vg,points,x,y,w,h*.3,{c[1],c[2],c[3],56},{c[1],c[2],c[3],0})
    PolygonFade(vg,points,x,y+h*.38,w,h*.28,{4,9,18,0},{4,9,18,140})
    PolygonFade(vg,points,x,y+h*.66,w,h*.34,{4,9,18,140},{4,9,18,245})
    -- CSS inset shadows sit below the opaque positioned image, so no visible outline.
    D.Rect(vg,x,y,w-22,3,c)
    if m.sweep.value>0 and m.sweep.value<1 then Paint.Sweep(vg,points,x,y,w,h,m.sweep.value) end
    local badgeY=y+(self.mini and 10 or 14);local badgeSize=self.mini and 13 or 15
    local badgePad=self.mini and 10 or 12;local tierText='T'..tier
    local label=require('Config').TIERS[tier].name:gsub('^T%d%s*','')
    local numberWidth=D.Width(vg,tierText,badgeSize,'vox-tabular')
    local badgeWidth=badgePad+numberWidth+(self.mini and 12 or 22+D.Width(vg,label,12,nil,2))
    local badgeHeight=self.mini and 21.6 or 26
    D.Path(vg,{x,badgeY,x+badgeWidth,badgeY,x+badgeWidth-10,badgeY+badgeHeight,x,badgeY+badgeHeight});nvgFillColor(vg,D.Color(c));nvgFill(vg)
    D.Text(vg,tierText,x+badgePad,badgeY+(self.mini and 3 or 4),badgeSize,{10,15,24,255},'vox-tabular')
    if not self.mini then D.Text(vg,label,x+badgePad+numberWidth+6,badgeY+7,12,{10,15,24,255},nil,nil,2) end
    if self.hero then
        local fw=24+D.Width(vg,'主打推荐',13,nil,3);local fx=x+w-30-fw
        D.Rect(vg,fx,y+14,fw,26,{255,180,60,255})
        nvgSave(vg);nvgIntersectScissor(vg,fx,y+14,fw,26)
        for offset=-26,fw,16 do
            D.Path(vg,{fx+offset,y+40,fx+offset+8,y+40,fx+offset+34,y+14,fx+offset+26,y+14});nvgFillColor(vg,nvgRGBA(255,207,106,255));nvgFill(vg)
        end
        nvgRestore(vg);D.Text(vg,'主打推荐',fx+12,y+19,13,{26,18,5,255},nil,nil,3)
    end
    local tx=x+(self.hero and 30 or 16)
    local size=self.hero and (self.heroTitleSize or 46) or self.mini and 17 or 21;local titleHeight=size*1.2
    local barHeight=self.hero and 62 or self.mini and 0 or 50*m.reveal.value
    local titleY=y+h-(self.hero and 26+16 or self.mini and 14 or 14+8)-barHeight-titleHeight
    D.Text(vg,p.kind,tx,titleY-(self.hero and 22 or 17),self.hero and 14 or 12,c,nil,nil,2)
    D.Text(vg,p.name,tx,titleY,size,nil,nil,nil,self.hero and 2 or 1,false,titleHeight)
    if not self.mini and (self.hero or m.opacity.value>0) then
        local barY=titleY+titleHeight+(self.hero and 16 or 8)
        local column=self.hero and 46 or 38;local length=self.hero and 254 or 182
        nvgSave(vg);nvgIntersectScissor(vg,tx,barY,300,barHeight)
        if not self.hero then nvgGlobalAlpha(vg,m.opacity.value) end
        self.bars=self.bars or Paint.Bars(p.id)
        for i,b in ipairs(self.bars) do
            local yy=barY+(i-1)*(self.hero and 23 or 18)
            D.Text(vg,b[1],tx,yy,self.hero and 13 or 11,{219,238,255,179},'vox-body')
            local filled=length*math.min(1,b[3]);local thickness=self.hero and 6 or 4
            D.Rect(vg,tx+column,yy+5,length,thickness,{255,255,255,31})
            if filled>0 then
                nvgBeginPath(vg);nvgRect(vg,tx+column-8,yy-3,filled+16,thickness+16)
                nvgFillPaint(vg,nvgBoxGradient(vg,tx+column,yy+5,filled,thickness,0,8,nvgRGBA(c[1],c[2],c[3],179),nvgRGBA(c[1],c[2],c[3],0)));nvgFill(vg)
                D.Rect(vg,tx+column,yy+5,filled,thickness,c)
            end
        end
        nvgRestore(vg)
    end
    if m.opacity.value>0 then
        local bw=49+D.Width(vg,'查看',13,nil,2);local bx=x+w-26-bw+8*(1-m.button.value)
        nvgSave(vg);nvgGlobalAlpha(vg,m.opacity.value)
        D.Rect(vg,bx,y+h-47,bw,31,c);D.Icon(vg,'eye',bx+14,y+h-40,15,{10,15,24,255})
        D.Text(vg,'查看',bx+35,y+h-40,13,{10,15,24,255},nil,nil,2)
        nvgRestore(vg)
    end
end
return Card
