-- Original matchHud.js composition and CSS dimensions, in the existing UI frame.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Layer=UI.Widget:Extend('VoxMatchHud')
local M={}
local orange={255,106,19,255}
local blue={46,168,255,255};local red={255,74,61,255};local roles={assault='突击',heavy='重装',sniper='狙击'}
local function Panel(vg,x,y,w,h,color,cut)
    D.Panel(vg,x,y,w,h,cut or 10,color or {11,13,17,235},{255,255,255,20})
end
function Layer:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.session;local b=s.battle;local rule=b.rules
    local k=math.min(r.w/1920,r.h/1080);local w,h=r.w/k,r.h/k
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k)
    local cfg=require('combat.ArenaData').modes[b.mode]
    local avw=cfg.size*44;local mid=b.mode=='conquest' and 274 or 194
    local cx=w/2;local span=avw*2+76*2+mid+24;local x=cx-span/2
    for _,team in ipairs({'blue','red'}) do
        local entries={};for _,e in ipairs(b.entries) do if e.unit.team==team then entries[#entries+1]=e end end
        local ax=team=='blue' and x or x+span-avw
        for i,e in ipairs(entries) do local u=e.unit;local px=ax+(i-1)*44;local color=u==b.player and orange or team=='blue' and blue or red
            local points={px+6,14,px+40,14,px+34,60,px,60}
            D.Path(vg,points);nvgFillColor(vg,nvgRGBA(26,29,34,255));nvgFill(vg)
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .32);Paint.Image(vg,'UI/Avatars/'..e.member.avatar..'.jpg',{x=px,y=14,w=40,h=46},1,.5,points);nvgRestore(vg)
            D.Rect(vg,px,56,34,4,color);D.Rect(vg,px+3,51,34*u:Health(),3,D.white)
            if not u.alive then D.Path(vg,{px,49,px+38,22,px+40,25,px+2,52});nvgFillColor(vg,D.Color(red));nvgFill(vg) end
        end
        local sx=team=='blue' and x+avw+6 or cx+mid/2+6
        Panel(vg,sx,8,76,58,team=='blue' and {26,120,208,255} or {216,52,42,255})
        D.Text(vg,b.mode=='conquest' and string.format('%.0f',rule.score[team]) or rule.score[team],sx+38,11,34,D.white,'vox-title',NVG_ALIGN_CENTER)
        if b.mode=='elimination' then for i=1,2 do D.Rect(vg,sx+22+(i-1)*18,56,14,4,rule.score[team]>=i and D.white or {0,0,0,102}) end
        else D.Text(vg,b.mode=='conquest' and '%' or '米',sx+38,49,10,D.white,'vox-title',NVG_ALIGN_CENTER) end
    end
    Panel(vg,cx-mid/2,8,mid,b.mode=='conquest' and 80 or 58,{11,13,17,235},14)
    local left=rule.state=='prep' and math.max(0,math.ceil(rule.cfg.prep-rule.t)) or math.ceil(rule:TimeLeft())
    local clock=rule.state=='prep' and tostring(left) or string.format('%d:%02d',math.floor(left/60),left%60)
    D.Text(vg,clock,cx,10,b.mode=='conquest' and 20 or 30,rule.sudden and red or D.white,'vox-tabular',NVG_ALIGN_CENTER,nil,false,30)
    if b.mode=='conquest' then
        for i,p in ipairs(rule.points) do local xx=cx+(i-2)*62;local color=p.contested and orange or p.owner=='blue' and blue or p.owner=='red' and red or D.muted
            D.Path(vg,{xx,35,xx+14,49,xx,63,xx-14,49});nvgFillColor(vg,D.Color(color));nvgFill(vg)
            D.Text(vg,p.id,xx,39,19,D.white,'vox-title',NVG_ALIGN_CENTER)
            for j=1,3 do D.Rect(vg,xx-19+(j-1)*14,72,11,4,math.abs(p.v)*3>=j and (p.v>=0 and blue or red) or {255,255,255,34}) end
        end
    else
        D.Text(vg,rule.overtime and '加时' or rule.sudden and '决胜状态' or b.mode=='escort' and ((rule.half==1 and '上半场' or '下半场')..' · '..(rule.attack=='blue' and '进攻' or '防守')) or '歼灭战 · 第 '..rule.round..' 回合',cx,46,11,D.muted,'vox-title',NVG_ALIGN_CENTER,3)
    end
    require('ui.MatchObjectives').Draw(vg,s,w,h)
    require('ui.MatchComms').Draw(vg,self,b,w,h)
    local banner=b.banner
    if banner then
        local t=banner.age;local alpha=math.min(1,t/.35)*math.min(1,(3.2-t)/.3)
        nvgSave(vg);nvgGlobalAlpha(vg,alpha);local y=h*.24
        D.Rect(vg,w*.1,y,w*.8,150,{7,8,10,216});D.Rect(vg,w*.1,y,w*.8,2,D.orange);D.Rect(vg,w*.1,y+148,w*.8,2,D.orange)
        D.Text(vg,banner.tag,cx,y+15,13,D.orange,'vox-title',NVG_ALIGN_CENTER,8)
        D.Text(vg,banner.text,cx,y+41,76,D.white,'vox-title',NVG_ALIGN_CENTER,12, false,76)
        nvgRestore(vg)
    end
    if not b.player.alive and rule.state~='over' then D.Text(vg,'战车已被击毁 · 观战队友',cx,h-78,24,D.white,'vox-title',NVG_ALIGN_CENTER,3) end
    if rule.state=='over' or input:GetKeyDown(KEY_TAB) or s.touchScoreboard then
        local bw=math.min(1440,w*.94);local bh=830;local bx,by=(w-bw)/2,(h-bh)/2;local rowHeight=cfg.size==4 and 48 or 62
        self.resultRect={x=bx*k,y=by*k,w=bw*k,h=bh*k}
        Panel(vg,bx,by,bw,bh,{11,13,17,242},26)
        local over=rule.state=='over';local title=over and (rule.winner=='blue' and '胜利' or rule.winner=='red' and '失利' or '平局') or cfg.name
        D.Text(vg,title,bx+36,by+30,over and 92 or 48,rule.winner=='red' and red or blue,'vox-title',nil,10)
        D.Text(vg,rule.score.blue..' : '..rule.score.red,bx+bw-36,by+64,40,D.white,'vox-tabular',NVG_ALIGN_RIGHT)
        local y=by+145
        for _,team in ipairs({'blue','red'}) do
            D.Text(vg,team=='blue' and '蓝队' or '红队',bx+34,y,24,team=='blue' and blue or red,'vox-title',nil,5)
            D.Text(vg,'击毁       阵亡          伤害',bx+bw-34,y+10,12,D.muted,'vox-title',NVG_ALIGN_RIGHT,3);y=y+40
            for _,e in ipairs(b.entries) do if e.unit.team==team then local u=e.unit;local st=b.stats[u]
                D.Rect(vg,bx+34,y,bw-68,rowHeight,u==b.player and {255,106,19,38} or {255,255,255,10})
                D.Rect(vg,bx+34,y,4,rowHeight,u==b.player and orange or team=='blue' and blue or red)
                Paint.Image(vg,'UI/Avatars/'..e.member.avatar..'.jpg',{x=bx+38,y=y,w=rowHeight,h=rowHeight},1,.5)
                D.Text(vg,u.name,bx+116,y+6,21,D.white,'vox-title')
                D.Text(vg,roles[e.member.role] or '机修师',bx+116,y+rowHeight-19,12,D.muted,'vox-title',nil,2)
                D.Text(vg,st.kills,bx+bw-340,y+18,22,D.white,'vox-tabular',NVG_ALIGN_CENTER)
                D.Text(vg,st.deaths,bx+bw-240,y+18,22,D.white,'vox-tabular',NVG_ALIGN_CENTER)
                D.Text(vg,math.floor(st.damage+.5),bx+bw-80,y+20,19,D.white,'vox-tabular',NVG_ALIGN_RIGHT)
                y=y+rowHeight+5
            end end
            y=y+16
        end
        if over then D.Rect(vg,bx,by+bh-90,bw,1,{255,255,255,20}) end
    else self.resultRect=nil end
    nvgRestore(vg)
