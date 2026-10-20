-- Original matchHud.js composition and CSS dimensions, in the existing UI frame.
local MatchBanner=require("ui.MatchBanner")
local ArenaData=require("combat.ArenaData")
local MatchTop=require("ui.MatchTop")
local MatchObjectives=require("ui.MatchObjectives")
local MatchFeed=require("ui.MatchFeed")
local MatchComms=require("ui.MatchComms")
local MatchFeedback=require("ui.MatchFeedback")
local MatchSpectator=require("ui.MatchSpectator")
local MatchScoreboard=require("ui.MatchScoreboard")
local MatchMinimap=require("ui.MatchMinimap")
local SourceButton=require("ui.SourceButton")
local MatchActions=require("combat.MatchActions")
local MatchResultButton=require("ui.MatchResultButton")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Layer=UI.Widget:Extend('VoxMatchHud')
local BoardContent=UI.Widget:Extend('VoxMatchScoreboardContent')
local BoardScroll=UI.ScrollView:Extend('VoxMatchScoreboardScroll')
local M={}
local orange={255,106,19,255}
local blue={46,168,255,255};local red={255,74,61,255}
local function Panel(vg,x,y,w,h,color,cut)
    D.Panel(vg,x,y,w,h,cut or 10,color or {11,13,17,235},{255,255,255,20})
end
function Layer:Render(vg)
    if self.session.battle.mvpShow and not self.session.battle.mvpShow.done then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.session;local b=s.battle;local rule=b.rules
    local k=MatchBanner.Scale(r.w,r.h,s.touch);local w,h=r.w/k,r.h/k
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k)
    local cfg=ArenaData.modes[b.mode]
    local cx=w/2
    MatchTop.Draw(vg,b,w)
    MatchObjectives.Draw(vg,s,w,h,k)
    if self.minimap then self.minimap:Draw(vg) end
    MatchFeed.Draw(vg,b,w)
    MatchComms.Draw(vg,self,b,w,h)
    MatchFeedback.Draw(vg,b,w,h)
    if rule.state~='over' then MatchBanner.Draw(vg,b.banner,w,h) end
    if not b.player.alive and rule.state~='over' then MatchSpectator.Draw(vg,b,w,h) end
    nvgRestore(vg)
end
function BoardScroll:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local k=self.sourceScale or 1
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k)
    MatchScoreboard.Background(vg,0,0,r.w/k,r.h/k,self.layer.boardAlpha)
    nvgRestore(vg)
end
function BoardScroll:Update(dt)
    if self.props.visible==false then return end
    UI.ScrollView.Update(self,dt)
