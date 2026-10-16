local SourceParagraph=require("ui.SourceParagraph")
local ArenaData=require("combat.ArenaData")
local CommsCard=require("ui.CommsCard")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Coord=require 'core.Coord'
local Page=UI.Widget:Extend('VoxMatchIntro')
local M={};local role={assault='突击',heavy='重装',hover='悬浮快攻',sniper='狙击'}
local orange={122,216,255,255}
function M.New(owner) local p=Page{pointerEvents='auto',focusable=false};p.owner=owner;p.paragraph=SourceParagraph.New(22,33);return p end
function Page:GetAbsoluteLayout() local w,h=UI.GetViewportSize();return {x=0,y=0,w=w,h=h} end
function Page:GetAbsoluteLayoutForHitTest() return self:GetAbsoluteLayout() end
function Page:HitTest() return not self.owner.done end
function Page:OnPointerDown() return true end
function Page:OnPointerUp() return true end
function Page:OnClick(event)
    local r=self.skipRect;if r and event.x>=r.x and event.x<=r.x+r.w and event.y>=r.y and event.y<=r.y+r.h then self.owner:Finish() end;return true
end
function Page:Render(vg)
    local intro=self.owner;if intro.done then return end
    D.Begin(vg);local vw,vh=UI.GetViewportSize();local k=math.min(vw/1920,vh/1080);local w,h=vw/k,vh/k;local shot=intro.shot
    nvgSave(vg);nvgScale(vg,k,k)
    D.Rect(vg,0,0,w,h*.09,{0,0,0,255});D.Rect(vg,0,h*.91,w,h*.09,{0,0,0,255})
    if shot.team then
        D.Text(vg,shot.team=='blue' and '我方阵容' or '敌方阵容',w/2,h*.13,56,shot.team=='blue' and {92,196,255,255} or {255,106,94,255},'vox-title',NVG_ALIGN_CENTER,12)
        D.Text(vg,shot.team=='blue' and 'YOUR SQUAD' or 'OPPOSING FORCE',w/2,h*.13+68,13,D.muted,'vox-title',NVG_ALIGN_CENTER,8)
        local camera=intro.session.camera:GetCamera()
        for i,entry in ipairs(intro.session.battle.entries) do if entry.unit.team==shot.team then
            local p=entry.unit:Position();local point=Coord.Vec(p[1],p[2]+2.6,p[3]);local uv=camera:WorldToScreenPoint(point)
            if camera.node:WorldToLocal(point).z>camera.nearClip and uv.x>0 and uv.x<1 and uv.y>0 and uv.y<1 then
                local alpha=math.max(0,math.min(1,(intro.localTime-.3-entry.slot*.25)/.45));local x=uv.x*w-60;local y=uv.y*h-54
                nvgSave(vg);nvgGlobalAlpha(vg,alpha)
                D.Path(vg,{x,y,x+300,y,x+300,y+54,x,y+54});D.Gradient(vg,x,y,300,54,{16,34,56,224},{16,34,56,160},true)
                D.Rect(vg,x,y,3,54,entry.member.player and orange or shot.team=='blue' and {46,168,255,255} or {255,74,61,255})
                Paint.Image(vg,'UI/Avatars/'..entry.member.avatar..'.jpg',{x=x+5,y=y+5,w=44,h=44},1,.5)
                D.Text(vg,entry.member.name,x+59,y+6,18,D.white,'vox-title',nil,1)
                D.Text(vg,(entry.member.player and intro.session.name..' · 你' or (role[entry.member.role] or '')..' · T'..entry.member.tier)..' · LV '..entry.member.level,x+59,y+32,11,D.muted,'vox-title',nil,2)
                nvgRestore(vg)
            end
        end end
    elseif intro.index==1 then
        local cfg=ArenaData.modes[intro.session.battle.mode]
        D.Text(vg,cfg.en..' · '..cfg.size..'V'..cfg.size..' · AI 对战',w*.05,h*.13,13,orange,'vox-title',nil,8)
        D.Text(vg,cfg.name,w*.05,h*.13+30,64,D.white,'vox-title',nil,8)
        D.Text(vg,'坠舰陨坑 · 第 7 边境星区 · CV-07 ARGUS 坠毁现场',w*.05,h*.13+105,14,D.muted,'vox-title',nil,4)
    elseif shot.label then
        D.Text(vg,shot.label[1],w*.95,h*.13,12,orange,'vox-title',NVG_ALIGN_RIGHT,5)
        D.Text(vg,shot.label[2],w*.95,h*.13+27,34,D.white,'vox-title',NVG_ALIGN_RIGHT,5)
    end
    local sw=math.min(980,w*.86);local x=(w-sw)/2;local Comms=CommsCard
    local card=intro.comms.card
    if card then local height=Comms.Height(vg,card,sw);Comms.Draw(vg,card,x,h*.91-26-height,sw,height,1,intro.time) end
    local sy=h*.91+22;D.Text(vg,'空格',w-195,sy,12,D.muted,'vox-tabular');D.Text(vg,'跳过介绍',w-132,sy,12,D.muted,'vox-title',nil,3)
    self.skipRect={x=(w-230)*k,y=(sy-8)*k,w=202*k,h=46*k}
    nvgRestore(vg)
end
return M
