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
    if rule.state=='over' or b.boardOn or s.touchScoreboard then
        MatchScoreboard.Draw(vg,self,b,w,h,k,cfg)
    else self.resultRect=nil end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Layer{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    layer.minimap=MatchMinimap.New(session)
    local exit=SourceButton{text='退出对局',sourceKind='flat',pointerEvents='auto',position='absolute',right=14,top=12,width=112,height=34,onClick=function() MatchActions.ConfirmLeave(session.battle) end};root:AddChild(exit)
    local back=MatchResultButton{text='回机库',position='absolute',width=134,height=50,visible=false,onClick=function() session.wantsReturn=true end};root:AddChild(back)
    local retry=MatchResultButton{text='再来一局',primary=true,position='absolute',width=156,height=50,visible=false,onClick=function() MatchActions.Again(session.battle) end};root:AddChild(retry)
    local result={layer=layer,exit=exit,back=back,retry=retry}
    function result.Update(dt)
        MatchFeedback.Update(session.battle,nil,session.intro and not session.intro.done or false)
        MatchBanner.Update(session.battle)
        MatchFeed.Update(session.battle)
        MatchObjectives.Update(session,dt)
        layer.minimap:Update()
        local show=session.battle.mvpShow;local over=session.battle.rules.state=='over' and session.battle.result~=nil and (not show or show.done);back:SetVisible(over);retry:SetVisible(over);exit:SetVisible(session.battle.rules.state~='over' and (not show or show.done))
        MatchScoreboard.Update(layer,session.battle,over or ((not show or show.done) and (session.battle.boardOn or session.touchScoreboard==true)),dt)
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
