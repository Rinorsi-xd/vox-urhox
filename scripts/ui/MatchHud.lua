-- Original matchHud.js composition and CSS dimensions, in the existing UI frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Layer=UI.Widget:Extend('VoxMatchHud')
local M={}
local orange={255,106,19,255}
local blue={46,168,255,255};local red={255,74,61,255}
local function Panel(vg,x,y,w,h,color,cut)
    D.Panel(vg,x,y,w,h,cut or 10,color or {11,13,17,235},{255,255,255,20})
end
function Layer:Render(vg)
    if self.session.battle.mvpShow and not self.session.battle.mvpShow.done then return end
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.session;local b=s.battle;local rule=b.rules
    local k=require('ui.MatchBanner').Scale(r.w,r.h,s.touch);local w,h=r.w/k,r.h/k
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k)
    local cfg=require('combat.ArenaData').modes[b.mode]
    local cx=w/2
    require('ui.MatchTop').Draw(vg,b,w)
    require('ui.MatchObjectives').Draw(vg,s,w,h,k)
    if self.minimap then self.minimap:Draw(vg) end
    require('ui.MatchFeed').Draw(vg,b,w)
    require('ui.MatchComms').Draw(vg,self,b,w,h)
    require('ui.MatchFeedback').Draw(vg,b,w,h)
    if rule.state~='over' then require('ui.MatchBanner').Draw(vg,b.banner,w,h) end
    if not b.player.alive and rule.state~='over' then require('ui.MatchSpectator').Draw(vg,b,w,h) end
    if rule.state=='over' or b.boardOn or s.touchScoreboard then
        require('ui.MatchScoreboard').Draw(vg,self,b,w,h,k,cfg)
    else self.resultRect=nil end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Layer{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    layer.minimap=require('ui.MatchMinimap').New(session)
    local exit=require('ui.SourceButton'){text='退出对局',sourceKind='flat',pointerEvents='auto',position='absolute',right=14,top=12,width=112,height=34,onClick=function() require('combat.MatchActions').ConfirmLeave(session.battle) end};root:AddChild(exit)
    local back=require('ui.MatchResultButton'){text='回机库',position='absolute',width=134,height=50,visible=false,onClick=function() session.wantsReturn=true end};root:AddChild(back)
    local retry=require('ui.MatchResultButton'){text='再来一局',primary=true,position='absolute',width=156,height=50,visible=false,onClick=function() require('combat.MatchActions').Again(session.battle) end};root:AddChild(retry)
    local result={layer=layer,exit=exit,back=back,retry=retry}
    function result.Update(dt)
        require('ui.MatchFeedback').Update(session.battle,nil,session.intro and not session.intro.done or false)
        require('ui.MatchBanner').Update(session.battle)
        require('ui.MatchFeed').Update(session.battle)
        require('ui.MatchObjectives').Update(session,dt)
        layer.minimap:Update()
        local show=session.battle.mvpShow;local over=session.battle.rules.state=='over' and session.battle.result~=nil and (not show or show.done);back:SetVisible(over);retry:SetVisible(over);exit:SetVisible(session.battle.rules.state~='over' and (not show or show.done))
        require('ui.MatchScoreboard').Update(layer,session.battle,over or ((not show or show.done) and (session.battle.boardOn or session.touchScoreboard==true)),dt)
        back.revealAlpha=layer.boardAlpha;retry.revealAlpha=layer.boardAlpha
        local r=layer.resultRect
        if over and r then
            local k=r.scale
            back:SetStyle({left=r.x+r.w-344*k,top=r.buttonY,width=134*k,height=50*k})
            retry:SetStyle({left=r.x+r.w-192*k,top=r.buttonY,width=156*k,height=50*k})
        end
    end
    function result.Dispose() layer.minimap:Dispose();layer.minimap=nil end
    return result
end
return M
