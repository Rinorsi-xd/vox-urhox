-- Frozen matchHud.js banners: source queue, timings, CSS curves and dimensions.
local M={}
local colors={win={46,168,255,255},lose={255,74,61,255},warn={255,106,19,255},go={255,211,106,255}}
local white={255,255,255,255}
local function Now() return Time:GetSystemTime()/1000 end
local function Start(owner,item,now) item.startedAt=now;item.age=0;owner.banner=item end
function M.Push(owner,text,tag,sub,cls,ms,mini)
    local item={text=text,tag=tag or '',sub=sub or '',cls=cls or '',duration=(ms or 2600)/1000,mini=mini==true}
    if owner.banner and owner.banner.text==text then return false end
    owner.bannerQueue=owner.bannerQueue or {}
    if owner.banner then
        if #owner.bannerQueue<3 then owner.bannerQueue[#owner.bannerQueue+1]=item;return true end
        return false
    end
    Start(owner,item,Now());return true
end
function M.Update(owner,now)
    local item=owner.banner;if not item then return end
    now=now or Now();item.age=math.max(0,now-item.startedAt)
    if now>=item.startedAt+item.duration+.3 then
        owner.banner=nil
        local nextItem=owner.bannerQueue and table.remove(owner.bannerQueue,1)
        if nextItem then Start(owner,nextItem,now) end
    end
end
function M.Clear(owner) owner.banner=nil;owner.bannerQueue={} end
local function Notice(text,sub,cls,ms,tag,mini) return {text=text,sub=sub,cls=cls,ms=ms,tag=tag,mini=mini} end
local function Round(n) return math.floor((n or 0)+.5) end
local function Fmt(t) t=t or 0;return string.format('%d:%02d',math.floor(t/60),math.floor(t%60)) end
function M.ForEvent(b,e,world)
    local r=b.rules;local kind=e.type;local blue=e.team=='blue';local attack=(e.attack or r.attack)=='blue'
    if b.mode=='elimination' then
        if kind=='roundPrep' then
            local final=e.final==true or r:Final()
            return Notice(final and '决胜局' or '第 '..e.round..' 回合','比分 '..r.score.blue..' : '..r.score.red..' · '..r.cfg.prep..' 秒后出发',final and 'warn' or 'prep',3000,final and 'FINAL ROUND' or 'ROUND '..e.round)
        elseif kind=='roundStart' then return Notice('出击！','消灭全部敌人','go',1800,'ENGAGE')
        elseif kind=='suddenDeath' then return Notice('决胜时刻','最后 1 分钟 · 维修失效 · 时间到比剩车数和剩余耐久','warn',3200,'FINAL MINUTE')
        elseif kind=='roundEnd' then
            local alive=e.alive or world and world.alive or {blue=0,red=0};local hp=e.hp or world and world.hp or {}
            local sub=e.how=='wipe' and '拆光对手' or e.how=='alive' and '时间到 · 剩车 '..alive.blue..' : '..alive.red
                or e.how=='hp' and '时间到 · 剩车数相同 · 剩余耐久 '..Round((hp.blue or 0)*100)..'% : '..Round((hp.red or 0)*100)..'%' or ''
            local score=e.score or r.score
            return Notice(e.winner=='blue' and '回合胜利' or e.winner and '回合失利' or '回合平局',sub,e.winner=='blue' and 'win' or e.winner and 'lose' or 'prep',3200,'ROUND '..e.round..' · '..score.blue..' : '..score.red)
        end
    elseif b.mode=='conquest' then
        if kind=='roundPrep' then return Notice('站点争夺',r.cfg.prep..' 秒后出发 · 每个站点三个节点，推满才算占领','prep',3000,'CONQUEST')
        elseif kind=='roundStart' then return Notice('出击！','抢下 A · B · C 三个站点','go',1800,'ENGAGE')
        elseif kind=='pointTaken' then return Notice((blue and '我方' or '敌方')..'占领 '..e.id..' 点','我方 '..r:Owned('blue')..' 个站点 · 敌方 '..r:Owned('red')..' 个',blue and 'win' or 'lose',1800,'POINT '..e.id..' SECURED',true)
        elseif kind=='pointLost' then return Notice((blue and '我方' or '敌方')..'失去 '..e.id..' 点','一个节点被推掉了',blue and 'lose' or 'win',1600,'POINT '..e.id..' LOST',true)
        elseif kind=='shieldDown' then return Notice(blue and '我方护盾熄灭' or '敌方护盾熄灭',blue and '三个站点全丢了 · 反应堆正在被偷分' or '去打敌方反应堆上的质子，偷他们的分',blue and 'lose' or 'warn',3000,'SHIELD DOWN')
        elseif kind=='shieldUp' then return Notice(blue and '我方护盾恢复' or '敌方护盾恢复','','prep',1600,'SHIELD ONLINE',true)
        elseif kind=='overtime' then return Notice('加时','比分持平 · 下一次占点或击毁定胜负','warn',3000,'OVERTIME') end
    elseif b.mode=='escort' then
        if kind=='halfPrep' then return Notice(e.half==1 and '上半场' or '下半场',attack and '我方进攻 · 贴着运输车把它推到北要塞' or '我方防守 · 守住运输车，别让它过去','prep',3000,attack and 'ATTACK' or 'DEFEND')
        elseif kind=='halfStart' then return Notice('出击！',attack and '推车！' or '拦住运输车！','go',1800,'ENGAGE')
        elseif kind=='checkpoint' then return Notice('检查点 '..e.n,'加时 '..Round(e.bonus or r.c.bonus)..' 秒'..(attack and ' · 复活点前移' or ''),attack and 'win' or 'lose',2000,'CHECKPOINT',true)
        elseif kind=='overtime' then return Notice('加时','进攻方还贴着车 · 没人推 5 秒结束','warn',3000,'OVERTIME')
        elseif kind=='halfEnd' then return Notice(e.done and '运输车到站' or '时间到',(attack and '我方' or '敌方')..'推进 '..Round(e.dist)..' 米'..(e.done and ' · 用时 '..Fmt(e.time) or ''),attack and 'win' or 'lose',3200,r.half==1 and 'HALF TIME' or 'FULL TIME') end
    end
