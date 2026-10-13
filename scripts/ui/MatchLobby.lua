-- Frozen matchLobby.js composition. The shared loading overlay owns input.
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Motion=require 'ui.SourceButtonMotion'
local M={};local blue={46,168,255,255};local red={255,74,61,255}
local orange={255,106,19,255}
local roles={assault='突击',heavy='重装',sniper='狙击',hover='悬浮快攻'}
function M.Emblem(vg,x,y,size,t)
    for _,layer in ipairs({{'ring-t',t*math.pi*2/30},{'ring-s',-t*math.pi*2/7},{'ring-txt',t*math.pi*2/60},{'base',0},{'gear',t*math.pi*2/12},{'core',0}}) do
        nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,layer[2]);Paint.Image(vg,'UI/Match/emblem-'..layer[1]..'.png',{x=-size/2,y=-size/2,w=size,h=size},1,.5);nvgRestore(vg)
    end
end
function M.Dependencies(roster)
    local paths={'UI/Match/division-insignia.png','UI/Modes/map-crater.jpg'}
    for _,layer in ipairs({'base','core','ring-t','ring-s','ring-txt','gear'}) do paths[#paths+1]='UI/Match/emblem-'..layer..'.png' end
    for _,team in ipairs({'blue','red'}) do for _,member in ipairs(roster[team]) do paths[#paths+1]='UI/Avatars/'..member.avatar..'.jpg' end end
    return paths
end
function M.Draw(page,vg,w,h)
    local flow=page.owner;local match=flow.match;local t=match.age;local cfg=match.cfg;local roster=match.roster
    D.Rect(vg,0,0,w,h,{7,8,10,255})
    if flow.artReady then nvgSave(vg);nvgGlobalAlpha(vg,.22);Paint.Image(vg,'UI/Modes/map-crater.jpg',{x=-w*.04,y=-h*.04,w=w*1.08,h=h*1.08},1.05+.07*(t%80)/80,.5);nvgRestore(vg) end
    require('ui.MatchBackground').Draw(vg,w,h,flow.elapsed,w/2,match.stage=='roster' and h*.46 or h/2-145)
    for _,y in ipairs({0,h-14}) do
        nvgSave(vg);nvgScissor(vg,0,y,w,14)
        for x=-56+(t*56/2.4)%56,w+28,28 do D.Path(vg,{x,y,x+14,y,x+28,y+14,x+14,y+14});nvgFillColor(vg,nvgRGBA(255,106,19,140));nvgFill(vg) end
        nvgRestore(vg)
    end
    if flow.artReady then Paint.Image(vg,'UI/Match/division-insignia.png',{x=34,y=30,w=58,h=58},1,.5) end
    D.Text(vg,'星际前途 · 特别安保部',106,30,22,D.white,'vox-title',nil,3)
    D.Text(vg,'战地机修师 · 出勤调度终端',106,62,11,D.muted,'vox-title',nil,4)
    D.Text(vg,'MATCHMAKING',w-34,34,22,orange,'vox-title',NVG_ALIGN_RIGHT,3)
    D.Text(vg,'SECTOR 7 · CRASH CRATER',w-34,65,11,D.muted,'vox-title',NVG_ALIGN_RIGHT,4)
    D.Text(vg,'NODE 07-ARGUS · LINK STABLE',34,h-62,11,D.muted,'vox-title',nil,4)
    D.Text(vg,'QUEUE // PVP-SIM',34,h-42,11,D.muted,'vox-title',nil,4)
    D.Text(vg,'AI 对战 · 离线',w-34,h-42,11,D.muted,'vox-title',NVG_ALIGN_RIGHT,4)
    if match.stage=='queue' or match.stage=='found' then
        local size=math.min(h*.46,420);local cx,cy=w/2,h/2-145
        if flow.artReady then M.Emblem(vg,cx,cy,size,t) end
        D.Text(vg,match.stage=='found' and '对局已找到' or '正在匹配',cx,cy+size/2+18,64,match.stage=='found' and orange or D.white,'vox-title',NVG_ALIGN_CENTER,8)
        D.Text(vg,match.stage=='found' and 'MATCH FOUND' or 'SEARCHING FOR MATCH',cx,cy+size/2+90,14,orange,'vox-title',NVG_ALIGN_CENTER,12)
        local yy=cy+size/2+126
        D.Text(vg,string.format('0:%02d',math.floor(t)),cx-55,yy,40,D.white,'vox-tabular',NVG_ALIGN_CENTER,4)
        D.Text(vg,string.format('预计 0:%02d',math.floor(match.wait+3+.5)),cx+45,yy+16,14,D.muted,'vox-title',nil,3)
        local total=cfg.size*2;local lit=math.min(total,1+math.floor((t/match.wait)^.8*total));local span=cfg.size*84+24
        for i=1,total do local team=i<=cfg.size and 'blue' or 'red';local slot=(i-1)%cfg.size;local index=slot*2+(team=='blue' and 1 or 2)
            local x=cx-span/2+slot*42+(team=='red' and cfg.size*42+24 or 0)
            D.Path(vg,{x+5,yy+68,x+39,yy+68,x+34,yy+78,x,yy+78});nvgFillColor(vg,D.Color(index<=lit and (team=='blue' and blue or red) or {255,255,255,20}));nvgFill(vg)
        end
        D.Text(vg,cfg.name..' · '..cfg.size..'V'..cfg.size..' · T'..match.tier..' · 坠舰陨坑',cx,yy+96,14,{255,255,255,160},'vox-title',NVG_ALIGN_CENTER,3)
        if match.stage=='queue' then
            page.cancelRect={x=cx-115,y=yy+140,w=230,h=46};D.Panel(vg,cx-115,yy+140,230,46,12,{11,12,15,176},{255,255,255,64})
            D.Text(vg,'取消匹配',cx-10,yy+153,15,D.white,'vox-title',NVG_ALIGN_CENTER,5)
            D.Text(vg,'ESC',cx+70,yy+155,11,D.muted,'vox-tabular')
        elseif t<.6 then D.Rect(vg,0,0,w,h,{255,106,19,115*(1-t/.6)}) end
        return
    end
    D.Text(vg,cfg.en..' · '..cfg.size..'V'..cfg.size,w/2,54,14,orange,'vox-title',NVG_ALIGN_CENTER,10)
    D.Text(vg,cfg.name,w/2,80,60,D.white,'vox-title',NVG_ALIGN_CENTER,10)
    local cardH=math.max(54,math.min(92,h*.084));local cardW=math.min(640,(w*.92-240)/2)
    local y=h*.22+(h*.48-(cfg.size*(cardH+10)+48))/2
    for _,team in ipairs({'blue','red'}) do
        local right=team=='red';local x=right and w/2+120 or w/2-120-cardW;local color=right and red or blue
        D.Text(vg,right and '红队' or '蓝队',right and x+cardW or x,y,30,color,'vox-title',right and NVG_ALIGN_RIGHT or nil,6)
        D.Text(vg,'平均 '..roster.rating[team],right and x+cardW-130 or x+130,y+12,13,D.muted,'vox-title',right and NVG_ALIGN_RIGHT or nil,3)
        for i,member in ipairs(roster[team]) do
            local progress=math.max(0,math.min(1,(t-.12-.09*(i-1))/.45));local ease=Motion.Ease(progress,false)
            local xx=x+(right and 60 or -60)*(1-ease);local yy=y+48+(i-1)*(cardH+10)
            nvgSave(vg);nvgGlobalAlpha(vg,ease)
            D.Panel(vg,xx,yy,cardW,cardH,18,{13,16,20,230},nil);D.Rect(vg,right and xx+cardW-4 or xx,yy,4,cardH,member.player and orange or color)
            if flow.artReady then Paint.Image(vg,'UI/Avatars/'..member.avatar..'.jpg',{x=right and xx+cardW-cardH or xx,y=yy,w=cardH,h=cardH},1,.5) end
            local tx=right and xx+cardW-cardH-16 or xx+cardH+16;local align=right and NVG_ALIGN_RIGHT or nil
            D.Text(vg,member.name,tx,yy+cardH/2-25,22,D.white,'vox-title',align,1)
            local subtitle=member.player and match.carName or (roles[member.role]..' · T'..member.tier)
            D.Text(vg,subtitle..' · 段位 '..member.rating,tx,yy+cardH/2+6,13,D.muted,'vox-title',align,2)
            local lx=right and xx+48 or xx+cardW-48
            D.Text(vg,'LV',lx,yy+cardH/2-24,14,D.muted,'vox-title',NVG_ALIGN_CENTER,1)
            D.Text(vg,member.level,lx,yy+cardH/2-3,24,D.white,'vox-title',NVG_ALIGN_CENTER)
            nvgRestore(vg)
        end
    end
    if flow.artReady then M.Emblem(vg,w/2,h*.46,190,t) end;D.Text(vg,'VS',w/2,h*.46+108,54,D.white,'vox-title',NVG_ALIGN_CENTER,6)
    local my=h*.76;if flow.artReady then Paint.Image(vg,'UI/Modes/map-crater.jpg',{x=0,y=my,w=w,h=h*.24},1,.4) end
    D.Rect(vg,0,my,w,h*.24,{7,8,10,150});D.Text(vg,'本局地图 · MAP',w*.05,h*.95-92,12,orange,'vox-title',nil,6)
    D.Text(vg,'坠舰陨坑',w*.05,h*.95-68,48,D.white,'vox-title',nil,6)
    D.Text(vg,'CRASH CRATER · 第 7 边境星区 · 600 × 600 米',w*.05,h*.95-15,13,D.muted,'vox-title',nil,2)
    local lw=math.min(520,w*.38);local lx=w*.95-lw
    D.Text(vg,flow.failed and '对局启动失败' or flow.progress==1 and '准备出击' or '正在进入战场…',w*.95,h*.95-42,14,flow.failed and red or D.white,'vox-title',NVG_ALIGN_RIGHT,4)
    D.Rect(vg,lx,h*.95-13,lw,6,{255,255,255,26});D.Rect(vg,lx,h*.95-13,lw*flow.progress,6,orange)
    if flow.failed then
        page.backRect={x=w*.95-112,y=h*.95-110,w=112,h=46};D.Panel(vg,page.backRect.x,page.backRect.y,112,46,0,{33,59,85,255})
        D.Text(vg,'返回',page.backRect.x+56,page.backRect.y+12,18,D.white,'vox-title',NVG_ALIGN_CENTER)
    end
end
return M
