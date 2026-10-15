-- Frozen MatchHud._teams/result and the final production CSS cascade.
local D=require 'ui.SourceDraw'
local Paint=require 'ui.WorkshopPaint'
local Motion=require 'combat.MvpMotion'
local Ease=require('ui.SourceButtonMotion').Ease
local M={}
local blue={46,168,255,255};local red={255,74,61,255};local gold={255,211,106,255}
local roles={assault='突击',heavy='重装',sniper='狙击',hover='悬浮快攻'}
local labels={'等级','击毁','助攻','阵亡','伤害','得分'}
local widths={70,80,80,80,120,110}
function M.Update(layer,b,visible,dt)
    local identity=visible and (b.rules.state=='over' and b.result or b.rules) or false
    if layer.boardIdentity~=identity then layer.boardIdentity=identity;layer.boardAge=0 end
    layer.boardAge=math.min(.2,(layer.boardAge or 0)+math.max(0,dt or 0))
    layer.boardAlpha=visible and Ease(layer.boardAge/.2,'css-ease-out') or 0
end
local function Reward(vg,result,x,y)
    local runs={{'段位分',16,'vox-body',false},
        {(result.delta>=0 and '+' or '')..result.delta,22,'vox-display',true},
        {'（'..result.profile.rating..'） · 经验',16,'vox-body',false},
        {'+'..result.xp,22,'vox-display',true},
        {' · 等级 '..result.profile.level,16,'vox-body',false}}
    for _,run in ipairs(runs) do
        if run[4] then x=x+4 end
        D.Text(vg,run[1],x,y,run[2],run[4] and D.white or {255,255,255,176},run[3],nil,1,true)
        x=x+D.Advance(vg,run[1],run[2],run[3],1)+(run[4] and 4 or 0)
    end
    return x