end
function BoardContent:Render(vg)
    local m=self.sourceLayout;if not m then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local k=self.sourceScale
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k)
    MatchScoreboard.Draw(vg,self.layer,self.session.battle,m.w,m.h,k,ArenaData.modes[self.session.battle.mode],m)
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Layer{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    layer.minimap=MatchMinimap.New(session)
    local exit=SourceButton{text='退出对局',sourceKind='flat',pointerEvents='auto',position='absolute',right=14,top=12,width=112,height=34,onClick=function() MatchActions.ConfirmLeave(session.battle) end};root:AddChild(exit)
    local scroll=BoardScroll{position='absolute',width=0,height=0,visible=false,scrollX=true,scrollY=true,bounces=false,showScrollbar=true,pointerEvents='auto'}
    scroll.layer=layer;root:AddChild(scroll);layer.boardScroll=scroll
    local content=BoardContent{width=0,height=0,flexShrink=0,pointerEvents='box-none'}
    content.layer=layer;content.session=session;scroll:AddChild(content)
    local back=MatchResultButton{text='回机库',position='absolute',width=134,height=50,visible=false,onClick=function() session.wantsReturn=true end};content:AddChild(back)
    local retry=MatchResultButton{text='再来一局',primary=true,position='absolute',width=156,height=50,visible=false,onClick=function() MatchActions.Again(session.battle) end};content:AddChild(retry)
    local result={layer=layer,exit=exit,back=back,retry=retry,scoreboardScroll=scroll,scoreboardContent=content}
    function result.Update(dt)
        MatchFeedback.Update(session.battle,nil,session.intro and not session.intro.done or false)
        MatchBanner.Update(session.battle)
        MatchFeed.Update(session.battle)
        MatchObjectives.Update(session,dt)
        layer.minimap:Update()
        local show=session.battle.mvpShow;local over=session.battle.rules.state=='over' and session.battle.result~=nil and (not show or show.done);back:SetVisible(over);retry:SetVisible(over);exit:SetVisible(session.battle.rules.state~='over' and (not show or show.done))
        local visible=over or ((not show or show.done) and (session.battle.boardOn or session.touchScoreboard==true))
        local identity=layer.boardIdentity
        MatchScoreboard.Update(layer,session.battle,visible,dt)
        scroll:SetVisible(visible)
        if identity~=layer.boardIdentity then
            scroll:SetScrollDirect(0,0);scroll.state.velocityX=0;scroll.state.velocityY=0;scroll.state.isDragging=false
            scroll:CancelSnap_()
        end
        back.revealAlpha=layer.boardAlpha;retry.revealAlpha=layer.boardAlpha
        if visible then
            local r=root:GetAbsoluteLayout();local dpr=graphics:GetDPR();local k=dpr/UI.GetScale()
            local w,h=r.w/k,r.h/k
            local b=session.battle;local cfg=ArenaData.modes[b.mode]
            local key=table.concat({r.w,r.h,k,tostring(over),tostring(b.result),tostring(b.mvp),cfg.size,math.floor(b.rules.score.blue),math.floor(b.rules.score.red),math.ceil(b.rules:TimeLeft()),b.rules.round or '',b.rules.half or '',tostring(b.rules.overtime),tostring(b.rules.sudden)},':')
            if r.w>0 and r.h>0 and key~=result.layoutKey then
                result.layoutKey=key
                local compact=w>h and h<=600
                local m=MatchScoreboard.Layout(w,h,b,cfg,compact)
                -- 手机结算：一列排两队要 ~675 CSS px 高，手机只有 ~390，回机库/再来一局被挤到滚动区最底下看不见。
                -- 两队并排后整体缩到刚好一屏放下（不低于 .6），按钮始终在屏幕内
                local fit=1
                if compact and over then
                    for f=1,.6,-.025 do
                        local c=MatchScoreboard.Layout(w/f,h/f,b,cfg,true,true)
                        fit=f;m=c
                        -- 一屏放下，且每列名字至少 120、两列不超出面板
                        if c.h<=c.viewH+.5 and c.nameWidth>=120 and 2*c.rowWidth+3*c.padding<=c.w+.5 then break end
                    end
                end
                result.boardFit=fit
                local k=k*fit -- 只在本次排版内生效；下面每帧算位置时再统一乘 boardFit，不能乘两遍
                result.scoreboardLayout=m;content.sourceLayout=m;content.sourceScale=k;scroll.sourceScale=k
                content:SetStyle({width=m.contentW*k,height=m.h*k})
                scroll:SetStyle({left=(r.w-m.w*k)/2,width=m.w*k,height=m.viewH*k})
                back.props.sourceScale=k;retry.props.sourceScale=k
                if over then
                    back:SetStyle({left=m.backX*k,top=m.buttonY*k,width=m.buttonBack*k,height=m.buttonH*k})
                    retry:SetStyle({left=m.retryX*k,top=m.retryY*k,width=m.buttonRetry*k,height=m.buttonH*k})
                else
                    -- ScrollView bounds include hidden descendants as well.
                    back:SetStyle({left=0,top=0,width=0,height=0})
                    retry:SetStyle({left=0,top=0,width=0,height=0})
                end
            end
            local m=result.scoreboardLayout
            if m then
                local kk=k*(result.boardFit or 1)
                local top=(r.h-m.viewH*kk)/2+m.viewH*kk*.02*(1-layer.boardAlpha)
                if result.boardTop~=top then scroll:SetStyle({top=top});result.boardTop=top end
            end
        else
            layer.resultRect=nil
        end
    end
    function result.Dispose()
        scroll:SetVisible(false);scroll:SetScrollDirect(0,0)
        scroll.state.velocityX=0;scroll.state.velocityY=0;scroll.state.isDragging=false
        layer.minimap:Dispose();layer.minimap=nil
    end
    return result
end
return M
