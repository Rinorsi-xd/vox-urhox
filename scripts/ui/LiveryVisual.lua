local Config=require("Config")
local UI=require("urhox-libs/UI/Core/UI")

local D=require 'ui.SourceDraw'
local Panel=require('urhox-libs/UI/Widgets/Panel'):Extend('VoxLiveryPanel')
local Data=require 'construction.LiveryData'
local function Text(vg,t,x,y,size,color,font,line) D.Text(vg,t,x,y,size,color or D.muted,font or 'vox-body',nil,0,false,line) end
local function Kbd(vg,t,x,y)
    local w=D.Width(vg,t,10.5,'vox-body')+10;D.Rect(vg,x,y,w,16.7,{35,63,93,255});Text(vg,t,x+5,y+1,10.5,{219,238,255,255},nil,14.7);return w
end
function Panel:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local x,y,w,h=r.x,r.y,r.w,r.h
    D.Path(vg,{x,y,x+w-12,y,x+w,y+12,x+w,y+h,x,y+h});nvgFillColor(vg,nvgRGBA(10,22,37,214));nvgFill(vg);D.Rect(vg,x,y,w-12,1,{83,123,156,68})
    local right=self.props.side=='right';D.Icon(vg,right and 'sliders' or 'livery',x+16,y+16.5,18,D.orange)
    D.Text(vg,right and '贴纸属性' or '贴纸库',x+42,y+16,19,D.white,nil,nil,1,false,19)
    D.Text(vg,right and 'PROPERTIES' or 'STICKERS',x+w-16,y+20.5,10,{122,216,255,191},'vox-body',NVG_ALIGN_RIGHT,2.5,false,10)
    if not right then D.Text(vg,'点一张贴纸，再点车身贴上去',x+w/2,y+h-31,12,{127,154,180,255},'vox-body',NVG_ALIGN_CENTER,0,false,16.8);return end
    local d=s.session:List()[s.session.sel];local st=d and Data.Catalog().byId[d.s]
    if not d then
        D.Rect(vg,x+16,y+47,268,133.96875,{11,26,44,153});D.Rect(vg,x+16,y+47,268,1,{61,88,114,68})
        Text(vg,'没有选中贴纸',x+28,y+59,15,D.white,'vox-title',18);Text(vg,'点车上的贴纸可以选中它',x+28,y+80,12)
        if require('controls.TouchMode').Enabled() then
            Text(vg,'按住贴纸拖动挪位置',x+28,y+106.8,12)
            Text(vg,'拖四角调大小，拖顶上的圆点转角度',x+28,y+127.6,12)
            Text(vg,'空白处拖动转视角，双指捏合拉近拉远',x+28,y+150.4,12)
        else
        local k=Kbd(vg,'左键',x+29,y+105.8);Text(vg,'拖动挪位置',x+29+k+4,y+106.8,12)
        Text(vg,'拖四角调大小，拖顶上的圆点转角度',x+28,y+127.6,12)
        local a=Kbd(vg,'右键',x+29,y+149.4);Text(vg,'拖动转视角，',x+29+a+4,y+150.4,12)
        local b=Kbd(vg,'滚轮',x+29+a+80,y+149.4);Text(vg,'拉近拉远',x+29+a+80+b+4,y+150.4,12)
        end
    else
        local xx,yy=x+16,y+47
        D.Path(vg,{xx,yy,xx+52,yy,xx+52,yy+52,xx,yy+52});D.Gradient(vg,xx,yy,52,52,{185,193,202,255},{143,154,166,255})
        if st then s.thumbnails:Draw(self,vg,st,d.c,xx+3.12,yy+3.12,45.76,45.76) end
        Text(vg,st and st.name or d.s,xx+62,yy+6.85,18,D.white,'vox-title',19.8)
        Text(vg,st and st.kind=='shape' and '图形 · 可改色' or '角色立绘 · 原色',xx+62,yy+30.65,11.5)
        local dy=111
        if st and st.kind=='shape' then for i=1,#st.colors do Text(vg,#st.colors==1 and '颜色' or i==1 and '主色' or '副色',xx,y+dy,11);dy=dy+85.46875 end end
        Text(vg,'大小',xx,y+dy+3.5,11);D.Text(vg,string.format('%.1f 米',d.w*.5),xx+268,y+dy+2.5,13,{219,238,255,255},'vox-display',NVG_ALIGN_RIGHT)
        dy=dy+30;Text(vg,'角度',xx,y+dy+3.5,11);D.Text(vg,tostring(math.floor(((math.deg(d.r)+540)%360)-180+.5))..'°',xx+268,y+dy+2.5,13,{219,238,255,255},'vox-display',NVG_ALIGN_RIGHT)
    end
    local ly=y+47+s.propHeight+12;D.Rect(vg,x+16,ly,268,1,{61,88,114,102})
    Text(vg,'车上的贴纸',x+16,ly+11,14,D.white,'vox-title',14);D.Text(vg,#s.session:List()..' / 48',x+w-16,ly+13,12,D.muted,'vox-display',NVG_ALIGN_RIGHT)
    if #s.session:List()==0 then
        Text(vg,'还没有贴纸。从左边挑一张，点在车身上。',x+35,ly+62,12,{127,154,180,255})
    end
end
local Hint=require('urhox-libs/UI/Widgets/Panel'):Extend('VoxLiveryHint')
function Hint:Render(vg)
    D.Begin(vg);local s=self.owner;local session=s.session;local text,key,tail
    if session.pick then local st=Data.Catalog().byId[session.pick];text='拿着「'..st.name..'」：点车身贴上去（车轮、武器会动，贴不上） · ';key='Esc';tail=' 放下'
    elseif session.sel>0 then text='拖动挪位置 · 拖四角调大小 · 拖顶上的圆点旋转 · ';key='Delete';tail=' 撕掉'
    elseif #session:List()>0 then text='点车上的贴纸选中它，或者从左边再挑一张' end
    if not text then return end
    -- 触屏没有 Esc / Delete：去掉键位，句尾的「· 」也一起收掉
    if key and require('controls.TouchMode').Enabled() then key=nil;text=text:gsub(' · $','') end
    local r=self:GetAbsoluteLayout();local lead=D.Width(vg,text,13,'vox-body');local span=lead+(key and D.Width(vg,key,10.5,'vox-body')+12+D.Width(vg,tail,13,'vox-body') or 0);local x=r.x+(r.w-span-28)/2
    D.Rect(vg,x,r.y,span+28,32.6875,{8,20,35,153});Text(vg,text,x+14,r.y+7,13,{219,238,255,255},nil,18.6875)
    if key then local kw=Kbd(vg,key,x+15+lead,r.y+8);Text(vg,tail,x+16+lead+kw,r.y+7,13,{219,238,255,255},nil,18.6875) end
end
local Picker=require('urhox-libs/UI/Widgets/ColorPicker'):Extend('VoxLiveryCustomColor')
function Picker:Render(vg)
    D.Begin(vg)
    local r=self:GetAbsoluteLayout();local hit=self:GetAbsoluteLayoutForHitTest();self.inputBounds_={x=hit.x,y=hit.y,w=hit.w,h=hit.h}
    local d=self.owner.session:List()[self.owner.session.sel];local color=d and d.c and d.c[self.channel];local custom=true
    if color and not self.isOpen_ then self:SetValue({r=(color>>16)&255,g=(color>>8)&255,b=color&255}) end
    for _,p in ipairs(Config.PALETTE) do if p.hex==color then custom=false;break end end
    if custom and color then D.Rect(vg,r.x,r.y,r.w,r.h,{(color>>16)&255,(color>>8)&255,color&255,255})
    else
        self:RenderBackgroundImage(vg,'Livery/custom-color.png',r,'contain',nil)
    end
    nvgBeginPath(vg);nvgRect(vg,r.x+.5,r.y+.5,r.w-1,r.h-1);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(0,0,0,85));nvgStroke(vg)
    if custom and color then
        for _,edge in ipairs({{2,D.ink,2},{3.5,D.orange,1.5}}) do nvgBeginPath(vg);nvgRect(vg,r.x-edge[1],r.y-edge[1],r.w+edge[1]*2,r.h+edge[1]*2);nvgStrokeWidth(vg,edge[3]);nvgStrokeColor(vg,D.Color(edge[2]));nvgStroke(vg) end
    end
    if self.isOpen_ then UI.QueueOverlay(function(context) self:RenderPopup(context) end) end
end
return {Panel=Panel,Hint=Hint,Picker=Picker}