end
local function Rows(layer,b)
    local key=tostring(b.rules)..':'..tostring(b.result)..':'..math.floor(b.clock*10)
    if layer.boardKey==key then return layer.boardRows end
    local teams={blue={},red={}}
    for i,e in ipairs(b.entries) do teams[e.unit.team][#teams[e.unit.team]+1]={entry=e,index=i,score=Motion.Score(b.stats[e.unit])} end
    for _,list in pairs(teams) do table.sort(list,function(a,c) return a.score==c.score and a.index<c.index or a.score>c.score end) end
    layer.boardKey=key;layer.boardRows=teams;return teams
end
local function Fit(vg,text,size,width,font)
    text=tostring(text);if D.Width(vg,text,size,font)<=width then return text end
    local chars={};for _,cp in utf8.codes(text) do chars[#chars+1]=utf8.char(cp) end
    repeat table.remove(chars) until #chars==0 or D.Width(vg,table.concat(chars)..'...',size,font)<=width
    return table.concat(chars)..'...'
end
function M.Draw(vg,layer,b,w,h,k,cfg)
    if b.rules.state=='over' and not b.result then layer.resultRect=nil;return end
    local over=b.rules.state=='over';local teams=Rows(layer,b)
    local header=over and 133.796875 or 94
    local teamHeight=12+2*(29+8+26+5+cfg.size*67)+16+22
    local bh=header+teamHeight+(over and 118 or 0);local bw=math.min(1440,w*.94)
    local bx,by=(w-bw)/2,(h-bh)/2+bh*.02*(1-(layer.boardAlpha or 1))
    nvgSave(vg);nvgGlobalAlpha(vg,layer.boardAlpha or 1)
    Paint.Glow(vg,bx,by+4,bw,bh,12,{8,15,28},85/255)
    D.Path(vg,{bx,by,bx+bw-26,by,bx+bw,by+26,bx+bw,by+bh,bx+26,by+bh,bx,by+bh-26})
    nvgFillColor(vg,nvgRGBA(16,34,56,245));nvgFill(vg)
    D.Path(vg,{bx,by,bx+bw-26,by,bx+bw,by+26,bx+bw,by+header,bx,by+header})
    nvgFillColor(vg,nvgRGBA(27,53,78,255));nvgFill(vg)
    D.Rect(vg,bx,by+header-1,bw,1,{255,255,255,20})
    local winner=b.rules.winner;local title=over and (winner=='blue' and '胜利' or winner=='red' and '失败' or '平局') or cfg.name
    D.Text(vg,title,bx+(over and 36 or 34),by+(over and 30 or 22),over and 92 or 34,over and (winner=='red' and red or winner=='blue' and blue or D.white) or D.white,'vox-title',nil,over and 10 or 4,false,over and 82.8 or 34,
        over and winner and {{blur=40,color=winner=='red' and {255,74,61,102} or {46,168,255,102}}} or nil)
    if not over then
        D.Text(vg,cfg.en..' · '..cfg.size..'V'..cfg.size..' · 坠舰陨坑',bx+34,by+62,12,{255,106,19,255},'vox-title',nil,5)
        local state=b.mode=='elimination' and ('第 '..b.rules.round..' 回合'..(b.rules.sudden and ' · 决胜时刻' or ''))
            or b.mode=='escort' and (b.rules.half==1 and '上半场' or '下半场') or b.rules.overtime and '加时' or '进行中'
        local right=bx+bw-34
        layer.boardTimeWidth=D.Width(vg,state,14,'vox-body',3)
        D.Text(vg,state,right,by+23.5,14,{255,255,255,160},'vox-body',NVG_ALIGN_RIGHT,3)
        local left=math.max(0,math.ceil(b.rules:TimeLeft()))
        D.Text(vg,string.format('%d:%02d',math.floor(left/60),left%60),right,by+41.5,28,D.white,'vox-display',NVG_ALIGN_RIGHT)
    end
    local sc=b.rules.score;local suffix=b.mode=='conquest' and '%' or b.mode=='escort' and '米' or ''
    local text=math.floor(sc.blue)..suffix;local other=math.floor(sc.red)..suffix;local size=over and 40 or 44
    local colonWidth=D.Width(vg,':',22,'vox-display')
    local tx=over and bx+36+D.Width(vg,title,92,'vox-title',10)+28 or bx+bw-56-layer.boardTimeWidth-D.Width(vg,text,size,'vox-display')-D.Width(vg,other,size,'vox-display')-colonWidth-28
    local scoreY=over and by+header-66 or by+27.5
    D.Text(vg,text,tx,scoreY,size,over and D.white or blue,'vox-display',nil,over and 2 or 0)
    tx=tx+D.Width(vg,text,size,'vox-display',over and 2 or 0)+14;D.Text(vg,':',tx,scoreY+6,22,{255,255,255,96},'vox-display')
    tx=tx+colonWidth+14;D.Text(vg,other,tx,scoreY,size,over and D.white or red,'vox-display',nil,over and 2 or 0)
    if over then for i,event in ipairs(b.rules.history or {}) do
        local x=bx+bw-36-(#b.rules.history-i+1)*40;local y=by+header-30
        D.Path(vg,{x+5,y,x+39,y,x+34,y+10,x,y+10});nvgFillColor(vg,D.Color(event.winner=='blue' and blue or event.winner=='red' and red or {255,255,255,32}));nvgFill(vg)
    end end
    local x,y=bx+34,by+header+12;local rw=bw-68;local nameWidth=rw-602
    local centers={};local nextX=x+62+nameWidth
    for i,width in ipairs(widths) do centers[i]=nextX+width/2;nextX=nextX+width end
    for _,team in ipairs({'blue','red'}) do
        local list=teams[team];local alive,damage=0,0
        for _,row in ipairs(list) do local e=row.entry;alive=alive+(e.unit.alive and 1 or 0);damage=damage+b.stats[e.unit].damage end
        local name=team=='blue' and '蓝队 · 我方' or '红队 · 敌方';D.Text(vg,name,x,y,24,team=='blue' and blue or red,'vox-title',nil,5)
        D.Text(vg,alive..' / '..#list..' 存活 · 总伤害 '..D.Number(damage),x+D.Width(vg,name,24,'vox-title',5)+14,y+12,12,{255,255,255,112},'vox-body',nil,3)
        y=y+37;D.Text(vg,'机修师',x+78,y+5.5,12,{255,255,255,112},'vox-body',nil,3)
        for i,label in ipairs(labels) do D.Text(vg,label,centers[i],y+5.5,12,{255,255,255,112},'vox-body',NVG_ALIGN_CENTER,3) end;y=y+31
        for _,row in ipairs(list) do local e=row.entry;local u=e.unit;local st=b.stats[u];local me=u==b.player;local isMvp=over and b.mvp==e
            if me then D.Path(vg,{x,y,x+rw,y,x+rw,y+62,x,y+62});D.Gradient(vg,x,y,rw,62,{122,216,255,64},{122,216,255,16},true)
            else D.Rect(vg,x,y,rw,62,{28,53,75,255}) end
            D.Rect(vg,x,y,4,62,me and D.orange or team=='blue' and blue or red)
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .4);Paint.Image(vg,'UI/Avatars/'..e.member.avatar..'.jpg',{x=x,y=y,w=62,h=62},1,.5);nvgRestore(vg)
            local display=Fit(vg,u.name,21,nameWidth-16-(isMvp and 60 or 0),'vox-title')
            nvgSave(vg);nvgGlobalAlpha(vg,u.alive and 1 or .5);D.Text(vg,display,x+78,y+7,21,D.white,'vox-title');nvgRestore(vg)
            if isMvp then local mx=x+86+D.Width(vg,display,21,'vox-title');D.Rect(vg,mx,y+10,43,17,gold);D.Text(vg,'MVP',mx+6,y+11,11,{26,18,6,255},'vox-body',nil,2) end
            D.Text(vg,(me and '你' or roles[e.member.role] or '')..' · 段位 '..e.member.rating,x+78,y+39,12,{255,255,255,128},'vox-body',nil,2)
            local values={e.member.level,st.kills,st.assists or 0,st.deaths,D.Number(st.damage),math.floor(row.score+.5)}
            for i,value in ipairs(values) do local size=i==1 and 18 or i==5 and 19 or 22
                D.Text(vg,value,centers[i],y+(62-size*1.2)/2,size,i==6 and gold or i==1 and {255,255,255,176} or D.white,'vox-display',NVG_ALIGN_CENTER)
            end;y=y+67
        end;y=y+16
    end
    if over then
        local fy=by+header+teamHeight;D.Rect(vg,bx,fy,bw,1,{255,255,255,20})
        local gainEnd=Reward(vg,b.result,bx+36,fy+52)
        if b.mvp then D.Text(vg,Fit(vg,'★ 本局 MVP：'..b.mvp.unit.name,15,math.max(0,bx+bw-344-gainEnd-18),'vox-body'),gainEnd+18,fy+34.5,15,gold,'vox-body',nil,2) end
        D.Text(vg,'本局为 AI 对战（离线），对手和队友均为电脑控制',bx+36,fy+87,12,{255,255,255,85},'vox-body',nil,2)
        layer.resultRect={x=bx*k,y=by*k,w=bw*k,h=bh*k,scale=k,buttonY=(fy+19)*k}
    else layer.resultRect=nil end
    nvgRestore(vg)
end
return M