end
function M.Attach(session,root)
    local layer=Layer{position='absolute',width='100%',height='100%',pointerEvents='none'};layer.session=session;root:AddChild(layer)
    local exit=require('ui.SourceButton'){text='退出对局',sourceKind='flat',pointerEvents='auto',position='absolute',right=14,top=12,width=112,height=34,onClick=function() session.wantsReturn=true end};root:AddChild(exit)
    local back=require('ui.SourceButton'){text='返回机库',sourceKind='flat',position='absolute',width=170,height=52,visible=false,onClick=function() session.wantsReturn=true end};root:AddChild(back)
    local retry=require('ui.SourceButton'){text='再来一局',sourceKind='flat',position='absolute',width=170,height=52,visible=false,onClick=function() session.battle:Restart() end};root:AddChild(retry)
    local result={layer=layer,exit=exit,back=back,retry=retry}
    function result.Update()
        local over=session.battle.rules.state=='over';back:SetVisible(over);retry:SetVisible(over)
        local r=layer.resultRect
        if over and r then
            local k=math.min(r.w/1440,r.h/830)
            back:SetStyle({left=r.x+r.w-376*k,top=r.y+r.h-72*k,width=170*k,height=52*k})
            retry:SetStyle({left=r.x+r.w-190*k,top=r.y+r.h-72*k,width=170*k,height=52*k})
        end
    end
    return result
end
return M
