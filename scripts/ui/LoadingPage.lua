-- Frozen loadingPage.js + salvage.css; drawn inside the existing UI frame.
local LoadingFx=require("ui.LoadingFx")
local BootLoading=require("ui.BootLoading")
local MatchLobby=require("ui.MatchLobby")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Motion=require 'ui.SourceButtonMotion'
local Paint=require 'ui.WorkshopPaint'
local Page=UI.Widget:Extend('VoxLoadingPage')
local M={}
local gray={100,106,116,255};local green={61,220,132,255};local red={255,59,48,255}
function M.New(owner)
    local page=Page{pointerEvents='auto',focusable=false};page.owner=owner;page.focusable=false;page.pointers={}
    return page
end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest(x,y)
    local r=self:GetAbsoluteLayout();return self.owner.active and x>=0 and y>=0 and x<=r.w and y<=r.h
end
function Page:Open()
    UI.ClearFocus();self.owner.cancelled=false;self.backRect=nil
    self.fx=LoadingFx.New()
    UI.RegisterGlobalComponent('vox-loading-page',self);UI.PushOverlay(self)
end
function Page:Close()
    for id,kind in pairs(self.pointers) do UI.CancelPointer(id,kind) end
    self.pointers={};self.fx=nil;UI.PopOverlay(self);UI.UnregisterGlobalComponent('vox-loading-page')
end
function Page:OnPointerDown(event) self.pointers[event.pointerId]=event.pointerType;return true end
function Page:OnPointerUp(event) self.pointers[event.pointerId]=nil;return true end
function Page:OnPointerCancel(event) self.pointers[event.pointerId]=nil;return true end
function Page:OnClick(event)
    local cancel=self.cancelRect
    if self.owner.match and self.owner.match.stage=='queue' and cancel and event.x>=cancel.x and event.x<=cancel.x+cancel.w and event.y>=cancel.y and event.y<=cancel.y+cancel.h then self.owner:Back();return true end
    local r=self.backRect
    if self.owner.failed and r and event.x>=r.x and event.x<=r.x+r.w and event.y>=r.y and event.y<=r.y+r.h then
        if self.owner.map.boot then self.owner:Retry() else self.owner:Back() end
    end
    return true
end
local function Fade(vg,x,y,w,h,a,b,horizontal)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);D.Gradient(vg,x,y,w,h,a,b,horizontal)
end
local function Stroke(vg,color,width) nvgStrokeColor(vg,D.Color(color));nvgStrokeWidth(vg,width);nvgStroke(vg) end
function Page:DrawPage(vg,w,h)
    local flow=self.owner;local map=flow.map;local t=flow.elapsed;local accent=map.loadingColor or D.orange
    D.Rect(vg,0,0,w,h,{11,12,15,255})
    local entry=Motion.Ease(math.min(1,t/2.4),false);local zoom=1.12-.08*entry
    if t>2.4 then zoom=1.04+.04*(.5-.5*math.cos((t-2.4)*math.pi/34)) end
    if flow.artReady then Paint.Image(vg,map.loadingArt or 'UI/Modes/crater.jpg',{x=-w*.04,y=-h*.04,w=w*1.08,h=h*1.08},zoom,.5) end
    if entry<1 then D.Rect(vg,0,0,w,h,{0,0,0,102*(1-entry)}) end
    local shade={9,10,12,255};local stops={{0,.45,224,89},{.45,.7,89,26},{.7,1,26,140}}
    for _,s in ipairs(stops) do Fade(vg,w*s[1],0,w*(s[2]-s[1]),h,{shade[1],shade[2],shade[3],s[3]},{shade[1],shade[2],shade[3],s[4]},true) end
    Fade(vg,0,h*.5,w,h*.22,{9,10,12,0},{9,10,12,102})
    Fade(vg,0,h*.72,w,h*.28,{9,10,12,102},{9,10,12,242})
    Paint.Radial(vg,{0,0,w,0,w,h,0,h},w*.92,h*.78,w*.5,h*.6,{9,10,12,209},1)
    self.fx:Draw(vg,w,h,t,accent)
    local x=w*.052;local badge=42
    D.Rect(vg,x,h*.05,badge,badge,accent);D.Icon(vg,map.loadingIcon or 'flag',x+8,h*.05+8,26,{11,41,70,255})
    D.Text(vg,map.loadingBrand or map.name,x+badge+14,h*.05+7,28,D.white,'vox-title',nil,3)
    local base=h*.83;local title=104;local sub=20
    D.Text(vg,map.loadingKicker or '第 7 边境星区',x,base-title*1.35-sub-29,18,{154,160,170,255},'vox-body',nil,2)
    D.Text(vg,map.name,x,base-title*1.15-sub, title,D.white,'vox-title',nil,4)
    D.Text(vg,map.loadingSub or (map.id=='trial' and '100 米加速道 · 坡道 · 靶场' or 'CV-07 ARGUS 坠毁现场 · 自由探索'),x,base-sub,sub,{199,203,210,255},'vox-body')
    local lw=math.max(320,math.min(440,w*.22));local lx=w-x-lw;local row=40
    local ly=base-#flow.steps*row-49-(flow.failed and 120 or 0)
    D.Text(vg,flow.failed and '加载失败' or flow.progress==1 and '就绪' or '正在准备',lx,ly,24,flow.failed and red or flow.progress==1 and green or D.white,'vox-title',nil,2)
    D.Text(vg,math.floor(flow.progress*100+.5)..'%',lx+lw,ly-5,30,accent,'vox-tabular',NVG_ALIGN_RIGHT)
    D.Rect(vg,lx,ly+33,lw,1,{255,255,255,36})
    for i,step in ipairs(flow.steps) do
        local y=ly+42+(i-1)*row;local color=step.state=='done' and {199,203,210,255} or step.state=='run' and D.white or step.state=='fail' and red or gray
        if step.state=='done' then
            D.Path(vg,{lx+2,y+17,lx+6,y+22,lx+15,y+10,lx+12,y+8,lx+6,y+16,lx+4,y+14});nvgFillColor(vg,D.Color(green));nvgFill(vg)
        elseif step.state=='run' then
            nvgBeginPath(vg);nvgArc(vg,lx+7,y+16,7,t*math.pi*2/.7,t*math.pi*2/.7+math.pi*1.5,NVG_CW);Stroke(vg,accent,1.5)
        else
            nvgBeginPath(vg);nvgRect(vg,lx,y+9,14,14);Stroke(vg,color,1.5)
            if step.state=='fail' then nvgFillColor(vg,D.Color(red));nvgFill(vg) end
        end
        D.Text(vg,step.label,lx+32,y+6,17,color,'vox-body')
        D.Text(vg,step.note,lx+lw,y+8,15,gray,'vox-tabular',NVG_ALIGN_RIGHT)
    end
    if flow.failed then
        local ey=ly+42+#flow.steps*row+14
        nvgSave(vg);nvgScissor(vg,lx,ey,lw,52);D.Text(vg,flow.error,lx,ey,15,{255,138,128,255},'vox-body');nvgRestore(vg)
        self.backRect={x=lx,y=ey+58,w=112,h=46};D.Panel(vg,lx,ey+58,112,46,10,{37,104,161,255},{17,51,84,255})
        D.Text(vg,'返回',lx+56,ey+71,18,D.white,'vox-title',NVG_ALIGN_CENTER,nil,18)
    end
    local fy=h*.93-3;local tips=map.loadingTips or {'自由驾驶，熟悉操控和武器','靶车会逐块被打坏，看看你的火力','可以选任意档位'}
    local tip=tips[math.floor(t/4)%#tips+1]
    D.Text(vg,'提示',x,fy-40,18,accent,'vox-body')
    nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,(t%4)/.3));D.Text(vg,tip,x+50,fy-40,18,{199,203,210,255},'vox-body');nvgRestore(vg)
    D.Rect(vg,x,fy,w-x*2,3,{255,255,255,31});D.Rect(vg,x,fy,(w-x*2)*flow.progress,3,flow.progress==1 and green or accent)