end
function M.Scale(width,height,touch)
    local ref=touch and 600 or 1080
    return math.min(width/(ref*16/9),height/ref)*(touch and .8 or 1)
end
function M.State(item,h)
    local Ease=require('ui.SourceButtonMotion').Ease;local age=math.max(0,item.age or 0)
    local out=math.max(0,(age-item.duration)/.3);local fade=Ease(1-math.min(1,out),'css-ease-out')
    local band=Ease(age/.35,false)
    local tx=Ease((age-.08)/.5,false)
    local title=Ease((age-.08)/.7,false)
    return {y=h*(item.mini and .16 or .24),height=item.mini and 96 or 150,
        bandAlpha=out>0 and fade or band,bandScale=out>0 and .7+.3*fade or band,
        textAlpha=out>0 and fade or tx,textY=out>0 and 0 or 8*(1-tx),textScale=out>0 and .7+.3*fade or 1,
        size=item.mini and 44 or 76,spacing=(item.mini and 8 or 12)+(40-(item.mini and 8 or 12))*(1-title),blur=6*(1-title),
        tagSize=item.mini and 11 or 13,tagSpacing=item.mini and 6 or 8,color=colors[item.cls] or white}
end
local function FadeSpan(vg,D,x,y,w,h,color)
    D.Path(vg,{x,y,x+w/2,y,x+w/2,y+h,x,y+h});D.Gradient(vg,x,y,w/2,h,{color[1],color[2],color[3],0},color,true)
    D.Path(vg,{x+w/2,y,x+w,y,x+w,y+h,x+w/2,y+h});D.Gradient(vg,x+w/2,y,w/2,h,color,{color[1],color[2],color[3],0},true)
end
function M.Draw(vg,item,w,h)
    if not item then return end
    local D=require 'ui.SourceDraw';local state=M.State(item,h);local y,bh=state.y,state.height;local cx=w/2;local color=state.color
    nvgSave(vg);nvgTranslate(vg,0,y+bh/2);nvgScale(vg,1,state.bandScale);nvgGlobalAlpha(vg,state.bandAlpha)
    for _,s in ipairs({{0,.22,0,216},{.22,.5,216,230},{.5,.78,230,216},{.78,1,216,0}}) do
        local x,width=w*s[1],w*(s[2]-s[1]);D.Path(vg,{x,-bh/2,x+width,-bh/2,x+width,bh/2,x,bh/2})
        D.Gradient(vg,x,-bh/2,width,bh,{7,8,10,s[3]},{7,8,10,s[4]},true)
    end
    for _,ly in ipairs({-bh/2,bh/2-2}) do
        require('ui.WorkshopPaint').Glow(vg,w*.1,ly,w*.8,2,14,color,.55)
        FadeSpan(vg,D,w*.1,ly,w*.8,2,color)
    end
    nvgRestore(vg)
    local ta,td=D.FontMetrics(vg,state.tagSize,'vox-body');local sa,sd=D.FontMetrics(vg,15,'vox-body')
    local tagHeight=item.tag~='' and ta+td or 0;local subHeight=sa+sd
    local before,after=item.mini and 2 or 4,item.mini and 3 or 6
    local total=tagHeight+before+state.size+after+subHeight;local top=-total/2
    nvgSave(vg);nvgTranslate(vg,0,y+bh/2+state.textY);nvgScale(vg,1,state.textScale);nvgGlobalAlpha(vg,state.textAlpha)
    if tagHeight>0 then
        local tw=D.Width(vg,item.tag,state.tagSize,'vox-body',state.tagSpacing)
        D.Rect(vg,cx-tw/2-58,top+tagHeight/2-1,46,2,color);D.Rect(vg,cx+tw/2+12,top+tagHeight/2-1,46,2,color)
        D.Text(vg,item.tag,cx,top,state.tagSize,color,'vox-body',NVG_ALIGN_CENTER,state.tagSpacing,false,tagHeight)
    end
    nvgFontBlur(vg,state.blur)
    D.Text(vg,item.text,cx,top+tagHeight+before,state.size,white,'vox-title',NVG_ALIGN_CENTER,state.spacing,false,state.size,
        {{blur=30,color={color[1],color[2],color[3],153}},{y=4,color={0,0,0,170}}})
    nvgFontBlur(vg,0)
    D.Text(vg,item.sub,cx,top+tagHeight+before+state.size+after,15,{255,255,255,200},'vox-body',NVG_ALIGN_CENTER,3,false,subHeight)
    nvgRestore(vg)
end
return M
