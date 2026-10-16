local WorkshopPaint=require("ui.WorkshopPaint")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Ease=require('ui.SourceButtonMotion').Ease
local Layer=UI.Widget:Extend('VoxMvpShow')
-- This overlay retains the older VoxTitle (SmileySans), while newer outgame
-- pages use VoxIndustrial. Keep that source cascade local to the cinematic.
local runCache={};local runCount=0
local function Runs(text)
    text=tostring(text);if runCache[text] then return runCache[text] end
    local runs={}
    for _,cp in utf8.codes(tostring(text)) do
        local font=(cp<=255 or cp>=0x2010 and cp<=0x2027 or cp>=0x2030 and cp<=0x205e) and 'vox-display' or 'vox-story'
        local run=runs[#runs];if not run or run.font~=font then run={font=font,text=''};runs[#runs+1]=run end
        run.text=run.text..utf8.char(cp)
    end
    if runCount>=128 then runCache={};runCount=0 end
    runCache[text]=runs;runCount=runCount+1;return runs
end
local function Width(vg,text,size,spacing)
    local w=0;for _,run in ipairs(Runs(text)) do w=w+D.Width(vg,run.text,size,run.font,spacing) end;return w
end
local function Text(vg,text,x,y,size,color,spacing,lineHeight,shadows)
    local a,d=D.FontMetrics(vg,size,'vox-display');local baseline=y+a+(lineHeight and (lineHeight-a-d)/2 or 0)
    for _,run in ipairs(Runs(text)) do
        D.Text(vg,run.text,x,baseline,size,color,run.font,nil,spacing,true,nil,shadows)
        x=x+D.Width(vg,run.text,size,run.font,spacing)
    end
end
function Layer:Render(vg)
    local show=self.session.battle.mvpShow;if not show or show.done then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local w,h=r.w,r.h
    nvgSave(vg);nvgTranslate(vg,r.x,r.y)
    -- MVP is outside the source's 1920px UI surface: its CSS sizes remain
    -- actual screen pixels, even when the driving controls use a design scale.
    local cssScale=graphics:GetDPR()/UI.GetScale();nvgScale(vg,cssScale,cssScale);w=w/cssScale;h=h/cssScale
    if show.preparing then nvgRestore(vg);return end
    local fade=show.finishing and 1-Ease(math.min(1,show.finishing/.35),'ease') or 1
    nvgGlobalAlpha(vg,fade)
    local t=show.t;local reveal=math.max(0,t-6.3);local bars=1-Ease(math.min(1,reveal/.7),false)
    D.Rect(vg,0,-h*.08*(1-bars),w,h*.08,{0,0,0,255});D.Rect(vg,0,h-h*.08*bars,w,h*.08,{0,0,0,255})
    if show.flashAt then local alpha=.35*(1-Ease(math.min(1,(t-show.flashAt)/.38),'css-ease-out'));D.Rect(vg,0,0,w,h,{255,255,255,math.floor(255*alpha)}) end
    if reveal>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,Ease(math.min(1,reveal/.5),'ease')*fade)
        local x=w*.06-30*(1-Ease(math.min(1,reveal/.6),false));local y=h*.85-236.59375
        Text(vg,'MOST VALUABLE PLAYER · 本局最佳',x,y,14,{242,193,78,255},8,17)
        WorkshopPaint.Image(vg,'Mvp/title.png',{x=x-60,y=y+17-60,w=420,h=223},1,.5)
        local who=show.entry.unit.name;local maxWidth=w*.85-125;local size=30
        while size>16 and Width(vg,who,size,3)>maxWidth do size=size-1 end
        Text(vg,who,x,y+129.59375,size,{255,255,255,255},3,37,{{y=2,color={0,0,0,170}}})
        local team=show.entry.unit.team;local badge=team=='red' and '红队' or '蓝队';if show.entry.unit==self.session.battle.player then badge=badge..' · 你' end
        local bx=x+Width(vg,who,size,3)+12;local bw=Width(vg,badge,14,3)+20
        D.Rect(vg,bx,y+140.390625,bw,23,team=='red' and {255,74,61,255} or {46,168,255,255});Text(vg,badge,bx+10,y+143.390625,14,{255,255,255,255},3,17,{{y=2,color={0,0,0,170}}})
        local sx=x
        for _,item in ipairs({{'kills','击毁'},{'assists','助攻'},{'deaths','阵亡'},{'damage','伤害'}}) do
            local text=tostring(math.floor((show.stats[item[1]] or 0)+.5))
            D.Text(vg,text,sx,y+180.59375,40,{255,255,255,255},'vox-display',nil,1,false,40,{{y=3,color={0,0,0,170}}})
            Text(vg,item[2],sx,y+220.59375,13,{255,255,255,160},3,16)
            sx=sx+math.max(D.Width(vg,text,40,'vox-display',1),Width(vg,item[2],13,3))+28
        end
        nvgRestore(vg)
    end
    local hint=t<6.3 and '跳过' or '继续';local textWidth=Width(vg,hint,12,3);local y=t<6.3 and h-h*.08+32-23 or h-51
    local x=w-28-textWidth;Text(vg,hint,x,y+2,12,{255,255,255,144},3,19)
    local kw=D.Width(vg,'空格',12,'vox-display',3)+16;D.Rect(vg,x-8-kw,y,kw,23,{255,255,255,32});D.Text(vg,'空格',x-kw,y+2,12,{255,255,255,144},'vox-display',nil,3,false,19)
    nvgRestore(vg)
end
function Layer:OnPointerDown(event)
    if event.pointerType=='mouse' and event.button~=MOUSEB_LEFT then return end
    self.session.battle.mvpShow:Skip();event:StopPropagation();return true
end
return Layer
