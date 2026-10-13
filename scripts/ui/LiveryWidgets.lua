local D=require 'ui.SourceDraw'
local Relief=require 'ui.SourceRelief'
local Data=require 'construction.LiveryData'
local Button=require('urhox-libs/UI/Widgets/Button'):Extend('VoxLiveryButton')
local function Stroke(vg,x,y,w,h,color,line)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgStrokeWidth(vg,line or 1);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
end
function Button:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props;local s=self.owner;local session=s.session
    local x,y,w,h=r.x,r.y,r.w,r.h;local hover=self.state.hovered;local color=D.muted;local kind=p.kind
    nvgSave(vg);if p.disabled then nvgGlobalAlpha(vg,.4) end
    if kind=='group' then
        local on=s.group==p.group
        if on then Relief.Draw(vg,x,y,w,h,true,true,{x,y,x+w,y,x+w,y+h,x,y+h},true);color={243,249,255,255}
        else D.Rect(vg,x,y,w,h,hover and {31,61,93,255} or {24,48,74,255});D.Rect(vg,x,y,w,1.5,{142,198,249,128}) end
        D.Text(vg,p.text,x+w/2,y+8,15,color,nil,NVG_ALIGN_CENTER,0,false,15)
        D.Text(vg,p.english,x+w/2,y+26,8.5,{color[1],color[2],color[3],179},'vox-body',NVG_ALIGN_CENTER,0,false,8.5)
    elseif kind=='sticker' then
        local st=p.sticker;local on=session.pick==st.id;local yy=hover and y-2 or y
        D.Path(vg,{x,yy,x+w-8,yy,x+w,yy+8,x+w,yy+h,x,yy+h});nvgFillColor(vg,D.Color(on and {29,79,134,255} or hover and {27,56,88,255} or {20,43,67,255}));nvgFill(vg)
        Stroke(vg,x+.5,yy+.5,w-1,h-1,on and D.orange or {61,88,114,85},on and 2 or 1)
        local ix,iy,side=x+6,yy+6,w-12;D.Path(vg,{ix,iy,ix+side,iy,ix+side,iy+side,ix,iy+side});D.Gradient(vg,ix,iy,side,side,{185,193,202,255},{143,154,166,255})
        for dx=4,side,8 do for dy=4,side,8 do nvgBeginPath(vg);nvgCircle(vg,ix+dx,iy+dy,1);nvgFillColor(vg,nvgRGBA(255,255,255,16));nvgFill(vg) end end
        s.thumbnails:Draw(self,vg,st,nil,ix+side*.07,iy+side*.07,side*.86,side*.86)
        D.Text(vg,st.name,x+w/2,yy+side+11,12,on and D.white or color,'vox-body',NVG_ALIGN_CENTER,0,false,14.4)
        if on then D.Rect(vg,x+6,yy+6,60,14,D.orange);D.Text(vg,'拿在手上',x+11,yy+8,10,D.ink,'vox-body') end
    elseif kind=='layer' then
        local d=session:List()[p.index];if not d then nvgRestore(vg);return end;local st=Data.Catalog().byId[d.s]
        local on=session.sel==p.index;local miss=not session.app.car.livery.dirty and not session.app.car.livery.meshes[p.index]
        if miss then nvgGlobalAlpha(vg,.6) end
        D.Rect(vg,x,y,w,h,on and {29,79,134,255} or hover and {27,56,88,255} or {18,38,59,255});if on then D.Rect(vg,x,y,3,h,D.orange) end
        D.Rect(vg,x+4,y+4,28,28,{143,154,166,255});if st then s.thumbnails:Draw(self,vg,st,d.c,x+5.4,y+5.4,25.2,25.2) end
        D.Text(vg,st and st.name or d.s,x+40,y+(miss and 7 or 11.75),12.5,on and D.white or color,'vox-body',nil,0,false,12.5)
        if miss then D.Text(vg,'没贴到车身上',x+40,y+21.5,10.5,{231,187,112,255},'vox-body') end
        if d.m then D.Icon(vg,'mirror',x+w-22,y+(h-14)/2,14,D.orange) end
    elseif kind=='swatch' then
        local d=session:List()[session.sel];local c=d and d.c and d.c[p.channel];local on=c==p.hex
        D.Rect(vg,x,y,w,h,p.custom and {127,98,161,255} or {((p.hex>>16)&255),(p.hex>>8)&255,p.hex&255,255})
        if p.custom then for i,hex in ipairs({0xff5050,0xffd23f,0x6be36b,0x3fd0ff,0x7a6bff,0xff5fd0}) do D.Rect(vg,x+(i-1)*w/6,y,w/6,h,{(hex>>16)&255,(hex>>8)&255,hex&255,255}) end end
        Stroke(vg,x+.5,y+.5,w-1,h-1,{0,0,0,85});if on then Stroke(vg,x-2,y-2,w+4,h+4,D.ink,2);Stroke(vg,x-3.5,y-3.5,w+7,h+7,D.orange,1.5) end
    else
        local selected=p.action=='mirror' and session:List()[session.sel] and session:List()[session.sel].m or p.action=='flip' and session:List()[session.sel] and session:List()[session.sel].f==1
        local points=kind=='bar' and p.action=='undo' and {x+14,y,x+w,y,x+w,y+h,x,y+h,x,y+14} or p.action=='done' and {x,y,x+w,y,x+w,y+h-14,x+w-14,y+h,x,y+h} or {x,y,x+w,y,x+w,y+h,x,y+h}
        if kind=='bar' then self:RenderBackgroundImage(vg,'Livery/bar-'..p.action..'.png',r,'cover',nil)
        else Relief.Draw(vg,x,y,w,h,selected,true,points,true) end
        if hover and not p.disabled then D.Path(vg,points);nvgFillColor(vg,nvgRGBA(255,255,255,35));nvgFill(vg) end
        local fs=kind=='bar' and 17 or 12;local size=kind=='bar' and 20 or 15;local span=D.Width(vg,p.text,fs,kind=='bar' and 'vox-title' or 'vox-body')+size+(kind=='bar' and 8 or 5)+(p.action=='done' and 43 or 0)
        local xx=x+(w-span)/2;D.Icon(vg,p.icon,xx,y+(h-size)/2,size,{207,226,243,255});D.Text(vg,p.text,xx+size+(kind=='bar' and 8 or 5),y+(h-fs)/2,fs,D.white,kind=='bar' and 'vox-title' or 'vox-body')
        if p.action=='done' then local kx=xx+span-31;D.Rect(vg,kx,y+13.5,29,19,{35,63,93,255});D.Text(vg,'Esc',kx+5,y+15.5,10,{219,238,255,204},'vox-body') end
    end;nvgRestore(vg)