end
local function Ease(x)
    if x<=0 then return 0 elseif x>=1 then return 1 end
    local lo,hi=0,1
    for _=1,16 do local t=(lo+hi)/2;local u=1-t;if 3*u*u*t*.7+3*u*t*t*.2+t^3<x then lo=t else hi=t end end
    local t=(lo+hi)/2;return 3*(1-t)*t*t+t^3
end
function Page:DrawTransition(vg,w,h)
    local flow=self.owner;local phase=flow.phase;local cover=phase=='cover' or phase=='exit-cover'
    local accent=flow.map.loadingColor or D.orange
    local reveal=phase=='reveal' or phase=='exit-reveal'
    if not cover and not reveal then return end
    local bw=w*1.6;local bh=h*1.2;local skew=math.tan(math.rad(-18))*bh*.5
    for i=1,2 do
        local delay=cover and (i-1)*.09 or (2-i)*.07
        local progress=Ease((flow.time-delay)/(cover and .46 or .52))
        local shift=cover and 1.15*(1-progress) or -1.3*progress
        local x=-w*.3+bw*shift;local y=-h*.1
        D.Path(vg,{x-skew,y,x+bw-skew,y,x+bw+skew,y+bh,x+skew,y+bh})
        nvgFillColor(vg,D.Color(i==1 and accent or {11,12,15,255}));nvgFill(vg)
        if i==2 then
            D.Path(vg,{x-skew,y,x+28-skew,y,x+28+skew,y+bh,x+skew,y+bh});nvgFillColor(vg,D.Color(accent));nvgFill(vg)
        end
    end
end
function Page:Render(vg)
    if not self.owner.active then return end
    D.Begin(vg);local w,h=UI.GetViewportSize()
    -- Drive HUD may switch its scale; the loading surface retains source 1080p.
    local k=math.min(w/1920,h/1080);local logicalW,logicalH=w/k,h/k
    self.backRect=nil;self.cancelRect=nil
    nvgSave(vg);nvgScale(vg,k,k);nvgScissor(vg,0,0,logicalW,logicalH)
    if self.owner.pageVisible then
        if self.owner.map.boot then
            if self.owner.phase=='boot-exit' then nvgGlobalAlpha(vg,math.max(0,1-self.owner.time/.8)) end
            BootLoading.Draw(self,vg,logicalW,logicalH)
        elseif self.owner.match then MatchLobby.Draw(self,vg,logicalW,logicalH) else self:DrawPage(vg,logicalW,logicalH) end
        self.owner:PageRendered()
    end
    self:DrawTransition(vg,logicalW,logicalH);nvgRestore(vg)
    if self.backRect then local r=self.backRect;self.backRect={x=r.x*k,y=r.y*k,w=r.w*k,h=r.h*k} end
    if self.cancelRect then local r=self.cancelRect;self.cancelRect={x=r.x*k,y=r.y*k,w=r.w*k,h=r.h*k} end
end
function Page:Dispose() self:Close();self:Destroy() end
return M