end
local Slider=require('urhox-libs/UI/Widgets/Slider'):Extend('VoxLiverySlider')
function Slider:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local value=self.props.value;local ratio=(value-self.props.min)/(self.props.max-self.props.min)
    nvgBeginPath(vg);nvgRoundedRect(vg,r.x,r.y+(r.h-6)/2,r.w,6,3);nvgFillColor(vg,nvgRGBA(239,239,239,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,r.x,r.y+(r.h-6)/2,r.w*ratio,6,3);nvgFillColor(vg,D.Color(D.blue));nvgFill(vg)
    nvgBeginPath(vg);nvgCircle(vg,r.x+7+ratio*(r.w-14),r.y+r.h/2,7);nvgFillColor(vg,D.Color(D.blue));nvgFill(vg)
end
local Surface=require('urhox-libs/UI/Widgets/Panel'):Extend('VoxLiverySurface')
function Surface:OnPointerDown(e) self.owner.controls:Down(e) end
function Surface:OnPointerMove(e) self.owner.controls:Move(e) end
function Surface:OnPointerUp(e) self.owner.controls:Up(e) end
function Surface:OnPointerCancel() self.owner.controls:Cancel() end
function Surface:Render(vg)
    D.Begin(vg);local controls=self.owner.controls;local g=controls:Gizmo();if not g then return end
    local function Box(box,color,dash,gap,width)
        for i,a in ipairs(box) do local b=box[i%#box+1];local len=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2)
            for d=0,len,(dash+gap)*g.k do local t1,t2=d/math.max(1,len),math.min(len,d+dash*g.k)/math.max(1,len);D.Line(vg,a.x+(b.x-a.x)*t1,a.y+(b.y-a.y)*t1,a.x+(b.x-a.x)*t2,a.y+(b.y-a.y)*t2,color,width*g.k) end
        end
    end
    local twin=controls.session:Twin(controls.session.sel);local tb=twin>0 and controls:Corners(controls.session:List()[twin])
    if tb then Box(tb,{122,216,255,136},3,4,1) end;Box(g.box,D.orange,6,4,1.5);D.Line(vg,g.tx,g.ty,g.x,g.y,D.orange,1.5*g.k)
    for _,p in ipairs(g.box) do D.Rect(vg,p.x-6*g.k,p.y-6*g.k,12*g.k,12*g.k,{11,26,44,255});Stroke(vg,p.x-6*g.k,p.y-6*g.k,12*g.k,12*g.k,D.orange,2*g.k) end
    nvgBeginPath(vg);nvgCircle(vg,g.x,g.y,7*g.k);nvgFillColor(vg,D.Color(D.blue));nvgFill(vg);nvgStrokeWidth(vg,2*g.k);nvgStrokeColor(vg,nvgRGBA(219,238,255,255));nvgStroke(vg)
end
return {Button=Button,Slider=Slider,Surface=Surface}
